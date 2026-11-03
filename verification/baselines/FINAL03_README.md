# FINAL03 HDMI 整合版

2026-10-31。从根目录 `50_HDMI_Canny_System` 的 BlackFix_NoSwap_20261031 独立派生；占用 HDMI 共用编号空间的 54 号，工程名按用户要求以 FINAL 开头。原 50、34 和纯 RGB 分支保留。

上电即 **FULL / A / WB / LIVE**。SW0 单键循环 FULL → SPLIT → SHAPE → NUMBER → EXPR → FULL；SW1 打开/关闭右侧设置卡片。没有组合键命令，任何多键手势均取消；SW0/SW1 长按也只执行一次。

- FULL：SW2 循环 WB / RED / BAL / GRAY / CLEAN，SW3 冻结/继续当前对象。
- SPLIT：固定 A 左 B 右，SW2 选择 A/B，SW3 冻结/继续选中对象；SYNC 时作用于组。
- SHAPE：沿用原图形算法；SW2 开关辅助标注，SW3 锁定/解锁已有有效结果，视频继续实时。没有有效结果时提示 NO RESULT。
- NUMBER / EXPR：完整搜索框与对应结果区，NUMBER 有十字与空白 28×28 预览。参照 34 的实际坐标和字形绘制，显示 NUMBER ?、EXPR LIVE WAIT / EXPR ?；没有数字/算式后端，不产生假数字、假运算或假检测框。SW2 控制辅助框，SW3 无结果时提示 NO RESULT。

白平衡是三通道 RGB AUTO/LOCK。**Gamma 2.2、Gaussian 降噪/轻锐化固定开启**，锐化 strength=4、detail limit=16，不提供开关、强度或 RGB 人工增益按键。Canny 的 GLOBAL DENOISE 是独立的检测前端参数，不改变 WB 滤波链路。没有套用 53 的候选绿色抑制比例。

检测默认 H6/L3、去噪 ON；保留 H/L 手动调整，始终 1≤L≤H≤255。新界面只提供采集检测阈值，取消冻结缩图阈值预览与无效 MIN 项。冻结图保留采集当时的 BAL/CLEAN，修改共用检测参数不会重算旧图；需要更新冻结帧或恢复 LIVE。

设置卡片最多显示六项，向下自动滚动；选中黄色、编辑青色。设置不会自动消失，只由 SW1 显式关闭；关闭在下一显示帧完整移除面板与帮助。恢复默认必须经 SW0 确认，SW1 在确认框中取消回列表。设置只保留本次上电期间，不写 Flash。

保留 50 的紧密 48 位快照、512 深 FIFO、AXI 安全取消/排空和黑窗恢复。为同时保留 A/B/SYNC 冻结对象并独立查看实时识别视频，快照池扩为 **6×4 MiB**；新增实时显示槽独立受保护，不占用原三条冻结时间线。NUMBER/EXPR 图框在显示输出侧以原分辨率绘制，避免随快照缩小。具体适配见 [菜单实现说明](菜单实现说明.md)。

[按键操作](按键操作_简版.md) · [构建与验证](编译与验证结果.md) · [菜单 RTL 预览](verification/menu_v2/full_settings.png) · [数字页](verification/menu_v2/number_shell.png) · [算式页](verification/menu_v2/expression_shell.png)

下载文件：`outflow/FINAL03_HDMI_Canny_System.bit`；Flash 文件：同名 `.hex`。以 `outflow/BUILD_STATUS.json` 的完整构建、源码哈希和实际时序为准。仿真截图使用合成背景，不是摄像头实拍；本工程尚待上板验收。

复现入口：`python tools/build_project.py`；`python tools/run_menu_v2.py`；`python tools/run_checks.py`；`python verification/hdmi50/validate_display_v2.py`。打包入口 `python tools/package_project.py` 会校验当前构建、验证记录及 ZIP 内逐文件 SHA256。
