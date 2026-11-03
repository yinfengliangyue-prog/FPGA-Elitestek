# 基线资料与参考实现

此目录保存FINAL03、52、53的来源说明/旧构建摘要，不是FINAL04当前通过报告。当前结果看verification/VALIDATION_CURRENT.json和outflow/BUILD_STATUS.json。

wb53_ref.v仅供仿真，将原53视频增强模块改名并接入已生效Q8，用原垂直行缓存作为算术对照，不参与生产综合。production使用compact行缓存，逐像素一致性另有日志。

source52子目录是52原参考模型/测试来源，原UI图片或报告只代表52；FINAL04菜单预览在verification根目录，并有UI_CAPTURE_PROVENANCE.json标注合成输入。
