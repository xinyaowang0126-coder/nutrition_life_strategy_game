# 最新双篇Web试玩发布

日期：2026-10-27。用户要求提交整个项目、推送GitHub并确保线上试玩可行。发布目标为现有仓库的`main`分支；GitHub Pages直接使用该分支根目录，根页面跳转`Play/`。

## 发布内容

- 学生篇与周阿姨篇的当前源码、测试、素材和项目说明／汇报材料。
- 周阿姨在家决定用餐、厨房制作、开门冰箱、集市与三家店铺，配方、库存、冷藏／再热、邀约和汇演。
- 两篇共用的已选卡、成本预览、详情、键盘／触摸与每日弹层衔接，以及自动／手动存档。
- 从当前源码重新生成的9个`Play/`文件，保持无Web线程依赖的现有导出设置。

## 体积与发布保护

旧本地候选PCK为139,041,360字节，超过GitHub普通Git的100 MiB单文件限制。28张不透明场景插画改用Godot有损导入、质量0.9；保留原始PNG、尺寸、透明物件及字体，不改存档格式或玩法数据。新包的精确大小和SHA-256见[文件清单](../assets/github-release-2026-10-27/web-files.json)。

`Assert-CleanWebPack`现在先拒绝超过100 MiB的PCK，再检查目录、关键运行资源、项目配置和开发内容隔离。新增门禁使用实际超限文件验证拒绝路径。受限环境曾导出空`project.binary`，现有项目配置门禁正确拒绝；正式包在能访问本机Godot配置及模板的环境重新生成，必须通过相同审计才可发布。

压缩设置说明：[Godot官方图片导入文档](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)。单文件限制：[GitHub官方说明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。

## 提交前验证

- 完整源码回归527/527、45套件、0失败／0跳过，主场景启动通过；[摘要](../assets/github-release-2026-10-27/verification.json)。
- 发布门禁42项通过，包括超限PCK、空／损坏项目配置、缺失素材和开发插件泄漏。
- 最终图片导入后重跑可读性套件、主场景与Web导出审计。
- 在独立`Play/`资源目录中直接加载发布PCK，检查37张故事贴图和两个故事开局；[包内运行摘要](../assets/github-release-2026-10-27/pack-runtime.json)。

本记录保留提交前证据。科学审校、真人学习效果、真实手机硬件和完整七日浏览器体验不由工程回归代替。

## 推送后核验方法

1. 确认远端`main`等于本地提交，Pages构建的`commit`为该提交且状态`built`。
2. 从正式Pages地址下载`Play/index.pck`，与文件清单逐字节SHA-256核对；检查HTML、JS、WASM与音频工作脚本均可访问。
3. 用真实浏览器进入两个故事，实际选择并确认一餐，检查最新厨房／集市场景；刷新后从“继续”恢复，确认阶段、余额与记录没有重复结算，查看控制台错误。

试玩地址：<https://xinyaowang0126-coder.github.io/nutrition_life_strategy_game/Play/>。
