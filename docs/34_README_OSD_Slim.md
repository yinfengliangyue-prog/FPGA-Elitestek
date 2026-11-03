> 来源历史资料。本文保留34或FINAL04时期的设计和验证记录；当前FINAL06的四功能、操作及构建结论以工程根目录README和指南为准。

# 34_math2.1 HDMI：精简菜单同步版

本版保留真实算式识别，只同步拍摄所需菜单外观。生产入口 `math_hdmi_video` 默认 `SLIM_OSD=1`，上电精简；菜单字形、2倍字号、x=12/y=20、12像素字距、24像素行距、白字/深灰底与50整合版一致。34为EXPR补充X字形，其他共同字形逐位相同。

## 实际按键

| 按键 | 作用 |
| --- | --- |
| SW0短按后释放 | 原功能：OFF → NUMBER → EXPR → OFF |
| EXPR下SW0长按至少1秒后释放 | 原功能：锁定/解锁已确认算式结果 |
| SW1+SW2同时按下后全部释放 | 菜单页名循环 AI → AI EDGE → VIEW → CANNY → AI；仅切菜单页名，不改变识别算法 |
| SW0+SW1+SW2同时按下后全部释放 | 精简/帮助切换；组合键不会误触SW0模式或锁定 |

SW0保持原20ms去抖/1秒长按。新增菜单组合键同为20ms去抖；交错释放也会取消该整次SW0识别动作。任何按键唤醒对应菜单；在60Hz名义HDMI输出下480帧约8秒无操作，帮助和情境行隐藏。页名始终保留，识别开启才显示 `AI NUM1 SHAPE0 INDP`。帮助模式超时后会隐藏，下次按键可再次唤醒；再次三键组合可切回精简。

## 显示范围

- 精简默认仅有实际识别状态和页名。34没有白平衡/FPS功能，因此不显示虚构WB/FPS读数。
- SW0切模式/锁定后临时显示NUMBER/EXPR LIVE/LOCK上下文；停止操作约8秒后隐藏。
- 保留真实结果、搜索框、字符框和数字预览。为避开6行帮助区，结果移到y=180，NUMBER预览移到y=220；旧EXPR READY/诊断/底部SW0帮助在生产精简路径隐藏。
- 共同菜单区域适合剪辑衔接；两工程识别主体和整帧图像并不相同。50的NUM为空壳，34保留真实算法，不能用34识别画面证明50具有识别能力。

## 证据与构建

`verification/hdmi/SLIM_UI_VALIDATION.json`：真实组合键+原SW0、帧边界发布、帮助/上下文超时及115200像素菜单几何。

`verification/hdmi/SLIM_VIDEO_VALIDATION.json`：SLIM_OSD=1真实生产算式链与HDMI gearbox，确认12+34=46并抓取1920×1080实际串行RGB帧。`math_hdmi_slim_confirmed_frame.png`是实际仿真输出，不是手工排版示意。

`verification/hdmi/SLIM_HARDWARE_VALIDATION.json`：以STAGING_ORIGIN逐项审计未动算法、相机、DDR、HDMI/PLL/外设；重跑完整20位启动延迟、生产光栅+gearbox及原SW0。新增SDC仅为三路UI键输入到各自第一级同步器D端的精确例外，数量不为1会报错；视频时钟关系继续约束。

`verification/osd_original/VALIDATION.json`保留旧套件的每项真实结果。旧baseline分割/小尺寸框像素等夹具存在与当前噪声/诊断版不兼容的失配，不能把此记录写成“全部历史用例通过”；当前可用的发布、稳定、噪声和全高清HDMI测试证据分别保留。

`outflow/BUILD_STATUS.json`记录本次最终源hash、map/interface/pnr/pgm、全部setup/hold关系和最终place资源；`验证与构建结果_OSD精简.md`汇总结果。没有下载开发板，仿真和报告不等于实物显示/摄像头/电气/全部CDC签核。

## E盘工具与复现命令（PowerShell）

在本工程目录打开PowerShell，使用实际安装位置，避免历史脚本中的旧D盘参考：

```powershell
$env:EFINITY_RUN = 'E:/ELEGtools/efinity/2026.1/bin/efx_run.bat'
$env:MODELSIM_VSIM = 'E:/ELEGtools/Modelsim_201/modelsim_ase/win32aloem/vsim.exe'
python tools/check_slim_osd.py
python tools/check_slim_hardware.py
python tools/check_hdmi_video.py --slim
python tools/run_original_functional_regression.py
python tools/build_hdmi.py
python tools/package_slim.py
```

`run_original_functional_regression.py`会如实保留已知旧夹具失配；当前版必要的全高清/发布/稳定/噪声、精简菜单和硬件保护证据由`package_slim.py`逐项核对最终源hash。ModelSim会在ASCII临时路径运行，Efinity也采用独立ASCII快照，不更改原工程目录内的综合输入。
