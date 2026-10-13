# 08 NUT-208：旧状态盘点与已确认恢复规则 R2

记录日期：2026-09-04。审计源码基线：`f4f0efe`，分支 `codex/nutrition-health-m2`。

**最新状态（2026-10-08）：A/B/C1–C3相应范围完成，V1/V2同源恢复、旧负担生产路径已清；D完整表达与联合验收待完成，M2未整体完成。** 最新验收见第12节，前面保留历史检查点。R1未实现，运行规则版本仍为`recovery-gameplay-v1`，阈值保持。

## 1. 本次范围与实际基线

- NUT-208A 开工时工作区干净，最新提交已包含 NUT-207、Godot AI 3.2.5 和原交接文件；本次 B 续接保留 A 的未提交文档、独立 probe 与冻结基线。旧文档中 NUT-207“尚未提交”是此前状态。
- 保留 NUT-207 的角色口味与不可变健康历史；四个健康功能开关仍关闭。
- A 已建立旧行为证据、规则表与测试/迁移清单；本轮 B 只实现独立服务、恢复记录与纯迁移接口，不调整食物、行动、睡眠、跨日、结局或 HUD 的生产行为。
- 另为现有 `MealHealthSnapshot` 增加隔离校验：禁止 `recovery_state/gameplay_state_version/sleep_snapshot/next_day_effect` 进入健康快照。它阻止额外恢复字段混入健康历史，不改变正常快照生成、健康档案 schema 或游戏结算。
- 当前没有完整游戏存档/断点续玩。`MealHealthArchive` 存的是独立健康历史；`run_history`、`state`、阶段和库存属于内存中的本局数据。
- 不提交、推送、合并、Web 导出或发布；`Play/` 和插件保持原样。

## 2. 旧值的全部生产路径

以下路径相对 `life-strategy/`；行号以审计基线为准，迁移时以符号名定位。代码中的 `burden`（配置/兼容输入）、`diet_burden`（运行状态）、`character_health`（反向显示）实为同一混合轨道。

### 2.1 数据与用餐

| 位置 | 当前行为 | 后续处理 |
| --- | --- | --- |
| `scripts/GameData.gd:20` / `STARTING_STATS` | 初始 `diet_burden=24`，HUD 显示 `100-24=76` | B 引入独立恢复状态；C 删除初始旧值；D 删除显示转换 |
| `scripts/CardDataStore.gd:15` | `burden` 在整数属性解析表中，供四类 XML 共用 | C 移除生产字段后处理解析入口；旧档适配器单独识别旧键 |
| `data/cards/foods.xml` | 23 项全部声明 burden；有正、零、负值 | C 全部移除，不能搬成 food.recovery_delta |
| `data/cards/meal_sources.xml` | 四个来源也声明 burden；当前均为 0 | C 删除；不能因当前为 0 而漏掉来源加法 |
| `scripts/systems/MealResolver.gd:84` / `_stat_delta` | 汇总每项 food.burden，再加 source.burden 到 diet_burden | C 删除该输出键；食物的价格、饱腹、精力和角色口味保留 |
| `MealResolver.gd:119` / 跳餐 delta | 跳餐显式写 `diet_burden=0`，另有精力/心情/压力/饱腹变化 | C 删除旧键；跳餐继续留下未吃记录与既有玩法取舍 |
| V1 `scripts/GameRoot.gd` 与 V2 `scripts/ui_v2/GameRootV2.gd:664` | `meal_group_mix` 组合触发旧值 -2，另加精力等效果 | C 删除旧值效果；其余游戏效果单独保留并注明来源 |
| 同上，V2 `GameRootV2.gd:669` | 连续 comfort 组合触发旧值 +3，另有心情 +4 | C 删除旧值效果；不得把角色口味推断为饮食健康 |

23 项食物旧 burden 原值（仅作历史证据）：

| food_id | 值 | food_id | 值 |
| --- | ---: | --- | ---: |
| rice_plain | 0 | oatmeal | 0 |
| egg | 0 | tofu | 0 |
| greens | -2 | tomato | -1 |
| apple | -1 | banana | 0 |
| milk | 1 | coffee | 1 |
| bubble_tea | 8 | instant_noodles | 11 |
| fried_chicken | 12 | salad_bowl | -4 |
| sandwich | 2 | tomato_egg_stir_fry | 1 |
| celery_pork_stir_fry | 2 | steamed_fish | 0 |
| mixed_grain_rice | 0 | plain_yogurt | 0 |
| whole_wheat_bread | 0 | unsalted_nuts | 0 |
| chicken_vegetable_rice | 3 | — | — |

上表已与本轮 probe 的 `burden_catalog` 核对，旧值不是恢复规则或营养分类的依据。

### 2.2 行动、睡眠与日终

| 生产者 | 旧 burden 变化 | 触发位置/时序 |
| --- | ---: | --- |
| 复习 / 歇一会儿 / 补充存粮 | 0 / 0 / 0 | `actions.xml`；V1/V2 行动接受后结算 |
| 散步 / 喝水 / 留点空 | -2 / -3 / -1 | 同上；V2 `_apply_action():715` 转为 diet_burden |
| 早点睡 / 再看一会儿 / 刷会儿手机 | -4 / +2 / +1 | `sleep_options.xml`；V2 `_choose_sleep():844`，先结算睡眠再日终 |
| 旧日 quality ≥66 | -2 | V1/V2 `_finish_day`；同时精力 +4、心情 +4 |
| 旧日 quality <42 | +4 | 同上；同时压力 +5；42–65 无该档效果 |
| 日终饱腹 >92 | +4 | 同上；同时精力 -3 |
| 日终固定恢复 | -3 | 同上；不检查玩家做过什么；同时还有饱腹 -6 |
| 通用 `_apply_stat_delta` / `_clamp_stats` | 接收任意旧键，再限制在 0–100 | 两个 GameRoot 都须改；不能只删 XML |
| `WeeklyEventService.gd:78` | 有旧键限幅入口；现有事件无直接 burden delta | C 移除旧键接入口，保留事件实际精力/压力/行动变化 |

V2 时序：确认用餐 → 合法性/库存/费用检查 → 用餐 delta → 组合 delta → 限幅/余力 → 餐后行动 → 睡眠 delta（此处尚不限幅）→ 日终 quality/饱腹/预算/复习进度效果 → 固定恢复 → 限幅/余力 → 连续低余力天数 → 次日状态 → 写入日记录 → 提前结束或日结。V1 有独立实现，不能漏改。七天与周内事件已经存在，不是本任务新增功能。

## 3. 消费者、显示及隐含旁路

### 3.1 次日学习状态

`DayCarryoverService.evaluate_day()`（`scripts/systems/DayCarryoverService.gd:42`）除读取 `diet_burden`，还接受旧 `burden` 别名。优先级为严重 → 轻度 → 加成 → 照常。

- 严重：精力 ≤22、压力 ≥82、饱腹 ≤12、burden ≥82、跳餐 ≥2 任一；或饮食压力与夜读并存、过度安排且精力 <35、压力 ≥75 且精力 <35。
- 轻度：夜读、精力 <42、压力 ≥66、饱腹 <24、burden ≥68、过度安排、饮食压力且未早睡任一。
- 加成：早睡、三餐未跳过、谷物餐 ≥2/蔬菜餐 ≥1/蛋白来源餐 ≥1、限制因素计数 ≤1、精力 ≥58、心情 ≥45、压力 ≤52、burden ≤55、未过度安排，必须同时成立。
- 饮食压力：跳餐 ≥1、吃过餐数 <3、添加糖餐+高钠餐+油炸餐的计数 ≥3 任一。同一餐可贡献多个因素，并非三餐互斥计数。
- 过度安排：复习 ≥3 次且 `nap/walk/allow_imperfection` 总次数为 0；喝水不计作这三种恢复行动。
- 对应的次日复习修正：`brain_fog=-4`、`fatigued=-2`、`clear_focus=+3`、`steady=0`。这些 ID 也关联插画，不应只靠搜索玩家显示词决定删除范围。

**关键迁移点：删 burden 条件仍不够。** 旧餐次/食物组/糖钠油炸计数也必须从恢复判定 API 移出，否则仍在用饮食标签评价恢复。餐次与组成记录留给独立饮食观察。

### 3.2 余力与结局

`MealResolver.calculate_stability():230`：

```text
mental = mood×0.55 + (100-stress)×0.45
budget_safety = 剩余天数为0时100，否则clamp(balance/(剩余天数×10)×100,0,100)
余力 = round(clamp(quality×0.20 + mental×0.25 + energy×0.20
    + satiety×0.10 + (100-diet_burden)×0.10
    + study_progress×0.10 + budget_safety×0.05 - 极低状态/预算罚值,0,100))
```

罚值：energy<16 为10，mood<16 为10，satiety<12 为8，stress>88 为10；有剩余天数且 balance<剩余天数×6 为8。

`select_ending():257` 按顺序判断：余力 ≤15 → collapsed；复习 <50 → study_shortfall；复习 ≥70 且余力 ≥60 且 burden ≤60 → stable_endurance；余力 ≥25 → barely_survived；否则 collapsed。V1/V2 还各自累计连续两天余力 ≤15 的提前结束条件。

`quality` 的 20% 和原有日终精力/压力效果仍是旧兼容玩法；NUT-208 只拆 burden 轨道，剩余清理归 NUT-308。不得把它标成新的饮食指导，也不能宣称全部旧饮食逻辑已经移除。

### 3.3 玩家呈现与历史

| 路径 | 当前依赖 | D 的验收目标 |
| --- | --- | --- |
| `GameData.gd:16,68,72` | 标题、100-burden、delta取反 | 删除旧别名与转换函数的生产调用 |
| V1 `GameRoot.gd` / `scenes/game/GameRoot.tscn` | 属性顺序、反向数值、指标说明、burden≥65建议、静态提示 | 兼容入口同步处理；不能让旧场景继续教“降角色健康负担” |
| V1 `scripts/ui/ChoiceCard.gd:145` | 食物/行动/睡眠 tooltip | 食物/来源无恢复增减；行动/睡眠只描述其真实游戏效果 |
| V2 `CharacterHUD.gd:36,128,137,245,275` 与对应 tscn | BurdenChip、character_health、颜色、数值反转、旧键 fallback | 改为离散恢复状态与原因，删除“角色健康”和分值/进度条 |
| V2 `StickyNotePopup.gd:180` 与对应 tscn | character_health/burden/diet_burden 三入口 | 食物、来源去掉旧指标（包括 +0）；行动/睡眠不伪造 recovery_delta |
| `CompactChoiceCard` / `TakeoutFoodRowCard` | 卡面无直接旧值，但详情 payload 进入 StickyNote | 检查四来源、行动、睡眠全部详情入口 |
| `DailySummaryPopup` / `NewDayPopup` | 显示余力、次日状态、summary等派生信息 | 新规则的睡眠/行动/状态依据可读，重复打开不重算 |
| `NewDayPopup.gd:103` 与 tscn:210 | 缺省“昨天的饮食和休息，让今天的脑子……” | 改为明确的游戏恢复说明，避免饮食与认知因果兜底 |
| `GameData.ENDINGS` | 结局副标题假定“饭没落下”等经历 | 改为条件真实支持的表达；无轨迹证据时不声称三餐/熬夜事实 |
| V2 `_build_day_record():1057` | `start_state/end_state` 携旧值；睡眠仅 id/name | B/C 冻结新规则版本、睡眠实际效果、输入与命中原因 |
| `MealHealthArchive` / `MealHealthSnapshot` | 独立 JSON；黑名单排除游戏字段 | 不写恢复结果，不改档案版本，不用恢复重算饮食资料 |

## 4. 已确认恢复状态矩阵 R2

### 4.1 状态与输入

使用 `recovery_state` 结构，规则版本 `recovery-gameplay-v1`。四个正常状态为 `rested / steady / strained / depleted`，玩家标题为“恢复充分 / 状态照常 / 有些疲惫 / 需要缓缓”。不再建立 0–100 的恢复总分或可加减的“健康”。标题和阈值仅是游戏设计，不表示现实疲劳/睡眠评估。用户确认了第 8 节的玩家体验取舍；下述具体阈值与权重作为工程默认实现，后续通过模拟校准，无需用户逐数签署。

每局初始 `steady`，来源为 `new_run_default`。每个日终在睡眠及原有日终游戏效果结算、限幅后计算一次；白天 HUD 展示“昨夜恢复”，今日精力/压力继续实时显示。白天行动不反复改写恢复状态；日结可以预览明日效果。

判定器输入严格限定为四个键：终日 `energy/stress`、本日真正完成的 `action_counts`、当次 `sleep_id`。判定器拒绝营养账本、食物 ID、餐次/组成/因素、profile、quality、burden、心情或饱腹等额外字段；非法输入不会回退为 steady。完整睡眠实际效果快照由记录层保存，仅用于说明已发生的游戏效果，不传给判定器；这样快照中的心情/饱腹不会成为隐藏判定输入。

**保留的间接游戏关系必须明确：** 食物仍能改变精力/压力，餐食组合与旧 quality 日终效果也可能改变它们，因此不同用餐选择仍可能间接影响恢复。这里分离的是恢复判定与饮食资料，不是取消食物的游戏效果。固定 energy/stress/行动/睡眠后，单独改变饮食记录、profile、旧 burden/quality 参数，恢复必须完全一致；旧 quality 对精力/压力的兼容影响在 NUT-308 再处理。

### 4.2 判定优先级和精确边界

令 `overworked = study次数≥3 且 nap+walk+allow_imperfection次数=0`。只有成功完成的白天行动计数；睡眠选项 night_study 不计为白天 study，被拒绝、没钱、没精力、重复点击、跳过行动不计数。当前每天3行动格、每个行动占1格，因此实际过度安排就是三次复习挤满全部行动格。每天喝水上限仍为两次；喝水不被分类为休息，不能在未来扩展行动格时自动解除 overworked。

| 优先级 | 条件（该行任一成立） | 结果 | 次日复习 | 次日开场效果 |
| ---: | --- | --- | ---: | --- |
| 1 | energy≤22；stress≥82；night_study 且（energy<35 或 stress≥75）；overworked 且 energy<35；stress≥75 且 energy<35 | depleted | -4 | energy -3、mood -2、stress +3 |
| 2 | night_study；energy<42；stress≥66；overworked | strained | -2 | energy -2、stress +2 |
| 3 | sleep_early **且** energy≥58 **且** stress≤52 **且**非overworked（全部成立） | rested | +3 | energy +3、mood +1、stress -2 |
| 4 | 有效且完整输入未命中以上条件 | steady | 0 | 无 |

R2 沿用原有主要精力/压力阈值及复习/开场 delta，移除饮食与饱腹/心情门槛。`scroll_phone` 保留当晚精力 -10、心情 +8 等效果，恢复档位按结算后的实际状态判断，不必定进入 strained。`night_study` 仍至少 strained，其复习 +16、精力 -22 等原值保持。早睡不能覆盖严重精力不足或高压力。

事实原因以稳定 ID 保存，如 `LOW_ENERGY_SEVERE / HIGH_STRESS_SEVERE / LATE_STUDY / PHONE_AT_NIGHT / OVERWORKED / EARLY_SLEEP`；每个 OR 子句有独立规则 ID，复合条件另设 `LATE_STUDY_LOW_ENERGY / LATE_STUDY_HIGH_STRESS / OVERWORKED_LOW_ENERGY / HIGH_STRESS_LOW_ENERGY`。显示文案不用于规则判定。记录所有事实原因并独立标记决定当前档位的 `matched_rule_ids`，不能只写“综合判断”。`PHONE_AT_NIGHT` 只保留在事实 `reason_ids`，不会进入 `matched_rule_ids`，不单独触发档位。

### 4.3 行动、睡眠及玩法矩阵

| 输入/事件 | 新恢复轨道处理 | 保留的现有玩法 |
| --- | --- | --- |
| 任意食物/来源/餐食组合 | 不写 recovery_state，不设恢复加减值；移除 burden 效果 | 价格、库存、饱腹、精力、口味和组合其他游戏效果 |
| 跳餐 | 不直接处罚恢复档位；仍记未吃 | 既有精力/压力/饱腹效果及饮食记录 |
| study | 成功次数进入 overworked | 精力 -8、压力 +3、心情 -2、饱腹 -4；复习收益仍受现有规则修正 |
| nap | 作为一次恢复行动，解除“全日没有恢复行动”条件 | 精力 +14、心情 +2、压力 -4、饱腹 -2 |
| walk | 同上，不按 -2 burden 换算成恢复加分 | 精力 -3、心情 +3、压力 -6、饱腹 -3；仍应用当日事件修正 |
| allow_imperfection | 同上；有复习进度代价 | 精力 +4、心情 +7、压力 -8、复习 -2 |
| drink_water | 不算上述恢复行动、不清除 overworked；通过精力/压力间接作用 | 精力 +1、压力 -1、饱腹 +3；行动格及每天两次上限 |
| restock_pantry | 不算恢复行动 | 费用、精力、心情/压力和库存变化，日一次上限 |
| sleep_early | 显式 sleep ID 参与 rested 条件，不能跳过严重/轻度检查 | 精力 +26、心情 +3、压力 -9、饱腹 -12 |
| night_study | 显式晚间安排原因，至少 strained | 精力 -22、心情 -5、压力 +12、复习 +16、饱腹 -11 |
| scroll_phone | 记录晚间安排事实；按实际精力/压力/行动判断，不设必定疲惫条件 | 精力 -10、心情 +8、压力 -2、饱腹 -8 |
| 旧日终 burden -3 / quality对burden / 过饱对burden | 全部删除，不转成 recovery 加减 | 其他日终游戏效果保持，单独追溯 |
| 新日开场 | 消费前一日冻结的恢复结果，先开场delta再事件；限幅 | 只应用一次；打开弹窗/读历史不能重复应用 |

### 4.4 余力、结局与健康开关

- 余力仅替换原 `(100-diet_burden)×0.10`：rested +10、steady +7、strained +4、depleted +1。它是现有游戏余力公式中的一项贡献，不保存/显示为恢复评分。其余权重、罚值和 rounding 保持，第 7 天无未来餐费压力保持。
- 日内余力使用昨夜的冻结状态；日终先生成本日恢复，再更新余力和连续低余力计数，避免先用旧恢复判提前结束。
- stable_endurance 改为“复习≥70 且余力≥60”，不附加恢复档位门槛。恢复通过余力贡献与次日复习效率间接影响结局；其余结局优先级、复习50/余力15与25边界、连续两天低余力提前结束不变。
- B 的兼容阶段不接生产；C/D 联合收口之前不向玩家展示半套新旧含义。最终新局使用新恢复规则，不受 health data/engine/ui/weekly 控制。
- 四个健康开关相同游戏输入必须同恢复、同余力、同结局。开关 off 仍完整可玩，不能用打开健康资料补足恢复所需输入。

### 4.5 可人工复核的规则例子

以下 energy/stress 为**睡眠及日终结算后的输入**，不是睡前值，不再叠加睡眠 delta。

| energy / stress | 睡眠/行动 | 输出与原因 |
| --- | --- | --- |
| 58 / 52 | 早睡、复习2次 | rested；边界满足 |
| 57 / 52 | 早睡、复习2次 | steady；未达到加成阈值 |
| 58 / 53 | 早睡、复习2次 | steady；未达到加成阈值 |
| 42 / 65 | 早睡、复习2次 | steady |
| 41 / 65 或 42 / 66 | 早睡、复习2次 | strained；精力或压力轻度边界 |
| 22 / 40 或 70 / 82 | 早睡、散步1次 | depleted；早睡/散步不覆盖严重条件 |
| 60 / 40 | 夜读、复习2次 | strained；LATE_STUDY 决定轻度档位 |
| 60 / 40 | 刷手机、复习2次 | steady；保留 PHONE_AT_NIGHT 事实，不命中疲惫规则 |
| 34 / 40 | 夜读、复习2次 | depleted；晚间安排与低精力叠加 |
| 60 / 40 | 早睡、复习3次 | strained；overworked，三个行动格均已用完 |
| 60 / 40 | 早睡、复习2次+散步1次 | rested；有恢复安排且状态足够 |
| 同上任一有效输入 | 外部只改变奶茶/炸鸡/跳餐/profile/旧burden记录 | 四个直接输入相同时结果不变；把这些字段传入判定器则拒绝 |

## 5. B：数据版本和迁移契约（已实现并验证）

本节定义 B 的实施契约，不声称已存在完整存档模块。B 建立纯转换/校验接口和独立 fixture，不新增保存/读取游戏的 UI，也不扫描或覆写真实 user:// 文件。接口尚未接入当前局：

- `RecoveryRules.evaluate(inputs)`：严格验证四键输入，生成恢复判定和原因。
- `RecoveryStateService.new_run()`：直接返回已知新局默认记录。
- `RecoveryStateService.settle(day, before_sleep, sleep_snapshot, action_counts, settlement_effects=[])`：根据睡前值、实际睡眠快照和有序日终效果，推导 after_sleep、end_of_day 与 clamp_delta，冻结记录并返回 `{valid, errors, recovery_state}`。
- `RecoveryStateService.validate/normalize/unavailable`：记录校验、JSON 数字规范化和不可用状态构造；验证历史的字段与算术关系，不重新调用 evaluate 判断档位。
- `RecoveryStateMigration.encode(record)` 返回 `{valid, errors, data}`，失败时 `data=null`；`load_data(envelope)` 返回 `{status, gameplay_state_version: 2, recovery_state, errors}`，status 为 `known / legacy_unknown / invalid / unsupported_version`。没有磁盘读写或当前局恢复副作用。

独立记录的 envelope 仅包含三个键：`{kind: "gameplay_recovery", gameplay_state_version: 2, recovery_state}`。其中没有余额、库存、阶段、事件或整局进度，它不是完整游戏存档。

```text
gameplay_state_version = 2
recovery_state = {
  schema_version: 1,
  rules_version: "recovery-gameplay-v1",
  status: "known | legacy_unknown | invalid | unsupported_version",
  condition: "rested | steady | strained | depleted | null",
  origin: "new_run_default | day_settlement | legacy_record",
  evaluated_day: 1..7 | null,
  inputs: {energy, stress, action_counts, sleep_id} | null,
  sleep_snapshot: {id, energy, mood, stress, study, satiety} | null,
  before_sleep: {energy, stress} | null,
  after_sleep: {energy, stress} | null,
  end_of_day: {energy, stress} | null,
  settlement_effects: [{source_id, requested_delta}],
  clamp_delta: {energy, stress} | null,
  reason_ids: [], matched_rule_ids: [],
  next_day_effect: {study_modifier, opening_delta} | null
}
```

- 初始默认值是已知的新局玩法默认，不是假造已睡过一夜；evaluated_day/inputs/sleep_snapshot 均为空，次日效果为 0/空。
- 睡眠快照写当次应用数值；before/after/end 三个阶段区分睡眠、限幅和日终其他效果。after_sleep 为尚未限幅的原始值，允许暂时超出0–100；end_of_day 和判定输入才限定0–100。settlement_effects保存有序非睡眠来源及请求delta，clamp_delta单列限幅造成的实际变化，不能把总变化全部归因睡眠。
- 所有数值须有限整数，不能用字符串/布尔/小数替代。action_counts只允许当前已知行动ID、非负次数，总格数≤3、drink_water≤2、restock_pantry≤1；缺失sleep、未知sleep ID或超过次数为invalid。inputs与end_of_day一致，inputs.sleep_id与sleep_snapshot.id一致；来源为new_run_default时例外字段须全部按上述初始约定为空。
- 日记录保存深拷贝的输入、版本、原因和结果；读取历史不查今天的睡眠 XML，不重算旧恢复。下一天消费记录中的 next_day_effect；重复打开/重复点击必须幂等。
- 先检查容器及 gameplay 版本，再检查 recovery 版本和内容。只有可识别的旧 stats/day_record 结构（无版本或 gameplay v1）才进入 `legacy_unknown`，其 condition=null、next_day_effect=null、reason=`LEGACY_RECOVERY_NOT_RECORDED`。任意对象、空对象、null 和健康档案不会被当作旧游戏状态。不能按 `100-burden`、旧学习状态 ID 或旧 quality 反推恢复。
- gameplay v2缺recovery或混入burden/diet_burden/character_health为invalid，不能降成legacy_unknown；无版本但带新恢复字段也为invalid。未来gameplay/schema或不支持的rules_version → unsupported_version；畸形字段/容器/小数或字符串版本 → invalid。整条恢复记录不部分采用，unknown/invalid/unsupported均不可消费next_day_effect。保留原记录供只读诊断。
- 历史未知态显示“这段历史没有恢复记录”，不显示正常/差/0分。当前没有续玩接入，所以未知记录不能流入运行中结局；未来续玩需单独规定恢复起点，不能在此次迁移器里偷偷默认 steady。
- 当前健康档案 schema/model 不随之递增，不写 recovery_state 到 MealHealthSnapshot，不把旧健康历史当玩法存档。若出现混合旧记录，健康导入只保留既有可接受饮食信息，恢复适配返回独立结果，两者不互相补造字段。
- `MealHealthSnapshot.FORBIDDEN_FIELDS` 增加上述四个恢复专用键，即使值为初始空恢复记录也拒绝；这是现有代码的隔离校验加固，不是恢复玩法接入。

## 6. 实施次序、测试与回退

| 切片 | 实施清单 | 必须通过的验收 |
| --- | --- | --- |
| A（完成） | 旧字段盘点、机器基线、规则矩阵、版本和测试方案 | 基线可复现；现有验证通过；用户已确认修订 R2 |
| B（完成） | 独立 RecoveryRules/RecoveryStateService 与纯迁移器；新字段契约、输入校验和未知态；不切换生产 | 37/37 新专项、全量 217/217；深拷贝、旧记录识别/降级、历史不重算与健康隔离通过 |
| C（完成） | V1/V2同源记录/冻结消费与R2余力/结局，旧生产配置/写入/消费清理完成 | C3为274/274、V1/V2七日、72局对照与图形核验；D已完成后续联合出口 |
| D（本地工程完成） | HUD/详情/日结/新日/结局/帮助与V1兼容统一，旧数字与误导兜底退休 | 288/288、72局无玩法差异、六组图形布局与原生输入、Godot MCP跨日通过；专业/真人/真实手机验收另列 |

新测试矩阵（B 独立服务范围已验证，生产流程与 UI 验收归 C/D）：

1. 阈值：energy=21/22/23、34/35、41/42、57/58；stress=51/52/53、65/66、74/75、81/82。同一输入多规则命中时优先级和原因完整。
2. 行动：study 2/3 次；0/1 次 nap/walk/allow；喝水0/2次不能解除过度安排；重复/非法/未执行行动不计数；雨天行动用实际效果。
3. 睡眠：三选项相同睡前状态的真实结算；高压力/低精力覆盖早睡；相同终日输入但不同 sleep ID 可追溯分叉；中断/重复提交不能重复结算。
4. 饮食隔离：固定恢复直接输入，更改原料/糖钠油炸/餐次/旧burden/quality不改结果；反向执行每种恢复行为后，已有健康快照逐字段不变、版本不变，缺失/unknown不被补全。
5. 余力/结局：四种恢复贡献、0/100限幅、rounding、study49/50/69/70、余力15/16/24/25/59/60；在复习和余力相同时四档恢复均不额外拦截 stable_endurance；连续两天≤15；第7天预算逻辑；全部四种结局可达。
6. 历史：旧/空/未来/非法输入，深拷贝，睡眠XML更改不重算；current run与读入历史不混合，开场效果只消费一次。
7. 实际流程：固定seed七天、全跳餐夜读、正常预算、补货/来源/事件、改口味、健康data on/off。旧新状态差异另写报告，不强行要求旧余力/次日/结局完全一致；余额/库存/阶段等未改机制应保持。
8. UI：1920×1080、720×1280，窄屏390×640；新局/四恢复档/旧档未知；食物/来源/行动/睡眠详情；日结与新日依据；关闭/切换/重复打开，无旧标签、越界或颜色独占语义。

现有测试迁移位置：`test_meal_systems` 的来源 burden 和结局边界；`test_day_carryover` 的5条旧饮食规则；`test_food_preference_flow` 的旧delta断言；`test_health_guidance_m1` 的反向HUD断言。应以新语义断言替换，不直接删除。`test_v2_flow` 的完整7天/提前崩溃/防重复输入，`test_health_snapshot_flow` 的 data on/off同结果及21条快照继续保留。

`tests/fixtures/health_v1_baseline/` 和本轮恢复基线是历史证据，不随新规则改写。测试中故意包含 burden 的“禁止游戏字段进入健康快照”样例属于必要反例，不应被全仓关键字删除。

回退：A/B 不改变生产；C/D 验证失败时恢复对应切片源码或隔离开发分支，不能把新恢复写进旧 burden，也不能用健康功能开关偷偷恢复混合路径。新的本局状态不反向迁回旧算法；已冻结历史保持原版本只读。

## 7. A 阶段本地证据（历史记录）

- Godot 4.7.2 统一验证：`180/180`、19套件通过，发布配置静态检查与主场景烟测通过。日志：`life-strategy/.godot/logs/nut208a-project-verification.log`。
- 有已知根证书存储读取告警；无脚本解析失败、测试失败或主场景加载失败。该检查没有做Web导出或发布。
- 新增独立 `tests/legacy_recovery_audit_probe.gd`，直接调用真实旧规则与 V2 结算；不进入生产启动入口，不作为未来恢复规则测试预期。
- probe 两次运行均退出0，`probe_errors=[]`，输出字节相同。冻结证据：[legacy_baseline.json](../../../tests/fixtures/recovery_v1_baseline/legacy_baseline.json)，复现说明：[README](../../../tests/fixtures/recovery_v1_baseline/README.md)。其中包含14个生产源码/数据文件的SHA256。
- 受控旧burden=55/56/67/68/81/82依次触发clear_focus/steady/steady/fatigued/fatigued/brain_fog；混合日旧值50→61→58→81→79→75→72→68→65。真实七天结束为stable_endurance、余额20、余力74、burden0；全跳餐夜读第2天collapsed。
- 相同受控起点的三种睡眠均调用真实入口：早睡旧burden50→46→41/clear_focus；夜读50→52→47/fatigued；刷手机50→51→46/steady（依次为睡前/睡眠后未限幅/日终）。由此可直接检查候选R1对刷手机规则的变化。
- 当时 probe 是旧规则证据；候选 R1 尚未接入或验证平衡，A 阶段没有新增 UI 截图。R1 的手机必定疲惫与最佳结局恢复门槛已在用户确认的 R2 中取消；冻结旧 JSON 保留，不重写为新规则期望。B/C 的新验证结果另记，不能用此处通过率替代。

复现全量：

```powershell
.\tools\verify_project.ps1 -GodotPath 'E:\Program\GodotEngine\Godot_v4.7.2-stable_win64_console.exe'
```

## 8. 游戏设计确认记录

根据 [Backlog NUT-208](./06_implementation_backlog.md#nut-208-拆解旧-diet_burden--角色健康)，“结算迁移前需游戏设计确认”，A 的出口为“签署新状态矩阵”。此处只请求玩法规则确认，不代替 NUT-003/NUT-602 营养专业审核，不修改到期证据。

| 项目 | 已确认 R2 / 实施默认 | 确认状态 |
| --- | --- | --- |
| 状态形式与时序 | 四档离散状态，日终一次更新，白天展示昨夜恢复，不设健康/恢复总分 | 既定方向，可继续实施 |
| 刷手机的玩家体验 | 保留精力/心情等现有代价与收益，按实际状态判定；不强制疲惫 | 用户已同意 |
| 最佳结局的玩家体验 | 只需复习≥70且余力≥60；恢复通过余力和复习效率间接影响，不设额外门槛 | 用户已同意 |
| 精确规则与权重 | §4.2 阈值、四档贡献+10/+7/+4/+1；移除饮食metrics/旧值直接门槛；旧quality兼容保留至308 | 工程实施默认，后续模拟校准，无需逐数签署 |
| 旧记录 | legacy_unknown，不从旧混合值反推；不新增完整存档/续玩 | 既定方向，可继续实施 |

确认者/日期/意见：**用户，2026-09-04。** 在助手明确建议“刷手机按实际状态判断”和“恢复先通过余力、复习效率间接影响最佳结局”，并说明其余方向可直接推进之后，用户回复“同意”。据此将未实现的 R1 修订为 R2，A 出口已满足，B 开始实施。该确认是玩法取舍确认，不代表用户逐项签署数值平衡，也不替代营养专业审核。

## 9. B 本地验收（2026-09-04）

- Godot 4.7.2 统一验证 **217/217、22 个套件通过**；恢复规则 14/14、恢复记录 9/9、迁移 14/14 均纳入全量。发布配置静态检查与主场景烟测通过，日志：`life-strategy/.godot/logs/nut208b-project-verification.log`。
- R2 的手机/夜读区别、严格输入、阈值、冻结溯源、JSON 数字规范化、历史不重新 evaluate、畸形/未来版本与健康快照四键隔离均通过。9 条真实旧日记录可识别并降级为 legacy_unknown，不从旧值反推。
- A 冻结 JSON 保持原样，SHA256 为 `3F67E90FBDFBE423853E390BB8AF4B0C0C3BB2F5AE4CEAB4CB5FEBAE6F50F2F5`；其中 14 个旧生产源码/数据哈希全部匹配。健康快照校验文件不在该 14 项内，本轮确实增加了隔离护栏。
- 新服务仅在独立服务之间引用，未接入 GameRoot；当前玩法、UI、正常健康快照生成及健康档案 schema 不变。插件、`project.godot` 与 `Play/` 无本轮差异，Godot AI 3.2.5 保留；四个健康开关仍关闭。
- 无新增 UI 截图、提交、推送、Web 导出或发布。B 的接口工程验收不代表 C/D 的七天新规则平衡与界面验收；下一步 C，D 后续，M2 尚未整体完成。

## 10. C1日终记录接入（2026-10-08）

- 正常睡眠捕获真实睡前energy/stress与六键实际睡眠快照；日终增量按source_id与允许字段记录，最后限幅后调用既有服务。成功行动计数来自已执行记录，不包含拒绝/跳过/夜读；睡眠与日终重复入口幂等。
- pending_recovery_state保存新结果，日记深拷贝为recovery_state。C1日记暂时仍有旧字段，不标完整gameplay v2；只可单独encode恢复记录，不新增磁盘存档或续玩。
- 新next_day_effect暂未应用，次日/余力/结局/旧HUD保留；C2/C3/D尚未实现，旧quality的精力/压力效果仍有间接影响，未宣称全部饮食逻辑已移除。
- 专项14/14、全量247/247及25套件，门禁21项、本地Web导出/PCK审计通过。72局同种子对照原玩法无差异，444条有效恢复记录；34条未来次日效果差异单独保存。旧冻结JSON哈希保持，健康数据开/关同结果，健康快照不变。
- 详见[执行记录](../../../../docs/process/NUT208C1_DAY_SETTLEMENT_2026-10-08.md)与[差异报告](../../../../docs/process/NUT208C1_COMPARISON_2026-10-08.json)。本轮没有新UI或设备验收，不提交、推送、发布；下一项C2。

## 11. C2冻结恢复消费与V2余力/结局（2026-10-08）

- 新RecoveryGameplayService验证记录可用性/版本/时间，第一日只用明确新局默认，后续取上一日本局日记。恢复→事件→一次限幅；重复_start_day不清行动、不重应用，弹窗重开与重复推进同样幂等。复习使用冻结效果副本，未知/非法记录不能成为中性有效恢复。
- 白天余力用昨夜状态，日终先生成新恢复再更新余力/低余力计数；10/7/4/1及原余力其他权重/罚值/rounding保持，V2最佳结局无旧负担或额外恢复档位门槛。旧quality兼容及V1默认接口保留到对应清理。
- 专项16/16、全量263/263、26套件，门禁22项与本地Web审计通过。72局/444条记录有效，58局终态字段变化；48最佳/12勉强/12提前结束，四结局另由受控真实结算验证。实际原生第二日rested/复习13/重开不变，1920×1080截图留存，不冒充手机验收。
- [执行记录](../../../../docs/process/NUT208C2_RECOVERY_CONSUMPTION_2026-10-08.md)与[差异报告](../../../../docs/process/NUT208C2_COMPARISON_2026-10-08.json)。旧冻结JSON/健康资料/schema/开关保持；不提交、推送、发布。下一项C3与D，完整恢复与教育候选尚未完成。

## 12. C3旧路径与V1共享迁移（2026-10-08）

- 23食物/4来源/6行动/3睡眠共36项旧属性移除，解析、餐食、事件、增量/限幅拒绝旧键，新局/标签/转换函数及共享余力/结局旧入口退休。健康反例、旧记录识别与冻结fixture保持。
- V1新增同源实际行动/睡眠/有序日终记录、深拷贝、防重与冻结消费，复习/事件/门槛/补货同源处理；第7日无虚构未来餐费。非旧负担游戏效果和R2阈值保持，旧quality兼容留NUT-308。
- 原旧服务与生成器以.gd.txt只读归档，当前旧生成入口拒绝重生成，JSON原哈希保持。旧数字UI入口隐藏避免兜底成正常分，D仍负责完整离散恢复与依据。
- 专项11/11、全量274/274、27套件，门禁22项及本地Web审计通过；两版本七日、72局/444条对照无非退休字段差异，三个画布21个日/尺寸组合/15张截图通过。无新增浏览器或手机验收，未发布。
- [执行记录](../../../../docs/process/NUT208C3_LEGACY_RETIREMENT_2026-10-08.md)与[对照报告](../../../../docs/process/NUT208C3_COMPARISON_2026-10-08.json)。下一项D，健康profile/schema/开关及专业签署状态保持。

## 13. D恢复表达与联合工程出口（2026-10-08）

- 只读RecoveryPresenter读取版本化冻结记录，不重新判定历史；HUD/新日/日结/帮助、四来源/行动/睡眠详情和V1兼容统一显示实际依据与效果。旧数字节点退休，unknown/invalid/unsupported均不能默认正常恢复，内部图像ID仅作素材索引。
- 第一日明确起步，无虚构昨夜；恢复与饮食观察并列，完整溯源按需滚动。日终显示次日效果，周末不承诺未应用效果；结局与轨迹来自实际日记录，不预设漏餐、熬夜、成绩或健康结果。
- 专项14/14、全量288/288、28套件、门禁22项、本地Web审计通过；72局/444条与C3所有已记录玩法结果无差异；六组常规/放大字体布局、桌面/390×640原生输入、Godot MCP实际跨日/复习13/重开幂等通过。日志0错误，三个已有类型警告另记。
- [执行记录](../../../../docs/process/NUT208D_RECOVERY_PRESENTATION_2026-10-08.md)、[对照](../../../../docs/process/NUT208D_COMPARISON_2026-10-08.json)与[MCP记录](../../../../docs/process/NUT208D_MCP_2026-10-08.json)。A–D和M2本地工程出口完成，不代表专业审校或教育候选完成；23份draft/四开关/schema/旧基线/证据状态保持，未发布。下一项EDU-02/03及G4。
