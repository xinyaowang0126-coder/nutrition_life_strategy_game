# 选菜打磨：直接移出与完整说明

已选区增加了明确的“移出”按钮。玩家修改搭配时，不必再滚回原来的菜卡；只编辑当前选择，确认制作或购买时才结算。手机按最多两栏展示已选食物，桌面按最多三栏排列，图片、食物名和按钮保持在各自卡片内。

键盘移出一项后，焦点转到下一项的移出按钮；删空后回到刚移出的菜卡，可直接重新选择。确认按钮在空选择时禁用。旧按钮的重复信号不会把食物重新加回，也不会消费现金、原料或调味料。

选满三样后的不可选原因会进入食物详情；移出后重新查看，已经解除的限制不会留在详情中。390×844实际渲染还复现了“未开封常温纯牛奶”换行后底部禁用说明被截断的问题，现按卡内内容调整高度，避免依赖固定高度截字。

验证：

- 完整 **481/481、42套**，新增4项覆盖移出幂等、删空、动态详情及三种逻辑画布的内外边界。随后加强已选格内图片／文字／按钮边界检查，household_ui 15/15再次通过。
- 原生实际输入：390×844与1280×720分别检查鼠标移出、键盘连续移出、删空与重新加入；分别切换到另一种窗口尺寸，无裁切或额外结算。
- 原生案例使用明确声明的8项超市菜单和3项选择夹具；菜单中的食物均来自真实游戏数据。只编辑选择，不执行购买。
- 原生触摸640×960：轻触选菜、滑动不误选、键盘加入，以及轻触移出一次且不扣料通过；不等同于真实手机硬件验收。
- 主场景启动、Web导出及PCK资源审查通过。
- 实际网页708×884、DPR 1：选择豆腐、米饭、番茄，查看满选后的燕麦详情，鼠标／键盘逐项移出，删空后确认禁用、Enter重新加入，再次查看详情时旧限制已解除。全程停在第1天早餐、余额¥210，控制台错误和警告为空。

代码入口：[HouseholdMealStage.gd](../../life-strategy/scripts/stories/HouseholdMealStage.gd)、[HouseholdFoodCard.gd](../../life-strategy/scripts/stories/HouseholdFoodCard.gd)；实际输入脚本：[household_selection_visual_probe.gd](../../life-strategy/tests/household_selection_visual_probe.gd)。结果和截图见[验证目录](../assets/selection-ui-polish-2026-10-15/)。

网页证据：[三样已选](../assets/selection-ui-polish-2026-10-15/browser-three-selected.png)、[不可选原因](../assets/selection-ui-polish-2026-10-15/browser-blocked-details.png)、[移出后](../assets/selection-ui-polish-2026-10-15/browser-after-mouse-remove.png)、[空选择](../assets/selection-ui-polish-2026-10-15/browser-empty-selection.png)、[解除后的详情](../assets/selection-ui-polish-2026-10-15/browser-unblocked-details.png)。本轮网页不覆盖完整七日、文件导入导出、刷新恢复、读屏或真实手机触摸；牛奶窄卡的裁切修复以390×844原生渲染核验。

本地候选：`artifacts/selection-ui-polish-2026-10-15-web/`。未提交、推送或更新线上Play。受限Windows环境下Godot保留原有系统证书库启动提示，脚本与导出检查通过。
