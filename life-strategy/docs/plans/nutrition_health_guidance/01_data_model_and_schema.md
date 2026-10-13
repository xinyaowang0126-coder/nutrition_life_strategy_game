# 01 数据模型与字段规范

## 1. 目标

建立一个与游戏数值解耦、能表示“已知/估算/未知”、支持复合菜和证据追溯的健康教育数据层。它应回答：

- 这张卡实际代表多大一份、什么配方和什么做法？
- 哪些食物组真正出现了，复合菜中各组成是否足以支撑结构判断？
- 添加糖、钠、油炸、咖啡因等观察依据是什么、置信度多高？
- 数据变更后，旧存档为何仍能复现当时的反馈？

## 2. 当前问题

方案起始时，`data/cards/foods.xml` 同时承载游戏结算和少量营养标签：

- `cost`、`satiety`、`energy`、`mood`、`burden` 是游戏平衡值，不是营养测量。
- `food_groups` 只表示某类“出现”，没有份量和组成依据。
- `nutrient_tags` 容易把食物类别等同于摄入充足。
- `limit_tags` 覆盖不一致；23 个条目中只有奶茶、方便面和炸鸡有记录。
- `tags` 混有玩法、口味、分类和健康含义，无法安全作为评估输入。
- 复合菜只有合并后的组别，无法识别真实原料或跨餐重复。

因此新评估器不得直接把上述字段当作充分的健康依据。

NUT-207 已将全部 23 项食物的 `mood` 迁入独立角色偏好资料，并从食物 `tags` 移除 `favorite`、`mood`。食物剩余的游戏值和旧营养标签仍遵守上述限制；`burden` 与旧结算的拆分继续由 NUT-208 承接，不能据此认定 M2 已整体完成。

## 3. 推荐存储结构

保留 `foods.xml` 作为游戏卡牌目录，新建独立健康资料层：

```text
data/
├─ cards/
│  └─ foods.xml                       # 现有游戏效果与卡牌可见资料
├─ characters/
│  └─ default_food_preferences.xml    # NUT-207：本局角色口味，不属于健康资料
└─ health/
   ├─ food_health_profiles.xml        # 以 food_id 连接食物健康资料
   ├─ evidence_registry.xml           # 证据、适用范围与版本
   └─ guidance_copy.xml               # 经审核的观察与建议模板
```

建议新增读取/校验代码：

```text
scripts/health/
├─ HealthDataStore.gd
├─ HealthDataValidator.gd
├─ HealthEvidenceRegistry.gd
├─ MealHealthSnapshot.gd             # NUT-206 已实现：冻结当餐资料
├─ MealHealthArchive.gd              # NUT-206 已实现：健康记录 JSON 存取/旧记录迁移
└─ HealthGuidanceConfig.gd
```

连接规则：

1. `food_health_profiles.xml/profile@food_id` 必须对应唯一的 `foods.xml/food@id`。
2. 游戏层可以没有健康资料；此时健康层返回“信息不足”，不得创建默认健康标签。
3. 健康层不得读取 `mood`、`energy`、`burden`、`cost` 决定结构或限制因素。
4. 删除食物卡前必须先处理健康资料和存档迁移。
5. 数据加载失败时保持游戏可玩，但健康 UI 进入明确的降级态并写入错误日志。

## 4. 根节点和版本

建议根节点：

```xml
<food_health_profiles
  schema_version="1"
  model_version="diet-pattern-v2.0"
  locale="zh-CN"
  reviewed_at="YYYY-MM-DD">
  ...
</food_health_profiles>
```

| 字段 | 必填 | 含义 |
| --- | --- | --- |
| `schema_version` | 是 | 文件结构版本；解析器据此迁移 |
| `model_version` | 是 | 评估语义版本；写入每条用餐快照 |
| `locale` | 是 | 内容语言和适用语境，不等同于营养标准版本 |
| `reviewed_at` | 是 | 整体最近复核日期 |

版本规则：

- 改字段结构：递增 `schema_version`。
- 改分类阈值、观察语义或建议优先级：递增 `model_version`。
- 只改错别字且不影响语义：不必改模型版本，但要记录内容版本。
- 存档中的旧快照不自动用新模型重算；周总结只聚合相同主版本或明确显示“规则已更新”。

## 5. 食物健康资料字段

### 5.1 `profile`

| 字段 | 类型/枚举 | 必填 | 规则 |
| --- | --- | --- | --- |
| `food_id` | String | 是 | 对应卡牌 ID，唯一 |
| `profile_version` | 正整数 | 是 | 本条资料修订号 |
| `display_basis` | String | 是 | 玩家可理解的份量基准，如“一碗”“一瓶” |
| `portion_status` | `known / estimated / unknown` | 是 | 是否有足够信息描述份量 |
| `portion_value` | Float | 条件 | 有可靠数据时填写，必须大于 0 |
| `portion_unit` | `g / ml / piece / pack / bowl / serving` | 条件 | 与 value 同时出现 |
| `portion_band` | `small / medium / large / unknown` | 是 | 仅作当前游戏内相对描述，不宣称个体推荐量 |
| `basis_type` | 见 5.2 | 是 | 数据来自哪里 |
| `composition_status` | `known / estimated / unknown` | 是 | 对原料组成掌握到什么程度；不得用 profile 总置信度代替 |
| `confidence` | `high / medium / low / unknown` | 是 | 对当前配方和份量的把握 |
| `review_status` | `draft / expert_reviewed / needs_update` | 是 | 未审核资料不得生成肯定性建议 |
| `evidence_refs` | 逗号分隔 ID | 是 | 至少一个证据或“产品配方待确认”记录 |
| `reviewed_by` | String | 条件 | 专业复核后填写角色/代号，避免不必要个人信息 |
| `reviewed_at` | ISO 日期 | 条件 | `expert_reviewed` 时必填 |

`portion_band` 只帮助界面表达“小份/常规份/大份”，不能直接换算成“达标比例”。若角色年龄、性别和身体状况未定义，玩家界面不显示个体化克数目标。

### 5.2 `basis_type`

| 枚举 | 使用场景 | 默认置信度上限 |
| --- | --- | --- |
| `package_label` | 游戏明确模拟某个包装标签 | high |
| `menu_recipe` | 项目有固定配方和出品份量 | high |
| `standard_recipe_estimate` | 使用一般配方估算 | medium |
| `visual_estimate` | 仅根据插画/描述估算 | low |
| `generic_category` | 只有品类名，没有具体产品/配方 | low |
| `unknown` | 无可靠依据 | unknown |

“原味酸奶”“全麦面包”“三明治”等名称不能自动视为有固定营养组成；若没有模拟标签或配方，必须使用 `generic_category` 或 `unknown`。

NUT-204D 已为本游戏中的 `milk / plain_yogurt / whole_wheat_bread` 单独冻结版本化包装商品规格，因此这三个特定 food_id 可以使用 `package_label + confidence="high"`。这不是对所有“牛奶/原味酸奶/全麦面包”的泛化，也不改变上述默认规则；新增同名商品仍须另建规格或回到 unknown。

`package_label` 和 `menu_recipe` 允许由游戏设计定义虚构但固定的产品。此时 `confidence="high"` 只表示“这项游戏内规格能够稳定复现”，不表示同名现实商品都具有该组成，也不表示健康含义已获审核。规格事实、玩法效果和健康解释必须分别管理：

- 规格事实记录杯量、配方、模拟标签值等确定输入；
- 玩法效果记录余力、心情、价格等游戏数值，可以按平衡需要调整；
- 健康解释仍由版本化阈值、外部依据和 `review_status` 控制。

因此，一个 profile 可以同时为 `basis_type="menu_recipe"`、`confidence="high"`、`review_status="draft"`：配方是确定的，但尚不能生成玩家肯定性健康建议。

## 6. 原料与食物组组成

复合菜和单一食物都使用 `component`，避免只给复合菜贴多个组别：

`profile@composition_status` 必须显式填写。复合菜暂时没有可核对原料时使用 `unknown`，允许 `components` 为空；`known/estimated` 的复合菜至少要有一个 component。这样“没填原料”不会被误读成“没有该原料”。

| 字段 | 类型/枚举 | 必填 | 规则 |
| --- | --- | --- | --- |
| `ingredient_id` | String | 是 | 稳定原料 ID，用于跨餐去重 |
| `name` | String | 是 | 编辑器/审校显示名 |
| `food_group` | 规范枚举 | 是 | 不允许自由文本 |
| `contribution_band` | `trace / small / material / dominant / unknown` | 是 | 表示这份菜中该组成的相对存在程度 |
| `amount_value` | Float | 否 | 有可靠配方时记录 |
| `amount_unit` | `g / ml / piece` | 条件 | 与 amount 同时出现 |
| `basis_type` | 同上 | 是 | 可覆盖 profile 的总依据 |
| `confidence` | 同上 | 是 | 可覆盖 profile 的总置信度 |

规范食物组：

- `grains_tubers`：谷薯类；
- `vegetables`：蔬菜；
- `fruits`：水果；
- `eggs`：蛋类；
- `soy_products`：大豆及制品；
- `poultry_livestock`：畜禽肉；
- `fish_seafood`：鱼虾等水产品；
- `dairy`：奶及奶制品；
- `nuts_seeds`：坚果种子；
- `beverages`：饮品占位，不作为餐盘组成；
- `other`：无法归类但已知；
- `unknown`：信息不足。

评估层再把组别投影到餐盘角色：

| 餐盘角色 | 可映射组别 |
| --- | --- |
| `staple` | `grains_tubers` |
| `vegetable` | `vegetables` |
| `protein_source` | `eggs`、`soy_products`、`poultry_livestock`、`fish_seafood`；奶类是否计入由模型配置决定 |
| `fruit_daily` | `fruits`，只用于日/周观察，不要求每餐出现 |
| `dairy_daily` | `dairy`，只用于日/周观察 |
| `nuts_daily` | `nuts_seeds`，只用于日/周观察 |

核心规则：

- `trace` 不得用于宣称“这一类已经补齐”。
- `small` 只能显示“有少量记录”，不能显示完成态。
- `material` 或 `dominant` 才能支持“这一餐包含该组成”，但仍不等于个体摄入充足。
- `unknown` 必须传播到结果，不能按 `material` 处理。
- 水果不替代蔬菜，饮料不替代饮水记录，咖啡不作为完成一餐的组成。
- 同一真实原料在不同 profile 中复用稳定 `ingredient_id`，例如白米饭卡与鸡肉时蔬饭都使用 `cooked_white_rice`；只改变做法或菜名不能制造新的多样性。
- 默认多样性只统计 `food_group != other` 且 `contribution_band != trace` 的主要原料；油、酱汁、调味料和装饰性葱姜不增加“主要食材种数”。
- 同一 `food_id` 在多个来源出现时必须代表同一个标准游戏物品；若来源配方不同，使用 variant 模型或拆分 food_id。

## 7. 烹调和需留意因素

### 7.1 `cooking_method`

建议枚举：

`boiled`、`steamed`、`stir_fried`、`deep_fried`、`baked`、`raw_ready_to_eat`、`brewed`、`mixed`、`not_applicable`、`unknown`。

烹调方式只描述事实。`deep_fried` 可以生成“本餐含油炸食物”的观察，但不能覆盖其蛋白质来源等其他特征。

`not_applicable` 表示这项固定商品无需用当前烹调枚举描述，例如即开即饮的包装牛奶和酸奶；它必须单独出现，不能与任何其他 cooking method 共存。`unknown` 表示本应记录但资料不足。二者不得互换，也不能把 `not_applicable` 解释为“不需要储存、没有食品安全要求”或任何健康结论。

### 7.2 `factor`

| 字段 | 类型/枚举 | 必填 | 规则 |
| --- | --- | --- | --- |
| `factor_id` | `added_sugar / sodium / saturated_fat / deep_fried / caffeine` | 是 | 只启用已有证据和审核文案的项 |
| `band` | `none / present / low / moderate / high / unknown` | 是 | `deep_fried` 只接受 `none / present / unknown`；其他 factor 不接受 `present`，数值等级由模型配置和证据版本定义 |
| `basis_type` | 同 5.2 | 是 | 不得只凭 `tags` 推断 |
| `confidence` | 同 5.1 | 是 | UI 可转成“依据明确/估算/未知” |
| `evidence_refs` | ID 列表 | 是 | 支撑分类和展示文案 |

规则：

- `none` 只能在配方/标签明确时使用，不能把“没填”当作“没有”。
- `present` 目前只允许 `factor_id="deep_fried"`，且必须同时存在 `cooking_method="deep_fried"`；反过来，只要做法为 `deep_fried` 就必须记录 `band="present"`。任一方向缺失都会阻断目录，它只表示油炸做法确实存在，不等于“高”或任何健康结果。
- `unknown` 不触发肯定的风险语句，只显示“配方/标签未明确”。
- `moderate/high` 的阈值必须集中在 `HealthGuidanceConfig.gd`，不得散落在 UI。
- “高钠”“高糖”等词只有符合所采用标准时才能显示；否则使用“含钠信息值得查看”“有添加糖记录”等更窄的事实表达。
- 限制因素和积极组成并列输出，不做加减分。

## 8. 咖啡因、过敏原和食品安全

### 8.1 咖啡因

咖啡/奶茶等可包含：

| 字段 | 含义 |
| --- | --- |
| `caffeine_status` | `known / estimated / unknown / not_applicable` |
| `caffeine_mg` | 仅在固定产品或配方可靠时填写 |
| `caffeine_band` | `none / low / moderate / high / unknown` |
| `serving_time_relevance` | `none / evening_attention / unknown` |

咖啡因的剂量阈值和“晚间”时间窗口进入版本化配置。没有剂量时不得显示精确毫克，也不得根据“咖啡”名称假装所有产品相同。`caffeine_status="not_applicable"` 时必须同时满足：不含 `caffeine_mg`、`caffeine_band="none"`、`serving_time_relevance="none"`；任一矛盾组合都由 Validator 阻断。

### 8.2 过敏原

`allergen` 只用于信息披露和后续标签阅读玩法，不收集玩家疾病史：

| 字段 | 枚举 |
| --- | --- |
| `allergen_id` | 受控列表，如 `milk / egg / soy / fish / peanut / tree_nut / gluten_cereal` |
| `presence` | `contains / may_contain / unknown` |
| `basis_type` | `package_label / menu_recipe / generic_category / unknown` |

受控列表上线前须按目标地区法规和专业审校确定。不要把“过敏原提示”改写为对具体玩家的医疗建议。

### 8.3 食品安全

宿舍库存和即食食品可包含：

| 字段 | 示例 |
| --- | --- |
| `storage` | `room_temperature / refrigerated / frozen / unknown` |
| `shelf_life_rule_id` | 引用审核过的规则，不在食物条目中写自由文本 |
| `cold_chain_required` | Boolean/unknown |
| `reheat_required` | Boolean/unknown |
| `ready_to_eat` | Boolean/unknown |

食品安全提示必须由明确事件触发，如库存过期、冷藏中断或需要复热；不能因为某类食物“看起来不健康”而触发。

当前 schema v1 的生产解析器只实际读取 `profile / component / method / factor`；`allergens` 与 `food_safety` 仍是运行时占位，Validator 尚未校验其完整性。因此 NUT-204D 不在 XML 中填写或推断过敏原、储存、冷链和保质期，也不得因为数组为空显示“无过敏原/无需冷藏/可以安全食用”。过敏原需要后续 schema、解析、校验和专业复核切片；宿舍库存的储存、过期和冷链事件继续由 NUT-506 承接。

同样，schema v1 中的 `basis_type="package_label"` 只表示“这是一套可复现的游戏内包装商品规格”，并不包含完整营养成分表。每 100 g/ml、每份、`NRV%`、标签标准版本和法规过渡语境仍须在 NUT-505 中另建结构，不能塞进 `display_basis` 或依赖 UI 自行计算。

## 9. 完整 XML 示例

以下仅展示目标结构，数值和份量必须在内容迁移时复核：

```xml
<profile
  food_id="chicken_vegetable_rice"
  profile_version="1"
  display_basis="游戏内固定配方：鸡肉时蔬饭盒 480 g"
  portion_status="known"
  portion_value="480"
  portion_unit="g"
  portion_band="large"
  basis_type="menu_recipe"
  composition_status="known"
  confidence="high"
  review_status="draft"
  evidence_refs="GAME-SPEC-204C-V1,CDG-2022-DIVERSITY,CDG-2022-03"
  caffeine_status="not_applicable"
  caffeine_band="none"
  serving_time_relevance="none">
  <component
    ingredient_id="cooked_white_rice"
    name="熟白米饭"
    food_group="grains_tubers"
    contribution_band="dominant"
    amount_value="200"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <component
    ingredient_id="chicken_meat"
    name="熟鸡肉"
    food_group="poultry_livestock"
    contribution_band="material"
    amount_value="100"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <component
    ingredient_id="broccoli"
    name="西兰花"
    food_group="vegetables"
    contribution_band="material"
    amount_value="70"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <component
    ingredient_id="bok_choy"
    name="小青菜"
    food_group="vegetables"
    contribution_band="small"
    amount_value="50"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <component
    ingredient_id="carrot"
    name="胡萝卜"
    food_group="vegetables"
    contribution_band="small"
    amount_value="30"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <component
    ingredient_id="chicken_rice_sauce"
    name="鸡肉饭调味酱汁"
    food_group="other"
    contribution_band="small"
    amount_value="20"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <component
    ingredient_id="stir_fry_oil"
    name="烹调用油"
    food_group="other"
    contribution_band="small"
    amount_value="10"
    amount_unit="g"
    basis_type="menu_recipe"
    confidence="high" />
  <method id="mixed" />
  <factor
    factor_id="sodium"
    band="unknown"
    basis_type="menu_recipe"
    confidence="high"
    evidence_refs="GAME-SPEC-204C-V1,CDG-2022-05" />
</profile>
```

这个条目的份量和组成是可稳定复现的游戏事实；组件克数合计为 480 g。`review_status="draft"` 与 `sodium=unknown` 仍会阻止“三类均衡”“份量充足”“低钠”等玩家结论。确定配方不等于完成健康审核。

## 10. 运行时数据契约

### 10.1 `FoodHealthProfile`

解析器返回结构化字典/Resource：

```gdscript
{
  "food_id": "chicken_vegetable_rice",
  "profile_version": 1,
  "model_version": "diet-pattern-v2.0",
  "portion": {
    "status": "known",
    "value": 480.0,
    "unit": "g",
    "label": "游戏内固定配方：鸡肉时蔬饭盒 480 g",
    "band": "large"
  },
  "basis_type": "menu_recipe",
  "composition_status": "known",
  "components": [
    {"ingredient_id": "cooked_white_rice", "food_group": "grains_tubers", "contribution_band": "dominant", "amount_value": 200.0, "amount_unit": "g"},
    {"ingredient_id": "chicken_meat", "food_group": "poultry_livestock", "contribution_band": "material", "amount_value": 100.0, "amount_unit": "g"},
    {"ingredient_id": "broccoli", "food_group": "vegetables", "contribution_band": "material", "amount_value": 70.0, "amount_unit": "g"},
    {"ingredient_id": "bok_choy", "food_group": "vegetables", "contribution_band": "small", "amount_value": 50.0, "amount_unit": "g"},
    {"ingredient_id": "carrot", "food_group": "vegetables", "contribution_band": "small", "amount_value": 30.0, "amount_unit": "g"},
    {"ingredient_id": "chicken_rice_sauce", "food_group": "other", "contribution_band": "small", "amount_value": 20.0, "amount_unit": "g"},
    {"ingredient_id": "stir_fry_oil", "food_group": "other", "contribution_band": "small", "amount_value": 10.0, "amount_unit": "g"}
  ],
  "cooking_methods": ["mixed"],
  "factors": [{"factor_id": "sodium", "band": "unknown"}],
  "caffeine": {
    "status": "not_applicable",
    "band": "none",
    "serving_time_relevance": "none"
  },
  "allergens": [],
  "food_safety": {},
  "confidence": "high",
  "review_status": "draft",
  "evidence_refs": ["GAME-SPEC-204C-V1", "CDG-2022-DIVERSITY", "CDG-2022-03"]
}
```

示例中的 component 为便于阅读只列出快照判断所需的关键字段；实际解析结果仍保留 `name / basis_type / confidence` 等第 6 节字段。

示例中的 `allergens: []` 和 `food_safety: {}` 是当前解析器的兼容占位，不表示已经解析出“无过敏原”或“没有储存要求”。消费者在后续 schema 落地前必须忽略这两个空值，不能生成玩家文案。

所有可选字段都使用明确空值/枚举，不用 `0` 代表未知。

### 10.2 `MealHealthSnapshot`

玩家确认选择时写入不可变快照：

```gdscript
{
  "day": 2,
  "phase": "dinner",
  "status": "eaten",
  "source_id": "takeout",
  "food_ids": ["chicken_vegetable_rice"],
  "profile_versions": {"chicken_vegetable_rice": 1},
  "model_version": "diet-pattern-v2.0",
  "component_snapshot": [
    {"ingredient_id": "cooked_white_rice", "amount_value": 200.0, "amount_unit": "g"},
    {"ingredient_id": "chicken_meat", "amount_value": 100.0, "amount_unit": "g"},
    {"ingredient_id": "broccoli", "amount_value": 70.0, "amount_unit": "g"},
    {"ingredient_id": "bok_choy", "amount_value": 50.0, "amount_unit": "g"},
    {"ingredient_id": "carrot", "amount_value": 30.0, "amount_unit": "g"},
    {"ingredient_id": "chicken_rice_sauce", "amount_value": 20.0, "amount_unit": "g"},
    {"ingredient_id": "stir_fry_oil", "amount_value": 10.0, "amount_unit": "g"}
  ],
  "factor_snapshot": [{"factor_id": "sodium", "band": "unknown"}],
  "confidence": "high"
}
```

跳餐使用 `status="skipped"`，不伪造食物、组别、份量或 `quality`。加载旧存档时可以标记 `status="legacy_unknown"`，不要反推不存在的数据。

### 10.3 NUT-206 实际快照与存取契约（2026-09-04）

10.2 是精简示例。当前 `MealHealthSnapshot.build(day, record, catalog)` 还保存以下字段：

| 字段 | 实际用途 |
| --- | --- |
| snapshot_schema_version | 当前为 1；未知未来格式拒绝加载 |
| profile_versions / model_version | 保存当餐使用的资料修订号和模型版本；不读取新目录重算旧餐 |
| profile_snapshots | 按 food_id 保存完整健康资料深拷贝，保留份量、组成、做法、咖啡因、因素、证据引用、confidence 和 review_status |
| component_snapshot / factor_snapshot | 保留完整组成/因素字段，并附 food_id、profile_version；此层不提前去重，不计算健康结论 |
| data_status | ready 表示所选资料结构齐全，partial 表示有缺失/无效资料，unavailable 表示目录不可用；跳餐为 not_applicable，旧资料为 legacy_unknown |
| missing_food_ids / invalid_food_ids | 显式记录缺口；成功进餐即使缺资料仍为 eaten，不改成 skipped |
| guidance_status | 固定 not_evaluated；high + draft 是合法组合，不能视为专业审核通过 |
| catalog_reviewed_at | 捕获时的目录维护日期，不替代逐条专业签署 |
| legacy_skipped | 仅迁移旧记录的显式布尔 skipped；旧分数或空 food_ids 不能推断跳餐 |

旧记录缺少日期时保存 `day=null`，缺少有效餐次时保存 `phase="unknown"`。不使用数组下标、当前游戏日期、旧 quality 或当前食物资料补全历史。schema/day/profile 版本在 JSON 边界仅接受安全范围内的有限整数数值，经过验证后恢复 int；份量数值保留精度，字符串数字、布尔值和小数版本拒绝加载。

`MealHealthArchive` 保存以下外层结构：

```json
{
  "schema_version": 1,
  "kind": "meal_health_archive",
  "snapshots": []
}
```

- `append_snapshot / get_snapshots / to_save_data` 使用独立深拷贝；外部修改返回值不改变历史记录。
- `load_data` 支持上述版本化结构、旧单餐记录数组和无 schema 的 `{ "day": 2, "meal_records": [...] }`。如果旧日记录使用 `meals`，由调用方显式将该数组及其外层 day 传入，不猜测完整游戏存档格式。
- 旧记录已有 `health_snapshot` 或直接是带 snapshot_schema_version 的快照时，验证后原样保留资料，不迁为 legacy；未来或损坏版本不能回退到旧格式解析。
- 整批验证成功后才替换内存；`save_file / load_file` 返回 ok/status/error。写入使用同目录临时文件及重命名替换，失败时保留已有档案。
- 这是健康记录归档，不保存余额、库存、阶段、手牌等完整游戏状态，不提供整局断点续玩。

GameRootV2 仅在 `health_guidance_v2/data` 开启后捕获已通过结算校验的确认/跳餐，一餐追加一次；资料异常或写盘失败不撤销已成立的游戏选择。自动保存默认写入 `user://health_guidance/latest_meals.json`，可用 health_history_path 注入其他路径或空串关闭自动保存。目录按本局首次有效提交懒加载，重开清空本局快照和缓存，首次新提交覆盖 latest 文件；需要保留旧局时可显式保存到不同路径。

`get_health_snapshots()` 返回本局记录，`save_health_history(path)` 保存本局；`load_health_history(path)` 仅返回历史 snapshots，不替换本局档案或游戏状态，因此读旧档后继续游戏不会混局。默认 data/engine/ui/weekly 仍全部关闭，off 时不加载资料或写文件。

## 11. 校验规则

`HealthDataValidator.gd` 至少输出：

### 阻断错误

- 重复或不存在的 `food_id`；
- 非法枚举、负份量、单位缺失；
- `composition_status="known"` 却没有任何 component（不依赖外部复合菜 ID 清单，历史快照加载也执行此校验）；
- 已知配方的同单位 component 总量与已知份量不闭合；
- 同一稳定 `ingredient_id` 在不同 profile 中映射到不同食物组；
- `review_status="expert_reviewed"` 但缺少复核日期或证据；
- `factor@band="none/high"` 却没有依据；
- `deep_fried` 使用分级 band，或做法与 `present` 因素没有双向匹配；
- 复合菜无任何 component 且未声明 unknown；
- `schema_version` 高于解析器支持版本。

### 警告

- `profile` 仍为 `draft`；
- `confidence="low/unknown"`；
- 复合菜所有 component 都为 `unknown`；
- 含咖啡/茶关键词但咖啡因状态未填；
- 商品型食物缺营养标签/配方待确认记录；
- 健康资料引用了已废弃证据版本。

CI 中阻断错误必须为 0；警告要有显式白名单、负责人和到期日，不能永久忽略。

## 12. 与现有字段的迁移

| 现有字段 | 迁移用途 | 新评估器是否直接读取 |
| --- | --- | --- |
| `food_groups` | 初始迁移提示，人工拆为 component | 否 |
| `nutrient_tags` | 人工核对候选依据 | 否 |
| `limit_tags` | 人工核对 factor 候选 | 否 |
| `tags` | 玩法筛选和内容检索 | 否 |
| `kind` | 卡牌展示 | 否 |
| `energy/burden` | 游戏结算；burden 的长期拆分由 NUT-208 承接 | 否 |
| 食物旧 `mood`、`favorite/mood` 标签 | NUT-207 已迁入角色偏好 XML；食物目录不再保存这些字段/标签 | 否 |
| `food_preference` / `preference_reactions` | 当局口味展示与游戏结算历史 | 否 |
| `scenes/sources` | 可行建议筛选 | 是，但只判断能否获得 |
| `dorm_stock` | 库存和可行建议 | 是，但不改变营养分类 |

迁移顺序：

1. 新建健康资料文件和校验器，不接 UI。
2. 为 23 个条目逐项创建 profile，未知字段明确填写 unknown。
3. 双读期间比较旧标签和新资料，但只记录差异，不向玩家显示两套结论。
4. 新评估器与 UI 上线后，停止 `MealResolver` 生成健康 `quality`。
5. 完成两个稳定版本后删除旧健康字段，或保留为纯内容检索字段并重命名。

## 13. 口味和偏好数据分离

### 13.1 NUT-207 已接入的角色资料

“青菜心情 -2”“沙拉心情 -3”现已明确归于本局角色的口味，不能作为食物固有属性或健康判断。`data/characters/default_food_preferences.xml` 使用独立 schema：

```xml
<food_preferences schema_version="1" id="campus_student" version="1" name="本局角色">
  <reaction food_id="greens" mood_delta="-2" comfort="false" />
  <reaction food_id="bubble_tea" mood_delta="18" comfort="true" />
</food_preferences>
```

上例仅展示两个条目；默认文件实际包含全部 23 个 food_id，原有 mood 数值逐项保留。`comfort=true` 仅显式配置在 `bubble_tea`、`instant_noodles`、`fried_chicken`，其余为 false。`schema_version` 表示 XML 格式，`version` 表示角色偏好资料修订号，不与健康 profile/model 版本混用。

`FoodPreferenceService` 返回的角色资料为：

```gdscript
{
  "id": "campus_student",
  "version": 1,
  "name": "本局角色",
  "reactions": {
    "greens": {"mood_delta": -2, "comfort": false}
  }
}
```

解析器校验根节点、格式版本、角色 ID/名称、正整数资料版本、重复 food_id、整数 mood_delta 与显式 true/false。文件缺失、格式不完整、重复条目或未来格式均返回 `{}`，整份失败，不接受前半份资料，也不阻止正常游戏运行。

### 13.2 读取、显示和未知态契约

| 接口 | 行为 |
| --- | --- |
| `default_profile()` | 读取默认角色资料；缓存及返回值相互独立，调用方得到深拷贝 |
| `load_profile(path)` | 显式读取指定 XML；验证失败返回 `{}`，不改用默认角色 |
| `reaction(food_id, profile)` | 返回 profile_id、profile_version、character_name、status、mood_delta、comfort |
| `decorate_food(food, profile)` | 返回食物深拷贝，移除顶层 mood，增加由 reaction 生成的 food_preference |

已配置反应使用 `status="known"`；缺失条目或非法资料使用 `status="unspecified" / mood_delta=0 / comfort=false`。这里的 0 是“本次不施加口味心情效果”的游戏处理，并非推断该食物没有健康影响。显式传入 `{}` 必须保持未设置，绝不从食物旧 mood、favorite/mood 标签或健康资料补造偏好。`MealResolver.build_record` 省略偏好参数时才使用默认角色，以兼容已有调用方。

V1 与 V2 的食物显示和结算读取同一份当局偏好。卡片显示“口味”效果，详情将本局角色口味与食物/健康资料分开；未知时显示“口味未设置”，不把负反应写成“健康食物不好吃”。改变偏好会改变游戏心情与 comfort，不改变 `FoodHealthProfile`。

### 13.3 当局生命周期与历史边界

- V2 的 `set_food_preferences(profile)` 复制输入；在餐次界面更新后刷新展示并关闭旧详情，避免显示上一个角色的反应。外部继续修改原字典不会改变本局偏好。
- 当局偏好跨日保留；重新开始一局时恢复默认角色资料。本轮没有新增角色选择页或偏好事件 UI。
- `record.preference_reactions` 保存每项 food_id 对应的角色 ID、资料版本、名称、known/unspecified 状态、mood_delta 和 comfort，仅用于游戏历史与结算追溯。
- `MealHealthSnapshot` 不包含 food_preference 或 preference_reactions，也不读取口味影响组成、因素、confidence 或健康资料版本。该边界与四个健康开关是否开启无关。
- 行动、睡眠和来源自身的心情效果仍属于原有游戏规则；本次迁移只处理食物口味，不提前拆分 NUT-208 的恢复轨道。

### 13.4 NUT-207 验收结果（2026-09-04）

Godot AI 更新至 3.2.5 后，统一验证 `180/180`、19 个套件通过；偏好数据 `7/7`、流程 `7/7`、UI `9/9`，导出配置回归 `7/7` 已包含在全量内。发布配置静态检查与主场景烟测通过。实际渲染覆盖 `1920×1080`、`720×1280`，分别检查默认青菜、默认沙拉和修改偏好后的青菜，共 6 张截图；文字完整、无越界，`report.json` 的 failures 为空。

验收中已修复详情便签复用旧折行高度导致的越界，以及异步显隐竞态。日志位于 `life-strategy/.godot/logs/nut207-post-upgrade-verification.log`，截图位于 `life-strategy/.godot/nut207-visual/`。本项验收完成；四个健康开关仍关闭，两项到期证据仍待复核，新改动尚未提交、推送、导出或发布。下一步为 NUT-208A 状态矩阵盘点。

### 13.5 NUT-208 恢复状态契约 R2（2026-09-04）

NUT-207 与 Godot AI 3.2.5 升级已包含在本地提交 `f4f0efe`。恢复状态盘点、已确认四档规则 R2 与版本契约见 [08 恢复状态迁移](./08_recovery_state_migration.md)，具体字段与 API 见第 5 节。用户已同意刷手机按实际状态判断、最佳结局不增加恢复门槛；A 完成，B 独立规则/记录/纯迁移接口已完成工程及本地验证，C/D 未实施。未加入生产 state 或健康快照，不能从旧 burden 反转推算新恢复。R1 从未实现，因此运行规则版本仍为 `recovery-gameplay-v1`。

判定器严格只接 `energy/stress/action_counts/sleep_id` 四键；旧 burden、quality、食物/profile 等额外字段被拒绝。`new_run()` 返回默认记录；`settle(day, before_sleep, sleep_snapshot, action_counts, settlement_effects=[])` 推导并冻结睡眠后值、日终值和限幅差量，返回 `{valid, errors, recovery_state}`。完整睡眠与日终效果快照用于独立游戏溯源；历史读取验证结构和算术一致性，不重新判定档位。

独立 envelope 为 `{kind: "gameplay_recovery", gameplay_state_version: 2, recovery_state}`，仅存恢复记录，不含余额、库存、阶段或整局进度。迁移器 `encode(record)` 返回 `{valid, errors, data}`，`load_data(envelope)` 返回 `{status, gameplay_state_version: 2, recovery_state, errors}`，没有磁盘读写或续玩接入。只有可识别旧 stats/day_record 才降级为 `legacy_unknown`；null、任意对象与健康档案不能冒充旧玩法记录。gameplay/recovery 版本与健康档案 schema/model 分开，未来/畸形版本拒绝消费，不改写或补造健康历史。四个健康开关维持关闭，插件保留；本轮不提交或发布。

既有 `MealHealthSnapshot.FORBIDDEN_FIELDS` 增加 `recovery_state/gameplay_state_version/sleep_snapshot/next_day_effect`，防止初始空恢复记录通过额外键进入健康历史。该隔离校验不改变正常用餐快照生成或档案 schema，也不切换当前玩法。

B 本地验证：Godot 4.7.2 全量 217/217、22 套件，含恢复规则 14/14、记录 9/9、迁移 14/14；静态发布配置与主场景烟测通过，日志 `.godot/logs/nut208b-project-verification.log`。9 条真实旧日记录降级通过；A 冻结 JSON 及 14 个生产来源哈希保持一致，无新增 UI 截图。下一步 C 接入生产消费者，M2 尚未整体完成。

## 14. 验收标准

- [x] 23 个卡牌 ID 都有 profile 或明确的缺失白名单（当前 23 项全部为 draft）。
- [ ] 复合菜能追溯到原料 ID，重复食材不会被当成新的多样性。
- [ ] 所有份量、因素和做法都有已知/估算/未知态；不适用的做法显式使用 `not_applicable`。
- [x] 游戏数值修改不会改变 `FoodHealthProfile`。
- [x] 数据错误能在启动或 CI 中定位到文件、food_id 和字段。
- [ ] 旧存档可加载；旧记录显示“历史数据不足”而非伪造结果。
- [x] 玩家确认用餐时保存模型/资料版本快照（NUT-206，data 开关默认关闭）。
- [ ] 专业复核前，草稿资料只生成保守的事实描述。
