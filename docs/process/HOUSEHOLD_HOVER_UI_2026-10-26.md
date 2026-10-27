# 周阿姨篇：透明插画按钮、悬停详情和共用界面风格

日期：2026-10-26。

家中做饭、存粮、去集市和食物卡补上桌面悬停、键盘焦点详情；移开后收起，预览不拦截点击。问号按钮打开固定详情，未营业店铺仍能查看规则。竖屏通过问号点按查看详情。

早餐店、家常小馆和水果摊复用家中入口的 `HouseholdPropButton` / `HouseholdPropArt`：透明底蒸笼、家常饭菜和水果筐直接叠在街景上，按插画轮廓和名牌点击，悬停放大、抬起，键盘焦点显示轮廓高亮。没有带框照片卡。

家中标题改为与学生篇一致的顶部居中纸签，显示“早餐去哪吃？”等餐次标题和操作提示；标题字体使用学生篇的粗体。家中、集市和食物卡的问号详情按钮共用学生篇 `V2Theme` 的深棕色样式。

同日补齐之前遗漏的“去集市”入口右上角问号。点击或触摸仅打开固定介绍，不进入集市；Esc 关闭后焦点回到该问号。补丁后的周阿姨界面回归 **36/36** 通过，三种尺寸重新通过鼠标／触摸检查，[专项测试报告](../assets/household-hover-2026-10-26/outing-details-tests-report.json)、[桌面详情](../assets/household-hover-2026-10-26/1280x720/outing-details.png)、[手机详情](../assets/household-hover-2026-10-26/390x640/outing-details.png)。本地 Web 候选已重新导出并通过包审计及运行检查；下方 526 项为本日上一轮完整回归，本补丁未重复全量运行。

三个新素材由内置 ImageGen 生成，保留透明度并保存到项目。文件和完整提示词见[素材清单](../../life-strategy/assets/generated/stories/props/market-props-manifest.json)。资源通过显式预加载进入导出依赖。

## 验证

- 完整回归 **526/526、45 套**通过：[测试报告](../assets/household-hover-2026-10-26/tests-report.json)。
- 独立原生窗口 **1280×720、640×960、390×640** 均通过鼠标、键盘输入和布局检查；两个竖屏窗口以原始 ScreenTouch 点按早餐插画进入菜单。覆盖悬停出现和收起、图片和名称点击、关闭中的店铺详情、Esc 返回、午餐营业状态。浏览前后余额、精力、库存和餐次记录保持。第一天介绍和午餐是明确的测试夹具，没有将此验证称为完整一日或七日试玩。
- [桌面报告](../assets/household-hover-2026-10-26/1280x720/report.json)、[竖屏报告](../assets/household-hover-2026-10-26/640x960/report.json)、[窄屏报告](../assets/household-hover-2026-10-26/390x640/report.json)。
- 验证门禁 **41 项**通过。
- 本地 Web 候选 `artifacts/household-hover-2026-10-26-web/`：PCK **132.60 MiB**。有效项目设置、开发内容排除和三个透明素材均通过[包审计](../assets/household-hover-2026-10-26/pack-audit.json)；匹配 Godot 运行时从生产 PCK 加载素材、集市原生控件、统一详情按钮和家中标题的[运行检查](../assets/household-hover-2026-10-26/pack-runtime.json)通过。最初沙箱内导出的临时配置写入失败，已在获准的正常 Godot 环境重新导出并通过检查。没有覆盖旧候选、Play 或 Windows 演示包。

## 画面

- [桌面家中标题](../assets/household-hover-2026-10-26/1280x720/home-prompt.png)
- [桌面集市透明按钮](../assets/household-hover-2026-10-26/1280x720/market-breakfast.png)
- [家中悬停详情](../assets/household-hover-2026-10-26/1280x720/home-hover-home_kitchen.png)
- [早餐店与统一问号按钮](../assets/household-hover-2026-10-26/1280x720/breakfast-menu.png)
- [窄屏集市](../assets/household-hover-2026-10-26/390x640/market-breakfast.png)

本轮修改与已有未提交工作保留在同一工作区，未提交、推送或对外发布。
