from pathlib import Path
import subprocess,json,hashlib,time
P=Path(__file__).resolve().parents[1];V=P/'verification';LIB=V/'sim52ui'
SIM=Path(r'E:\ELEGtools\Modelsim_201\modelsim_ase\win32aloem')
def run(exe,*args):
 r=subprocess.run([str(SIM/(exe+'.exe')),*map(str,args)],cwd=V,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace')
 if r.returncode:raise RuntimeError(r.stdout)
 return r.stdout
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
sources={n:sha(P/n) for n in ['rtl/replay52/replay_raster52.v','verification/tb_ui52.sv']}
if not LIB.exists():run('vlib',LIB)
(V/'compile_ui52.log').write_text(run('vlog','-sv','-work',LIB,*[P/n for n in sources]),encoding='utf-8')
do=V/'run_ui52.do';do.write_text(f'onerror {{quit -force -code 2}}\nonbreak {{quit -force -code 1}}\nvsim -lib {{{LIB.as_posix()}}} tb_ui52\nrun -all\nquit -force -code 0\n')
out=run('vsim','-c','-do',do,'-l',V/'ui52.log')
assert 'PASS' in out and '** Fatal' not in out and '** Error' not in out,out
assert sources=={n:sha(P/n) for n in sources}
captures={}
for i,label in enumerate(['LIVE','REPLAY','COMPARE']):
 f=V/f'ui52_fixture_{i}.ppm';assert f.stat().st_size==6220817
 captures[label]={'file':f.name,'sha256':sha(f)}
(V/'VALIDATION_UI.json').write_text(json.dumps(dict(source_hashes=sources,captures=captures,synthetic_fixture=True,hardware_tested=False),indent=2))
print('\n'.join(x for x in out.splitlines() if 'PASS' in x),flush=True)
