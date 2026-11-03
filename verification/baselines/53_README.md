# 53 HDMI Green Suppress Gamma

从51 RGBFix Linear派生，保留CFA_RGGB=0的红蓝映射。用户反馈线性版太暗，要求抑制绿色并恢复之前Gamma/锐化。
生产路径：三通道AUTO/LOCK/MANUAL增益选择 → 绿色增益乘224/256（四舍五入）→ Gamma2.2 → 原轻锐化（strength4/detail limit16）→ OSD → HDMI1080p60。
绿色修正放在白平衡选择之后，AWB统计仍看未修正的输入；模式冻结/切换不会重复乘绿色系数。屏显G的Q8为实际有效值。0.875是本次候选初值，尚非用户确认的环境配比。SW3选G后SW1/SW2仍可调整，步长提示为修正前控制步长，实际G约为其0.875倍。
按键沿用51：SW0模式循环，SW3选择R/B/G/LIGHT，SW1加、SW2减，SW3+SW2粗细步长，SW3+SW1预设，SW3+SW0返回AUTO。LIGHT可整体调亮。摄像头J4，HDMI TX。
不提高传感器曝光，沿用半曝光00/5D/60；Gamma主要提亮中间调，不保证修复欠曝、噪声、失焦或高光饱和。47/51原工程保留，不自动修改Canny或整合版50。
工程入口ti60f225_oob.xml，下载outflow/53_HDMI_WB_GreenSuppress_Gamma.bit。build_final.cmd编译，run_tests.cmd --hd验证，verification/package_project.py打包。
完整验证结果见verification/green_gamma_status.json及regression53.log。编译/仿真通过不代表实物颜色、清晰度已经验收。

当前完整编译map/interface/pnr/pgm均PASS；约束报告最小setup +0.379ns、hold +0.026ns，不扩展为CDC或全部板级时序签核。完整HD手动帧2073600像素、RGB AUTO两帧4147200像素、HDMI RGB/DE/HS/VS对照通过。绿色系数0/224/256、512个增益及饱和/舍入测试通过；新增模式测试独立日志tb_green_modes53.log。其它模块回归沿用51，日志中的旧编号仅表示继承测试名称。
BIT SHA256: `e84424ceaa9bccaca2a273ca98d3f5bed17414cda9c131596cef341fdb7109b1`


## 2026-10-31 用户验收与后续默认（覆盖上文待验/候选配比状态）

用户实物反馈效果非常好，几乎没有色差；LOCK照片有效Q8：R320（1.250000倍）、G158（0.6171875倍）、B329（1.28515625倍）。当前环境接受为以后彩色/WB默认，保留本版Gamma与锐化。此为用户主观实物验收，不是仪器测色证明。
G158是已经乘过224/256的最终有效增益，后续不能再乘一次。权威默认资料为同级上层default_wb_profile.json；工程calibration_profile.json也已记录。
后续AUTO暂定相对该基准±5%：R304～336、G151～165、B313～345，每次有效更新最多1Q8。此范围是助手对“小幅微调”的实现约定。本次只更新校准资料，53 RTL/bit不变，现有53上电AUTO尚未加入上述基准初始化与限幅；需要保留照片效果时使用LOCK。后续工程按新默认实现并编译验证。不追改历史工程或无WB的Canny输入。
