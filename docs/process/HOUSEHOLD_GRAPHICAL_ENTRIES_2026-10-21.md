# 周阿姨：图形物件承担入口

日期：2026-10-21。用户指出“现在按钮就只是按钮吗？我还是想要图形元素”。本轮在已经恢复的家居情境里补齐图形交互，不调整人物所在空间和出门流程。

## 改动

- 做饭、存粮、外出分别使用锅与食材、开门冰箱、购物袋的独立透明插画；记事本使用小册子与铅笔。原来的长名牌缩成短标签，保留少量辅助文字。
- 图形具有纸边、落影和轻微抬起/按压反馈，键盘焦点通过图形轮廓高亮表示；记事本聚焦时也保留图形表达。
- 图形和短标签连接到同一操作。透明区域按图片透明度过滤命中，避免放大后的透明留白拦住旁边的图形或详情入口。
- 图形锚定家中原有物件，背景、人物、外出弹窗、到店切换和返回家中的逻辑保持。现有配方、预算、库存和确认结算规则不变。
- 纹理与透明命中图片按资源共享缓存，避免每次返回来源页重复解码。

实现位于`HouseholdSourceStage.gd`、`HouseholdPropArt.gd`、`HouseholdPropButton.gd`和`PropTint.gdshader`；没有修改学生篇来源布局。

## 实际画面

- [1280×720完整前后对照](../assets/household-graphics-2026-10-21/1280x720-comparison.png)
- [640×960完整前后对照](../assets/household-graphics-2026-10-21/640x960-comparison.png)
- [390×640完整前后对照](../assets/household-graphics-2026-10-21/390x640-comparison.png)
- [手机默认画面](../assets/household-graphics-2026-10-21/640x960-01-home.png)、[图形悬停](../assets/household-graphics-2026-10-21/640x960-01-cooking-hover.png)、[MCP实际运行](../assets/household-graphics-2026-10-21/mcp-graphical-home.png)

三组完整对照均已合成并打开查看；只增加36像素QA标题，不裁掉HUD和人物。前后均为第1天早餐来源页、余额210、未确认餐次。首轮整图发现冰箱/记事本偏小和购物袋叠影，已调整比例和位置后重新检查。

## 检查

最终统一验证`tools/verify_project.ps1`为**510/510、45套**，包括周阿姨UI **23项**，资源/发布配置门禁和主场景烟测通过。新增图形资源与点击区域契约，并核对记事本图形焦点。[完整结果](../assets/household-graphics-2026-10-21/tests-report.json)，原始日志`.cache/household-graphics-verified.log`。

三种独立原生窗口均无错误：检查图形可见/命中范围、透明角不拦截、悬停实际缩放、点击锅图和短标签的一致性，以及外出、记事本、配方和返回。食物组合与午餐状态仍是明确夹具，不代表完整七日游玩。[原生报告](../assets/household-graphics-2026-10-21/native-report.json)。

MCP实际指向锅图得到1.045倍的图形缩放，鼠标点击锅图进入做饭选菜；回到家后点击购物袋打开外出，Esc关闭；点击册子打开记事本，Esc返回。全程状态、原料和餐次不变，预算210、精力60、记录0。新运行另行检查最终记事本轮廓焦点，`focus`为`StyleBoxEmpty`，图形轮廓为绿色；最终游戏日志无错误。[MCP报告](../assets/household-graphics-2026-10-21/mcp-report.json)。

原生检查为视口鼠标/键盘输入，不冒充真实手机触摸；本轮没有重新验证浏览器、整周人工游玩或读屏，也没有提交、推送、发布或重打既有演示包。测试局使用内存存档，测试游戏已停止，编辑器连接保留。

## 资源与提示词

四张插画均使用内置`image_gen`生成，已保存并由项目直接引用：

- [锅与食材](../../life-strategy/assets/generated/stories/props/cooking-wok-v1.png)
- [冰箱](../../life-strategy/assets/generated/stories/props/pantry-fridge-v1.png)
- [购物袋](../../life-strategy/assets/generated/stories/props/outing-tote-v1.png)
- [记事本](../../life-strategy/assets/generated/stories/props/notebook-pencil-v1.png)
- [完整提示词、参照及绝对路径](../../life-strategy/assets/generated/stories/props/manifest.json)

保留源PNG和原始透明度，仅用原生Atlas区域裁去透明留白；`regions.json`记录范围。没有覆盖既有家居背景或学生篇图片。
