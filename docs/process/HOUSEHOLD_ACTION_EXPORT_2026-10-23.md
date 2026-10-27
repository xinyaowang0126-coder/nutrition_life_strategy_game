# 周阿姨篇：浏览器试玩与导出收尾

日期：2026-10-23。续接[行动插画与演后回家](HOUSEHOLD_ACTION_NIGHT_2026-10-21.md)，完成导出依赖检查、浏览器首日试玩和刷新恢复。

## 本轮修正

- Windows与Web导出补齐图形入口使用的`PropTint.gdshader`和透明裁切表`props/regions.json`，解决编辑器正常、导出包缺依赖的问题。
- 导出门禁检查`project.binary`的`ECFG`文件头，拒绝非空但损坏的项目设置；新增关键着色器、裁切表、行动插画和夜景的包内检查。
- 睡前时钟改用原生圆弧和指针绘制，解决网页缺少字体回退时显示方框的问题。它是双篇共用控件，保留现有卡牌与睡前布局。
- 邀约提示仅在午后准备晚饭的阶段出现；晚饭结束后不再要求准备同一餐，失约结算继续交给原日结规则。

四张行动插画和同屋夜景沿用10月21日已生成的素材；保存位置、内置ImageGen提示词和人物参照见[行动与夜晚记录](HOUSEHOLD_ACTION_NIGHT_2026-10-21.md#插画保存位置与提示词)。

## 验证结果

完整回归**518/518、45套**，周阿姨UI **31项**；导出工具门禁**30项**。[完整测试](../assets/household-actions-2026-10-23/tests-report.json)，日志`.cache/household-action-2026-10-23-verified.log`及`.cache/household-action-gates.log`。

Web PCK为**110.16 MiB、408个条目**。已确认有效项目设置、入口着色器、裁切数据、四张行动图及夜景；用匹配版本的Godot直接加载包内资源，并初始化周阿姨故事到早餐来源页，运行无错误。[包内检查](../assets/household-actions-2026-10-23/pack-report.json)。导出过程中仍有既有编辑器设置保存诊断；没有把这些诊断算成已解决，也没有用仅退出码为0代替包内运行检查。

1280×720、640×960、390×640三个独立原生窗口重新执行行动、邀约、参演、夜晚和首日／次日检查，全部无错误。六组完整前后画面保留在[10月21日建立的素材目录](HOUSEHOLD_ACTION_NIGHT_2026-10-21.md#完整画面)，最终画面已随本轮更新。原生探针的事件日为声明夹具，不等同于整周人工游玩。

浏览器使用实际鼠标输入，没有注入游戏状态，完成以下流程：

1. 早餐选时蔬炖豆腐、白米饭，另做1份冷藏；确认前只查看配方。
2. 上午实际练歌，午餐取用两道冷藏菜并再热，午后歇一会儿。
3. 晚餐在社区食堂选燕麦、蒸蛋，花费6元；晚间休息后选择早点睡。
4. 日结记录三餐、排练8/70、余额204；进入第2天。
5. 刷新网页后继续，仍为第2天早餐前、排练8/70、余额204；精力78、心情65、饱腹62、压力27，没有重复应用开场或次日变化。
6. 学生篇用跳过流程抵达夜晚，仅复查共用时钟和布局；再切回周阿姨，独立进度保持。

检查尺寸为1280×720、390×640、640×960。最终浏览器警告／错误日志为空，临时尺寸覆盖已重置。[浏览器报告](../assets/household-actions-2026-10-23/browser/report.json)。

- [窄屏冷藏配方](../assets/household-actions-2026-10-23/browser/01-narrow-cold-plan.jpg)、[练歌行动](../assets/household-actions-2026-10-23/browser/02-narrow-action.jpg)、[再热后行动](../assets/household-actions-2026-10-23/browser/03-narrow-reheated-action.jpg)
- [首日日结](../assets/household-actions-2026-10-23/browser/05-day-one-summary.jpg)、[刷新后的继续入口](../assets/household-actions-2026-10-23/browser/07-reload-continue-entry.jpg)、[恢复后的第二天](../assets/household-actions-2026-10-23/browser/12-day-two-final.jpg)
- [修复后的桌面时钟](../assets/household-actions-2026-10-23/browser/09-desktop-clock-fixed.jpg)、[窄屏时钟](../assets/household-actions-2026-10-23/browser/10-narrow-clock-fixed.jpg)、[双篇独立进度](../assets/household-actions-2026-10-23/browser/11-independent-story-progress.jpg)

没有完成七日浏览器整局、真实手机触摸或浏览器文件导入／导出验收；这些仍与本轮证据分开。

## 本地试玩

[打开本机预览](http://127.0.0.1:8881/)。服务仅监听本机，浏览器页保留了本轮测试进度，可继续周阿姨的第2天。另有版本化候选目录`artifacts/household-actions-2026-10-23-web/`，与已检查的导出包一致。

原`Play/`与Windows演示包没有覆盖，没有提交、推送或对外发布。10月21日的MCP检查保留为历史证据；10月23日没有编辑器连接，本轮最终验证由原生探针、导出包启动和真实浏览器输入完成。
