# FINAL06_HDMI_Expression_System

2026-11-01，HDMI共用编号59，从56独立派生。保留原56、FINAL04、FINAL05及58，不覆盖历史工程。

现行目录：`E:\ELEGtools\xianshu_FPGA\FINAL06_HDMI_Expression_System`，配套ZIP放在工程同级。2026-11-01按用户要求迁入xianshu_FPGA主目录；历史构建日志中的旧绝对路径保留为当时记录。

本版保留FINAL04实际功能及56真实算式识别，彻底移除独立NUMBER页面。主功能只有 **FULL → FRAME → SHAPE → EXPR → FULL**。上电EXPR、识别OFF、搜索框ON；切主功能关闭识别。

- FULL：原图ORIG → BAL → CLEAN → 红色边缘叠加RED → GREY，LIVE/HOLD及单次更新；内部旧样式编码不变，避免改变已有回放解释。
- FRAME：120帧不可变录段＋3实时槽，LIVE/REPLAY/COMPARE，三速、循环、逐帧、A/B独立帧和样式、双游标、完成写入毫秒差、提前停止和排空重录；LIVE页NEW TAKE下新增LOCK A+B，同时锁住完整同帧或恢复实时，样式独立。
- SHAPE：原FINAL04完整几何分类、分类轮廓着色、结果锁定、AUX、H/L/DN。
- EXPR：复用现有全分辨率Canny边缘进入768ROI/192网格/32组件/原模型及整数运算；RESULT或SW3启动/关闭。红边缘始终显示，识别OFF时也可用于对准。无有效结果按原流程显示等待、未知或明确标记的上一有效结果。
- WB有效Q8基准R320/G158/B329，限幅AUTO与LOCK，G不二次抑绿；Gamma2.2、Gaussian及轻锐化固定开启。WB不反馈Canny/识别输入。
- 默认阈值BAL H6/L4、CLEAN H9/L4、EXPR H11/L5、FULL红边缘RED H8/L4；SHAPE H6/L3，DN ON且可调，各样式手调值分别记忆，恢复检测回到对应默认值。原图/GREY不另设边缘默认值。
- FPS DISPLAY开启后显示固定的DISPLAY FPS 60，不显示相机/视频实测计数；上下文菜单、有效Q8和300显示帧提示保留。300帧在60Hz时名义5秒。

FRAME仍只共享一套Canny：LIVE中最后调整的边缘样式加载对应采集阈值，两个视图不能同时拥有两套独立检测参数。历史回放样式切换只解释已存像素，不重算旧帧；新阈值仅作用后续采集。算式识别已改用同一套Canny的真实边缘位，EXPR使用独立H/L手调记忆，默认11/5；CLEAN独立默认9/4；生产不再实例化旧Sobel/连续性前端。模型、分割和整数运算不变。

独立数字标题、数字预览、字符框接口、页面入口及旧采集UI壳已移除。算式中必须识别0～9，因此保留内部MLP、权重和数字类模块；它们不构成独立NUMBER功能。

56相对FINAL04有内部资源取舍：读FIFO1024→512；只延迟最终缩图选中的低像素RGB554。功能清单没有删减，不能称RTL、抗停顿容量或所有场景完全相同。详细核查和证据见《FINAL04对照与整合留痕.md》。本版额外继承已有MenuFocusFix，防止样式/PAGE编辑时上下文重排丢失焦点。

完整map/interface/pnr/pgm通过，PnR seed7/TIMING_3/放置力度5；XLR 57291 / 60800、RAM 246 / 256、DSP 74 / 160；最终setup +0.074ns、hold +0.026ns。7组当前源码重跑＋18组未改依赖回归复核＋3套依赖hash核验算法证据。未下载板卡，现场识别、画面和长期稳定性待验。沿用SDC仍有旧名称警告，不等同所有CDC/约束全面签核。

当前修正版下载：`outflow/FINAL06_HDMI_Expression_System_BAL6_4_CLEAN9_4_20261101.bit`；Flash：同名前缀`.hex`。正常名字`outflow/FINAL06_HDMI_Expression_System.bit/.hex`及通用名逐字节一致。

bit SHA256：`4579e103e18c53f8ea3786ef682235c16a2005a8dcc9d81062322998bec20046`

当前操作以《菜单操作指南.md》为准。docs/内34和FINAL04资料为来源历史，旧五页面/NUMBER描述不代表本版。

新增菜单位置预览见[FRAME双窗锁定界面](verification/frame_pair_locked_settings.png)，由实际UI RTL配合纯色合成输入生成，不是板卡拍摄。
