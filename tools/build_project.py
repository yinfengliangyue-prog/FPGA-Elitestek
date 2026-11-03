from pathlib import Path
import subprocess,hashlib,json,time,datetime,xml.etree.ElementTree as ET,shutil,sys,re
P=Path(__file__).resolve().parents[1]
def sources():
 files=[]
 for folder in ('rtl','ip'):
  files += [p for p in (P/folder).rglob('*') if p.is_file() and 'Testbench' not in p.parts and p.suffix in ('.v','.sv','.vh','.svh','.mem','.json')]
 files += [p for p in (P/'model').glob('*.mem') if p.name.startswith(('w1_bank','w2.','b1.','b2.'))]
 files += [P/n for n in ('ti60f225_oob.xml','ti60f225_oob.peri.xml','ti60f225_oob.sdc')]
 return {p.relative_to(P).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}
before=sources();start=time.time()
seed_arg=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--pnr-seed=')),None)
effort_arg=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--pnr-effort=')),None)
assert effort_arg is None or (seed_arg is not None and effort_arg in ('1','2','3','4','5'))
seed_change=None
if seed_arg is not None:
 assert seed_arg.isdigit()
 previous=json.loads((P/'outflow/BUILD_STATUS.json').read_text())
 assert previous['source_hashes']==before and previous['source_inputs_unchanged']
 xml_path=P/'ti60f225_oob.xml';old_xml=xml_path.read_text()
 old_seed=re.search(r'<efx:param name="seed" value="(\d+)"',old_xml).group(1)
 old_effort=re.search(r'<efx:param name="placer_effort_level" value="(\d+)"',old_xml).group(1)
 assert old_seed!=seed_arg
 trial=P/'verification/resource_trials'/('seed'+old_seed)
 trial.mkdir(parents=True,exist_ok=True)
 for n in ['outflow/BUILD_STATUS.json','outflow/ti60f225_oob.route.rpt.xml','outflow/ti60f225_oob.timing.rpt','outflow/ti60f225_oob.route.out','outflow/ti60f225_oob.hier_util.rpt','outflow/ti60f225_oob.bit','outflow/ti60f225_oob.hex','ti60f225_oob.xml','verification/BUILD_RESUME_EVIDENCE.json']:
  if (P/n).exists():shutil.copy2(P/n,trial/(Path(n).name))
 trials_file=P/'verification/PNR_SEED_TRIALS.json'
 trials=json.loads(trials_file.read_text()) if trials_file.exists() else []
 trials.append(dict(seed=int(old_seed),placer_effort_level=int(old_effort),complete_build=previous['complete_build'],timing_passed=previous.get('timing_passed'),setup_slack_ns=previous.get('setup_slack_ns'),hold_slack_ns=previous.get('hold_slack_ns'),archive=trial.relative_to(P).as_posix(),outputs=previous.get('outputs')))
 trials_file.write_text(json.dumps(trials,indent=2),encoding='utf-8')
 new_xml,count=re.subn(r'(<efx:param name="seed" value=")'+old_seed+r'(")',lambda m:m[1]+seed_arg+m[2],old_xml)
 assert count==1
 effort_change=None
 if effort_arg is not None and old_effort!=effort_arg:
  new_xml,count=re.subn(r'(<efx:param name="placer_effort_level" value=")'+old_effort+r'(")',lambda m:m[1]+effort_arg+m[2],new_xml)
  assert count==1
  effort_change=dict(field='place_and_route/placer_effort_level',old=int(old_effort),new=int(effort_arg),reference='Efinity2026.1/scripts/aoe/core/options_constants.py dp_efft enum1..5')
 xml_path.write_text(new_xml,encoding='utf-8')
 seed_change=dict(field='place_and_route/seed',old=int(old_seed),new=int(seed_arg),old_xml_sha256=hashlib.sha256(old_xml.encode()).hexdigest(),old_project_archive=str(trial/'ti60f225_oob.xml'))
 if effort_change:seed_change['placer_effort_change']=effort_change
 before=sources()
 assert {n:h for n,h in before.items() if n!='ti60f225_oob.xml'}=={n:h for n,h in previous['source_hashes'].items() if n!='ti60f225_oob.xml'}
resume='--resume-interface' in sys.argv or seed_arg is not None
log=P/'verification/build_selected_baselines.log'
resume_evidence=None
if resume:
 previous=json.loads((P/'outflow/BUILD_STATUS.json').read_text())
 assert (seed_change is not None or previous['source_hashes']==before) and previous['source_inputs_unchanged']
 previous_log=log.read_text()
 assert re.search(r'\bmap\s*:\s*PASS',previous_log)
 assert (P/'outflow/ti60f225_oob.map.v').exists()
 resume_evidence=dict(reason='Interface process could not access installed Efinity pt/db in the sandbox; RTL synthesis passed.',map_input_hashes=before,map_netlist_sha256=hashlib.sha256((P/'outflow/ti60f225_oob.map.v').read_bytes()).hexdigest(),original_status=previous)
 if seed_change:
  resume_evidence.update(reason='PnR-only optimization retry; identical synthesized RTL, IP, model, interface and SDC. XML changes only the recorded PnR seed and, if declared, detailed placement effort.',seed_change=seed_change,map_input_hashes=previous['source_hashes'])
 (P/'verification/BUILD_RESUME_EVIDENCE.json').write_text(json.dumps(resume_evidence,indent=2),encoding='utf-8')
(P/'verification/BUILD_INPUTS.json').write_text(json.dumps({'started':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),'source_hashes':before},indent=2),encoding='utf-8')
status_path=P/'outflow/BUILD_STATUS.json'
status_path.write_text(json.dumps({'complete_build':False,'state':'building','hardware_tested':False,'source_hashes':before},indent=2),encoding='utf-8')
with log.open('a' if resume else 'w',encoding='utf-8') as fd:
 for flow in (['pnr','pgm'] if seed_change else ['interface','pnr','pgm'] if resume else ['compile']):
  result=subprocess.run(['E:/ELEGtools/efinity/2026.1/bin/efx_run.bat','ti60f225_oob','--prj','-f',flow,'--timeout','7200'],cwd=P,stdout=fd,stderr=subprocess.STDOUT)
  if result.returncode:break
if result.returncode or before!=sources():
 status_path.write_text(json.dumps({'complete_build':False,'state':'failed' if result.returncode else 'stale_inputs','returncode':result.returncode,'source_inputs_unchanged':before==sources(),'source_hashes':before,'hardware_tested':False},indent=2),encoding='utf-8')
 raise SystemExit(result.returncode or 3)
root=ET.parse(P/'outflow/ti60f225_oob.route.rpt.xml').getroot()
ns={'e':'http://www.efinixinc.com/tool_report'}
groups={g.attrib['name']:{v.attrib.get('name'):v.attrib.get('value') for v in g.findall('e:group_data',ns)} for g in root.findall('e:group',ns)}
timing=groups['Timing (Final)'];wns=float(timing['Worst Negative Slack (WNS)'].split()[0]);hold=float(timing['Worst Hold Slack (WHS)'].split()[0])
resources=groups['Core Resources'];passed=wns>=0 and hold>=0
status={'complete_build':True,'source_inputs_unchanged':True,'timing_passed':passed,'setup_slack_ns':wns,'hold_slack_ns':hold,'resources':resources,'seconds':time.time()-start,'hardware_tested':False,'source_hashes':before,'outputs':{}}
if resume:status['synthesis_resume_evidence']='verification/BUILD_RESUME_EVIDENCE.json'
for suffix in ('bit','hex'):
 src=P/f'outflow/ti60f225_oob.{suffix}'
 if src.stat().st_mtime<start:raise RuntimeError('Old build output: '+str(src))
 digest=hashlib.sha256(src.read_bytes()).hexdigest();status['outputs'][src.name]=digest
 if passed:
  alias=P/f'outflow/{P.name}.{suffix}';shutil.copy2(src,alias);status['outputs'][alias.name]=digest
(P/'outflow/BUILD_STATUS.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in status.items() if k not in ('source_hashes',)},indent=2),flush=True)
if not passed:raise SystemExit(2)
