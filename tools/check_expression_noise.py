"""Independent adverse-grid verification of arithmetic noise rejection.

Each fixture gives the expected glyph foreground explicitly. The sampler is a
separate boolean-rectangle implementation, not a translation of the CCL FSM.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time

import numpy as np
from noise_reference import cases, sampling_box, normalize

ROOT = Path(__file__).resolve().parents[1]
(ROOT/'verification/_scratch/check_expression_noise').mkdir(parents=True,exist_ok=True)
V = ROOT/'verification/noise'


def write_mem(path, values):
    path.write_text(''.join(f'{int(v):02x}\n' for v in np.asarray(values).ravel()), encoding='ascii')


def generate():
    V.mkdir(parents=True, exist_ok=True)
    scenes = cases()
    groups = []
    for size in sorted({c['grid'].shape[0] for c in scenes}):
        selected = [c for c in scenes if c['grid'].shape[0] == size]
        prefix = f'noise{size}'
        grids = [c['grid'] for c in selected]
        counts = [len(c['boxes']) for c in selected]
        boxes = np.zeros((len(selected), 5, 4), np.uint8)
        crops = np.zeros_like(boxes)
        samples = np.zeros((len(selected), 5, 784), np.uint8)
        labels = np.full((len(selected), 5), 15, np.uint8)
        rows = []
        for j, case in enumerate(selected):
            if case['boxes']:
                boxes[j, :len(case['boxes'])] = case['boxes']
            for i, box in enumerate(case['boxes']):
                crop = sampling_box(case['boxes'], i, size)
                crops[j, i] = crop
                # Ownership isolates this token's actual foreground from every
                # other token, even when their padded windows could overlap.
                glyph = case['foreground'].copy()
                glyph[:, :box[0]] = 0; glyph[:, box[1]+1:] = 0
                samples[j, i] = normalize(glyph, crop).ravel()
                labels[j, i] = case['labels'][i]
            rows.append(dict(name=case['name'], boxes=case['boxes'],
                labels=list(case['labels']), expected_expression_valid=case['expected_expression_valid'],
                allowed_reject_reasons=case['reject'], noise_min=case['noise_min'], tags=case['tags']))
        for suffix, data in (
            ('grids', grids), ('counts', counts), ('boxes', boxes), ('crops', crops),
            ('expected', samples), ('labels', labels),
            ('valid', [c['expected_expression_valid'] for c in selected]),
            ('reason_masks', [sum(1 << n for n in c['reject']) if c['reject'] else 1 for c in selected]),
            ('noise_min', [c['noise_min'] for c in selected])):
            write_mem(V/f'{prefix}_{suffix}.mem', data)
        groups.append(dict(grid=size, scenes=len(selected), prefix=prefix, cases=rows))
    report = dict(groups=groups, case_count=len(scenes),
        bit_count=sum(len(c['boxes'])*784 for c in scenes),
        expected_character_transactions=sum(len(c['boxes']) for c in scenes),
        oracle='Human-authored clean foreground and injected noise; independent boolean-rectangle normalization.',
        limits=['Synthetic occupancy-grid video enters after Sobel/continuity; not physical camera accuracy.',
          'Labels are supplied by the harness to exercise parser admission/rejection; MLP accuracy is covered by the separate full HDMI video test.'])
    (V/'FIXTURES.json').write_text(json.dumps(report, indent=2))
    return report


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--generate-only', action='store_true')
    args = ap.parse_args()
    report = generate()
    if args.generate_only:
        print('Generated', report['case_count'], 'noise scenes'); return
    simroot = (ROOT/'verification/_scratch/check_expression_noise')
    vsim = Path(os.environ.get('MODELSIM_VSIM', 'E:/ELEGtools/Modelsim_201/modelsim_ase/win32aloem/vsim.exe'))
    sources = [ROOT/'rtl/number/number_preprocess.v', ROOT/'rtl/number/expression_engine.v', V/'tb_expression_noise.sv']
    fixtures = sorted(V.glob('noise*.mem'))
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    source_hashes = {p.relative_to(ROOT).as_posix():sha(p) for p in sources}
    fixture_hashes = {p.relative_to(ROOT).as_posix():sha(p) for p in fixtures}
    for src in sources + fixtures:
        dst = simroot/src.relative_to(ROOT); dst.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(src, dst)
    include = '\n'.join(f'wire done{g["grid"]}; noise_test #(.G({g["grid"]}),.CASES({g["scenes"]}),.PREFIX("{g["prefix"]}")) t{g["grid"]}(done{g["grid"]});' for g in report['groups'])
    (simroot/'verification/noise/top.sv').write_text('`timescale 1ns/1ps\nmodule tb_expression_noise;\n'+include+'\ninitial begin wait('+ '&&'.join(f'done{g["grid"]}' for g in report['groups'])+');$display("PASS EXPRESSION_NOISE_ALL: every fixture checked");$finish;end\ninitial begin #400000000;$fatal(1,"noise suite timeout");end\nendmodule\n')
    ini = simroot/'verification/noise/noise.ini'
    ini.write_text('[Library]\nwork = verification/noise/work\nothers = '+(vsim.parent.parent/'modelsim.ini').as_posix()+'\n', encoding='ascii')
    script = simroot/'verification/noise/run.do'
    script.write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\nif {![file exists verification/noise/work]} {vlib verification/noise/work}\nvlog -modelsimini verification/noise/noise.ini -sv +incdir+. '+' '.join(p.relative_to(ROOT).as_posix() for p in sources)+' verification/noise/top.sv\nvsim -onfinish exit work.tb_expression_noise\nrun -all\nquit -code 1 -force\n', encoding='ascii')
    started = time.time(); print('Testing noise scenes:', simroot, flush=True)
    with (V/'console.log').open('w') as console:
        proc = subprocess.run([str(vsim), '-modelsimini', 'verification/noise/noise.ini', '-c', '-do', 'verification/noise/run.do', '-l', 'verification/noise/rtl.log'], cwd=simroot, stdout=console, stderr=subprocess.STDOUT, timeout=900)
    logpath = simroot/'verification/noise/rtl.log'
    output = logpath.read_text(encoding='utf-8', errors='replace') if logpath.exists() else ''
    if logpath.exists(): shutil.copy2(logpath, V/'rtl.log')
    passed = proc.returncode == 0 and 'PASS EXPRESSION_NOISE_ALL:' in output and not any(s in output for s in ('** Error:', '** Fatal:', '** Warning:', 'Not enough words', 'Failed to open readmem'))
    unchanged = all(sha(ROOT/name) == digest for name, digest in {**source_hashes, **fixture_hashes}.items())
    passed = passed and unchanged
    report.update(passed=passed, hardware_tested=False, seconds=round(time.time()-started, 3),
        source_hashes=source_hashes, fixture_hashes=fixture_hashes, input_unchanged=unchanged,
        summary=[s for s in output.splitlines() if 'PASS ' in s])
    (V/'VALIDATION.json').write_text(json.dumps(report, indent=2))
    print('EXPRESSION NOISE', 'PASS' if passed else 'FAIL', report['seconds'], flush=True)
    print('\n'.join(report['summary']) if passed else output[-15000:], flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__': main()
