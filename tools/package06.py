from pathlib import Path
import hashlib,json,os,zipfile
P=Path(__file__).resolve().parents[1];sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
b=json.loads((P/'outflow/BUILD_STATUS.json').read_text());a=json.loads((P/'verification/AUDIT06.json').read_text());v=json.loads((P/'verification/VALIDATION_CURRENT.json').read_text())
assert b['complete_build'] and b['timing_passed'] and b['source_inputs_unchanged'] and a['passed'] and v['passed']
assert all(sha(P/n)==h for n,h in b['source_hashes'].items())
assert all(sha(P/n)==h for n,h in v['source_hashes'].items()), 'Validation is from a different RTL revision'
assert json.loads((P/'SOURCE_ORIGIN.json').read_text(encoding='utf-8'))['revision'].startswith(a['revision']), 'Audit revision does not match release'
exclude={'work_syn','work_pnr','__pycache__','_scratch','history','archive','resource_trials'}
files=[]
for folder,dirs,names in os.walk(P):
 dirs[:]=[d for d in dirs if d not in exclude and not d.startswith(('work55_','work_','sim_'))]
 for name in names:
  f=Path(folder)/name;rel=f.relative_to(P)
  if name in ('MANIFEST_SHA256.json','PACKAGE_STATUS.json','transcript') or f.suffix in ('.wlf','.pyc','.ini','.do','.ppm','.wdb'):continue
  if rel.parts[0]=='outflow' and not (name in ('BUILD_STATUS.json','ti60f225_oob.route.out') or f.suffix in ('.bit','.hex','.rpt','.log') or name.endswith('.rpt.xml')):continue
  if rel.parts[0]=='verification' and name.startswith('RESULTS_') and rel.as_posix() not in v['accepted_reports']:continue
  files.append(f)
manifest={f.relative_to(P).as_posix():sha(f) for f in sorted(set(files))}
(P/'MANIFEST_SHA256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');files.append(P/'MANIFEST_SHA256.json')
target=P.parent/(P.name+'.zip');temp=target.with_suffix('.tmp.zip')
with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in sorted(set(files)):z.write(f,P.name+'/'+f.relative_to(P).as_posix())
with zipfile.ZipFile(temp) as z:
 assert z.testzip() is None
 for n,h in manifest.items():assert hashlib.sha256(z.read(P.name+'/'+n)).hexdigest()==h,'ZIP mismatch '+n
temp.replace(target)
status=dict(verified=True,zip_path=str(target),files=len(set(files)),bytes=target.stat().st_size,sha256=sha(target),hardware_tested=False,outputs=b['outputs'])
(P/'PACKAGE_STATUS.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
print(json.dumps(status,indent=2))
