# NUT-208C1：V2日终恢复记录接入 · 2026-10-08

本轮完成C1：正常睡眠与日终结算现在生成独立R2恢复记录，并深拷贝到本局日记。下一项C2消费冻结的次日效果；C3移除旧负担及相关消费者，D再统一玩家表达。当前仍使用旧跨日、余力和结局，不把C1记为整套恢复迁移完成。

## 1. 实现与记录边界

- 新局创建明确的new_run_default记录；没有已发生睡眠的输入或快照，默认次日效果为0/空。
- 合法睡眠确认前捕获energy/stress，并冻结当次实际应用的id、energy、mood、stress、study、satiety。保留旧睡眠burden效果供后续C3迁移，但它不进入恢复快照或判定输入。
- 日终每个分支统一应用增量，并记录稳定source_id及允许的requested_delta；顺序保留为旧quality效果、低/高饱腹、预算、复习节奏、日末消耗。旧负担字段不进入恢复溯源。
- 最后限幅后调用既有RecoveryStateService.settle；判定输入只有终日energy/stress、真实成功行动计数和sleep_id。夜读不是白天study，拒绝、跳过和重复行动不计数。
- 记录sleep_snapshot、before_sleep、未限幅after_sleep、end_of_day、clamp_delta、规则版本、原因、命中规则和next_day_effect。另核对服务推导的终日值与真实游戏状态；不一致或缺少睡眠时保存invalid诊断，不伪造steady。
- 增加当日结算保护，睡眠或_finish_day重复调用不会重复增量、恢复判定或日记录。下一日清理临时输入与保护状态，新局清理历史和诊断。

接入见[V2控制器](../../life-strategy/scripts/ui_v2/GameRootV2.gd)。恢复计算继续使用[独立记录服务](../../life-strategy/scripts/systems/RecoveryStateService.gd)和[R2规则](../../life-strategy/scripts/systems/RecoveryRules.gd)，未修改其阈值与版本。

恢复结果存于pending_recovery_state，并以recovery_state字段写入run_history；get_pending_recovery_state返回深拷贝。C1日记仍含旧玩法字段，因此不标为gameplay_state_version=2，也不是完整存档。若要使用B的纯迁移接口，只encode独立恢复记录；混合日记整体输入迁移器应拒绝，测试已覆盖。

## 2. 健康隔离与分步切换

健康开关不控制这项玩法记录。data开/关下恢复与实际游戏状态一致；已生成的用餐快照逐字段不变，没有recovery_state、sleep_snapshot、next_day_effect或gameplay_state_version混入健康档案。

暂存的新next_day_effect尚未应用。DayCarryoverService、旧quality兼容效果、diet_burden、余力、结局和HUD仍按原路径工作。C1新增记录与防重保护，不同时显示新旧恢复解释，不开放新健康输出，不改变健康资料或档案版本。

## 3. 回归与发布包

| 验证 | 结果 |
| --- | --- |
| 恢复流程专项 | 14/14；三种真实睡眠入口、晚限幅、有序效果、成功行动/夜读区别、三次复习、雨天行动、重复结算、深拷贝、清理、缺失与溯源不一致、健康隔离、C1消费者边界、冻结旧数值 |
| 全量Godot4.7.2 | 247/247、25套件、0失败/跳过；资源导入和主入口烟测通过 |
| PowerShell门禁 | 21项通过；新增两项拒绝恢复脚本漏打包的回归 |
| 本地Web导出与PCK真实目录审计 | 通过；明确要求RecoveryStateService和RecoveryRules实际进入包，路径常量不能代替文件；PCK约53.12MiB |
| 冻结A基线 | legacy_baseline.json原SHA256保持3F67E90FBDFBE423853E390BB8AF4B0C0C3BB2F5AE4CEAB4CB5FEBAE6F50F2F5 |

新增[恢复流程回归](../../life-strategy/tests/test_recovery_flow.gd)。打包检查见[验证入口](../../tools/verify_project.ps1)及[门禁回归](../../tools/test_verification_gates.ps1)。日志与本地候选为artifacts/nut208c1-2026-10-08-verification.log、recovery-flow-direct.log、verification-gates.log及artifacts/nut208c1-2026-10-08-web。

本轮没有玩家可见的新UI，未追加实际设备、浏览器或截图验收。上述自动化和本地导出不代替C/D的完整玩法迁移、平衡、玩家验证或发布。

## 4. 接入前后同种子对照

先保存本轮开工时的控制器与策略探针，执行原6种策略×12种子共72局；接入后用同样策略/种子重跑。为补齐原探针未输出的库存，另以开工源码快照重放；仅隔离类名和探针类型声明、追加库存输出，没有重写旧玩法公式。该重放的原有输出字段与最初接入前样本逐项一致。

接入前后最终状态、预算、库存、结局、结束天数、餐次数、跳餐数和来源次数均无差异；444个真实日终均生成有效记录，规则状态分布为rested96、steady16、strained283、depleted49。这只描述固定脚本样本，不是最优策略证明、真人通关率或健康结论。

新记录中的次日效果与旧效果有34条不同，已完整保存于[差异报告](NUT208C1_COMPARISON_2026-10-08.json)。它们尚未影响玩家，本次不将其校准为与旧规则相同；C2切换后须检查这些变化与R2意图，再做G2平衡。

比较产物与源码哈希、具体差异均在报告中；详细前后样本和开工源码备份保留在忽略的artifacts目录，不保证新工作树具备这些本机文件。A冻结JSON原样保留，没有覆盖成新期望。

## 5. 续接C2

1. 消费前一日冻结的有效next_day_effect，核对evaluated_day及一次性开场应用，不在打开弹窗、看历史或重开详情时重算。
2. 明确known/new_run_default与invalid/legacy_unknown/unsupported_version的处理；非法历史不得成为中性有效恢复。
3. 完成当前/待用恢复、复习修正与事件顺序的生产接入，再按R2替换余力和结局边界。C1的34条差异作为对照入口，不以“全部新旧一致”为目标。
4. C3核对V1/V2、来源/食物/组合/行动/睡眠/事件的全部旧写入，D同步收口HUD、详情、日结、新日及结局。

本轮保留此前所有未提交成果；没有提交、推送或发布，Play与生产健康XML未改。23份资料仍draft，新营养开关全关，专业审校与教育输出接入继续按EDU-02/03与G4安排。
