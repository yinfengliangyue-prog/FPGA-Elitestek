from pathlib import Path
import subprocess,sys,json,hashlib,time,os,msvcrt
P=Path(__file__).resolve().parents[1];V=P/'verification'
SIM=Path(os.environ.get('MODELSIM_BIN',r'E:\ELEGtools\Modelsim_201\modelsim_ase\win32aloem'));LIB=V/('sim52hd' if '--hd' in sys.argv else 'sim52')
sim_lock=(V/(LIB.name+'.lock')).open('a+b')
if sim_lock.seek(0,2)==0:sim_lock.write(b'0');sim_lock.flush()
sim_lock.seek(0)
try:msvcrt.locking(sim_lock.fileno(),msvcrt.LK_NBLCK,1)
except OSError:raise SystemExit('This simulation suite is already running; wait for it to finish.')
def run(exe,*args):
 r=subprocess.run([str(SIM/(exe+'.exe')),*map(str,args)],cwd=V,text=True,errors='replace',stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 if r.returncode:raise RuntimeError(r.stdout)
 return r.stdout
if not LIB.exists():run('vlib',LIB)
rtl=[P/'rtl/frame_buffer/DC_FIFO.v',P/'rtl/edge/canny_stream_2ppc.v',P/'rtl/edge/edge_balanced_render_2ppc.v',P/'rtl/wb50/awb_grayworld_rgb_2ppc.v',P/'rtl/compare23/compare_reader23.v',P/'rtl/compare23/axi_pair23.v',P/'rtl/hdmi_gearbox40.v',*sorted((P/'rtl/replay52').glob('*.v'))]
hd='--hd' in sys.argv
sources={p.relative_to(P).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in rtl}
subprocess.run([sys.executable,str(V/'make_reference52.py'),*(['--hd'] if hd else [])],check=True)
args=['-sv','+incdir+'+P.as_posix(),'-work',LIB]
if hd:args+=['+define+FULL_HD']
(V/'compile52.log').write_text(run('vlog',*args,*rtl,*V.glob('tb_*.sv')),encoding='utf-8')
tops=['tb_replay52'] if hd else ['tb_keys52','tb_config52','tb_awb52','tb_control52','tb_gearbox40','tb_writer52','tb_raster52','tb_replay52']
results={}
for top in tops:
 tag=top+('_hd' if hd else '')
 do=V/(tag+'.do');do.write_text(f'onerror {{quit -force -code 2}}\nonbreak {{quit -force -code 1}}\nvsim -lib {{{LIB.as_posix()}}} {top}\nrun -all\nquit -force -code 0\n')
 start=time.time();out=run('vsim','-c','-do',do,'-l',V/(tag+'.log'))
 if 'PASS' not in out or '** Fatal' in out or '** Error' in out:raise RuntimeError(out)
 results[top]={'seconds':time.time()-start,'evidence':[x for x in out.splitlines() if 'PASS' in x or 'SCOREBOARD' in x]}
 print('\n'.join(results[top]['evidence']),flush=True)
after={p.relative_to(P).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in rtl}
if after!=sources:raise RuntimeError('RTL changed during verification; rerun against the final sources')
(V/('VALIDATION_HD.json' if hd else 'VALIDATION_RTL.json')).write_text(json.dumps({'tests':results,'source_hashes':sources,'board_tested':False},indent=2),encoding='utf-8')
