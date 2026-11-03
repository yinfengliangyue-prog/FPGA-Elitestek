from pathlib import Path
import subprocess,sys,os,json,hashlib,time,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1];V=P/'verification'
SIM=Path(os.environ.get('MODELSIM_BIN','E:/ELEGtools/Modelsim_201/modelsim_ase/win32aloem'))
hd='--hd' in sys.argv;config='hd' if hd else 'small';extra=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--tag=')),'');tag=config+('_'+extra if extra else '');lib=V/('work55_'+tag);ini=V/(tag+'.ini')
ini.write_text('[Library]\nwork = '+lib.as_posix()+'\nothers = '+(SIM.parent/'modelsim.ini').as_posix()+'\n')
def run(exe,args,log):
 r=subprocess.run([str(SIM/(exe+'.exe')),*map(str,args)],cwd=P,capture_output=True,text=True,errors='replace',timeout=3600)
 s=r.stdout+r.stderr;(V/log).write_text(s,encoding='utf-8')
 if r.returncode or any(t in s for t in ['** Error','** Fatal','Failed to open readmem','Not enough words','Too many words']):raise RuntimeError(s[-8000:])
 return s
if not lib.exists():run('vlib',[lib],'vlib55_'+tag+'.log')
ns={'e':'http://www.efinixinc.com/enf_proj'}
sources=[e.get('name') for e in ET.parse(P/'ti60f225_oob.xml').getroot().findall('e:design_info/e:design_file',ns) if e.get('name','').startswith('rtl/') and e.get('name')!='rtl/ti60f225_oob_top.v' and not any(k in e.get('name') for k in ['/ddr3_controller/','/dvi_tx/','/dsi_tx/','/cam_i2c_ctrl/','/mipi_config/'])]
sources+=['rtl/wb53/gaussian_vertical_sharpen_2ppc.v','verification/baselines/wb53_ref.v']
hashes={str(f.relative_to(P)):hashlib.sha256(f.read_bytes()).hexdigest() for f in (P/'rtl').rglob('*') if f.is_file()}
cases=[c for c in sys.argv[1:] if not c.startswith('--')] or ['keys55','wb55','control55','pack55','ui55','system55']
report=dict(passed=True,hardware_tested=False,configuration=config,cases=[],source_hashes=hashes,support_hashes={f.relative_to(P).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in V.glob('*.vh')},model_hashes={f.relative_to(P).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in (P/'model').glob('*.mem')})
for case in cases:
 tb=V/('tb_'+case+'.sv')
 run('vlog',['-modelsimini',ini,'-sv','+incdir+.','+incdir+rtl/wb24','+incdir+rtl/wb53',*(['+define+FULL_HD'] if hd else []),'-work',lib,*sources,tb],case+'_'+tag+'_compile.log')
 do=V/(case+'_'+tag+'.do');do.write_text('onerror {quit -force -code 2}\nonbreak {quit -force -code 3}\nvsim -onfinish exit work.tb_'+case+'\nrun -all\nquit -force -code 1\n')
 start=time.time();s=run('vsim',['-modelsimini',ini,'-c','-l',V/(case+'_'+tag+'_transcript.log'),'-do',do],case+'_'+tag+'.log');assert 'PASS ' in s
 summary=[l for l in s.splitlines() if 'PASS ' in l];print('\n'.join(summary),flush=True)
 report['cases'].append(dict(name=case,passed=True,seconds=time.time()-start,summary=summary,log='verification/'+case+'_'+tag+'.log',test_sha256=hashlib.sha256(tb.read_bytes()).hexdigest()))
assert all(hashlib.sha256((P/n).read_bytes()).hexdigest()==h for n,h in hashes.items()),'Source changed during regression'
(V/('RESULTS_'+tag+'_'+('_'.join(cases))+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
