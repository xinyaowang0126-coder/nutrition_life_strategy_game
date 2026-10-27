# 周阿姨：餐后行动与演后回家

日期：2026-10-21。承接“继续呢”，在配方／库存之后继续检查餐后行动、晚间和次日衔接。

2026-10-23已继续完成[浏览器与导出收尾](HOUSEHOLD_ACTION_EXPORT_2026-10-23.md)：下列同状态画面已更新，共用时钟改为原生线条；导出依赖、30项门禁、包内启动和真实浏览器首日／刷新恢复均另有记录。

## 玩家可见的改动

- 自己练歌、集体排练、参加汇演和约老陈吃饭使用四张独立场景插画，保持周阿姨原有面容、年龄、衣着及手绘风格。歇一会儿、散步、喝水等原有中性物件插画保留。
- 今日安排加入一条简短情境提示：普通日期说明合练／汇演日程，合练当天跟随实际可用原因，邀约后显示晚饭约定。
- 最后一天演前提示读取当前排练和精力，同时列出差额，例如“还差排练8、精力1”。达到条件后提醒实际选择汇演卡；若安排位已用完，仍显示真实不可用原因。
- 约饭动作的按钮文案与接水分开。额外操作按实际`slots`筛选，喝水和邀约都不会把插画放进占用安排的格子；邀请的零费用、零安排和实际同桌完成规则保留。
- 晚间文字围绕休息与次日活动组织，第3／5天前夜提示午后合练，第7天前夜提示汇演。最后一晚进入本周收尾，移除“周末就要到了”的未来预告。
- 实际汇演后先回家安排这一晚，舞台背景留给参演结局。修正此前只要`performed=true`，睡前也一直停在礼堂的情境错误；睡前与日结使用原屋的夜景，窗外入夜、屋内暖灯。

主要实现：`GameRootV2.gd`提供只读日程和末日短缺提示，`ActionStage.gd`只在传入故事提示时显示该行，`choir_actions.xml`更新四个图片路径。没有改动行动参数、每日推进、排练收益、演前门槛或存档格式。[XML对照](../assets/household-actions-2026-10-21/action-data-parity.json)核对10个行动，除图片路径外的属性与描述均与本轮开工时的Git版本相同。

## 完整画面

- [640×960行动前后](../assets/household-actions-2026-10-21/640x960-action-comparison.png)、[演后夜晚前后](../assets/household-actions-2026-10-21/640x960-final-night-comparison.png)
- [390×640行动前后](../assets/household-actions-2026-10-21/390x640-action-comparison.png)、[演后夜晚前后](../assets/household-actions-2026-10-21/390x640-final-night-comparison.png)
- [1280×720行动前后](../assets/household-actions-2026-10-21/1280x720-action-comparison.png)、[演后夜晚前后](../assets/household-actions-2026-10-21/1280x720-final-night-comparison.png)
- [合练当天](../assets/household-actions-2026-10-21/640x960-02-choir-group.png)、[晚饭约定](../assets/household-actions-2026-10-21/640x960-14-invitation-planned.png)
- [上台前缺项](../assets/household-actions-2026-10-21/390x640-04-choir-performance-locked.png)、[达到演前条件](../assets/household-actions-2026-10-21/390x640-05-choir-performance-ready.png)

前后均为声明过的同状态夹具：第1天餐后、预算210、排练0／精力60，或第7天已参演的夜晚、排练70／精力40。完整画面只增加40像素QA标题，没有裁掉HUD和人物。事件日截图为明确设置日期的独立夹具，不冒充整周人工试玩。首轮横屏完整对照发现家中仍有白天采光，补同屋夜景后重新检查夜晚与日结。

## 验证

统一`tools/verify_project.ps1`通过：**518/518、45套**，周阿姨UI为**31项**。新增关键插画、零安排格、演前双缺项／真实阻止原因、合练提示、演后背景和布局检查。[完整结果](../assets/household-actions-2026-10-21/tests-report.json)，最终原始日志`.cache/household-action-2026-10-23-verified.log`。资源导入仍有既有`Safe save failed`缓存保存诊断，未删除编辑器缓存；独立游戏日志无该诊断。

三个独立原生窗口均检查卡片详情只读、喝水不推进、实际练歌、首日夜晚／日结／次日、独立合练日、邀约日和演前夹具。邀约不扣状态、不占安排，实际点击汇演后只生成一次参演并回家进入夜晚。输入为原生视口鼠标／键盘事件。初期探针指向了隐藏选择按钮和旧来源控件名，修正为实际卡身和当前入口后重新执行，最终三组无错误。[原生报告](../assets/household-actions-2026-10-21/native-report.json)。

学生篇有三种尺寸的行动／夜晚配对画面及完整套件回归。夜晚包含共用时钟与对应留白的有意调整，帧间另有立绘呼吸等动态时刻差异，保留[逐帧像素结果与差异范围](../assets/household-actions-2026-10-21/campus-comparison.json)，不声称全部截图逐像素相同。

MCP使用内存存档和显式第7天晚饭后夹具，先核对62排练／24精力的双短缺，再设置70／40并以真实鼠标输入点击汇演卡。结果`performed=true`、一条参演记录、精力22、阶段sleep、家居背景；夜晚提示本周收尾。首次3秒就绪等待超时，随后确认会话live再执行输入，最终运行日志无错误。[MCP报告](../assets/household-actions-2026-10-21/mcp-report.json)。

10月21日的检查不含浏览器；10月23日的浏览器首日与刷新恢复见续接记录，仍没有真实手机或真人整周验收。没有提交、推送、对外发布或覆盖原演示包；原生测试局已停止，后续浏览器预览保留。工程通关不代表医学、学习或玩家体验效果已经得到验证。

## 插画、保存位置与提示词

均由内置`image_gen`生成，以既有周阿姨立绘作为身份与画风参考；不是修改原人物立绘。四张源PNG复制到项目内，原生成文件保留：

- [自己练歌](../../life-strategy/assets/generated/stories/actions/zhou_rehearse-v1.png)
- [集体排练](../../life-strategy/assets/generated/stories/actions/zhou_group_rehearsal-v1.png)
- [参加汇演](../../life-strategy/assets/generated/stories/actions/zhou_perform-v1.png)
- [邀请老陈](../../life-strategy/assets/generated/stories/actions/zhou_call_friend-v1.png)
- [完整提示词、身份参照、原始路径和最终绝对路径](../../life-strategy/assets/generated/stories/actions/manifest.json)
- [原屋夜景](../../life-strategy/assets/generated/stories/night/zhou_home_night-v1.png)、[夜景提示词与保存位置](../../life-strategy/assets/generated/stories/night/zhou_home_night-v1.json)：只改变原家居的光照与窗外时间，保留房间、家具、取景及绘画风格。
