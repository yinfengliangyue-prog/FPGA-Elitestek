"""Check persistent sampling windows and the bounded WAIT LAST display state."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time
import numpy as np
from noise_reference import normalize, projected_boxes, sampling_box

ROOT = Path(__file__).resolve().parents[1]
(ROOT/'verification/_scratch/check_expression_stability').mkdir(parents=True,exist_ok=True)
V = ROOT/'verification/stability'
V.mkdir(exist_ok=True)
scenes = []
BASE = [(7,26,24,65),(41,58,43,46),(73,88,24,65)]

def scene(name, left=8, right=25, shift=0, expected=None, blank=False, four=False,
          minus_left=42, expire=False, top=25, bottom=64):
    a=np.zeros((96,96),np.uint8)
    if not blank:
        def ring(x0,x1,y0,y1):
            a[y0:y1+1,x0]=a[y0:y1+1,x1]=1
            a[y0,x0:x1+1]=a[y1,x0:x1+1]=1
        if four:
            a[25:65,8]=1;a[25:65,20]=1
        else:ring(left+shift,right+shift,top,bottom)
        a[44:46,minus_left+shift:minus_left+shift+16]=1
        ring(74+shift,87+shift,25,64)
    boxes=projected_boxes(a)
    desired=[sampling_box(boxes,i,96) for i in range(len(boxes))]
    scenes.append(dict(name=name,grid=a,boxes=boxes,desired=desired,
                       crops=desired if expected is None else expected,expire=expire))

scene('initial',expected=BASE)
scene('one_cell_inward_deadband',left=9,expected=BASE)
scene('return_from_jitter',expected=BASE)
scene('one_cell_outward_still_inside_crop',left=7,expected=BASE)
expanded=[(5,26,24,65),BASE[1],BASE[2]]
scene('foreground_escape_expands_immediately',left=6,expected=expanded)
scene('shrink_observation_1',expected=expanded)
scene('shrink_observation_2',expected=expanded)
contracted=[(6,26,24,65),BASE[1],BASE[2]]
scene('shrink_observation_3_one_cell_step',expected=contracted)
scene('stop_shrinking_inside_deadband',expected=contracted)
scene('right_shrink_1',right=23,expected=contracted)
scene('right_shrink_2',right=23,expected=contracted)
scene('right_shrink_3',right=23,expected=[(6,25,24,65),BASE[1],BASE[2]])
scene('large_motion_reinitializes_all_windows',shift=6)
scene('character_count_change_reinitializes',four=True)
scene('brief_blank',blank=True)
scene('return_after_blank')
scene('wide_previous_character',right=29,minus_left=34)
scene('neighbour_gap_clamps_history',minus_left=31,
      expected=[(7,28,24,65),(30,50,43,46),BASE[2]])
scene('history_expires_without_inference',minus_left=31,expire=True)
scene('reset_before_vertical_jitter',expected=BASE)
scene('vertical_inward_deadband',top=26,bottom=63,expected=BASE)
scene('vertical_outward_still_inside',top=24,bottom=65,expected=BASE)
vertical=[(7,26,22,67),BASE[1],BASE[2]]
scene('top_and_bottom_escape_expand',top=23,bottom=66,expected=vertical)
scene('vertical_shrink_1',expected=vertical)
scene('vertical_shrink_2',expected=vertical)
vertical_small=[(7,26,23,66),BASE[1],BASE[2]]
scene('vertical_shrink_3',expected=vertical_small)
right_big=[(7,28,23,66),BASE[1],BASE[2]]
scene('right_foreground_escape_expands',right=27,expected=right_big)
scene('right_expanded_shrink_1',expected=right_big)
scene('right_expanded_shrink_2',expected=right_big)
scene('right_expanded_shrink_3',expected=[(7,27,23,66),BASE[1],BASE[2]])
scene('count_change_before_slow_motion',four=True)
scene('slow_motion_anchor',expected=BASE)
scene('slow_motion_1',shift=1,expected=BASE)
slow2=[(7,28,24,65),(41,60,43,46),(73,90,24,65)]
scene('slow_motion_2',shift=2,expected=slow2)
scene('slow_motion_3',shift=3,expected=slow2)
scene('slow_motion_4',shift=4,expected=[(8,30,24,65),(42,62,43,46),(74,92,24,65)])
slow5=[(12,31,24,65),(46,63,43,46),(78,93,24,65)]
scene('cumulative_drift_reacquires_at_5',shift=5,expected=slow5)
scene('slow_motion_after_reacquisition',shift=6,expected=slow5)

def mem(name,values):
    (V/name).write_text(''.join(f'{int(v):02x}\n' for v in np.asarray(values).ravel()),encoding='ascii')

counts=[len(s['boxes']) for s in scenes]
mem('grids.mem',[s['grid'] for s in scenes]);mem('counts.mem',counts)
mem('expire.mem',[s['expire'] for s in scenes])
boxes=np.zeros((len(scenes),5,4),np.uint8)
for i,s in enumerate(scenes):
    if s['boxes']:boxes[i,:len(s['boxes'])]=s['boxes']
mem('boxes.mem',boxes)
for mode in ('stable','bypass'):
    crops=np.zeros_like(boxes);bits=np.zeros((len(scenes),5,784),np.uint8)
    for i,s in enumerate(scenes):
        selected=s['crops'] if mode=='stable' else s['desired']
        for j,crop in enumerate(selected):
            crops[i,j]=crop
            glyph=s['grid'].copy();box=s['boxes'][j]
            glyph[:,:box[0]]=0;glyph[:,box[1]+1:]=0
            bits[i,j]=normalize(glyph,crop).ravel()
    mem(mode+'_crops.mem',crops);mem(mode+'_bits.mem',bits)

vsim=Path(os.environ.get('MODELSIM_VSIM','E:/ELEGtools/Modelsim_201/modelsim_ase/win32aloem/vsim.exe'))
sim=(ROOT/'verification/_scratch/check_expression_stability')
sources=['rtl/number/number_preprocess.v','rtl/number/expression_overlay.v',
         'verification/stability/tb_expression_stability.sv']
fixtures=sorted(V.glob('*.mem'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs={p.relative_to(ROOT).as_posix():sha(p) for p in [ROOT/s for s in sources]+fixtures}
for name in inputs:
    target=sim/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
(sim/'modelsim.ini').write_text('[Library]\nwork = work\nothers = '+(vsim.parent.parent/'modelsim.ini').as_posix()+'\n',encoding='ascii')
(sim/'run.do').write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\nif {![file exists work]} {vlib work}\nvlog -sv '+ ' '.join(sources)+'\nvsim -onfinish exit work.tb_expression_stability\nrun -all\nquit -code 1 -force\n',encoding='ascii')
print('Stability simulation:',sim,flush=True);started=time.time()
with (V/'console.log').open('w') as console:
    p=subprocess.run([str(vsim),'-c','-do','run.do','-l','rtl.log'],cwd=sim,stdout=console,stderr=subprocess.STDOUT,timeout=300)
log=(sim/'rtl.log').read_text(encoding='utf-8', errors='replace');(V/'rtl.log').write_text(log)
unchanged=all(sha(ROOT/n)==h for n,h in inputs.items())
passed=p.returncode==0 and 'PASS EXPRESSION_STABILITY_ALL' in log and unchanged and not any(s in log for s in ('** Error:','** Fatal:','** Warning:'))
report=dict(passed=passed,hardware_tested=False,input_unchanged=unchanged,
    seconds=round(time.time()-started,3),scenes=[s['name'] for s in scenes],
    source_hashes={n:h for n,h in inputs.items() if not n.endswith('.mem')},
    fixture_hashes={n:h for n,h in inputs.items() if n.endswith('.mem')},
    scope='Two-pixel video into production preprocessing; every normalized bit and crop checked against declared windows. Production overlay checked with a shortened grace timer; physical camera accuracy is not measured.',
    summary=[l for l in log.splitlines() if 'PASS ' in l])
(V/'VALIDATION.json').write_text(json.dumps(report,indent=2))
print('STABILITY','PASS' if passed else 'FAIL',report['seconds'],flush=True)
print('\n'.join(report['summary']) if passed else log[-9000:],flush=True)
raise SystemExit(0 if passed else 1)
