from pathlib import Path
import hashlib,json,re,sys,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1];V=P/'verification'
BASE=Path('E:/ELEGtools/xianshu_FPGA/FINAL04_HDMI_WB_Replay_System')
SRC=BASE.parent/'HDMI_Recognition/56_HDMI_Expression_FINAL04'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
def valid_hashes(h):
    return all((P/n).exists() and sha(P/n)==x for n,x in h.items())

def audit():
    origin=json.loads((V/'FINAL04_56_SOURCE_COMPARISON.json').read_text())
    for key,root in [('56',SRC),('FINAL04',BASE)]:
        for n,h in origin['original_source_hashes'][key].items():
            assert sha(root/n)==h, 'Original source changed: '+str(root/n)
    assert not any(c['missing'] for c in origin['comparison'].values())
    prior=json.loads((SRC/'verification/AUDIT56.json').read_text())
    protected={n:h for n,h in prior['final04_identity'].items() if n not in ['rtl/final/final_recognition.v','rtl/final/menu55.vh','rtl/final/raster55.v','rtl/final/control55.v']}
    assert valid_hashes(protected)
    assert valid_hashes(prior['math34_identity'])
    assert sha(P/'default_wb_profile.json')==sha(BASE/'default_wb_profile.json')
    for n in ['rtl/number/number_mlp.v','rtl/number/number_preprocess.v','rtl/number/expression_overlay.v']:
        assert sha(P/n)==sha(SRC/n),n
    # Verification-only baselines must remain literal protected parent sources.
    expected_ui=(BASE/'rtl/final/ui55.v').read_text().replace('module ui55 #','module golden_ui_literal06 #').replace('`include "rtl/final/menu55.vh"','`include "verification/baselines/menu_final04_literal.vh"')
    assert (V/'baselines/final04_ui_literal.vh').read_text()==expected_ui
    assert sha(V/'baselines/menu_final04_literal.vh')==sha(BASE/'rtl/final/menu55.vh')
    expected_cap=(SRC/'rtl/final/final_recognition.v').read_text().replace('module final_recognition #','module golden_recognition56 #').replace('final_number_annotation #','golden_number_annotation56 #')+'\n'+(SRC/'rtl/final/final_number_annotation.v').read_text().replace('module final_number_annotation #','module golden_number_annotation56 #')
    assert (V/'baselines/recognition56_literal.vh').read_text()==expected_cap
    baseline_hashes={f.relative_to(P).as_posix():sha(f) for f in (V/'baselines').glob('*.vh')}

    menu=(P/'rtl/final/menu55.vh').read_text();ui=(P/'rtl/final/ui55.v').read_text();keys=(P/'rtl/final/keys55.v').read_text();sys55=(P/'rtl/final/system55.v').read_text();top=(P/'rtl/ti60f225_oob_top.v').read_text()
    assert 'FULL=0,SPLIT=1,SHAPE=2,EXPR=3' in menu
    assert not any('NUMBER' in s for s in [menu,ui,keys,sys55])
    assert 'rec_preview' not in ui and 'rec_digit' not in ui and 'rec_box,' not in ui
    assert '.BOOT_APP(3)' in top and 'DIGIT_ENABLE' not in top
    assert "recognition_run&&(app_mode==3)" in sys55 and ".expression_mode(1'b1)" in sys55
    assert not (P/'rtl/final/final_number_annotation.v').exists()
    ns={'e':'http://www.efinixinc.com/enf_proj'}
    files=[e.get('name') for e in ET.parse(P/'ti60f225_oob.xml').getroot().findall('e:design_info/e:design_file',ns)]
    assert 'rtl/final/final_number_annotation.v' not in files
    assert all(n in files for n in ['rtl/shape/shape_contour_detector.v','rtl/shape/shape_color_overlay.v','rtl/number/number_mlp.v','rtl/number/expression_engine.v'])
    revision=json.loads((V/'FPS60_STYLE_PRESETS_REVISION.json').read_text())
    expr_revision=json.loads((V/'EXPR_CANNY_REVISION.json').read_text())
    pair_revision=json.loads((V/'PAIR_LOCK_MENU_HOLD_REVISION.json').read_text())
    clean_revision=json.loads((V/'CLEAN94_REVISION.json').read_text())
    assert valid_hashes({n:h for n,h in clean_revision['baseline_source_hashes'].items() if n not in {'rtl/final/keys55.v','ti60f225_oob.xml'}})
    fixture_proof=P/clean_revision['unchanged_fixture_proof']
    assert sha(fixture_proof)==clean_revision['unchanged_fixture_proof_sha256']
    unchanged_inputs=json.loads(fixture_proof.read_text())
    assert unchanged_inputs['baseline_zip_sha256']==clean_revision['baseline_zip_sha256'] and valid_hashes(unchanged_inputs['files'])
    assert clean_revision['presets']=={'BAL':[6,4],'CLEAN':[9,4],'RED':[8,4],'SHAPE':[6,3],'EXPR':[10,5]}
    current_origin=json.loads((P/'SOURCE_ORIGIN.json').read_text(encoding='utf-8'))
    assert current_origin['style_threshold_defaults']==clean_revision['presets']
    assert current_origin['expression_threshold_bank']=='EXPR' and current_origin['expression_threshold_default']==[10,5]
    pair_changes=set(pair_revision['changed_rtl'])
    allowed=set(revision['changed_rtl'])|set(expr_revision['changed_rtl'])|pair_changes|{'ti60f225_oob.xml'}
    assert valid_hashes({n:h for n,h in revision['baseline_source_hashes'].items() if n not in allowed})
    assert valid_hashes({n:h for n,h in expr_revision['baseline_source_hashes'].items() if n not in set(expr_revision['changed_rtl'])|pair_changes|{'ti60f225_oob.xml'}})
    assert valid_hashes({n:h for n,h in pair_revision['baseline_source_hashes'].items() if n not in pair_changes|{'ti60f225_oob.xml'}})
    control=(P/'rtl/final/control55.v').read_text()
    assert '(!pair_valid||pair_bank!=k)' in control and 'chosen_a=pair_bank;chosen_b=pair_bank' in control
    assert "4'd15:if(app_sync==1&&page==0)" in control
    assert '.frame_locked_out(axi_locked)' in sys55 and 'status_now={axi_locked,' in sys55
    assert '.frame_locked(frame_locked)' in sys55 and 'LOCK A+B' in ui
    assert 'repeated_nav' in keys and 'if(settings_open&&!editing)begin move_cursor' in keys
    pipeline=(P/'rtl/number/number_video_pipeline.v').read_text()
    old_baseline=P/expr_revision['legacy_pipeline_baseline']
    assert sha(old_baseline)==expr_revision['baseline_source_hashes']['rtl/number/number_video_pipeline.v']
    old_pipeline=old_baseline.read_text()
    assert pipeline.split(' assign red_edges=',1)[1]==old_pipeline.split(' assign red_edges=',1)[1], 'Recognition algorithms after edge interface changed'
    assert '.EXTERNAL_EDGES(1)' in sys55 and '.external_edge_bits(edges)' in sys55
    assert '.de_in(ed),.valid_in(ev),.hs_in(eh),.vs_in(es)' in sys55
    assert 'G_BAL:set_threshold(6,4);G_RED:set_threshold(8,4)' in keys
    assert 'bal_high<=6;bal_low<=4;clean_high<=9;clean_low<=4;expr_high<=10;expr_low<=5;red_high<=8;red_low<=4;shape_high<=6;shape_low<=3;' in keys
    assert 'SHAPE:select_group(G_EXPR)' in keys and 'G_CLEAN:set_threshold(9,4);G_EXPR:set_threshold(10,5)' in keys
    assert "frame_app==3?3'd1" in (P/'rtl/final/raster55.v').read_text()
    reference=json.loads((V/'EXPR_CANNY_REFERENCE.json').read_text())
    assert reference['generator_sha256']==sha(V/'make_expr_canny_reference.py')
    assert valid_hashes(reference['dependencies']) and valid_hashes({'verification/'+n:h for n,h in reference['outputs'].items()})
    assert revision['stored_style_codes']==[0,2,4,1,3]
    assert revision['presets']=={'BAL':[8,4],'CLEAN':[10,5],'RED':[8,4],'SHAPE':[6,3]}
    assert 'DISPLAY FPS 60' in ui and 'FPS 000/000' not in ui and 'fps_meter_inst' not in top
    if '--sources-only' in sys.argv:
        print(f'PASS SOURCE06: protected FINAL04 and34 algorithms/models unchanged except explicitly audited raster/edge-interface wrappers; shared Canny EXPR input; original56/FINAL04 inputs unchanged; four applications and no NUMBER production UI; {len(protected)} FINAL04 identities checked')
        return
    build=json.loads((P/'outflow/BUILD_STATUS.json').read_text())
    assert build['complete_build'] and build['timing_passed'] and build['source_inputs_unchanged']
    assert valid_hashes(build['source_hashes'])
    if build.get('synthesis_resume_evidence'):
        resume=json.loads((P/build['synthesis_resume_evidence']).read_text())
        assert sha(P/'outflow/ti60f225_oob.map.v')==resume['map_netlist_sha256']
        assert valid_hashes({n:h for n,h in resume['map_input_hashes'].items() if n!='ti60f225_oob.xml'})
        if resume.get('seed_change'):
            change=resume['seed_change']
            archive=P/'verification/resource_trials'/('seed'+str(change['old']))/'ti60f225_oob.xml'
            old=archive.read_text()
            new,count=re.subn(r'(<efx:param name="seed" value=")'+str(change['old'])+r'(")',lambda m:m[1]+str(change['new'])+m[2],old)
            assert count==1 and hashlib.sha256(old.encode()).hexdigest()==change['old_xml_sha256']
            if change.get('placer_effort_change'):
                effort=change['placer_effort_change']
                assert effort['field']=='place_and_route/placer_effort_level' and effort['new'] in range(1,6)
                new,count=re.subn(r'(<efx:param name="placer_effort_level" value=")'+str(effort['old'])+r'(")',lambda m:m[1]+str(effort['new'])+m[2],new)
                assert count==1
            assert new==(P/'ti60f225_oob.xml').read_text(), 'PnR retry changed XML beyond recorded seed/placement effort'
    log=(V/'build_selected_baselines.log').read_text()
    stage_states={n:re.findall(r'\b'+n+r'\s*:\s*(PASS|FAIL)',log) for n in ['map','interface','pnr','pgm']}
    assert all(values and values[-1]=='PASS' for values in stage_states.values())
    timing=(P/'outflow/ti60f225_oob.timing.rpt').read_text()
    def rows(t):
        return [dict(launch=m[0],capture=m[1],constraint_ns=float(m[2]),slack_ns=float(m[3])) for m in re.findall(r'^\s*(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\(',t,re.M)]
    sr=rows(timing.split('Setup (Max) Clock Relationship',1)[1].split('Hold (Min) Clock Relationship',1)[0])
    hr=rows(timing.split('Hold (Min) Clock Relationship',1)[1].split('NOTE:',1)[0])
    paths=[float(v) for v in re.findall(r'^Slack\s*:\s*(-?\d+\.\d+)',timing,re.M)]
    assert len(sr)>=12 and len(hr)>=12 and min(c['slack_ns'] for c in sr+hr)>=0 and paths and min(paths)>=0
    route=(P/'outflow/ti60f225_oob.route.out').read_text()
    keyline=next(l for l in route.splitlines() if l.startswith('20 KEY first-stage synchronizer D pins:'))
    assert keyline.count('~FF|D')==4 and 'Error(s) found while executing SDC' not in route
    hier=(P/'outflow/ti60f225_oob.hier_util.rpt').read_text()
    assert len(re.findall(r'\+mlp\s+\|',hier))==1 and len(re.findall(r'\+detector\s+\|',hier))==1
    assert 'legacy_sobel' not in hier and not re.search(r'\+continuity\s+\|',hier), 'Duplicate legacy recognition frontend synthesized'
    assert len(re.findall(r'\+core\s+\|',hier))==1
    mapped=(P/'outflow/ti60f225_oob.map.v').read_text()
    assert 'math34|legacy_sobel' not in mapped and 'math34/legacy_sobel' not in mapped
    seed=int(next(x.get('value') for x in ET.parse(P/'ti60f225_oob.xml').getroot().findall('e:place_and_route/e:param',ns) if x.get('name')=='seed'))
    placer_effort=int(next(x.get('value') for x in ET.parse(P/'ti60f225_oob.xml').getroot().findall('e:place_and_route/e:param',ns) if x.get('name')=='placer_effort_level'))
    a=dict(passed=True,hardware_tested=False,project_index=59,number_ui=False,boot_page='EXPR',pnr_seed=seed,placer_effort_level=placer_effort,revision=clean_revision['revision'],frame_pair_lock='FRAME LIVE only; one complete committed snapshot; background history continues; page/app/new take/reset release',menu_navigation_hold='SW2/SW3 after600ms every150ms, clamp, no confirm repeat, no release duplicate and late-chord rollback',expression_frontend='existing full-resolution Canny; no legacy Sobel/continuity instance',expression_defaults=[10,5],expression_threshold_bank='EXPR independent',expression_red_overlay='Always ON including recognition OFF; AUX controls boxes only',style_order=revision['style_order'],threshold_presets=clean_revision['presets'],fps_display='Fixed nominal display60, not a camera measurement',
        setup_relationships=sr,hold_relationships=hr,detailed_slack_paths=len(paths),minimum_detailed_slack_ns=min(paths),
        final04_identity=protected,math34_identity=prior['math34_identity'],verification_baseline_hashes=baseline_hashes,
        original_projects_unchanged=True,key_first_stage_exact_match=keyline,removed='Independent NUMBER page and capture/UI shell only; expression MLP retained')
    (V/'AUDIT06.json').write_text(json.dumps(a,ensure_ascii=False,indent=2),encoding='utf-8')

    required={('small',n) for n in 'cleanexpr06 pairlock06 menuhold06 boot06 keys06 keys55 focus55 style_presets06 ui55 menu_identity06 shape_lock_v2 capture_identity06 wb55 control55 pack55 packwide55 reader55 writer52 system55 tasks55 nativeexpr56 exprcanny06 exprbinding06 mlp'.split()}|{('hd','transport55')}
    seen=set();cases=[];reports=set()
    for f in sorted(V.glob('RESULTS_*.json'),key=lambda p:p.stat().st_mtime,reverse=True):
        d=json.loads(f.read_text());config=d['configuration']
        if not d['passed'] or not valid_hashes(d.get('model_hashes',{})):continue
        differences={n.replace(chr(92),'/') for n,h in d['source_hashes'].items() if not (P/n).exists() or sha(P/n)!=h}
        if differences and differences!={'rtl/final/keys55.v'}:continue
        reuse=bool(differences)
        if reuse and d['source_hashes'].get('rtl/final/keys55.v',d['source_hashes'].get('rtl\\final\\keys55.v'))!=clean_revision['baseline_source_hashes']['rtl/final/keys55.v']:continue
        for c in d['cases']:
            key=(config,c['name'])
            if key not in required or key in seen:continue
            if reuse and c['name'] in {'cleanexpr06','boot06','keys06','keys55','focus55','style_presets06','menuhold06'}:continue
            if sha(V/('tb_'+c['name']+'.sv'))!=c['test_sha256']:continue
            included=set();known={k.replace(chr(92),'/'):v for k,v in {**d['source_hashes'],**d.get('support_hashes',{}),**baseline_hashes}.items()}
            def walk(file):
                for n in re.findall(r'`include\s+"([^"]+)"',file.read_text()):
                    if n in included:continue
                    included.add(n);assert n in known and sha(P/n)==known[n],n;walk(P/n)
            walk(V/('tb_'+c['name']+'.sv'))
            log=P/c['log'];s=log.read_text(errors='replace')
            assert 'PASS ' in s and re.search(r'Errors:\s*0,',s) and not any(t in s for t in ['** Error','** Fatal','Failed to open readmem','Not enough words','Too many words'])
            if reuse:assert not re.search(r'Loading work\.keys55\b',s), 'Changed module loaded in reused simulation'
            cases.append(dict(**c,reused=reuse,dependency_evidence='All RTL except uninstantiated keys55 plus model/fixture hashes unchanged from previous24-case release' if reuse else 'Current RTL rerun',configuration=config,report=f.relative_to(P).as_posix(),log_sha256=sha(log),support_includes=sorted(included)))
            seen.add(key);reports.add(f.relative_to(P).as_posix())
    assert seen==required,('Missing current-source simulations',sorted(required-seen))
    extra=[]
    for name in ['verification/noise/VALIDATION.json','verification/stability/VALIDATION.json','verification/hdmi/PUBLICATION_VALIDATION.json']:
        d=json.loads((P/name).read_text());assert d['passed'] and d.get('input_unchanged',True) and valid_hashes(d['source_hashes'])
        assert valid_hashes(d.get('fixture_hashes',{}))
        extra.append(dict(name=name,origin_project=str(SRC),reused=True,dependency_hashes=d['source_hashes'],report_sha256=sha(P/name),summary=d['summary']))
    v=dict(passed=True,hardware_tested=False,current_source_cases=len(cases),rerun_current_rtl_cases=sum(not x['reused'] for x in cases),unchanged_dependency_cases=sum(x['reused'] for x in cases),cases=cases,accepted_reports=sorted(reports),shared_algorithm_suites=extra,verification_baseline_hashes=baseline_hashes,
        source_hashes={f.relative_to(P).as_posix():sha(f) for f in (P/'rtl').rglob('*') if f.is_file()},
        limits=['Canny10/5 production768 ROI/192grid recognition uses cropped white margins and a clean-background derivative of12+34 glyphs; original checker texture is retained only in the separate legacy Sobel regression. Shared Canny recognition and red-raster binding also use real RAW/DDR with reduced synthetic input.',
            '120-frame RAW/shared-DDR chain uses reduced synthetic input; four1080p display frames are a separate transport test.',
            'DISPLAY FPS60 is the fixed nominal display rate, not a measured camera or display rate. FRAME has one shared Canny capture threshold and immutable recorded pixels.',
            'FRAME LIVE LOCK A+B pins the same completed snapshot in both views; styles remain independent; H/L changes affect future acquisitions, not the held image. An empty lock request waits for a first commit. Leaving LIVE or FRAME, NEW TAKE and reset release the pair pin.',
            'BAL defaults/resets/restores6/4 and CLEAN9/4; EXPR retains independent10/5, RED8/4 and SHAPE6/3 unchanged. Only keys55 differs from the preceding release. Reused non-key simulations require every other RTL/model/fixture hash unchanged and no keys55 loaded; key-dependent cases are rerun.',
            'No board download, accuracy survey, long-duration acceptance, or complete CDC/SDC signoff.'])
    (V/'VALIDATION_CURRENT.json').write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
    # The existing packaging tool consumes these two explicit audit names.
    print(f'PASS FINAL06: {len(cases)} validated cases ({v['rerun_current_rtl_cases']} rerun, {v['unchanged_dependency_cases']} unchanged-dependency reuse) + {len(extra)} algorithm suites; {len(sr)} setup/{len(hr)} hold/{len(paths)} nonnegative paths; parents unchanged')

def documents():
    b=json.loads((P/'outflow/BUILD_STATUS.json').read_text());a=json.loads((V/'AUDIT06.json').read_text());v=json.loads((V/'VALIDATION_CURRENT.json').read_text())
    assert b['complete_build'] and b['timing_passed'] and a['passed'] and v['passed']
    bit=b['outputs'][P.name+'.bit'];hx=b['outputs'][P.name+'.hex']
    title=P.name
    (P/'README.md').write_text(f'''# {title}

2026-11-01，HDMI共用编号59，从56独立派生。保留原56、FINAL04、FINAL05及58，不覆盖历史工程。

现行目录：`{P}`，配套ZIP放在工程同级。2026-11-01按用户要求迁入xianshu_FPGA主目录；历史构建日志中的旧绝对路径保留为当时记录。

本版保留FINAL04实际功能及56真实算式识别，彻底移除独立NUMBER页面。主功能只有 **FULL → FRAME → SHAPE → EXPR → FULL**。上电EXPR、识别OFF、搜索框ON；切主功能关闭识别。

- FULL：原图ORIG → BAL → CLEAN → 红色边缘叠加RED → GREY，LIVE/HOLD及单次更新；内部旧样式编码不变，避免改变已有回放解释。
- FRAME：120帧不可变录段＋3实时槽，LIVE/REPLAY/COMPARE，三速、循环、逐帧、A/B独立帧和样式、双游标、完成写入毫秒差、提前停止和排空重录；LIVE页NEW TAKE下新增LOCK A+B，同时锁住完整同帧或恢复实时，样式独立。
- SHAPE：原FINAL04完整几何分类、分类轮廓着色、结果锁定、AUX、H/L/DN。
- EXPR：复用现有全分辨率Canny边缘进入768ROI/192网格/32组件/原模型及整数运算；RESULT或SW3启动/关闭。红边缘始终显示，识别OFF时也可用于对准。无有效结果按原流程显示等待、未知或明确标记的上一有效结果。
- WB有效Q8基准R320/G158/B329，限幅AUTO与LOCK，G不二次抑绿；Gamma2.2、Gaussian及轻锐化固定开启。WB不反馈Canny/识别输入。
- 默认阈值BAL H6/L4、CLEAN H9/L4、EXPR H10/L5、FULL红边缘RED H8/L4；SHAPE H6/L3，DN ON且可调，各样式手调值分别记忆，恢复检测回到对应默认值。原图/GREY不另设边缘默认值。
- FPS DISPLAY开启后显示固定的DISPLAY FPS 60，不显示相机/视频实测计数；上下文菜单、有效Q8和300显示帧提示保留。300帧在60Hz时名义5秒。

FRAME仍只共享一套Canny：LIVE中最后调整的边缘样式加载对应采集阈值，两个视图不能同时拥有两套独立检测参数。历史回放样式切换只解释已存像素，不重算旧帧；新阈值仅作用后续采集。算式识别已改用同一套Canny的真实边缘位，EXPR使用独立H/L手调记忆，默认10/5；CLEAN独立默认9/4；生产不再实例化旧Sobel/连续性前端。模型、分割和整数运算不变。

独立数字标题、数字预览、字符框接口、页面入口及旧采集UI壳已移除。算式中必须识别0～9，因此保留内部MLP、权重和数字类模块；它们不构成独立NUMBER功能。

56相对FINAL04有内部资源取舍：读FIFO1024→512；只延迟最终缩图选中的低像素RGB554。功能清单没有删减，不能称RTL、抗停顿容量或所有场景完全相同。详细核查和证据见《FINAL04对照与整合留痕.md》。本版额外继承已有MenuFocusFix，防止样式/PAGE编辑时上下文重排丢失焦点。

完整map/interface/pnr/pgm通过，PnR seed{a['pnr_seed']}/TIMING_3/放置力度{a['placer_effort_level']}；XLR {b['resources']['XLRs']}、RAM {b['resources']['Memory Blocks']}、DSP {b['resources']['DSP Blocks']}；最终setup {b['setup_slack_ns']:+.3f}ns、hold {b['hold_slack_ns']:+.3f}ns。{v['rerun_current_rtl_cases']}组当前源码重跑＋{v['unchanged_dependency_cases']}组未改依赖回归复核＋3套依赖hash核验算法证据。未下载板卡，现场识别、画面和长期稳定性待验。沿用SDC仍有旧名称警告，不等同所有CDC/约束全面签核。

当前修正版下载：`outflow/{title}_BAL6_4_CLEAN9_4_20261101.bit`；Flash：同名前缀`.hex`。正常名字`outflow/{title}.bit/.hex`及通用名逐字节一致。

bit SHA256：`{bit}`

当前操作以《菜单操作指南.md》为准。docs/内34和FINAL04资料为来源历史，旧五页面/NUMBER描述不代表本版。

新增菜单位置预览见[FRAME双窗锁定界面](verification/frame_pair_locked_settings.png)，由实际UI RTL配合纯色合成输入生成，不是板卡拍摄。
''',encoding='utf-8')
    (P/'菜单操作指南.md').write_text('''# FINAL06 四功能操作指南

SW0～SW3均低电平按下，单键命令通常松开后执行；多键或交错组合取消。

| 设置关闭时 | SW0 | SW1 | SW2 | SW3 |
|---|---|---|---|---|
| FULL | 下一功能 | 打开设置 | 原图→BAL→CLEAN→红边缘→GREY | LIVE/HOLD |
| FRAME LIVE | 下一功能 | 打开设置 | 进入回放 | 停止录制并回看 |
| FRAME REPLAY/COMPARE | 下一功能 | 打开设置 | 前一帧，可长按 | 后一帧，可长按 |
| SHAPE | EXPR | 打开设置 | AUX轮廓显示 | 有真实结果后锁定/解锁；无结果不锁 |
| EXPR | FULL | 打开设置 | 搜索框/字符框AUX | 真实算式识别OFF/ON |

上电进入EXPR且识别OFF。按SW3启动识别；切离EXPR自动关闭。没有独立NUMBER页。AUX只影响辅助显示，不停止算法；结果开关控制真实识别。

设置中：SW2上移、SW3下移，按住约0.6秒后每0.15秒连续移动一项，首尾停住、松手不再多走一步；SW0进入编辑或执行，SW1直接关闭。确认框中不连翻。编辑中SW2减、SW3加、SW0完成；H/L和帧号支持长按。样式或BUFFER PAGE重排菜单时保留当前编辑项焦点。恢复和NEW TAKE需SW0确认，可SW1取消；普通编辑无超时关闭。

Canny视图、SHAPE及EXPR将GLOBAL H/L/DENOISE置顶，BAL默认6/4、CLEAN默认9/4、EXPR默认10/5、FULL红边缘默认8/4、SHAPE默认6/3，DN ON；各样式手调值分别记忆，恢复检测仅恢复当前参数组及DN ON，L不超过H。上电/复位进入EXPR，Canny加载EXPR的10/5；切回FULL时加载对应样式参数。回放/对比优先播放、帧号、速度或A/B对象。历史帧不重算；GLOBAL只影响后续采集。FRAME LIVE最后调整的边缘样式决定共享Canny阈值，A/B不是两套独立检测器。FRAME比较中分别设置FRAME A、FRAME B和A/B STYLE，SELECT A/B选择对象；播放含0.5X/1X/2X及循环，NEW TAKE先排空旧事务再重新录制。

FRAME初始LIVE页，NEW TAKE下一项为LOCK A+B，SW0直接切换ON/OFF，无需进入编辑。ON将两窗固定到同一张已完成写入的快照，窗口标题显示HOLD，底部显示LIVE A+B LOCKED，后台120帧录制继续。锁定后A/B样式仍能独立切换；调H/L只影响后续采集，不重算已锁图像。OFF恢复实时；离开LIVE页或FRAME功能、NEW TAKE和复位会解除双窗锁定。若请求时尚无完整帧，等待第一张成功提交。

FULL保持后可在设置中UPDATE HELD FRAME单次更新。白平衡仅AUTO/LOCK，有效R/G/B Q8只读。Gamma/Gaussian/轻锐化固定开，不设置滤波按键。FPS DISPLAY默认关闭，开启后固定显示DISPLAY FPS 60，为屏幕标称值，不是相机或视频实测帧率。OSD和5秒名义提示保留。

EXPR直接复用全分辨率Canny边缘识别，默认H10/L5，使用独立H/L记忆，CLEAN默认9/4；菜单H/L/DN置顶，RESTORE DETECT恢复10/5和DN ON。红边缘在RESULT OFF和ON时均显示，SW2/AUX只隐藏搜索框/字符框；SW3/RESULT仍只启停真实算式分析。模型、分割和整数算术保留，旧Sobel/连续性前端在生产路径中移除。
''',encoding='utf-8')
    c=json.loads((V/'FINAL04_56_SOURCE_COMPARISON.json').read_text())
    (P/'FINAL04对照与整合留痕.md').write_text(f'''# FINAL04 → 56 → FINAL06 核查与整合留痕

2026-11-01。用户要求先核查56相对FINAL04是否删减，再移除独立数字界面，成为FINAL06。当前共用编号59；58已存在而未改动。原56、FINAL04生产输入hash前后核对未变。

## 核查结论

没有发现56删去FINAL04核心功能。原FINAL04的NUMBER和EXPR只是外壳；56保持NUMBER外壳并新增真实EXPR。本版按用户要求删除NUMBER外壳，保留真实EXPR。这里的完整保留指实际功能，不代表内部实现、性能余量或所有输入场景逐项完全相同。

| 检查项 | 56相对原FINAL04 | FINAL06 |
|---|---|---|
| FULL五样式、HOLD/UPDATE | 保留 | 保留 |
| FRAME120/3实时槽、三速、循环、逐帧、A/B、双游标、时间差、提前停止/重录 | 保留 | 保留 |
| SHAPE分类、颜色地图、结果锁定 | 保留，算法源码一致 | 保留，算法源码一致；清理包装层有逐周期对照 |
| WB基准/限幅AUTO/LOCK及固定Gamma/Gaussian/轻锐化 | 保留，源码/配置一致 | 保留 |
| Canny/49 BAL-CLEAN、H/L/DN、GRAY、FPS | 保留，算法源码一致 | 保留 |
| 真实算式 | 从34新增 | 保留，生产强制EXPR模式 |
| 独立NUMBER页面 | 原来也是外壳 | 用户明确要求彻底移除 |
| 上下文菜单和提示 | 保留，EXPR RESULT变OFF/ON | 四功能标题；加入已有MenuFocusFix |

原FINAL04与56：rtl中{len(c['comparison']['rtl']['identical'])}个文件逐字节一致、6个改变、没有缺失；ip {len(c['comparison']['ip']['identical'])}个、model {len(c['comparison']['model']['identical'])}个一致。完整清单见verification/FINAL04_56_SOURCE_COMPARISON.json。

## 必须明说的内部差异

1. 56读FIFO由1024降为512。本版维持512；相同瞬时停顿的吸收容量较小，不能声称抗抖动余量与FINAL04完全相同。实际512深度读取消/排空/恢复和共享DDR整链重跑。
2. 56将彩色对齐从双像素28bit缩为最终2×2抽取所用低像素14bit，形状轮廓另按真实边缘着色。共享快照仍是RGB554、BAL8、CLEAN8、edge1、annotation1的32bit记录；没有再次减少回放色深。存储载荷/全宽打包用独立参考核对。
3. 56为模型ROM、标签RAM和小表做了存放优化；原模型和整数算法保持，MLP参考逐分数验证。不能把更小资源占用称为所有输入准确率已上板验证。

## FINAL06初版具体改动

主功能编码FULL0/FRAME1/SHAPE2/EXPR3，SW0四页循环。删除NUMBER菜单枚举、独立预览/字符框/标题接口及final_number_annotation采集UI模块。算式内部数字分类仍保留；生产expression_mode固定1。初版未改变WB/Canny/形状分类算法、曝光、引脚和SDC。继承既有MenuFocusFix，样式/PAGE重排时保留编辑焦点。

verification/baselines中的原FINAL04 UI及原56采集包装层仅供独立对照，不是生产入口。保留页面菜单/编辑/滚动/EXPR OFF界面逐像素比较；四页标题和RESULT OFF/ON为预期变化。原56包装层与本版形状/彩色/掩码/锁定逐周期比较。旧路径真实12+34=46贯通Sobel、连续性、768ROI/192网格、MLP、算式计算和实际UI，作为legacy参数分支回归；不能作为当前Canny输入的独立证据。

## 当前FPS、样式和默认阈值更新

按用户2026-11-01新要求，开启FPS DISPLAY后固定显示屏幕标称60，不再展示相机/视频实测计数；移除生产顶层计数实例。样式循环改为原图/BAL/CLEAN/红边缘/GREY，保留原存储编码0/2/4/1/3。BAL默认H6/L4、CLEAN H9/L4、RED H8/L4，各自保存手调值；恢复检测加载当前组的默认值并打开DN。SHAPE保持H6/L3；此前EXPR与CLEAN共享H10/L5，本轮CLEAN改9/4且EXPR独立保留10/5，替代此前Sobel2/最低6输入，上电进入EXPR加载10/5。新的默认仅覆盖本FINAL06指定样式，不追改其它工程。

FRAME仍共享一个Canny，LIVE中最后修改的边缘样式更新后续采集阈值；A/B同时显示不同样式不代表并行两套阈值。历史回放样式不重新检测，原录段保持不可变。新style_presets06用真实按键和Canny检查12288输入像素及配置发布，并检查复位、恢复、独立手调记忆、L<=H、长按与组合取消。FPS用无效和任意实测输入分别检查显示仍固定60及关闭隐藏。菜单对照只适配指定的ORIG/GREY标签，原GLOBAL WB标题不改。

更新前ZIP及构建/验证记录保存在archive/20261101_before_FPS60_StylePresets；旧bit SHA为14a7e40c4837f8ce70ecd699402f0691f7c098098052518d9f16cd3a5a45a20c，仅作回退。

## EXPR红边缘与共享Canny修正

代码核查：此前math34内部确实有Sobel/连续性输入，但rgb_out未用于整合版显示，算式页又按原图样式渲染，所以缺少红边缘画面。当前按用户明确要求，number_video_pipeline新增编译期外部边缘接口，生产EXTERNAL_EDGES=1直接使用system55既有全分辨率Canny的edges/DE/valid/HS/VS。旧Sobel和continuity只留在默认参数分支供独立legacy回归，不在当前生产层级。768ROI、192网格、2个命中成格、32组件、归一化、模型、投票和整数运算均保留。

EXPR红边缘渲染使用同一Canny检测形成的DDR快照掩码，OFF也显示，AUX只控制UI框。EXPR独立默认10/5，CLEAN独立默认9/4，GLOBAL H/L/DN置顶且可调整，恢复检测回到10/5和DN ON。参数在Canny帧边界生效，变更时清空识别状态再分析，切主功能仍关闭识别。FULL的RED依旧8/4，不因EXPR默认10/5被改动。

新测试exprcanny06以独立Python整数Canny模型逐像素核对边缘、独立2/16占用格及矩形归一化参考核对784位输入，再检查真实MLP及12+34=46与UI。其背景明确为去除原244/252棋盘纹理的合成白底字形，不冒充原有纹理场景通过；原纹理仍单独运行legacy Sobel回归。Canny前端改变边缘分布，不能沿用旧Sobel准确率或现场验收。exprbinding06另在实际system55的缩小RAW/DDR/Debayer链检查识别输入和快照红边缘像素，OFF/ON均有可见红像素，并覆盖读饥饿后的恢复。

本轮修改前FPS60完整包在archive/20261101_before_EXPR_Canny105；旧bit SHA32a8f6a56f8ba8b211a291f3715153549f7c7e9880c770db7ef61495ded69b43，仅供回退。

## FRAME同时锁定与长按菜单

LIVE页在NEW TAKE后插入LOCK A+B，直接动作发送独立命令15，控制器只在FRAME LIVE接受。两窗统一引用pair_bank；只保留已提交快照，空画面请求等待首次完整提交。allocator排除pair_bank，原120帧不可变录段继续写满，A/B样式独立。录满后仍保护被锁实时槽；极端情况下FULL保持槽、两窗锁定槽和最新槽占满三个实时槽时安全停等，解锁或离开FRAME LIVE释放pair pin后恢复，不覆盖锁定内容。切页、离开FRAME、NEW TAKE及复位均释放。状态通过扩展为48bit的原捆绑握手邮箱返回视频域，菜单ON/OFF及HOLD标签来自真实控制状态。

设置浏览时SW2/SW3支持0.6秒起连、每0.15秒一项，端点钳位，松开不重复。确认框禁止连翻，非数值编辑仍单次调整，H/L和帧号原长按行为保留；连翻后检测到组合键会恢复本次手势开始的光标，并取消后续动作。

pairlock06覆盖空帧、在途未提交、后台录满、实时槽/FULL保持竞争、解锁恢复及所有释放条件；menuhold06以真实消抖按键覆盖FULL/LIVE/REPLAY/COMPARE/SHAPE/EXPR、边界、松手、组合回滚、确认框和LOCK行单次执行；system55用真实AXI/帧像素参考检验录制中及录满后两窗锁帧，锁住期间继续记录与旧像素不覆盖。UI像素/文字核对新增项在NEW TAKE下一行，保留其它菜单的literal对照并显式适配新增行偏移。

修改前Canny105完整包及所有下载镜像保存在archive/20261101_before_PairLock_MenuHold。此前日期别名EXPR_Canny10_5_20261101移入回退目录，该阶段使用PairLock_MenuHold_20261101别名，现行更新为BAL6_4_CLEAN9_4_20261101别名。

## 当前BAL6/4与CLEAN9/4默认阈值

用户先要求CLEAN9/4，随后要求BAL默认6/4。仅keys55调整上电、复位和恢复检测：BAL6/4、CLEAN9/4；增加独立EXPR参数组保留算式10/5，手调记忆互不串扰。FULL RED8/4、SHAPE6/3不变。共享的是原一套Canny算法实例，参数记忆分开，不增加检测器或重算旧冻结/回放帧。WB/SHAPE/EXPR模型、缓存锁定、长按目录、样式顺序、FPS和曝光/引脚/约束保持本轮输入hash。

7项涉及按键的用例重跑，含新增cleanexpr06真实按键及Canny配置检查默认/手调11/3与11/6/切页/恢复/复位的隔离。其余18项仿真复用上一轮结果，逐文件验证所有其它RTL、模型、fixture/include相同，且仿真加载日志没有keys55；不把这些18项描述成本轮全量重跑。原3套算法证据继续按依赖hash核验。修改前完整包及下载镜像保存在archive/20261101_before_CLEAN94。

## 验证边界和拍摄记录

{v['rerun_current_rtl_cases']}组当前源码重跑＋{v['unchanged_dependency_cases']}组未改依赖回归复核；另3套旧算法证据只在依赖源码及夹具hash匹配时复用。完整RAW/120帧共享DDR整链是缩小合成输入；四帧1080p显示输运单独核对。不能合称120个全高清真实相机帧整链识别仿真。

历史：FINAL06初版seed3曾生成bit但setup为-0.060ns，随后仅改seed2通过；其旧尝试及安装库权限处理保留在归档/历史记录。本轮BAL6/4、CLEAN9/4及EXPR参数记忆分离重新完整综合，当前有效结果只以最新BUILD_STATUS及下述时序为准。

完整构建PnR seed{a['pnr_seed']}/TIMING_3/放置力度{a['placer_effort_level']}，XLR {b['resources']['XLRs']}、RAM {b['resources']['Memory Blocks']}、DSP {b['resources']['DSP Blocks']}；最终setup {b['setup_slack_ns']:+.3f}ns、hold {b['hold_slack_ns']:+.3f}ns；{len(a['setup_relationships'])}组setup、{len(a['hold_relationships'])}组hold和{a['detailed_slack_paths']}条详细slack非负。未改SDC以放宽指标，旧名称警告留档，不称所有约束/CDC全面签核。

尚未下载本版。建议现场分别拍摄FULL颜色、BAL/CLEAN、FRAME录制/回放/对比、SHAPE分类与锁定、EXPR的OFF→识别→退出，以及四页循环无NUMBER入口。53颜色认可不能代替本版实物验收；本版未测真实准确率、色差或长时间稳定性。
''',encoding='utf-8')
    lines=['# FINAL06 构建与验证结果','',f"完整map/interface/pnr/pgm通过；setup {b['setup_slack_ns']:+.3f}ns、hold {b['hold_slack_ns']:+.3f}ns。未下载板卡。",'', '| 项目 | 结果 |','|---|---|',f"| XLR | {b['resources']['XLRs']} |",f"| RAM | {b['resources']['Memory Blocks']} |",f"| DSP | {b['resources']['DSP Blocks']} |",f"| 当前回归 | {v['rerun_current_rtl_cases']}组重跑＋{v['unchanged_dependency_cases']}组未改依赖复核＋3套算法证据 |",'', '| 用例 | 结果 | 日志 |','|---|---|---|']
    lines += [f"| {x['name']} ({x['configuration']}) | PASS | {x['log']} |" for x in v['cases']]
    current_inputs={n:h for n,h in b['source_hashes'].items() if n!='ti60f225_oob.xml'}
    trials=[]
    for attempt in json.loads((V/'PNR_SEED_TRIALS.json').read_text()):
        status_file=P/attempt['archive']/'BUILD_STATUS.json'
        if not status_file.exists():continue
        old_status=json.loads(status_file.read_text())
        if {n:h for n,h in old_status.get('source_hashes',{}).items() if n!='ti60f225_oob.xml'}==current_inputs:
            trials.append(attempt)
    if trials:
        lines += ['', '本轮相同RTL/IP/模型/接口/SDC的布局尝试（仅PnR seed及放置优化力度变化；失败镜像不作下载入口）：', '', '| seed | 放置力度 | setup ns | hold ns | 时序 |','|---|---|---|---|---|']
        lines += [f"| {x['seed']} | {x.get('placer_effort_level',2)} | {x['setup_slack_ns']:+.3f} | {x['hold_slack_ns']:+.3f} | {'PASS' if x['timing_passed'] else 'FAIL，已归档'} |" for x in trials]
        lines += [f"| {a['pnr_seed']}（当前） | {a['placer_effort_level']} | {b['setup_slack_ns']:+.3f} | {b['hold_slack_ns']:+.3f} | PASS |"]
    lines += ['',f'bit SHA256：`{bit}`','',f'hex SHA256：`{hx}`','', '源码/原工程保护/时序明细见verification/AUDIT06.json；测试依赖和边界见verification/VALIDATION_CURRENT.json。']
    (P/'验证与构建结果.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('Wrote current FINAL06 README, operations, comparison and build/validation records')

if __name__=='__main__':
    if '--docs' in sys.argv:documents()
    else:audit()
