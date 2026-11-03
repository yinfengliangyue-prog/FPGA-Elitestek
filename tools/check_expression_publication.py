"""Verify diagnostic/result frame publication and result lock behavior."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
(ROOT/'verification/_scratch/check_expression_publication').mkdir(parents=True,exist_ok=True)
V = ROOT/'verification/hdmi'
runroot = (ROOT/'verification/_scratch/check_expression_publication')
vsim = Path(os.environ.get('MODELSIM_VSIM', 'E:/ELEGtools/Modelsim_201/modelsim_ase/win32aloem/vsim.exe'))
sources = ['rtl/number/expression_overlay.v', 'verification/number/tb_expression_publish.sv']
for name in sources:
    dest = runroot/name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT/name, dest)
(runroot/'modelsim.ini').write_text('[Library]\nwork = work\nothers = '
    + (vsim.parent.parent/'modelsim.ini').as_posix()+'\n')
(runroot/'run.do').write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
    'if {![file exists work]} {vlib work}\nvlog -sv '+ ' '.join(sources)
    +'\nvsim -onfinish exit work.tb_expression_publish\nrun -all\nquit -code 1 -force\n')
with (V/'publication_console.log').open('w') as console:
    result = subprocess.run([str(vsim), '-c', '-do', 'run.do', '-l', 'publication.log'],
        cwd=runroot, stdout=console, stderr=subprocess.STDOUT, timeout=90)
log = (runroot/'publication.log').read_text(encoding='utf-8', errors='replace')
(V/'publication.log').write_text(log)
passed = result.returncode==0 and 'PASS EXPRESSION_PUBLISH' in log and not any(
    marker in log for marker in ('** Error:', '** Fatal:', '** Warning:'))
report = dict(passed=passed, hardware_tested=False,
    summary=[line for line in log.splitlines() if 'PASS ' in line],
    source_hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sources})
(V/'PUBLICATION_VALIDATION.json').write_text(json.dumps(report, indent=2))
print('PUBLICATION', 'PASS' if passed else 'FAIL')
print('\n'.join(report['summary']) if passed else log[-7000:])
raise SystemExit(0 if passed else 1)
