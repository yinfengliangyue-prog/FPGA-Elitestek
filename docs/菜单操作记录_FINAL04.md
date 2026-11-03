> 来源历史资料。本文保留34或FINAL04时期的设计和验证记录；当前FINAL06的四功能、操作及构建结论以工程根目录README和指南为准。

# FINAL04 菜单操作记录（现行工程版）

更新：2026-10-31。适用工程：`E:\ELEGtools\xianshu_FPGA\FINAL04_HDMI_WB_Replay_System`，共用编号55。

本文将原《HDMI菜单交互重设计方案 v2》更新为FINAL04已经实现的菜单和按键记录。依据为本工程《改动与优化留痕_拍摄撰稿.md》、`keys55.v`、`menu55.vh`、`control55.v`和`ui55.v`。本次只更新文档，不修改RTL、下载文件或独立34_math2.1工程。

## 1. 从旧方案到FINAL04的变化

| 原v2方案 | FINAL04当前实现 |
|---|---|
| FULL → SPLIT → SHAPE → NUMBER → EXPR | FULL → FRAME → SHAPE → NUMBER → EXPR |
| SPLIT的独立/同步冻结时间线 | FRAME的LIVE／REPLAY／COMPARE，120帧历史录段＋3实时槽 |
| FULL选择A/B、与分屏共用旧冻结对象 | FULL独立保持当前帧；更新或恢复实时，不再选择旧A/B/SYNC对象 |
| 部分模式记忆菜单选中位置 | 每次重新打开设置，选中当前场景的第一优先项 |
| 通用参数固定排在后面 | Canny/SHAPE优先H、L、DENOISE；回放优先播放/帧号/速度；对比优先对象/A帧/B帧 |
| 主功能短提示约2秒 | 左下角短提示300显示帧，60Hz名义5秒 |
| 泛化的三通道AUTO/LOCK | 53颜色基准R320/G158/B329，有限AUTO微调；有效Q8只读 |
| 讨论中的数字/算式入口 | 保留搜索框和未知结果外壳，没有数字识别/运算后端 |

旧的两键/三键翻页、A/B同步和四键恢复命令均不使用。灰度GRAY仍保留，白平衡Gamma/Gaussian/轻锐化固定开启，不增加滤波按键。

## 2. 上电状态和主功能切换

上电进入 **FULL／WB彩色／LIVE／WB AUTO**，设置关闭；检测默认 **H6、L3、DENOISE ON**。有效白平衡基准为 **R320／G158／B329（Q8，256=1倍）**。后台自动开始录制一段最多120个处理输出帧，不必先进入FRAME。

设置关闭时，每次短按并松开 **SW0**，主功能循环：

**FULL全屏 → FRAME缓存/回放/对比 → SHAPE图形 → NUMBER数字界面 → EXPR算式界面 → FULL。**

| 从刚上电开始 | 操作 |
|---|---|
| 全屏彩色 | 无需按键 |
| 缓存/回放/对比 | SW0一次，首次进入FRAME LIVE |
| 图形识别 | SW0两次 |
| 数字界面 | SW0三次 |
| 算式界面 | SW0四次 |
| 回到全屏 | EXPR下再按SW0一次 |

来回切主功能不清空已录历史；FRAME子页可能保留本次上电的上次状态，因此使用过程中要看屏上LIVE／REPLAY／COMPARE，不要始终按首次进入推算。

## 3. 四个按键的现行分工

以下都是开发板SW0～SW3，操作在松开后执行。正常短按约0.1～0.3秒即可；每步先松开，再按下一步。

| 当前场景 | SW0 | SW1 | SW2 | SW3 |
|---|---|---|---|---|
| FULL | 下一主功能 | 打开设置 | WB→RED→BAL→GRAY→CLEAN循环 | 暂停／恢复全屏画面 |
| FRAME LIVE | 下一主功能 | 打开设置 | 停止本段，进入REPLAY | 停止本段，进入REPLAY |
| FRAME REPLAY | 下一主功能 | 打开设置 | 历史上一帧 | 历史下一帧 |
| FRAME COMPARE | 下一主功能 | 打开设置 | 所选A/B上一帧 | 所选A/B下一帧 |
| SHAPE | 下一主功能 | 打开设置 | 辅助标注显示开关 | 有效结果锁定／解锁 |
| NUMBER／EXPR | 下一主功能 | 打开设置 | 搜索辅助框显示开关 | 提示NO RESULT，不进入假LOCK |
| 设置列表 | 编辑选中项／执行动作 | 关闭设置 | 上一项 | 下一项 |
| 设置编辑 | 完成编辑，回列表 | 关闭设置 | 数值减／前一选项 | 数值加／后一选项 |
| 动作确认框 | 确认执行 | 取消，回设置列表 | 无动作 | 无动作 |

**SW1在确认框里先取消确认，不会同时关闭设置；需要关闭时再按一次SW1。**

上电持键必须先全部松开。多键手势取消，不执行组合命令。SW0/SW1长按也只执行一次；只有H/L和历史帧号编辑、主画面的逐帧操作支持SW2/SW3长按连调，约0.6秒后每0.15秒一步。逐帧每次只移动一帧，到首尾饱和，不循环；手动步进会暂停播放。

## 4. 设置面板怎样使用

1. SW1打开右侧设置卡片，黄色为选中项。
2. SW2向上、SW3向下选择；共六行可见，超出自动滚动。
3. SW0进入编辑，当前项变青色。
4. SW2减小/前选、SW3增大/后选，调整直接生效。
5. SW0回列表，或SW1直接关闭，保留本次上电的调整。

设置不自动超时关闭。打开期间SW0不切主功能，SW3不执行主画面的冻结/步进/锁定操作。关闭后不留下设置帮助文字。再次打开总是选第一优先项，方便直接调常用参数。

切换BUFFER PAGE或彩色/边缘菜单上下文后，自动结束当前编辑；应重新看黄色选中项，再进入编辑。不能以为下一次SW3还在修改原来的PAGE或样式。

NEW TAKE、RESTORE VIEW、RESTORE DETECT需要SW0再次确认；仅上下浏览不会执行。UPDATE HELD FRAME、STOP AND REVIEW和RESULT为动作项；EFFECTIVE R/G/B Q8是只读项，SW0不会进入人工调节。数值在相应帧边界发布；这里只保留本次上电状态，不写Flash。

## 5. 各场景的菜单顺序

以下顺序按当前`menu55.vh`记录，英文是屏上菜单名。**RED／BAL／CLEAN属于边缘样式；WB／GRAY属于彩色/灰度场景。** FRAME LIVE只要任一窗口使用边缘样式，就把H/L/DENOISE置顶，所以上电默认WB/BAL属于此类。

| 场景 | 从第一项开始的实际顺序 |
|---|---|
| FULL WB／GRAY | DISPLAY STYLE → GLOBAL WB → EFFECTIVE R Q8 → EFFECTIVE G Q8 → EFFECTIVE B Q8 → VIDEO → UPDATE HELD FRAME → OSD → FPS DISPLAY → RESTORE VIEW |
| FULL RED／BAL／CLEAN | GLOBAL H → GLOBAL L → GLOBAL DENOISE → 上述FULL列表 → RESTORE DETECT |
| FRAME LIVE，任一窗为边缘样式 | GLOBAL H → GLOBAL L → GLOBAL DENOISE → BUFFER PAGE → STOP AND REVIEW → A STYLE → B STYLE → NEW TAKE → GLOBAL WB → EFFECTIVE R/G/B Q8三项 → OSD → FPS DISPLAY → RESTORE VIEW → RESTORE DETECT |
| FRAME LIVE，两窗均为WB／GRAY | BUFFER PAGE → STOP AND REVIEW → A STYLE → B STYLE → NEW TAKE → GLOBAL WB → EFFECTIVE R/G/B Q8三项 → OSD → FPS DISPLAY → RESTORE VIEW → RESTORE DETECT |
| FRAME REPLAY | PLAYBACK → FRAME B → SPEED → BUFFER PAGE → A STYLE → B STYLE → NEW TAKE → GLOBAL WB → EFFECTIVE R/G/B Q8三项 → OSD → FPS DISPLAY → RESTORE VIEW → GLOBAL H → GLOBAL L |
| FRAME COMPARE | SELECT A/B → FRAME A → FRAME B → BUFFER PAGE → A STYLE → B STYLE → NEW TAKE → GLOBAL WB → EFFECTIVE R/G/B Q8三项 → OSD → FPS DISPLAY → RESTORE VIEW → GLOBAL H → GLOBAL L |
| SHAPE | GLOBAL H → GLOBAL L → GLOBAL DENOISE → AUXILIARY → RESULT → GLOBAL WB → EFFECTIVE R/G/B Q8三项 → OSD → FPS DISPLAY → RESTORE VIEW → RESTORE DETECT |
| NUMBER／EXPR | AUXILIARY → RESULT → GLOBAL WB → EFFECTIVE R/G/B Q8三项 → OSD → FPS DISPLAY → RESTORE VIEW |

历史页的GLOBAL H/L仍是共用采集参数，只影响之后的采集，不会重新计算已录历史。REPLAY/COMPARE没有单独的旧快照阈值预览，也不显示旧INDP/SYNC项。MIN已取消。

## 6. FULL与边缘显示的操作实例

### 6.1 全屏切样式

在FULL主画面，SW2每次前进一个样式：

**WB彩色 → RED彩色红边 → BAL平衡边缘 → GRAY灰度 → CLEAN干净边缘 → WB。**

从刚上电开始，SW2一次为RED，两次为BAL，四次为CLEAN。也可在设置的DISPLAY STYLE里编辑，SW2前选、SW3后选。

### 6.2 调H/L和去噪

在FULL的RED/BAL/CLEAN，或SHAPE下：

- SW1打开设置，第一项就是GLOBAL H。
- 调H：SW0进入编辑，SW2减、SW3加；SW1关闭。
- 调L：打开设置后SW3一次选GLOBAL L，再SW0编辑。
- 调去噪：打开设置后SW3两次选GLOBAL DENOISE，再SW0编辑，SW2或SW3切换。

默认H6/L3/DN ON，范围保持 **1≤L≤H≤255**。降低H时如L超限，L同步钳制。菜单H006/L003就是数值6/3，三位格式不是新的阈值含义。

### 6.3 暂停、更新和恢复

FULL主画面SW3暂停，画面标HOLD；再按SW3恢复LIVE。暂停后想换一张仍保持暂停：SW1打开设置，选UPDATE HELD FRAME，SW0执行，再SW1关闭。也可以编辑VIDEO的LIVE/HOLD。

FULL的保持独立于120帧录段，不因暂停全屏而停止后台录制。改变GLOBAL参数不重算旧保持帧，要更新或恢复LIVE查看新采集效果。

## 7. FRAME的120帧录段、回放与对比

### 7.1 先理解录制规则

上电自动录一段最多120个处理输出帧，只发布完整写入的帧。录满后本段保留，实时画面继续；不是滚动的“最近120帧”。切主功能或返回LIVE不清空本段，只有确认NEW TAKE才覆盖重录。

按60Hz处理输出名义约2秒；传感器较慢时可能存在重复曝光，不能把120个处理输出帧等同120次独立曝光。帧号按有效段从001开始，界面N为有效数量。

### 7.2 从上电进入回放

1. SW0一次进入FRAME，首次是LIVE：左A实时、右B同一实时帧，默认WB/BAL。
2. 主画面短按SW2或SW3，停止录制并进入REPLAY；已完整写入的历史保留，初始暂停在首帧。
3. REPLAY左侧继续实时，右侧显示历史；若没有有效历史帧，不能假装已有可播放结果。

等录满120再执行第2步可回放完整段；更早执行就是提前停止。FRAME LIVE设置中的STOP AND REVIEW等效于这一停止回放动作。

### 7.3 播放和暂停

REPLAY下：**SW1打开 → 第一项PLAYBACK → SW0编辑 → SW3切PLAY/PAUSED → SW1关闭。** SW2编辑该项也会切换。进入回放不会自动播放，需用PLAYBACK启动。

播放到段尾自动循环，仅在FRAME REPLAY实际取显示帧时推进。通过BUFFER PAGE离开REPLAY会暂停；重新从BUFFER PAGE进入REPLAY会从首帧暂停开始。仅切到其他主功能时，FRAME子页和播放开关可能保留，回来后应看PLAY/PAUSED状态。

### 7.4 逐帧与速度

- 关闭设置时，SW2上一帧、SW3下一帧，长按连续；手动操作立即暂停播放，到首尾不回绕。
- 改速度：SW1打开，SW3两次选SPEED，SW0编辑；SW3按 **0.5×→1×→2×→0.5×** 循环，SW2反向。默认1×，所以第一次SW3是2×。
- 改速度不等于启动播放；需要时再到PLAYBACK设PLAY。
- FRAME B可直接编辑回放帧号；菜单里的逐帧同样暂停播放。

### 7.5 切换LIVE／REPLAY／COMPARE

在FRAME设置里找 **BUFFER PAGE**，SW0编辑，SW3按 **LIVE→REPLAY→COMPARE→LIVE** 循环，SW2反向。页面切换生效后会退出编辑，主功能仍为FRAME。

从REPLAY进入COMPARE的具体步骤：**SW1打开 → SW3三次到BUFFER PAGE → SW0编辑 → SW3一次到COMPARE → SW1关闭。**

首次FRAME LIVE默认WB/BAL，因此BUFFER PAGE位于H/L/DENOISE之后，是第四项；不能照REPLAY的第一项PLAYBACK来推算LIVE菜单。

### 7.6 A/B不同时刻对比

COMPARE左历史A、右历史B，位置固定；进入该页初始化A为首帧、B为本段最后一帧，所选对象默认B或保留已有选择。

- 改A帧：SW1打开，SW3一次到FRAME A，SW0编辑；自动选A，SW2/SW3减/加帧号；SW0完成或SW1关闭。
- 改B帧：重新SW1打开，SW3两次到FRAME B，SW0编辑；自动选B，再减/加帧号。
- 改当前逐帧对象：在第一项SELECT A/B里SW0编辑，SW2或SW3切A/B，SW1关闭；主画面SW2/SW3随后只移动所选对象。
- A STYLE/B STYLE分别设置两窗样式，彼此独立；需要同帧不同效果时，把A/B设置为同一帧号，不需要旧SYNC组合键。

时间线显示双游标、A/B帧号、有效段长N，以及时间差DT。时间戳为1ms精度、16bit模65.536秒的**完成写入时刻**，不是曝光起点；DT不应写成精确传感器曝光间隔。

进入COMPARE会重新设首/尾帧，不应把离开后再进入理解为保留上次两个帧号。三页的样式配置分别保留；恢复视图默认只影响当前页样式。

### 7.7 返回LIVE与重录

通过BUFFER PAGE回LIVE只恢复实时查看，仍保留本段，**不自动重新录像**。

重录：在FRAME任一页设置里选NEW TAKE → SW0弹出确认 → 再SW0确认。系统等待当前读/写排空，清理旧历史并回LIVE开始新一段；不是按下瞬间强行改DDR引用。SW1在确认框取消，旧历史保持。

重录保留H/L和去噪等检测设置，不等于恢复检测默认。切到SHAPE/NUMBER/EXPR也不会自行重录。

## 8. 白平衡、图形及数字/算式的真实功能

### 8.1 白平衡

本版采用53的颜色方法和用户认可基准，有效Q8上电/复位即为R320/G158/B329。AUTO有效范围为R304～336、G151～165、B313～345，每个接受更新每通道最多1 Q8，三路在有效帧边界共同发布；坏样本保持。LOCK冻结实际有效值，不冻结视频。

设置中 **GLOBAL WB** 编辑AUTO/LOCK；EFFECTIVE R/G/B Q8为只读有效增益，不能人工加减，没有MANUAL。G158已经包含53抑绿，不再乘一次0.875。±5%/每次1Q8是已实现的保守微调约定，不是用户仪器测得的最优范围。

例如FULL/WB上电状态：**SW1 → SW3一次选GLOBAL WB → SW0编辑 → SW3切LOCK → SW1关闭**。在边缘/SHAPE场景WB位置会后移，应看菜单标签。

Gamma2.2、Gaussian与限幅轻锐化strength4/detail16固定开启；没有滤波组合键或独立开关。GLOBAL DENOISE是Canny检测去噪，不能把它当成关闭WB颜色滤波。WB校准不反馈原Canny检测输入。

### 8.2 图形

FULL起点SW0两次进入SHAPE，真实图形后端工作。SW2仅隐藏/显示辅助标注，不关闭检测；SW3锁定/解锁已经有效的结果和标注，视频继续实时。无有效结果时提示NO RESULT，不进入假LOCK。

GLOBAL H/L/DENOISE调整会解除结果锁定；WB变化也解除该锁定。离开图形模式后清理锁定，重新进入按真实检测重新发布。

### 8.3 数字和算式

NUMBER/EXPR保留原版式的768×768搜索框（1920×1080下起点576,156）、十字、未知结果和相应预览位置。NUMBER显示NUMBER ?；EXPR显示EXPR LIVE WAIT／EXPR ?。SW2开关辅助框，SW3只给NO RESULT提示。

FINAL04没有数字预处理/MLP/算式后端，不输出真数字、运算结果或假LOCK。独立34_math2.1的真实识别是另一工程，本次文档更新不修改其原按键，也不把它的验证计入FINAL04能力。

## 9. 显示、复位与拍摄记录

主功能/样式/部分操作提示在左下角显示300个显示帧，1080p60名义5秒；不是设置自动关闭时间。设置卡片无超时，SW1显式关闭。HOLD、SHAPE LOCK、FRAME时间线/播放状态和有效结果等按实际状态显示，不能用短提示消失推断已恢复实时。

OSD SIMPLE/DETAIL控制额外状态文字，FPS DISPLAY可单独显示真实测量值；关闭设置后仍开启的DETAIL/FPS不是帮助残留，拍摄前需要干净画面可设SIMPLE、FPS OFF。

RESTORE VIEW只恢复当前功能显示配置，不清空120帧历史，不等于全系统复位。RESTORE DETECT确认后恢复H6/L3、DN ON；改变GLOBAL不重算历史。没有四键恢复或掉电保存。

建议拍摄顺序：

1. FULL彩色，打开GLOBAL WB，对比AUTO/LOCK并拍有效Q8。
2. FULL切BAL或CLEAN，打开设置演示H/L/DENOISE置顶，关闭设置后拍干净画面。
3. FRAME LIVE拍REC/DONE与有效数量，停止进入REPLAY。
4. 演示PLAY/PAUSED、0.5×/1×/2×、首尾饱和逐帧。
5. COMPARE选择A/B不同时刻，拍双游标、帧号、样式和DT；也可同帧不同样式对比。
6. NEW TAKE先取消一次，再确认一次，拍重新录制过程。
7. SHAPE拍真实结果/标注锁定；NUMBER/EXPR仅拍界面结构，不用撰稿描述成识别或运算成功。

## 10. 当前版本的实现取舍与证据

颜色链沿用53三通道统计、颜色/Gamma2.2及固定滤波方法，计算仍为RGB888；颜色基准是用户当前环境主观认可，不宣称仪器零色差或任意照明最优。

记录为960×540、每像素32bit：BAL8＋CLEAN8＋已检出边缘1＋标注1＋RGB554。完整分辨率先算边缘/BAL/CLEAN，再2×2池化。颜色缓存与FINAL03同为RGB554，低于独立52的RGB887，不是无损RGB888回放；旧NMS不再保存，因此没有冻结缩图重分类菜单。

外部DDR为256MiB，处理区120历史＋3实时槽，结束0x0FF99000，余421,888字节；不再叠加旧六个4MiB池。片内RAM与外部DDR分别预算。GRAY从已存彩色即时计算，无独立图像平面；不能把资源下降写成删除GRAY获得。

当前构建RAM224/256、XLR40407/60800、DSP67/160，最终setup +0.253ns、hold +0.026ns。14组当前源码配置重跑通过。全高清分别覆盖WB算术/边界逐像素对照、4帧显示输运；完整RAW/120帧共享DDR整链为缩小合成输入，没有声称120个原始相机全高清帧仿真。

当前bit：`outflow/FINAL04_HDMI_WB_Replay_System.bit`；SHA256：`6ebd25e21673e55bb53ecd1aeeb3f4bba3c817add3acd0a5e537bb099000d077`。后续改版以新的构建记录为准。

FINAL03“没什么问题”、53颜色认可与FINAL04软件验证分别记录；FINAL04尚未下载实物验收。拍摄后应补光照、相机、显示器、实际录放/黑屏/撕裂、持续时间及故障灯观察。

相关文件：[按键速查](按键操作_简版.md)、[菜单实现](菜单实现说明.md)、[改动与拍摄撰稿留痕](改动与优化留痕_拍摄撰稿.md)、[编译与验证](编译与验证结果.md)。原v2设计原文继续保留于`docs/菜单方案_v2_原文.md`，其中SPLIT/旧缓存/2秒提示等不再作为FINAL04操作依据。
