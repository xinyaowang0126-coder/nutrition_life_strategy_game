# 02 评估与建议引擎

> 2026-10-08 [G4A1](../../../../docs/design/G4A1_MEAL_COMPOSITION_CONTRACT.md)已实现单餐进餐事实、冻结组成/资料质量和受控短句接口；318/318、30套件通过，生产UI未接。下文是完整目标设计，日/周、多样性、因素阈值和建议未由本切片完成；原料合并的具体支持/顺序语义以G4A1契约为准。

## 1. 目标

用“多维观察 + 一条可行行动”替代当前单一 `quality` 分数。新引擎需要：

- 对一餐、一天和一周分别评估，不把不同时间尺度混在一个数字里；
- 区分食物出现、相对份量、信息置信度和真正的跨餐多样性；
- 保留同一食物的多面性，不用积极标签抵消需留意因素；
- 只提出玩家在真实游戏状态下做得到的建议；
- 任何结果都能解释“用了哪些记录、哪条规则和哪个证据版本”。

## 2. 从旧模型迁移的原因

当前 `MealResolver.plate_quality()` 把食物组、营养标签和限制标签加减为一个分数。这会造成：

- 跳餐 25 分可能高于某些已进餐选择的 20 分；
- 一份复合餐和三张明确组成的卡可得到同样结果；
- 同一复合餐重复三次仍被视为结构完整和多样；
- 添加糖、高钠和油炸被表示为扣分，玩家容易理解成可被别的“加分项”抵消；
- 精确到个位的分数制造了超出数据能力的确定感。

新模型不再修补分数权重，而是删除“总分”这个输出概念。

## 3. 服务边界

建议新增：

```text
scripts/health/
├─ DietPatternEvaluator.gd          # 纯函数：快照 -> 多维观察
├─ DietPatternLedger.gd             # 保存餐/日/周健康教育记录
├─ GuidanceComposer.gd              # 受控模板 -> 玩家文案
├─ FeasibleSuggestionService.gd     # 结合卡池、预算、库存筛选行动
├─ HealthGuidanceConfig.gd          # 角色映射、阈值、时间窗和版本
└─ HealthEvidenceRegistry.gd        # 证据查找、过期检查
```

现有服务的目标职责：

| 服务 | 保留 | 移除/禁止 |
| --- | --- | --- |
| `MealResolver` | 花费、饱腹、余力、心情、压力、库存等游戏结算 | 不再生成或展示健康 `quality` |
| `NutritionLedger` | 迁移期读取旧记录 | 不再聚合 0–100 分；最终由 `DietPatternLedger` 替代 |
| `DayCarryoverService` | 游戏状态和睡眠选择的跨日效果 | 不以健康观察推断疾病、认知状态或营养缺乏 |
| `CardDataStore` | 卡牌和来源资料 | 不承担新健康资料解析 |

依赖方向必须是：

```text
游戏状态 ────────> 可行建议筛选
食物健康快照 ────> 饮食模式评估 ────> 指导文案

饮食模式评估 -X-> 修改游戏数值
游戏正负数值 -X-> 修改健康分类
```

## 4. 输入契约

### 4.1 一餐输入

```gdscript
{
  "day": 1,
  "phase": "lunch",
  "status": "eaten", # eaten / skipped / legacy_unknown
  "source_id": "cafeteria",
  "food_ids": ["rice_plain", "egg", "tomato"],
  "component_snapshot": [],
  "factor_snapshot": [],
  "confidence": "medium",
  "model_version": "diet-pattern-v2.0"
}
```

`cost`、`mood`、`energy`、`burden` 不在评估输入中。来源和预算只在建议阶段用于可行性判断。

### 4.2 日/周输入

- 按时间顺序排列的 `MealHealthSnapshot`；
- 独立的饮水事件，仅记录发生次数/明确容量，不推断未记录行为；
- 独立的睡眠选择记录；
- 数据缺口和模型版本边界；
- 周窗口内的原料 ID 去重集合。

旧存档缺少健康快照时使用 `legacy_unknown`，不从旧总分逆推出组成。

## 5. 输出契约

引擎输出结构化结果，UI 不自行拼规则：

```gdscript
{
  "scope": "day", # meal / day / week
  "model_version": "diet-pattern-v2.0",
  "dimensions": {
    "regularity": {},
    "plate_structure": {},
    "diversity": {},
    "attention_factors": {}
  },
  "observations": [],
  "primary_suggestion": null,
  "fallback_suggestion": null,
  "separate_records": {
    "hydration": {},
    "sleep": {}
  },
  "data_quality": {
    "status": "partial",
    "unknown_food_ids": []
  },
  "scope_notice_id": "GENERAL_EDUCATION_NOT_MEDICAL"
}
```

明确禁止以下字段：

- `total_score`、`quality`、`grade`、`percentile`；
- `healthy / unhealthy` 二元食物标签；
- `diagnosis`、`deficiency`、`disease_risk`；
- 把饮水或睡眠转换成饮食加分的字段。

## 6. 状态语义

底层状态使用稳定代码，中文只在文案层映射：

| 代码 | 界面建议 | 含义 |
| --- | --- | --- |
| `supported` | 有记录 | 资料足以支持一个窄而明确的观察 |
| `partial` | 有，但信息不完整 | 有组成记录，但份量或配方不足以作更强判断 |
| `attention` | 值得留意 | 存在经审核的需留意事实或模式，不是道德评价 |
| `unknown` | 信息不足 | 无法可靠判断 |
| `not_applicable` | 本项不适用 | 如跳餐时不评餐盘结构 |

颜色不能单独承载含义；所有状态都配图标/文字。`supported` 不等于“达标”，`attention` 不等于“有病”。

## 7. 一餐评估

### 7.1 规律进餐

| 输入 | 输出 |
| --- | --- |
| `status=eaten` | `supported`：“这一餐有记录” |
| `status=skipped` | `attention`：“这一餐跳过了” |
| `status=legacy_unknown` | `unknown`：“历史记录不足” |

跳餐没有分数，也不与任何食物比较优劣。

### 7.2 餐盘结构

步骤：

1. 按 `ingredient_id` 合并同一原料，保留最可靠依据，不重复计数。
2. 将 `component.food_group` 投影到 `staple / vegetable / protein_source`。
3. `trace` 不计入结构；`small` 记为少量；`material/dominant` 记为有明确组成。
4. 任一关键组成只有 low/unknown 置信度时，整体最多为 `partial`。
5. 若三类都有 material/dominant 且置信度至少 medium，可描述“三类组成均有记录”，不得写“营养均衡/份量达标”。
6. 若只有一到两类，列出已有组成并允许建议筛选器寻找缺少的类别。
7. 水果作为日模式记录，不用水果补足单餐蔬菜位。
8. 饮品、坚果和奶类可单独记录，不自动补足主食或蔬菜。

NUT-204D 的牛奶和原味酸奶在未来评估器中只进入 `dairy_daily` 的事实记录，不形成“今天奶类足够”或单餐完成位；全麦面包只按其固定商品组成进入主食记录，名称和固定克数都不能直接推出“全谷物达标”。三条 profile 当前均为 draft，因此本片只冻结输入，不产生任何玩家观察或建议。

推荐结果：

```gdscript
{
  "status": "partial",
  "roles": {
    "staple": {"presence": "material", "confidence": "high"},
    "vegetable": {"presence": "small", "confidence": "medium"},
    "protein_source": {"presence": "material", "confidence": "high"}
  },
  "copy_id": "MEAL_STRUCTURE_VEG_SMALL",
  "evidence_refs": ["CDG-2022-03"]
}
```

### 7.3 需留意因素

每个 factor 独立输出：

```gdscript
[
  {
    "factor_id": "deep_fried",
    "status": "attention",
    "band": "present",
    "confidence": "high",
    "copy_id": "FACTOR_DEEP_FRIED_PRESENT"
  },
  {
    "factor_id": "sodium",
    "status": "unknown",
    "band": "unknown",
    "confidence": "unknown",
    "copy_id": "FACTOR_SODIUM_UNKNOWN"
  }
]
```

同一炸鸡可同时输出“有禽肉蛋白质来源记录”和“含油炸做法/钠信息值得留意”，两者不相减。

`present` 是 `deep_fried` 专用的二元做法事实，不参与 `low / moderate / high` 阈值比较；`deep_fried` factor 只接受 `none / present / unknown`，且 `present` 与 `cooking_method="deep_fried"` 必须双向匹配。上例是通过规则和文案审核后的目标输出。当前 NUT-204C profile 仍为 draft，因此只保存做法事实，不向玩家生成该 observation；钠仍保持 `unknown`。

## 8. 一天评估

### 8.1 规律性

- 分别列出早餐、午餐、晚餐的 `eaten/skipped/unknown`。
- 可显示“3 餐有 2 餐记录”，但这只是记录计数，不是健康分。
- 若游戏有加餐，单独记录，不把加餐自动当作补回跳餐。
- 对偶发跳餐使用事实描述；只有跨日反复模式才可给温和规划建议。

### 8.2 结构覆盖

- 聚合各餐角色状态，保留餐次信息。
- 不把某一餐大量的某类组成用于抵消另一餐的缺失。
- 可描述“蔬菜在午餐有记录，早餐和晚餐未记录/未知”，不写“今日蔬菜达标”。
- 对份量未知的记录只显示出现情况。

### 8.3 多样性

多样性基于 `ingredient_id` 去重：

- 同一 `chicken_vegetable_rice` 连吃三餐只贡献同一组原料 ID；
- 白米饭卡和鸡肉时蔬饭都使用 `cooked_white_rice`，鸡蛋卡/三明治/番茄炒蛋都使用 `chicken_egg`，番茄卡/沙拉/三明治/番茄炒蛋都使用 `tomato`；
- “时蔬”若没有明确原料，只能贡献一个通用 ID 和低置信度，不能假装多种蔬菜；
- `food_group="other"` 或 `contribution_band="trace"` 的油、酱汁、调味料与装饰性原料默认不进入“主要食材种数”；
- 游戏可以显示“记录到 N 种主要食材”，但不按 N 给等级；
- 数字只作为可核查事实，不能暗示达到个人营养需要。

建议同时输出：

```gdscript
{
  "unique_ingredient_count": 5,
  "repeated_ingredient_ids": ["cooked_white_rice"],
  "unknown_composite_count": 1,
  "status": "partial"
}
```

### 8.4 重复需留意因素

- 记录每个 factor 出现在哪些餐，不累计成惩罚分。
- 单次观察优先事实描述；同一因素跨餐重复时才提升建议优先级。
- `unknown` 不当作 `none`，也不当作 `high`。
- 积极组成、饮水、散步、睡眠都不能删除 factor 记录。

## 9. 一周评估

周总结展示模式而非成绩：

- 每天进餐记录的完整性趋势；
- 不同原料和食物组在哪些天出现；
- 重复选择和信息未知的比例；
- 添加糖/高钠/油炸/晚间咖啡因等已知观察的出现时点；
- 饮水事件和睡眠选择另设轨道。

不得：

- 生成周健康总分、S/A/B 等级或“超过 X% 玩家”；
- 通过一天“表现好”抵消另一天的观察；
- 用结局成败证明健康指导正确；
- 因玩家资源不足而使用责备语气。

## 10. 饮水和睡眠的独立轨道

### 10.1 饮水

若当前只记录“喝水”行动而没有容量：

- 显示“今天记录到 2 次饮水行动”；
- 不显示“已喝 1000 ml”或“达到目标”；
- 不修改饮食结构、添加糖或钠观察；
- 可在详情说明“游戏只记录主动选择，未记录不代表现实中没有饮水”。

### 10.2 睡眠

- 显示选择的睡眠时机/时长（仅在游戏明确记录时）。
- 咖啡因与睡眠的提示必须基于已审核时间窗口和剂量/置信度。
- `DayCarryoverService` 的 `clear_focus/fatigued/brain_fog` 应改为明确的游戏状态命名，如“进入状态较快/较慢（游戏效果）”。
- 不声称一天睡眠或一杯咖啡导致疾病、认知障碍或营养问题。

## 11. 可行建议服务

### 11.1 输入

`FeasibleSuggestionService` 接收：

- 当前天、阶段和已选来源；
- 当前/下一餐实际候选卡；
- 现金、库存、服务费、时间和选择上限；
- 已记录的结构空缺和需留意因素；
- 角色口味偏好（只用于排序，不改变健康分类）；
- 本日历史和建议冷却记录。

### 11.2 输出

```gdscript
{
  "suggestion_id": "ADD_AVAILABLE_VEGETABLE",
  "action_type": "add", # add / swap / choose_source / plan / check_label
  "target_phase": "dinner",
  "source_id": "cafeteria",
  "food_ids": ["greens", "tomato"],
  "copy_id": "NEXT_MEAL_ADD_VEG_OPTION",
  "rationale_observation_ids": ["DAY_VEGETABLE_NOT_RECORDED"],
  "feasibility": {
    "verified": true,
    "max_cost": 3,
    "inventory_required": false
  }
}
```

UI 只显示经过 `verified=true` 的建议。

### 11.3 可行性过滤

候选行动必须同时通过：

1. 对应阶段存在；
2. 来源允许；
3. 卡牌在卡池中且没有耗尽；
4. 玩家在计入服务费后买得起；
5. 不超过本餐选择数量；
6. 不与剧情锁定或库存规则冲突；
7. 文案不声称未知信息；
8. 不重复上一条建议，除非模式持续且没有替代方案。

如果当前便利店没有蔬菜：

- 不能显示“现在加份青菜”；
- 若换来源仍来得及且买得起，可显示“想加蔬菜的话，食堂有可选项”；
- 若不可换来源，可给下一餐的计划型建议；
- 若所有替代都不可行，则只保留观察，不强行生成建议。

### 11.4 建议优先级

每次最多显示 1 条主要行动和 1 条折叠备选：

1. 明确的食品安全事件；
2. 当前可补足的餐盘角色；
3. 连续跳餐的准备/规划行为；
4. 当日重复出现的已知需留意因素；
5. 跨餐原料重复时的可选替换；
6. 商品信息未知时的标签阅读；
7. 没有必要行动时显示一条事实性正反馈，不制造任务。

优先级不等于医学严重程度，只是游戏内反馈的呈现顺序。

这里的“商品信息未知”指真正缺少包装规格或标签字段，不包括“固定游戏规格已经明确、但健康解释仍为 draft”的条目。NUT-204D 三项不能因为 `review_status="draft"` 被错误推荐为“再看一次标签”，也不能用旧 `nutrient_tags` 补结论。每 100 g/ml、每份和 `NRV%` 的比较教学由 NUT-505 独立启用；在此之前最多提供中性的“看看包装/商品小档案”入口，不生成商品排名或替换建议。虚构规格与现实边界在统一帮助页说明，不要求每张卡重复元话语。

### 11.5 建议文案结构

固定三段数据，不让 UI 自由生成：

- `action`：具体、可点击，如“晚餐可加一份番茄或青菜”；
- `reason`：只解释当前记录，如“今天还没有蔬菜组成记录”；
- `scope`：必要时说明限制，如“份量以游戏卡牌资料为准；游戏内固定配方不等于现实菜品”。

禁止：

- “必须、绝对、排毒、燃脂、补脑、清零负担”；
- “今天吃坏了，明天补回来”；
- “喝水抵消高盐”“散步消耗奶茶”；
- 建议一个当前不可获得的食物。

## 12. 评估伪代码

```gdscript
func evaluate_day(meals: Array[Dictionary]) -> Dictionary:
    var normalized := normalize_snapshots(meals)
    var regularity := evaluate_regularity(normalized)
    var plate_structure := aggregate_plate_roles(normalized)
    var diversity := evaluate_unique_ingredients(normalized)
    var factors := collect_independent_factors(normalized)

    return {
        "scope": "day",
        "model_version": MODEL_VERSION,
        "dimensions": {
            "regularity": regularity,
            "plate_structure": plate_structure,
            "diversity": diversity,
            "attention_factors": factors,
        },
        "observations": compose_observation_tokens(
            regularity, plate_structure, diversity, factors
        ),
        "data_quality": evaluate_data_quality(normalized),
    }
```

`evaluate_day` 是纯函数，不访问 UI、随机数、存档或游戏数值。建议服务在得到评估结果后单独运行。

## 13. 必须保持的不变量

自动化测试应把以下规则当作系统契约：

1. 跳餐永远没有餐盘分数，也不能排在某种食物之上或之下。
2. 任何结果中都不存在可加总的健康分。
3. 增加一份明确蔬菜组成不会减少蔬菜结构记录。
4. 重复同一原料不会增加唯一原料数。
5. 改价格、心情、余力或 `burden` 不改变健康观察。
6. 饮水、散步和睡眠不会清除饮食 factor。
7. 添加一个 factor 不会删除已有积极组成。
8. unknown 不会静默变为 none、material 或 high。
9. 水果不会被映射为蔬菜。
10. 建议引用的 food_id 必须在目标上下文真实可选。
11. 文案层只消费 `copy_id` 和参数，不重复实现规则。
12. 同一输入、模型版本和数据快照必须产生相同输出。

## 14. `burden` 与跨日效果迁移

短期 M1：

- 玩家界面把 `burden` 反向显示为“角色健康（游戏属性）”，统一遵循“越高越好”；内部存档字段暂不迁移。
- 游戏属性详情明确“不是对玩家真实健康的评价，也不参与饮食结构判断”。
- `NutritionLedger` 和新健康引擎完全不读取它。

M2（NUT-208）必须拆分，而不是继续改名：

- 建立独立的恢复玩法轨道，输入只来自精力、压力、作息、过度安排和明确的恢复行动；
- 睡眠选择必须可追溯地改变恢复轨道和次日游戏状态；
- 食物的旧 `burden` 不再进入单一“健康”值；饮食只通过 profile 和多维观察进入健康教育层；
- 饮水、散步、早睡可以影响恢复玩法，但不能清除或减少任何饮食观察；
- 旧存档只做显式迁移，不能把旧 `diet_burden` 解释为真实健康或营养状态。

长期：

- 旧记录适配器识别旧 `burden`，恢复信息不足时显式降级；不能从旧混合值反推新游戏恢复状态；
- 删除把该值描述成“健康/饮食负担”的所有文案；
- 结局条件若继续使用它，应明确是玩法综合状态，不是健康诊断。

NUT-208A 现状审计与已确认 R2 见 [08 恢复状态迁移](./08_recovery_state_migration.md)。除了 burden，当前 DayCarryover 还直接读取餐次、组成和糖钠油炸计数，新恢复判定把这些输入全部移出；`energy/stress/action_counts/sleep_id` 以外的键会被拒绝。保留食物和旧 quality 对游戏精力/压力的间接影响，旧 quality 剩余兼容路径归 NUT-308；不能宣称已消除所有饮食对玩法的影响。

R2 采用日终一次生成的四档状态、明确规则优先级、冻结睡眠/行动依据与独立余力贡献。用户已确认：刷手机保留精力/心情效果，按实际状态判定，不必定疲惫；最佳结局仅需复习≥70且余力≥60，恢复只通过余力与复习效率间接影响。`PHONE_AT_NIGHT` 是事实原因，不是触发疲惫的规则。具体阈值和权重为工程默认，后续模拟校准；R1 未实现，运行规则仍为 `recovery-gameplay-v1`。

A 完成，B 独立 `RecoveryRules`、`RecoveryStateService` 与纯迁移接口已完成工程及本地验证，C/D 尚未实施，当前局仍使用旧结算。B 的独立恢复 envelope 使用 gameplay 版本 2，没有完整存档/续玩接入或磁盘读写；只识别明确的旧 stats/day_record 为 legacy_unknown，不从旧值反推，历史不重新 evaluate。`MealHealthArchive` 的健康档案 schema 不变，四个健康开关仍关闭，Godot AI 3.2.5 保留，本轮不提交或发布。

同时加固 `MealHealthSnapshot` 的现有黑名单，拒绝恢复记录/版本/睡眠快照/次日效果键混入健康历史；初始空恢复记录也不能作为额外数据进入。该校验不改变正常快照生成或游戏结算。

B 验证为 Godot 4.7.2 全量 217/217、22 套件，含恢复规则 14/14、记录 9/9、迁移 14/14；静态发布配置与主场景烟测通过。日志 `.godot/logs/nut208b-project-verification.log`，9 条真实旧日记录降级及冻结旧基线哈希核对通过。新规则七天平衡与界面验收仍归 C/D，不用 B 接口通过率代替。

## 15. 特性开关和兼容

建议使用：

| 开关 | 默认 | 用途 |
| --- | --- | --- |
| `health_guidance_v2_data` | off | 加载新 profile 和验证报告 |
| `health_guidance_v2_engine` | off | 影子运行新评估器并比较日志 |
| `health_guidance_v2_ui` | off | 显示新选择期/日结界面 |
| `health_guidance_v2_weekly` | off | 启用周趋势 |

依赖：UI 开关只能在 data 和 engine 开启时开启。正式发布后以一个版本观察稳定性，再删除旧 `quality` 读取路径。

## 16. 验收标准

- [ ] `MealResolver` 的游戏结算测试不因新健康层改变。
- [ ] 新引擎输出四个维度、数据质量、独立饮水/睡眠记录，无总分。
- [ ] 跳餐、同餐、复合菜重复、未知份量和限制因素均有金样例。
- [ ] 任意游戏数值变化不改变健康输出。
- [ ] 所有建议都通过来源、预算、库存、阶段和选择上限验证。
- [ ] 无可行选项时不生成虚假建议。
- [ ] 观察和建议都带 `copy_id`、证据 ID、置信度和模型版本。
- [ ] 旧存档显示降级结果而非重新伪造。
- [ ] `burden` 与饮食观察完全断开。
