# FINAL04 → 56 → FINAL06 核查与整合留痕

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

原FINAL04与56：rtl中131个文件逐字节一致、6个改变、没有缺失；ip 16个、model 24个一致。完整清单见verification/FINAL04_56_SOURCE_COMPARISON.json。

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

7组当前源码重跑＋18组未改依赖回归复核；另3套旧算法证据只在依赖源码及夹具hash匹配时复用。完整RAW/120帧共享DDR整链是缩小合成输入；四帧1080p显示输运单独核对。不能合称120个全高清真实相机帧整链识别仿真。

历史：FINAL06初版seed3曾生成bit但setup为-0.060ns，随后仅改seed2通过；其旧尝试及安装库权限处理保留在归档/历史记录。本轮BAL6/4、CLEAN9/4及EXPR参数记忆分离重新完整综合，当前有效结果只以最新BUILD_STATUS及下述时序为准。

完整构建PnR seed7/TIMING_3/放置力度5，XLR 57291 / 60800、RAM 246 / 256、DSP 74 / 160；最终setup +0.074ns、hold +0.026ns；15组setup、15组hold和258条详细slack非负。未改SDC以放宽指标，旧名称警告留档，不称所有约束/CDC全面签核。

尚未下载本版。建议现场分别拍摄FULL颜色、BAL/CLEAN、FRAME录制/回放/对比、SHAPE分类与锁定、EXPR的OFF→识别→退出，以及四页循环无NUMBER入口。53颜色认可不能代替本版实物验收；本版未测真实准确率、色差或长时间稳定性。
