# NUT-208A 旧恢复混合轨道证据

> 2026-10-08 C3续记：旧负担生产路径已移除，历史生成入口现明确拒绝以当前源码重生成旧证据。原生成器和旧DayCarryover源码分别保存为legacy_recovery_audit_probe.gd.txt、DayCarryoverService.gd.txt，仅供只读审计，均不运行或打包。下面复现命令是旧基线时的说明；要复现旧算法须使用对应旧源码，不在当前目录执行。冻结JSON与原哈希保持。

`legacy_baseline.json` 是 2026-09-04 在提交 `f4f0efe` 的生产逻辑上用 Godot 4.7.2 生成的冻结观察。它不是营养依据，也不是新恢复状态的测试期望；不得为通过新规则测试而改写。

生成器：`tests/legacy_recovery_audit_probe.gd`。它直接调用现有方法，控制器不进入场景树，所有健康开关关闭、健康历史路径为空；运行不写真实 `user://` 存档。

从仓库根目录复现到忽略目录：

```powershell
& 'E:\Program\GodotEngine\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'life-strategy' --script 'res://tests/legacy_recovery_audit_probe.gd' -- --output=res://.godot/nut208a/legacy_baseline.json
Get-FileHash -Algorithm SHA256 -LiteralPath 'life-strategy\.godot\nut208a\legacy_baseline.json'
```

本轮两次复现字节相同，SHA256：

`3F67E90FBDFBE423853E390BB8AF4B0C0C3BB2F5AE4CEAB4CB5FEBAE6F50F2F5`

内容包括23项食物、4来源、6行动、3睡眠的burden原值；代表用餐/跳餐；行动、组合、混合日；相同起点三种睡眠的真实结算对照；quality与过饱的日终边界；次日/余力/结局阈值；限幅和显示反转；真实七天及提前结束流程。受控场景会直接设置状态或quality以隔离分支，不能当作所有选择均通过来源/预算/库存验证的玩家流程；`seven_day_flow` 则调用实际来源、确认用餐、行动、睡眠和跨日入口。

`probe_errors=[]` 仅表示探针自身未发现流程错误；不代表候选R1通过平衡验收。睡眠到日终之间的原始值可以临时超过100，这是旧引擎最后统一限幅的真实行为。来源14项SHA256用于检测旧证据对应的生产版本，后续生产变更后应另存对照输出，不能覆盖本文件。

完整盘点、候选矩阵与确认记录见 [08恢复状态迁移](../../../docs/plans/nutrition_health_guidance/08_recovery_state_migration.md)。
