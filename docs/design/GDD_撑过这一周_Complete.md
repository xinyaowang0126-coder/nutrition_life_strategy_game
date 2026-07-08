# 《撑过这一周》完整游戏设计文档 (GDD v2.0)

> **文档用途**: 供 AI 编程助手（CodeX、Cursor、Claude Code 等）参考，用于引擎选型、系统架构和具体实现。
> **设计理念**: 本文档采用 **Data-Driven Design**，所有系统均给出具体数值、公式、数据结构和状态转换。

---

## 0. 项目元信息

| 字段 | 值 |
|---|---|
| 项目代号 | `nutrition-life-strategy` |
| 暂定标题 | 《撑过这一周》(Survive the Week) |
| 游戏类型 | 生活策略 + 卡牌构筑 + 资源管理 |
| 目标平台 | iOS / Android / PC (Windows/macOS/Linux) |
| 美术风格 | 2D 手绘/插画风格，暖色调为主 |
| 商业化 | 付费买断制（一次购买，完整体验） |
| 团队规模 | 1-3 人（以个人开发者为主要假想） |
| 引擎推荐 | **Unity 6 LTS (2D URP)** 或备选 **Godot 4.x** |
| 单局时长 | 15-25 分钟（7天模式）/ 30-45 分钟（14天模式） |

---

## 1. 引擎与技术选型

### 1.1 主推荐：Unity 6 LTS + 2D URP

**选择理由：**
- 全平台发布最成熟的方案（iOS/Android/PC/WebGL/Switch 均原生支持）
- 2D 工具链完整（Sprite、Tilemap、UI Toolkit/UGUI）
- 社区和生态巨大，个人开发者容易找到资源和解决方案
- 买断制无需考虑 Unity Runtime Fee（当前政策下个人版免费）
- C# 编码，AI 编程助手训练数据丰富

**技术栈建议：**
| 层次 | 技术 | 说明 |
|---|---|---|
| 引擎 | Unity 6 LTS (6000.x) | 长期支持版本 |
| 渲染 | 2D URP | 2D 通用渲染管线 |
| UI | UI Toolkit | 基于 CSS-like USS，适合响应式多平台 |
| 数据 | ScriptableObject + JSON | SO 存配置，JSON 存存档 |
| 架构 | 轻量 MVC + EventBus | 避免过度工程，适合小团队 |
| 动画 | DOTween (免费) | 2D 动画和 UI 过渡 |
| 本地化 | Unity Localization | 内置本地化支持 |
| 音频 | Unity Audio Mixer | 内置方案 |

### 1.2 备选：Godot 4.x

**选择理由（如果倾向开源）：**
- 完全免费开源，无任何授权费
- 2D 渲染性能优秀，原生 2D 支持好
- 打包体积小，适合移动端
- GDScript 学习门槛低

**权衡：** 社区资源、第三方插件和 AI 训练数据比 Unity 少；主机平台导出不如 Unity 成熟。

### 1.3 本 GDD 的引擎无关性

本文档中所有数值、公式、数据结构、状态机均以**平台无关**的方式描述。实现时可根据所选引擎选择最合适的序列化和架构方式。

---

## 2. 核心游戏循环

### 2.1 宏观循环

```
[主菜单] → [角色选择] → [难度/场景选择] → [进入游戏]
    ↑                                              ↓
    └──── [结局展示] ← [7/14天完成] ← [每日循环 × N]
```

### 2.2 每日循环（状态机）

```
┌──────────────────────────────────────────────────────┐
│                    新的一天开始                        │
│  1. 早晨结算：更新角色状态（睡眠→精力, 昨日→压力等）    │
│  2. 环境事件检查：是否触发生活事件                      │
│  3. 商店/采购阶段：可选，消耗时间和金钱                 │
│  4. 早餐阶段：打出手牌中的食物卡                        │
│  5. 午餐阶段：打出手牌中的食物卡                        │
│  6. 晚餐阶段：打出手牌中的食物卡                        │
│  7. 自由行动阶段：打出手牌中的行为卡/心理卡             │
│  8. 晚间结算：计算当日所有影响，更新指标                │
│  9. 过夜：睡眠结算（早睡/熬夜影响次日状态）             │
└──────────────────────────────────────────────────────┘
```

### 2.3 单日详细交互流程

```
STEP 1: 早晨简报 (5秒自动播放)
  - 显示 "第 X 天 / 共 N 天"
  - 显示当日生活事件（如有）
  - 显示角色状态摘要

STEP 2: 采购阶段 (可选，可跳过)
  - 玩家可以从商店购买食材/食物卡
  - 消耗：金钱 + 1 个时间格
  - 获得：食材卡进入手牌

STEP 3: 进餐阶段 (早餐/午餐/晚餐，共3轮)
  每轮：
  - 从手牌中选择 1 张食物卡打出（必须，可跳过但受到惩罚）
  - 可选：再打 1 张副食物卡（如饮品、水果、零食）
  - 打出后立即结算该餐的即时效果
  - 检查餐盘组合（Combo）并触发额外效果

STEP 4: 自由行动阶段 (2-3 个行动格)
  - 从手牌中选择行为卡/心理卡打出
  - 每张卡消耗 1 个行动格
  - 行动格用完或主动结束

STEP 5: 晚间结算 (3秒自动)
  - 结算当天所有指标变化
  - 显示 "今日状态" 摘要
  - 睡眠选择：早睡 / 普通 / 熬夜
    - 早睡：牺牲所有剩余行动格，次日精力大幅恢复
    - 普通：正常睡觉
    - 熬夜：额外获得 1 个深夜行动格，但次日精力惩罚

STEP 6: 过夜
  - 根据睡眠选择更新次日精力
  - 检查是否有夜间事件触发
  - 进入下一天
```

---

## 3. 完整数据模型

### 3.1 枚举定义

```csharp
// 角色类型
enum CharacterType {
    SleepDeprivedStudent,    // 熬夜学生/研究生
    OvertimeWorker,           // 加班上班族
    DietingWorker,            // 减脂上班族
    FitnessStudent,           // 健身大学生
    EmotionalEater,           // 情绪性进食者
    // 以下为后续解锁
    SolitaryYouth,            // 独居青年
    HypertensiveMiddleAged,   // 高血压中年人
    VeganBeginner,            // 素食新手
    ElderlyLivingAlone        // 独居老人
}

// 卡牌类型
enum CardType {
    Food,       // 食物卡
    Action,     // 行为卡
    Psycho       // 心理卡
}

// 食物卡子类型
enum FoodSubType {
    Staple,       // 主食
    Protein,      // 蛋白
    Vegetable,    // 蔬菜
    Fruit,        // 水果
    Drink,        // 饮品
    Snack,        // 零食/甜食
    FastFood,     // 快餐/外卖
    Instant,      // 速食/方便食品
    LightMeal     // 轻食/沙拉
}

// 行动卡子类型
enum ActionSubType {
    Study,        // 学习/复习
    Work,         // 工作/加班
    Exercise,     // 运动/训练
    Rest,         // 休息/小睡
    Social,       // 社交/聚餐
    Shopping,     // 采购/购物
    Cooking,      // 做饭/备餐
    SelfCare      // 自我照顾/散步等
}

// 心理卡子类型
enum PsychoSubType {
    SelfCompassion,    // 自我接纳
    StressRelief,      // 压力缓解
    HabitAnchor,       // 习惯锚定
    Reframe            // 认知重构
}

// 餐盘组合类型
enum MealComboType {
    Balanced,         // 均衡餐盘
    HighFiber,        // 高纤维组合
    HighProtein,      // 高蛋白组合
    ComfortMeal,      // 安慰餐
    BudgetHealthy,    // 省钱健康餐
    TakeoutRecovery,  // 外卖补救
    QuickFill,        // 快速饱腹
    VeggieHeavy       // 蔬果为主
}

// 生活事件类型
enum LifeEventType {
    FoodDeliveryPromo,   // 外卖优惠
    ExamWeek,            // 考试周
    OvertimeWeek,        // 加班周
    TightBudget,         // 预算紧张
    SocialInvitation,    // 聚餐邀请
    EmotionalLow,        // 情绪低谷
    EmptyFridge,         // 冰箱清空
    GoodWeather,         // 天气好（正面）
    PayDay,              // 发薪日（正面）
    FreeFood             // 免费食物（正面）
}

// 结局类型
enum EndingType {
    StableEndurance,     // 稳稳撑过
    BarelySurvived,      // 勉强撑过
    HealthyButBurnedOut, // 吃得健康但心态崩了
    HappyButUnhealthy,   // 心情不错但身体负担高
    FinanciallySafeButRunDown, // 预算撑住但状态不好
    Collapsed            // 没撑住
}
```

### 3.2 核心数据结构

#### 3.2.1 角色配置 (CharacterConfig)

```json
{
  "id": "sleep_deprived_student",
  "type": "SleepDeprivedStudent",
  "nameKey": "char_student_name",
  "descriptionKey": "char_student_desc",
  "unlockCondition": "default",
  "baseStats": {
    "stability": 65,
    "balance": 120,
    "timeSlots": 4,
    "energy": 50,
    "mood": 55,
    "satiety": 60,
    "stress": 55,
    "dietBurden": 25,
    "sleepQuality": 30,
    "selfControl": 60,
    "dietAnxiety": 20
  },
  "stabilityWeights": {
    "dietQuality": 0.20,
    "mentalState": 0.25,
    "energyState": 0.15,
    "sleepState": 0.15,
    "dietBurdenControl": 0.05,
    "goalProgress": 0.15,
    "budgetSafety": 0.05
  },
  "goalMetricKey": "study_progress",
  "goalTarget": 100,
  "availableActions": [
    "study", "cafeteria", "order_takeout",
    "buy_bubble_tea", "convenience_store", "instant_food",
    "nap", "sleep_early", "walk", "drink_water"
  ],
  "restrictedActions": ["complex_cooking", "bulk_shopping", "meal_prep"],
  "foodPreferences": {
    "favorite": ["bubble_tea", "instant_noodles", "fried_chicken"],
    "disliked": ["salad", "plain_vegetables"]
  },
  "stressThresholdLow": 30,
  "stressThresholdHigh": 75
}
```

#### 3.2.2 运行时角色状态 (RuntimeCharacterState)

```json
{
  "characterId": "sleep_deprived_student",
  "day": 1,
  "totalDays": 7,
  "stats": {
    "stability": {"current": 65, "max": 100, "min": 0},
    "balance": {"current": 120, "max": 200, "min": 0},
    "timeSlots": {"current": 4, "max": 5, "min": 0},
    "energy": {"current": 50, "max": 100, "min": 0},
    "mood": {"current": 55, "max": 100, "min": 0},
    "satiety": {"current": 60, "max": 100, "min": 0},
    "stress": {"current": 55, "max": 100, "min": 0},
    "dietBurden": {"current": 25, "max": 100, "min": 0},
    "sleepQuality": {"current": 30, "max": 100, "min": 0},
    "selfControl": {"current": 60, "max": 100, "min": 0},
    "dietAnxiety": {"current": 20, "max": 100, "min": 0}
  },
  "goalProgress": {
    "metricKey": "study_progress",
    "current": 0,
    "target": 100,
    "perDayRequirement": 14
  },
  "todayMeals": [], // 当天打出的食物卡记录
  "todayActions": [], // 当天打出的行为卡记录
  "activeEffects": [], // 当前作用的持续效果(Buff/Debuff)
  "mealHistory": [], // 过去几餐的简要记录（用于检测饮食模式）
  "comboHistory": [] // 本局触发过的组合记录（用于图鉴）
}
```

#### 3.2.3 卡牌配置 (CardConfig)

```json
// 食物卡示例
{
  "id": "rice_plain",
  "type": "Food",
  "subType": "Staple",
  "nameKey": "card_rice_name",
  "descriptionKey": "card_rice_desc",
  "rarity": "common",
  "cost": 2,
  "baseEffects": {
    "time": 0,
    "energy": 0,
    "satiety": 25,
    "mood": 0,
    "dietBurden": 0,
    "stress": 0
  },
  "hiddenNutrition": {
    "energyKcal": 200,
    "protein": 4,
    "fatBurden": 0,
    "sugarBurden": 0,
    "fiber": 1,
    "sodiumBurden": 0
  },
  "tags": ["staple", "cheap", "plain"],
  "isIngredient": true,
  "shelfLife": -1 // -1 表示不会过期
}

// 行为卡示例
{
  "id": "take_nap",
  "type": "Action",
  "subType": "Rest",
  "nameKey": "card_nap_name",
  "descriptionKey": "card_nap_desc",
  "rarity": "common",
  "cost": 0,
  "baseEffects": {
    "time": 1,
    "energy": 18,
    "mood": 0,
    "satiety": 0,
    "dietBurden": 0,
    "stress": -8
  },
  "requirements": {
    "minEnergy": 0,
    "maxStress": 100,
    "excludedByEvents": []
  },
  "tags": ["rest", "recovery"]
}

// 心理卡示例
{
  "id": "allow_imperfection",
  "type": "Psycho",
  "subType": "SelfCompassion",
  "nameKey": "card_allow_imperfection_name",
  "descriptionKey": "card_allow_imperfection_desc",
  "rarity": "uncommon",
  "cost": 0,
  "baseEffects": {
    "time": 0,
    "energy": 0,
    "mood": 5,
    "satiety": 0,
    "dietBurden": 0,
    "stress": -5,
    "dietAnxiety": -12,
    "selfControl": 8
  },
  "triggerCondition": "after_unhealthy_meal",
  "oneTimeUse": true,
  "tags": ["self_compassion", "anxiety_relief"]
}
```

#### 3.2.4 餐盘组合配置 (ComboConfig)

```json
{
  "id": "balanced_meal",
  "type": "Balanced",
  "nameKey": "combo_balanced_name",
  "descriptionKey": "combo_balanced_desc",
  "requiredTags": {
    "mustHave": [
      {"tag": "staple", "count": 1},
      {"tag": "protein", "count": 1},
      {"tag": "vegetable_or_fruit", "count": 1}
    ],
    "mustNotHave": []
  },
  "effects": {
    "stability": 5,
    "satiety": 10,
    "mood": 3,
    "dietQualityBonus": 8
  },
  "visualEffect": "balanced_plate_vfx",
  "unlockCondition": null
}

// 另一个示例
{
  "id": "comfort_meal",
  "type": "ComfortMeal",
  "nameKey": "combo_comfort_name",
  "descriptionKey": "combo_comfort_desc",
  "requiredTags": {
    "mustHave": [
      {"tag": "favorite_food", "count": 1},
      {"tag": "staple_or_protein", "count": 1}
    ],
    "mustNotHave": []
  },
  "effects": {
    "stability": 3,
    "satiety": 5,
    "mood": 15,
    "dietAnxiety": -10,
    "dietBurden": 3
  },
  "visualEffect": "comfort_glow_vfx",
  "unlockCondition": null
}
```

#### 3.2.5 生活事件配置 (LifeEventConfig)

```json
{
  "id": "food_delivery_promo",
  "type": "FoodDeliveryPromo",
  "nameKey": "event_delivery_promo_name",
  "descriptionKey": "event_delivery_promo_desc",
  "durationDays": 3,
  "triggerType": "random",
  "triggerWeight": 15,
  "minDay": 2,
  "modifiers": {
    "foodCategoryDiscount": {
      "category": "FastFood",
      "discountPercent": 30
    },
    "cardAppearRate": {
      "cardTag": "takeout",
      "multiplier": 2.0
    },
    "statModifiers": {
      "selfControl": -10,
      "dietBurden": 3 // per day
    }
  },
  "narrativeTextKey": "event_delivery_promo_narrative",
  "visualEffect": "phone_notification_vfx"
}
```

#### 3.2.6 结局条件配置 (EndingConfig)

```json
{
  "id": "stable_endurance",
  "type": "StableEndurance",
  "nameKey": "ending_stable_name",
  "descriptionKey": "ending_stable_desc",
  "priority": 1, // 优先级，数字越小越优先判定
  "conditions": {
    "allOf": [
      {"stat": "stability", "op": ">=", "value": 60},
      {"stat": "goalProgress", "op": ">=", "value": 70}
    ],
    "noneOf": [
      {"stat": "mood", "op": "<", "value": 20},
      {"stat": "dietBurden", "op": ">", "value": 70}
    ]
  },
  "endingTextKey": "ending_stable_text",
  "endingIllustration": "ending_stable_illustration"
}
```

---

## 4. 完整公式系统

### 4.1 稳定度 (Stability) — 核心HP

稳定度是游戏的"生命值"，由多个底层因素复合得出。它是实时计算的，不是存储值。

```
stability = CLAMP(0, rawStability, 100)

rawStability =
    dietState        × dietQualityWeight
  + mentalState      × mentalStateWeight
  + energyState      × energyStateWeight
  + sleepState       × sleepStateWeight
  + dietBurdenControl × dietBurdenControlWeight
  + goalProgressPct  × goalProgressWeight
  + budgetSafety     × budgetSafetyWeight

// 其中各子项的计算：

dietState = 100 - avg_last_3_meals_burden × 0.6
          + meals_with_veggie_count × 5
          + (consecutiveBalancedDays × 3)
// clamped to [0, 100]

mentalState = ((mood.current × 0.5) + ((100 - stress.current) × 0.5))
// 直接使用心情和压力的加权平均

energyState = energy.current
// 直接使用精力值

sleepState = sleepQuality.current
// 直接使用睡眠质量值

dietBurdenControl = 100 - dietBurden.current
// 饮食负担越低越好

goalProgressPct = (goalProgress.current / goalProgress.target) × 100
// 目标进度百分比

budgetSafety = CLAMP(0, (balance.current / (remainingDays × dailyMinimumSpend)) × 100, 100)
// dailyMinimumSpend 默认 = 10（每天最低伙食费）
// 如果余额 >= 剩余天数 × 最低消费，则为 100
// 如果余额 = 0，则为 0
```

**不同角色的权重配置：**

| 角色 | dietQuality | mentalState | energyState | sleepState | dietBurden | goalProgress | budgetSafety |
|---|---|---|---|---|---|---|---|
| 熬夜学生 | 0.20 | 0.25 | 0.15 | **0.15** | 0.05 | **0.15** | 0.05 |
| 加班上班族 | 0.15 | 0.20 | **0.25** | 0.10 | 0.10 | **0.15** | 0.05 |
| 减脂上班族 | **0.25** | **0.25** | 0.10 | 0.10 | **0.15** | 0.05 | 0.10 |
| 健身大学生 | **0.20** | 0.15 | **0.20** | 0.10 | 0.10 | **0.15** | 0.10 |
| 情绪性进食者 | 0.15 | **0.30** | 0.15 | 0.10 | 0.10 | 0.10 | 0.10 |

### 4.2 短板惩罚机制

如果任意关键指标低于阈值，稳定度会受到额外惩罚，防止"平均化"：

```
短板惩罚表：
  energy < 15:        stability -= 15, 显示 "精力严重不足"
  mood < 15:          stability -= 15, 显示 "情绪濒临崩溃"
  satiety < 10:       stability -= 10, 显示 "极度饥饿"
  stress > 90:        stability -= 15, 显示 "压力即将爆表"
  sleepQuality < 15:  stability -= 10, 显示 "睡眠严重不足"
  balance < dailyMinimumSpend × 2: stability -= 10, 显示 "经济危机"

// 多个短板可叠加，但总惩罚不超过 30
```

### 4.3 每日状态转换公式

#### 早晨起床结算

```
// 从昨晚的睡眠选择计算今日精力
sleepChoice → nextDayEnergy:
  早睡: energy += 35 + sleepQuality.current × 0.3
  普通: energy += 20 + sleepQuality.current × 0.2
  熬夜: energy += 5  + sleepQuality.current × 0.1

// 睡眠质量更新
sleepQuality += (sleepChoice == 早睡 ? 15 : (sleepChoice == 普通 ? 0 : -15))
// clamped to [0, 100]

// 每日压力自然增长（基础值）
stress += 3

// 如果前一天有高糖/高油餐，次日精力额外惩罚
if yesterdayHighSugarCount >= 2: energy -= 8
if yesterdayHighFatCount >= 2: energy -= 5
```

#### 每餐结算

```
// 打出食物卡后即时结算
satiety += card.satietyEffect
mood += card.moodEffect
dietBurden += card.dietBurdenEffect

// 角色偏好修正
if card.id in character.foodPreferences.favorite:
    mood += 5
    // 暗示更容易选择这类食物
if card.id in character.foodPreferences.disliked:
    mood -= 3

// 饱腹感超时惩罚
if satiety > 90:
    dietBurden += 3  // 暴饮暴食
    stability -= 2

// 饱腹感过低惩罚
if satiety < 15:
    stress += 5
    if character.type == EmotionalEater:
        // 冲动进食风险上升
        impulseRisk += 15
```

#### 晚间结算

```
// 计算今日饮食结构
todayVeggieCount = count of vegetable/fruit cards played today
todayProteinCount = count of protein cards played today
todayStapleCount = count of staple cards played today
todayHighSugarCount = count of high-sugar cards played today
todayHighFatCount = count of high-fat cards played today
todayMealCount = count of meals today (should be ~3)

// 饮食状态滚动评估
dietQualityTrend = weighted average of:
  40%: today's diet quality score
  35%: yesterday's diet quality score
  25%: day-before-yesterday's diet quality score

// 压力累积
if goalProgress.current < goalProgress.perDayRequirement * day:
    stress += 8  // 进度落后

// 预算压力
if balance.current < remainingDays * dailyMinimumSpend * 1.5:
    stress += 5

// 自控力自然恢复（每天少量）
selfControl += 5
// 但如果前一天压力 > 80，恢复减半
if yesterdayStress > 80: selfControl += 2
```

### 4.4 组合检测逻辑

```
// 每餐打出食物卡后，检测是否触发组合
function checkCombos(mealCards, character):
    combos = []

    for combo in allCombos:
        tagsInMeal = flatten(mealCards.map(tags))
        if satisfiesRequirements(tagsInMeal, combo.requiredTags):
            combos.append(combo)
            applyComboEffects(combo)

    // 多个组合可以同时触发
    // 但同类型组合每天最多触发一次
    return combos

// 需求检测示例
function satisfiesRequirements(tagsInMeal, requiredTags):
    for req in requiredTags.mustHave:
        count = tagsInMeal.filter(tag matches req.tag)
        if count < req.count: return false
    for req in requiredTags.mustNotHave:
        if tagsInMeal.contains(req.tag): return false
    return true
```

---

## 5. 完整卡牌库

### 5.1 食物卡（共 30 张初始 + 可扩展）

#### 主食类 (Staple)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rice_plain | 白米饭 | 2 | 25 | 0 | 0 | 200 | 4 | 0 | 0 | 1 | 0 | staple,cheap,plain | -1 |
| brown_rice | 糙米饭 | 4 | 30 | 0 | 0 | 220 | 5 | 0 | 0 | 4 | 0 | staple,whole_grain,fiber | -1 |
| oatmeal | 燕麦 | 3 | 32 | 0 | 0 | 180 | 6 | 0 | 0 | 5 | 0 | staple,whole_grain,fiber,cheap | 14 |
| bread_white | 面包 | 3 | 18 | 2 | 1 | 160 | 5 | 2 | 3 | 1 | 2 | staple,quick | 5 |
| noodles_plain | 素面 | 3 | 22 | 0 | 0 | 180 | 4 | 0 | 0 | 1 | 1 | staple,cheap | -1 |
| potato | 土豆 | 2 | 28 | 0 | 0 | 160 | 3 | 0 | 0 | 3 | 0 | staple,cheap,vegetable | 14 |

#### 蛋白类 (Protein)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| egg | 鸡蛋 | 2 | 18 | 0 | 0 | 80 | 7 | 3 | 0 | 0 | 1 | protein,cheap,versatile | 14 |
| tofu | 豆腐 | 3 | 20 | 0 | 0 | 80 | 8 | 2 | 0 | 1 | 0 | protein,cheap,vegetable | 7 |
| chicken_breast | 鸡胸肉 | 8 | 28 | -2 | 0 | 140 | 30 | 2 | 0 | 0 | 1 | protein,lean,fitness | 5 |
| fish | 鱼 | 10 | 25 | 0 | 0 | 130 | 22 | 4 | 0 | 0 | 2 | protein,healthy_fat | 3 |
| pork_stir_fry | 炒肉片 | 7 | 26 | 5 | 4 | 250 | 18 | 12 | 1 | 0 | 5 | protein,tasty,high_fat | 3 |
| milk | 牛奶 | 4 | 15 | 3 | 1 | 120 | 7 | 4 | 6 | 0 | 1 | protein,drink,calcium | 7 |

#### 蔬菜类 (Vegetable)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| greens | 青菜 | 3 | 10 | -2 | 0 | 30 | 3 | 0 | 0 | 4 | 1 | vegetable,fiber,plain | 4 |
| tomato | 番茄 | 3 | 8 | 3 | 0 | 25 | 1 | 0 | 3 | 2 | 0 | vegetable,fruit_like | 5 |
| broccoli | 西兰花 | 5 | 12 | -1 | 0 | 35 | 4 | 0 | 0 | 3 | 0 | vegetable,fiber,fitness | 5 |
| mixed_veggie | 混合蔬菜 | 6 | 12 | 0 | 0 | 40 | 3 | 0 | 2 | 4 | 1 | vegetable,fiber,convenient | 4 |
| cucumber | 黄瓜 | 2 | 6 | 1 | 0 | 16 | 1 | 0 | 0 | 1 | 0 | vegetable,cheap,plain | 5 |

#### 水果类 (Fruit)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| apple | 苹果 | 3 | 14 | 5 | 0 | 80 | 0 | 0 | 10 | 5 | 0 | fruit,fiber,mood | 10 |
| banana | 香蕉 | 3 | 18 | 5 | 0 | 100 | 1 | 0 | 8 | 3 | 0 | fruit,energy,mood | 5 |
| orange | 橙子 | 4 | 12 | 6 | 0 | 60 | 1 | 0 | 6 | 5 | 0 | fruit,vitamin,mood | 10 |
| berries | 莓果 | 8 | 8 | 8 | 0 | 50 | 1 | 0 | 4 | 8 | 0 | fruit,premium,antioxidant | 3 |

#### 饮品/甜食 (Drink/Snack)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bubble_tea | 奶茶 | 15 | 8 | 18 | 8 | 300 | 3 | 8 | 35 | 0 | 1 | drink,snack,high_sugar,mood,student_fav | -1 |
| coffee | 咖啡 | 8 | 2 | 5 | 1 | 20 | 1 | 0 | 0 | 0 | 0 | drink,energy,work | -1 |
| green_tea | 绿茶 | 3 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | drink,antioxidant,plain | -1 |
| soda | 汽水 | 5 | 2 | 8 | 6 | 140 | 0 | 0 | 35 | 0 | 1 | drink,high_sugar,snack | -1 |
| chocolate | 巧克力 | 8 | 10 | 12 | 5 | 220 | 3 | 12 | 18 | 1 | 0 | snack,high_sugar,high_fat,mood | 30 |
| chips | 薯片 | 6 | 8 | 10 | 7 | 250 | 3 | 14 | 2 | 1 | 8 | snack,high_fat,high_sodium,mood | 30 |

#### 外卖/快餐 (FastFood)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fried_chicken | 炸鸡 | 25 | 32 | 20 | 12 | 500 | 28 | 28 | 3 | 1 | 15 | fastfood,high_fat,high_sodium,tasty,student_fav | -1 |
| burger_set | 汉堡套餐 | 30 | 35 | 15 | 12 | 650 | 25 | 30 | 25 | 2 | 18 | fastfood,high_fat,high_sugar,high_sodium | -1 |
| pizza | 披萨 | 28 | 30 | 16 | 10 | 550 | 20 | 22 | 8 | 2 | 14 | fastfood,high_fat,tasty,social | -1 |
| salad_bowl | 沙拉碗 | 28 | 20 | -3 | 0 | 280 | 20 | 8 | 4 | 8 | 4 | light_meal,healthy,expensive | -1 |
| sandwich | 三明治 | 15 | 25 | 3 | 2 | 350 | 15 | 10 | 4 | 3 | 8 | fastfood,convenient,moderate | -1 |

#### 速食/方便食品 (Instant)

| ID | 名称 | 花费(¥) | 饱腹 | 心情 | 饮食负担 | 能量(kcal) | 蛋白(g) | 油脂 | 糖分 | 纤维 | 钠 | 标签 | 保质期 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| instant_noodles | 方便面 | 4 | 24 | 8 | 9 | 380 | 8 | 16 | 2 | 1 | 22 | instant,cheap,high_sodium,high_fat,student_fav | 180 |
| instant_porridge | 速食粥 | 5 | 20 | 2 | 4 | 180 | 4 | 3 | 3 | 1 | 12 | instant,cheap,moderate | 180 |
| frozen_dumpling | 速冻饺子 | 8 | 26 | 6 | 3 | 320 | 14 | 10 | 2 | 2 | 8 | instant,convenient,moderate | 90 |
| protein_bar | 蛋白棒 | 12 | 18 | 1 | 2 | 200 | 20 | 5 | 8 | 5 | 2 | instant,protein,fitness | 180 |

### 5.2 行为卡（共 18 张）

| ID | 名称 | 子类型 | 花费(¥) | 时间 | 精力 | 效果 | 条件 |
|---|---|---|---|---|---|---|---|
| study | 复习 | Study | 0 | 1 | 1 | studyProgress +12, stress +4 | 仅学生角色 |
| work_overtime | 加班 | Work | 0 | 1 | 2 | projectProgress +12, stress +6, fatigue +4 | 仅上班族角色 |
| go_cafeteria | 去食堂 | Shopping | -5 | 1 | 1 | 获得2张随机食堂食物卡（中低价位） | — |
| order_takeout | 点外卖 | Shopping | -20 | 0 | 0 | 获得1张自选外卖卡, mood+3 | 花费为平均 |
| grocery_shop | 买菜 | Shopping | -15 | 1 | 1 | 获得3张随机食材卡 | 学生受限 |
| simple_cook | 简单做饭 | Cooking | 0 | 1 | 1 | 消耗食材卡, dietQuality+10, satiety+5 | 需要食材卡 |
| bulk_cook | 备餐 | Cooking | 0 | 2 | 2 | 消耗3张食材卡, 获得3张成品食物卡(成本低) | 需要食材卡; 学生受限 |
| convenience_store | 便利店 | Shopping | -10 | 0 | 0 | 获得1张随机速食/零食卡 | — |
| exercise | 运动 | Exercise | 0 | 1 | 2 | stress -10, fatigue +5, dietBurden -3 | — |
| workout | 训练 | Exercise | 0 | 1 | 3 | stress -8, fatigue +8, trainingProgress +10, 蛋白需求+1 | 仅健身角色 |
| walk | 散步 | SelfCare | 0 | 1 | 0 | stress -6, mood +3 | — |
| nap | 小睡 | Rest | 0 | 1 | 0 | energy +18, stress -5 | energy < 60 效果减半 |
| sleep_early | 早睡 | Rest | 0 | 1 | 0 | 次日 energy +35, stress -10, sleepQuality +15 | 放弃所有剩余行动格 |
| social_dinner | 聚餐 | Social | -25 | 1 | 0 | mood +15, stress -8, dietBurden +8 | — |
| call_friend | 联系朋友 | Social | 0 | 1 | 0 | mood +8, stress -6 | — |
| drink_water | 喝水 | SelfCare | 0 | 0 | 0 | dietBurden -2, satiety +3 | 每天可使用2次, 免费无时间消耗 |
| meditate | 心理调节 | SelfCare | 0 | 1 | 0 | stress -10, selfControl +8, dietAnxiety -8 | — |
| weigh_self | 称体重 | SelfCare | 0 | 0 | 0 | 获得体重反馈, dietAnxiety ±5(随机) | 仅减脂角色 |

### 5.3 心理卡（共 12 张）

| ID | 名称 | 子类型 | 花费(¥) | 时间 | 效果 | 触发条件 | 一次性 |
|---|---|---|---|---|---|---|---|
| allow_imperfection | 允许不完美 | SelfCompassion | 0 | 0 | dietAnxiety -12, stress -5, mood +5 | 打出一张高负担食物后 | 是 |
| one_meal_not_define | 不用一顿饭定义自己 | SelfCompassion | 0 | 0 | 抵消本次饮食失控的心理惩罚, dietAnxiety -10 | 饮食负担单餐 > 8 后 | 是 |
| stability_over_extreme | 稳定比极端重要 | HabitAnchor | 0 | 0 | 若今天三餐均无极端失衡, stability +8 | 每日结束前自动检测 | 否 |
| today_worked_hard | 今天已经很努力了 | SelfCompassion | 0 | 0 | stress -10, selfControl +8, mood +5 | 完成目标相关行动后 | 否 |
| good_solid_meal | 好好吃一顿正餐 | HabitAnchor | 0 | 0 | 若本餐含主食+蛋白+蔬果, mood+8, stability+5 | 打出3类食物后 | 否 |
| small_joys_matter | 小确幸也重要 | StressRelief | 0 | 0 | 本回合若吃到喜欢的食物, mood额外+5, stress -3 | 打出偏好食物后 | 否 |
| plan_for_tomorrow | 明天是新的一天 | Reframe | 0 | 0 | stress -8, 次日自控力恢复+5 | 状态差的日子结束前 | 是 |
| listen_to_body | 听听身体的声音 | HabitAnchor | 0 | 0 | 若饱腹感<15, 提醒进食; 若饱腹感>90, 提醒停止 | 极端饱腹状态时 | 否 |
| food_is_not_enemy | 食物不是敌人 | SelfCompassion | 0 | 0 | dietAnxiety -15, mood +8 | dietAnxiety > 60 时 | 否 |
| progress_not_perfect | 追求进步而非完美 | Reframe | 0 | 0 | 今日饮食状态较昨日有所改善时, stability +8 | 饮食状态连续改善 | 否 |
| rest_is_productive | 休息也是生产力 | Reframe | 0 | 0 | stress -8, selfControl +5, 消除"休息=浪费"的罪恶感 | 选择休息行动后 | 否 |
| reach_out | 你不是一个人 | SelfCompassion | 0 | 0 | stress -12, mood +10 | 压力 > 75 且社交行动可用时 | 否 |

---

## 6. 完整组合/牌型系统

### 6.1 组合定义

| ID | 名称 | 需求 | 即时效果 | 延迟效果 |
|---|---|---|---|---|
| balanced_meal | 均衡餐盘 | staple≥1, protein≥1, veggie_or_fruit≥1 | satiety+10, mood+3, stability+5 | dietQuality+8 |
| high_fiber | 高纤维组合 | whole_grain≥1, (veggie≥1 OR fruit≥1 OR legume≥1) | satiety+8 | 下一餐冲动进食风险-20% |
| high_protein | 高蛋白组合 | protein≥2, proteinQuality="lean" | satiety+12 | 训练恢复+15% (仅健身角色) |
| comfort_meal | 安慰餐 | favorite_food≥1, staple_or_protein≥1 | mood+15, dietAnxiety-10, stability+3, dietBurden+3 | 对下一餐的控制力不惩罚 |
| budget_healthy | 省钱健康餐 | totalCost≤8, staple≥1, (protein≥1 OR veggie≥1) | satiety+8, stability+4 | budgetStress-5 |
| takeout_recovery | 外卖补救 | 上餐是 high_burden, 本餐含 fruit≥1 OR veggie≥1 OR drink_water | dietBurden-4, mood+3, stability+3 | 降低后续失控风险 |
| quick_fill | 快速饱腹 | instantFood=1, totalPrepTime=0 | satiety+15, time+1(返还) | dietBurden+2 (代价) |
| veggie_heavy | 蔬果为主 | veggie_or_fruit≥3 | dietQuality+12, dietBurden-5, mood-2 | fiberBonus+2天 |
| drink_balance | 饮品平衡 | high_sugar_drink=1, staple_or_protein≥1 | mood+8, 单独喝奶茶的 sugarCrash 被抵消 | dietBurden 惩罚减半 |

### 6.2 连续奖励

```
// 连续天数奖励
consecutiveBalancedMealDays:
  连续1天: 无额外奖励
  连续2天: stability +2/天
  连续3天: stability +4/天, dietQuality额外+3/天
  连续5天: stability +6/天, 解锁心理卡 "形成习惯的喜悦"
  连续7天: stability +8/天, 解锁成就 "节奏大师"

// 但注意：连续极端控制也有惩罚
consecutiveOverControlledDays (饮食焦虑或过度节食):
  连续2天: mood -3/天
  连续3天: dietAnxiety +5/天, 冲动进食风险 +15%
  连续4天: 自动触发 "暴食风险" 事件
```

---

## 7. 角色完整设定

### 7.1 角色一：熬夜学生 (SleepDeprivedStudent)

```
名称: 小林 / "明天考试今天才开始复习的人"
处境: 研究生/大学生，考试周临近，论文deadline在即

初始状态:
  stability: 65, balance: 120, timeSlots: 4
  energy: 50, mood: 55, satiety: 60
  stress: 55, dietBurden: 25, sleepQuality: 30
  selfControl: 60, dietAnxiety: 20

目标: studyProgress 0 → 100 (7天)
每日最低进度要求: 14

偏好食物:
  喜欢: bubble_tea, instant_noodles, fried_chicken (心情+5)
  不喜欢: salad, plain_vegetables (心情-3)

专属技能:
  "深夜冲刺": 熬夜时 studyProgress 额外+5
  "咖啡依赖": coffee 效果翻倍，但连续3天喝咖啡后效果减半

专属困境:
  睡眠是最大短板 (sleepQuality 权重 0.15)
  复习进度落后时压力累积加速
  奶茶和外卖出现率 +30%

可用行动: [study, cafeteria, order_takeout, buy_bubble_tea, 
           convenience_store, instant_food, nap, sleep_early, 
           walk, drink_water]
受限行动: [complex_cooking, bulk_shopping, meal_prep]

7天剧情节拍:
  Day 1: "打开复习计划，发现时间根本不够用..."
  Day 3: "外卖满减券和复习压力同时到达"
  Day 5: "第一次意识到自己不能只靠奶茶硬撑"
  Day 7: 根据结局走向不同结束语
```

### 7.2 角色二：加班上班族 (OvertimeWorker)

```
名称: 张哥 / "项目还有两周上线"
处境: 互联网/科技公司，项目deadline前的高强度工作期

初始状态:
  stability: 60, balance: 200, timeSlots: 3
  energy: 45, mood: 50, satiety: 55
  stress: 60, dietBurden: 35, sleepQuality: 35
  selfControl: 55, dietAnxiety: 15

目标: projectProgress 0 → 100 (14天)
每日最低进度要求: 7

偏好食物:
  喜欢: coffee, fried_chicken, beer(若有), burger_set (mood+5)
  不喜欢: plain_vegetables (心情-2)

专属技能:
  "职场社交": 聚餐应酬获得额外项目进度(+3)
  "公司食堂": cafeteria 价格 -30%

专属困境:
  时间是最大短板 (timeSlots 只有 3 而非 4)
  加班和休息是核心矛盾
  疲劳高时做饭成本翻倍

可用行动: [work_overtime, company_cafeteria, order_takeout, 
           grocery_shop, simple_cook, exercise, sleep_early,
           social_dinner, drink_water]
受限行动: [study, workout, bulk_cook]

14天剧情节拍:
  Day 1: "项目倒计时开始，leader说'这版必须上线'"
  Day 5: "连续加班后开始靠外卖续命"
  Day 9: "身体发出警告信号，但进度还差很多"
  Day 14: 项目上线日 + 结局
```

### 7.3 角色三：减脂上班族 (DietingWorker)

```
名称: 小王 / "这次一定要瘦下来"
处境: 上班族，正在执行减脂计划，但夹在工作和饮食控制之间

初始状态:
  stability: 55, balance: 180, timeSlots: 4
  energy: 50, mood: 45, satiety: 45
  stress: 50, dietBurden: 20, sleepQuality: 50
  selfControl: 70, dietAnxiety: 55

目标: 维持饮食稳定 14天 (隐含目标，不直接显示数字)
每日无硬性进度要求，但需要维持饮食和生活平衡

偏好食物:
  喜欢: salad_bowl, chicken_breast, green_tea (mood+3)
  但 secretly 也喜欢: chocolate, bubble_tea, cake (mood+8, 但dietAnxiety+10)

专属技能:
  "饮食知识": 能看到食物卡的隐藏营养信息 (其他角色看不到)
  "计划补偿": 控制饮食一天后，次日意志力+10

专属困境:
  饮食焦虑是核心指标，过高触发 "反弹" 事件
  连续低热量饮食会导致精力下降和暴食风险
  称体重可能导致焦虑波动
  在"控制"和"崩溃"之间找到平衡是核心挑战

可用行动: [regular_meal, control_diet, order_light_meal, 
           weigh_self, light_exercise, eat_favorite_food, 
           social_dinner, meditate, walk, drink_water]
受限行动: [work_overtime (疲劳+工作压力)]

14天剧情节拍:
  Day 1: "新计划第一天，充满决心"
  Day 4: "第一次称体重，数字不如预期"
  Day 7: "加班+聚餐，计划被打乱，开始焦虑"
  Day 10: "可能已经经历了一次反弹"
  Day 14: "对'健康'有了新的理解"
```

### 7.4 角色四：健身大学生 (FitnessStudent)

```
名称: 阿健 / "增肌还是减脂，这是个问题"
处境: 大学生，认真健身，但预算有限，学业和训练需要平衡

初始状态:
  stability: 60, balance: 150, timeSlots: 4
  energy: 65, mood: 55, satiety: 50
  stress: 40, dietBurden: 15, sleepQuality: 55
  selfControl: 65, dietAnxiety: 30

目标: trainingRecovery 维持在 60 以上（14天）
训练日和恢复日的平衡

偏好食物:
  喜欢: chicken_breast, egg, banana, protein_bar (mood+4)
  不喜欢: instant_noodles, soda (mood-3)

专属技能:
  "训练知识": 能看到食物的蛋白质数值（其他角色看不到）
  "代谢优势": 运动对饮食负担的降低效果 +50%

专属困境:
  蛋白摄入足够但不吃蔬果 → 恢复速度下降
  训练过度但睡眠不足 → 恢复大幅下降
  预算有限但需要高蛋白 → 经济紧张
  饮食容易单调 → 满足感不足

可用行动: [workout, cafeteria_add_meal, buy_protein_food, 
           meal_prep, rest_stretch, social_dinner, 
           grocery_shop, simple_cook, drink_water, sleep_early]
受限行动: [study 换成 workout; 不能 order_takeout(受限)]

14天剧情节拍:
  Day 1: "新的训练周期开始"
  Day 4: "第一次训练后身体反应"
  Day 8: "朋友约火锅，吃还是不吃？"
  Day 12: "体能测试日"
  Day 14: 周期结束 + 结局
```

### 7.5 角色五：情绪性进食者 (EmotionalEater)

```
名称: 阿静 / "吃东西是我唯一的慰藉"
处境: 正在经历一段情绪低谷，食物是主要的情绪调节方式

初始状态:
  stability: 50, balance: 150, timeSlots: 4
  energy: 45, mood: 35, satiety: 70
  stress: 70, dietBurden: 40, sleepQuality: 35
  selfControl: 35, dietAnxiety: 40

目标: 恢复情绪稳定 (7天)
无硬性进度要求，关注 mood 和 stress 的趋势

偏好食物:
  喜欢: chocolate, chips, bubble_tea, fried_chicken, ice_cream (mood+10)
  不太喜欢: salad, plain_vegetables, green_tea (mood-2)

专属技能:
  "安慰食物效果翻倍": 甜食/零食的心情加成 ×1.5
  "情绪感知": 能看到食物卡的隐藏心情效果(数值)

专属困境:
  心情好 → 不需要安慰食物 → 更容易健康饮食
  心情差 → 需要安慰食物 → 饮食负担上升 → 心情可能更差
  自控力波动大 (每天 ± 10 随机)
  极端节食的惩罚更重 (反弹风险 +50%)
  心理卡效果增强 (+30%)

可用行动: [stable_meal, eat_sweet, walk, call_friend, 
           sleep_early, meditate, order_takeout, drink_water,
           social_dinner, nap]
受限行动: [不能 complex_cooking, meal_prep; control_diet 惩罚加倍]

7天剧情节拍:
  Day 1: "今天又是不想说话的一天"
  Day 3: "吃了很多，但不知道为什么还是不开心"
  Day 5: "第一次注意到，吃完甜食后好像没那么糟"
  Day 7: "可能没有'好起来'，但有了一些不同的应对方式"
```

---

## 8. 生活事件系统完整定义

### 8.1 事件列表

| ID | 名称 | 类型 | 持续时间 | 触发条件 | 权重 | 效果 |
|---|---|---|---|---|---|---|
| food_delivery_promo | 外卖优惠 | 负面(中性) | 3天 | 随机, minDay=2 | 15 | 外卖-30%价格, 外卖出现率×2, selfControl-10 |
| exam_week | 考试周 | 负面 | 7天 | 学生角色, minDay=1 | 100(必发) | stress每日+3, 复习要求+20%, 奶茶/咖啡/速食出现率+50% |
| overtime_week | 加班周 | 负面 | 5天 | 上班族角色, minDay=3 | 50 | timeSlots-1, 外卖/便利店出现率+40%, 做饭/运动精力消耗+1 |
| tight_budget | 预算紧张 | 负面 | 4天 | 随机, minDay=3 | 20 | 每日可用预算-30%, 廉价食材价值+20% |
| social_invitation | 聚餐邀请 | 中性 | 1天 | 随机, minDay=3 | 25 | 选择: 参加/拒绝/参加但控制 |
| emotional_low | 情绪低谷 | 负面 | 3天 | 情绪进食者, mood<40时触发 | 40 | mood恢复-50%, 甜食出现率+80%, 心理卡效果+30% |
| empty_fridge | 冰箱清空 | 负面 | 2天 | 随机, minDay=4 | 20 | 自炊卡不可用, 采购行动价值+50% |
| good_weather | 天气好 | 正面 | 2天 | 随机, minDay=1 | 20 | 散步效果+50%, 运动精力消耗-1, mood每日+3 |
| pay_day | 发薪日 | 正面 | 1天 | 随机, 上班族角色, minDay=5 | 30 | 余额+50, mood+10 |
| free_food | 免费食物 | 正面 | 1天 | 随机, minDay=2 | 15 | 获得1张随机食物卡(免费), mood+5 |
| friend_visit | 朋友来访 | 正面 | 1天 | 随机, minDay=3 | 15 | mood+12, stress-10, 但可能耽误1个时间格 |
| health_scare | 健康警告 | 负面 | 1天 | dietBurden>60或sleepQuality<20 | 60 | 强制休息日, 无法进行高消耗行动, 但后续自控力+15 |
| rain_week | 阴雨连绵 | 负面 | 3天 | 随机 | 15 | 散步效果-50%, 外卖出现率+30%, mood每日-2 |

### 8.2 事件叠加规则

```
同一时间最多存在 2 个活跃事件
第3个事件触发时，自动结束最早的事件（或让玩家选择）
某些事件互斥（如 "外卖优惠" 和 "预算紧张" 不会同时出现）
专家难度允许 3 个事件同时存在
```

---

## 9. 结局系统完整定义

### 9.1 结局判定优先级（从高到低）

```
1. Collapsed (没撑住)
   condition: stability <= 10 持续 2天 OR goalProgress < 30 at Day 7/14
   → "生活节奏彻底崩盘。没关系，下次重新来过。"

2. StableEndurance (稳稳撑过)
   condition: stability >= 60 AND goalProgress >= 70 AND mood >= 40 AND dietBurden <= 55
   → "你找到了属于自己的可持续节奏。不完美，但很稳。"

3. HealthyButBurnedOut (吃得健康但心态崩了)
   condition: dietBurden <= 25 AND mood <= 35 AND stress >= 75
   → "食谱很完美，但人也撑不住了。健康不是只有身体。"

4. HappyButUnhealthy (心情不错但身体负担高)
   condition: mood >= 60 AND dietBurden >= 65 AND stability >= 45
   → "快乐也是一种营养。虽然身体负担有点大..."

5. FinanciallySafeButRunDown (预算撑住但状态不好)
   condition: balance >= remainingDays × dailyMinSpend × 2 AND energy <= 30 AND dietBurden >= 50
   → "钱省下来了，但精力和身体付出了代价。"

6. BarelySurvived (勉强撑过)
   condition: goalProgress >= 60 AND stability >= 30 (不满足以上任何条件)
   → "虽然过程很狼狈，但你撑过去了。有时候这就够了。"
```

### 9.2 特殊结局（隐藏）

```
7. PerfectBalance (完美平衡) [隐藏结局]
   condition: 7天模式, stability >= 80, all stats >= 50, 至少触发过5种不同组合
   → "不可思议——你在这艰难的一周找到了真正的平衡。这不是每个人都能做到的。"

8. FromDarkness (走出低谷) [情绪性进食者专属隐藏结局]
   condition: 情绪性进食者, Day 1 mood < 40, Day 7 mood >= 65, 
             至少使用过6张心理卡
   → "从黑暗中走出来，你比自己想象的更强大。"
```

---

## 10. 长期进度系统（局外成长）

因为是买断制游戏，长期进度主要用于角色解锁和内容扩展，不涉及付费。

### 10.1 解锁系统

```
初始可用:
  角色: 熬夜学生 (唯一)
  卡牌: 基础卡牌库 (约 40 张)
  模式: 7天模式

解锁条件:
  熬夜学生 任一结局 → 解锁 加班上班族
  加班上班族 任一结局 → 解锁 健身大学生
  熬夜学生 结局为 StableEndurance → 解锁 减脂上班族
  在任意角色中使用过 >= 5 张心理卡 → 解锁 情绪性进食者
  任意角色 结局为 StableEndurance → 解锁 独居青年
  完成 5 局游戏 → 解锁 高血压中年人
  完成 10 局游戏 → 解锁 素食新手
  所有基础角色结局一次 → 解锁 独居老人
  StableEndurance 达成 → 解锁 14天模式 (对已解锁角色)
  14天模式 StableEndurance → 解锁 挑战模式 (可叠加事件)
```

### 10.2 食谱图鉴

```
全局图鉴:
  记录所有触发过的组合
  每个组合有"首次触发"标记
  图鉴包含: 组合名称、所需食材、非说教式的营养说明
  示例: "番茄鸡蛋饭 — 便宜、好吃、做得快。在中国人的餐桌上出现频率最高的组合之一，不是没有原因的。"

收集奖励:
  收集 50% 组合 → 解锁新心理卡 "收集者的满足感"
  收集 100% 组合 → 解锁隐藏皮肤/主题色
```

### 10.3 角色故事进程

```
每个角色有 3-5 段短剧情
剧情在特定天数或特定状态触发
剧情不影响数值，但提供情感连接和世界观

剧情示例 (熬夜学生):
  Day 1 早晨: "小林打开手机，考试倒计时：7天。桌上堆着的复习资料像一座小山。"
  Day 3 压力>70: "今天已经喝了第三杯奶茶了。不是渴，是焦虑。"
  Day 5 stability<40: "他开始怀疑，自己是不是在复习，还是在拖延复习。"
  Day 7 结局: 根据结局走向给出不同收尾文本
```

---

## 11. UI/UX 详细规范

### 11.1 屏幕布局设计（移动端竖屏，375×812 基准）

```
┌──────────────────────────────┐
│  📍 第 3 天 / 7 天    [⚙]   │  ← 顶部栏 (48px)
├──────────────────────────────┤
│                              │
│  稳定度  ████████░░  62      │  ← 核心状态区 (80px)
│  有点危险                    │
│                              │
│  余额 ¥64  ⏰■■□  ⚡偏低   │  ← 资源栏 (36px)
│                              │
│  😊 低落  🍖 不足  😰 偏高  │  ← 心情/饱腹/压力 (36px)
│                              │
├──────────────────────────────┤
│  ▼ 当前事件: 外卖优惠(剩2天) │  ← 事件提示 (32px, 可折叠)
├──────────────────────────────┤
│                              │
│  📋 手牌区 (最多显示5张)     │  ← 手牌区 (140px)
│  ┌────┐ ┌────┐ ┌────┐      │     横向滑动
│  │🍚  │ │🥬  │ │🍗  │ ...  │     点击选中
│  │米饭│ │青菜│ │鸡肉│      │     拖拽到进餐区
│  │ ¥2 │ │ ¥3 │ │ ¥8 │      │
│  └────┘ └────┘ └────┘      │
│                              │
├──────────────────────────────┤
│  当前餐盘 / 行动区           │  ← 交互主区域 (200px)
│                              │
│  早餐: [__] 午餐: [__] 晚餐: [__] │  或
│  行动: [已选卡牌] [已选卡牌] │
│                              │
│  [组合预览: 均衡餐盘 ?]      │
│                              │
├──────────────────────────────┤
│  [采购] [结束当天] [详情]    │  ← 底部操作栏 (56px)
└──────────────────────────────┘
```

### 11.2 PC端布局（横屏，1920×1080 基准）

```
┌──────────────────────────────────────────────────────────┐
│  第3天/7天          稳定度 62          余额 ¥64  ⏰■■□  │
├────────────────────┬─────────────────────────────────────┤
│                    │                                     │
│   角色立绘         │   当前餐盘 / 行动区                 │
│   (插图)          │                                     │
│                    │   早餐 午餐 晚餐                     │
│   状态面板:        │   [__] [__] [__]                    │
│   精力 ██░░  偏低  │                                     │
│   心情 ██░░  低落  │   [组合预览]                       │
│   饱腹 █░░░  不足  │                                     │
│   压力 ███░  偏高  │   手牌区                            │
│   睡眠 ██░░  一般  │   ┌──┐┌──┐┌──┐┌──┐┌──┐          │
│                    │   │🍚││🥬││🍗││🧋││☕│          │
│   事件提示         │   └──┘└──┘└──┘└──┘└──┘          │
│   外卖优惠(剩2天)  │                                     │
│                    │   [采购] [详情] [结束当天]          │
│                    │                                     │
│   今日记录:        │   组合图鉴 (切换标签)               │
│   早: 米饭+鸡蛋    │   已触发: 均衡餐盘✓ 省钱健康餐✓    │
│   午: 待选择       │   未触发: 安慰餐 外卖补救...       │
│   晚: 待选择       │                                     │
└────────────────────┴──────────────────────────────────────────────────┘
```

### 11.3 配色方案

```
主色板:
  背景:       #FFF8F0 (温暖奶油色) / Dark: #1A1A2E
  主文字:      #2D2D2D / Dark: #E8E8E8
  辅文字:      #787878 / Dark: #9E9E9E
  强调色1:     #FF6B6B (温暖珊瑚色 — 用于重要提示、bad状态)
  强调色2:     #51CF66 (柔和绿色 — 用于正面状态、组合触发)
  强调色3:     #FFD43B (暖黄色 — 用于警告、中等状态)
  强调色4:     #748FFC (柔和蓝紫 — 用于信息、心理卡)
  卡牌底色:    #FFFFFF / Dark: #2A2A3E
  卡牌边框:    #E8E8E8 / Dark: #3A3A4E

角色主题色:
  熬夜学生:    #6C5CE7 (紫蓝 — 熬夜的夜色)
  加班上班族:  #636E72 (灰蓝 — 办公室)
  减脂上班族:  #00B894 (薄荷绿 — 清新健康)
  健身大学生:  #E17055 (活力橙 — 运动能量)
  情绪性进食者:#FD79A8 (柔和粉 — 温柔理解)
```

### 11.4 字体层级

```
移动端:
  标题 (天数):   24px Bold
  指标数值:      20px SemiBold
  指标标签:      13px Regular
  卡牌名称:      15px SemiBold
  卡牌描述:      12px Regular
  按钮文字:      14px Medium

PC端: 以上数值 × 1.3 比例
```

---

## 12. 音频设计简要

| 音频类别 | 内容 | 风格 |
|---|---|---|
| 背景音乐 (主界面) | 温暖的 Lo-fi / 轻钢琴 | 舒适、不打扰 |
| 背景音乐 (游戏中) | 根据角色和心情动态切换 | 低压力时轻松、高压力时稍紧张 |
| 音效 - 进餐 | 轻微的餐具声、咀嚼声(可选关闭) | 柔和、不写实过度 |
| 音效 - 组合触发 | 温暖的提示音 | 满足感 |
| 音效 - 心理卡 | 柔和的风铃或钢琴单音 | 安抚感 |
| 音效 - UI点击 | 轻柔的咔嗒声 | 干净、不刺耳 |
| 音效 - 事件触发 | 手机通知音（外卖优惠）、纸张翻动（考试周） | 生活化 |

---

## 13. 本地化考虑

### 13.1 首批语言
- 简体中文 (zh-CN) — 开发语言
- 繁体中文 (zh-TW)
- 英语 (en)
- 日语 (ja)

### 13.2 本地化挑战点
- 食物名称和概念（如"食堂"在西方不常见）
- 心理卡的表达在不同文化中的敏感性
- 货币符号和金额的本地化
- 部分食物组合的文化特殊性（如"番茄鸡蛋饭"在中国语境下的意义）

### 13.3 解决方案
- 核心逻辑与文本分离：所有文本使用 Localization Key
- 食物库支持不同地区的默认变体（如亚洲版"米饭"→欧美版"意面"）
- 心理卡文本由本地化团队审校（非机器翻译）

---

## 14. 文件/项目结构建议

```
Assets/
├── _Project/
│   ├── Scenes/
│   │   ├── Boot.unity                 # 启动/初始化场景
│   │   ├── MainMenu.unity             # 主菜单
│   │   ├── CharacterSelect.unity      # 角色选择
│   │   ├── Game.unity                 # 游戏主场景
│   │   └── Ending.unity              # 结局展示
│   │
│   ├── Scripts/
│   │   ├── Core/
│   │   │   ├── GameManager.cs         # 游戏主控制器 (状态机)
│   │   │   ├── DayManager.cs          # 每日流程控制器
│   │   │   ├── CardManager.cs         # 卡牌系统 (手牌/牌库/弃牌)
│   │   │   ├── EventBus.cs            # 事件总线 (全局通信)
│   │   │   └── SaveManager.cs         # 存档管理
│   │   │
│   │   ├── Systems/
│   │   │   ├── StatsSystem.cs         # 指标计算和更新
│   │   │   ├── EconomySystem.cs       # 经济系统
│   │   │   ├── ComboSystem.cs         # 组合检测和结算
│   │   │   ├── LifeEventSystem.cs     # 生活事件管理
│   │   │   ├── EndingSystem.cs        # 结局判定
│   │   │   ├── ProgressionSystem.cs   # 局外成长/解锁
│   │   │   ├── InventorySystem.cs     # 库存系统
│   │   │   └── NarrativeSystem.cs     # 剧情/对话系统
│   │   │
│   │   ├── Data/
│   │   │   ├── CharacterConfig.cs     # 角色配置数据结构
│   │   │   ├── CardConfig.cs          # 卡牌配置数据结构
│   │   │   ├── ComboConfig.cs         # 组合配置数据结构
│   │   │   ├── LifeEventConfig.cs     # 事件配置数据结构
│   │   │   ├── EndingConfig.cs        # 结局配置数据结构
│   │   │   └── GameState.cs           # 运行时游戏状态
│   │   │
│   │   ├── UI/
│   │   │   ├── MainHUD.cs             # 主界面控制器
│   │   │   ├── CardWidget.cs          # 卡牌组件
│   │   │   ├── ResourceBar.cs         # 资源条组件
│   │   │   ├── MealSlot.cs            # 进餐槽位组件
│   │   │   ├── ComboPreview.cs        # 组合预览组件
│   │   │   ├── DaySummary.cs          # 每日结算弹窗
│   │   │   ├── EndingScreen.cs        # 结局界面
│   │   │   └── UIAnimationHelper.cs   # UI动画辅助
│   │   │
│   │   └── Utils/
│   │       ├── FormulaCalculator.cs   # 公式计算工具类
│   │       ├── TagMatcher.cs           # 标签匹配工具
│   │       ├── RandomHelper.cs         # 随机数工具
│   │       └── LocalizationHelper.cs   # 本地化辅助
│   │
│   ├── ScriptableObjects/
│   │   ├── Characters/
│   │   │   ├── SO_Char_Student.asset
│   │   │   ├── SO_Char_Worker.asset
│   │   │   ├── SO_Char_Dieter.asset
│   │   │   ├── SO_Char_Fitness.asset
│   │   │   └── SO_Char_Emotional.asset
│   │   │
│   │   ├── Cards/
│   │   │   ├── Food/
│   │   │   │   ├── SO_Food_Rice.asset
│   │   │   │   ├── SO_Food_Egg.asset
│   │   │   │   └── ... (每张食物卡一个)
│   │   │   ├── Action/
│   │   │   │   └── ...
│   │   │   └── Psycho/
│   │   │       └── ...
│   │   │
│   │   ├── Combos/
│   │   │   └── ... (每个组合一个)
│   │   │
│   │   ├── Events/
│   │   │   └── ... (每个事件一个)
│   │   │
│   │   ├── Endings/
│   │   │   └── ... (每个结局一个)
│   │   │
│   │   └── DifficultySettings/
│   │       ├── SO_Difficulty_Normal.asset
│   │       ├── SO_Difficulty_Hard.asset
│   │       └── SO_Difficulty_Expert.asset
│   │
│   ├── Prefabs/
│   │   ├── CardWidget.prefab
│   │   ├── ResourceBar.prefab
│   │   └── ...
│   │
│   ├── Textures/
│   │   ├── Characters/     # 角色立绘和插画
│   │   ├── Cards/          # 卡牌插图
│   │   ├── UI/             # UI元素
│   │   ├── Backgrounds/    # 场景背景
│   │   └── Icons/          # 图标
│   │
│   ├── Audio/
│   │   ├── BGM/
│   │   ├── SFX/
│   │   └── Ambient/
│   │
│   ├── Localization/
│   │   ├── zh-CN/
│   │   ├── zh-TW/
│   │   ├── en/
│   │   └── ja/
│   │
│   └── Resources/
│       └── ... (运行时加载的资源)
│
└── (Unity 自动生成的文件...)
```

---

## 15. 开发阶段规划

### Phase 1: 核心原型 (4-6 周, 1人)

**目标**: 验证核心玩法循环是否有趣

**内容**:
- [ ] Unity 项目初始化，2D URP 配置
- [ ] 基础 UI 框架搭建（主界面 + 卡牌组件）
- [ ] 实现 1 个角色（熬夜学生）
- [ ] 实现 15 张食物卡 + 3 张行为卡
- [ ] 实现基本每日流程状态机（进餐 → 行动 → 结算）
- [ ] 实现 5 个核心指标（稳定度、余额、精力、心情、饱腹感）
- [ ] 实现稳定度公式（简化版，不含短板惩罚）
- [ ] 实现 2 个组合（均衡餐盘、快速饱腹）
- [ ] 7 天模式完整循环
- [ ] 简单的结局判定（3种结局）
- [ ] **里程碑：自己完整玩 5 局，验证是否有趣**

**此阶段不实现**: 经济系统、库存系统、生活事件、心理卡、多角色、图鉴

### Phase 2: 系统完整体验 (6-8 周, 1-2人)

**目标**: 实现所有核心系统，支持完整游戏体验

**内容**:
- [ ] 全部 5 个初始角色
- [ ] 完整食物卡库（30张）+ 行为卡（12张）
- [ ] 心理卡系统（8张）
- [ ] 经济系统（余额、价格、采购）
- [ ] 完整组合系统（8种组合）
- [ ] 生活事件系统（8个事件）
- [ ] 完整结局系统（6+2种）
- [ ] 短板惩罚机制
- [ ] 连续天数奖励
- [ ] 角色剧情文本
- [ ] 14 天模式
- [ ] 基本存档系统
- [ ] **里程碑：可以完整体验一局游戏，所有系统正常运作**

### Phase 3: 内容打磨 (6-8 周, 1-2人 + 1 美术)

**目标**: 美术、音频、内容和平衡性

**内容**:
- [ ] 角色立绘和场景插画
- [ ] 卡牌插画（或使用图标+色彩方案替代完整插画，节省成本）
- [ ] UI 视觉设计和动画
- [ ] 背景音乐和音效
- [ ] 数值平衡调整（基于 Phase 2 的测试数据）
- [ ] 角色剧情文本完稿
- [ ] 食谱图鉴系统
- [ ] 解锁/进度系统
- [ ] 3种难度模式
- [ ] 挑战模式（自定义事件叠加）
- [ ] **里程碑：游戏内容完整，可以给外部测试者试玩**

### Phase 4: 多平台与发布 (4-6 周, 1-2人)

**目标**: 跨平台适配和发布准备

**内容**:
- [ ] 多分辨率适配（手机竖屏 → 平板 → PC横屏）
- [ ] 本地化集成（首批 4 种语言）
- [ ] 性能优化（针对中低端手机）
- [ ] 可访问性（字体大小选择、色盲模式、音频字幕）
- [ ] Apple App Store / Google Play / Steam 商店页面准备
- [ ] 预告片和截图
- [ ] 外部测试和 Bug 修复
- [ ] **里程碑：所有平台可玩，准备提交审核**

### Phase 5: 后续内容扩展 (发布后)

- [ ] 解锁角色（独居青年、高血压中年人、素食新手、独居老人）
- [ ] 更多食物卡和行为卡
- [ ] 周常挑战模式
- [ ] 成就系统
- [ ] 社区反馈驱动的内容优化

---

## 16. 数值平衡参考指南

### 16.1 每日经济模型

```
典型学生角色每日预算:
  总收入: 初始 ¥120 / 7天 ≈ ¥17/天
  
  合理花费:
    早餐: ¥2-5   (米饭+鸡蛋 / 燕麦+牛奶)
    午餐: ¥5-10  (食堂/简单做饭/便利店)
    晚餐: ¥5-10  (同上)
    其他: ¥0-5   (水果/饮品)
  
  总计: ¥12-30/天 → 合理中位 ~¥18/天
  
  节省策略: 全自己做 ≈ ¥10/天 (需要时间和精力)
  放纵策略: 全外卖 ≈ ¥40+/天 (不可持续)
```

### 16.2 指标变化速率（每回合/每天）

```
健康变化的合理范围 (每天):
  stability    ±15  (正常波动)
  energy       +10~+35 (睡眠恢复) / -5~-25 (消耗)
  mood         ±10
  satiety      +20~+35 (进餐) / -15~-25 (消耗)
  stress       +3~+10 (自然增长/压力) / -5~-15 (缓解)
  dietBurden   +0~+12 (高负担食物) / -2~-5 (健康食物/运动)

极端情况:
  连续3天高负担饮食:  dietBurden 可达 70+
  连续3天早睡+均衡:  stability 可上升 20+
  一顿不吃的惩罚:    satiety -25, stability -8, stress +10
```

### 16.3 平衡性测试检查清单

```
□ 典型路线能否达到 StableEndurance？ (目标: 50% 的新手玩家能做到)
□ 完全放纵路线是否一定导致 Collapsed？ (目标: 是)
□ 完全健康路线是否可能导致 BurnedOut？ (目标: 是, 对减脂和情绪角色)
□ 是否有最优解（某张卡或策略明显强于其他）？
□ 每种组合是否都有被使用的场合？
□ 心理卡的效果是否足够有吸引力但不 OP？
□ 各角色是否有足够不同的游玩体验？
□ 7天和14天模式的时间感受是否合理？
□ 随机性是否让玩家感到"有趣"而非"不公平"？
□ 经济是否在最后几天会自然紧张（而非太松或太紧）？
```

---

## 17. 风险与缓解措施

| 风险 | 概率 | 影响 | 缓解措施 |
|---|---|---|---|
| 核心循环不够有趣 | 中 | 致命 | Phase 1 尽早纸面原型测试；准备好 pivot |
| 美术资源生产远超预算 | 高 | 高 | 使用图标+色彩方案替代部分插画；优先 UI 美术 |
| 数值平衡耗时过长 | 中 | 中 | 所有数值从 ScriptableObject 读取，方便调参；建立 Excel 数值模拟表 |
| 本地化成本高 | 中 | 中 | 首发中文+英语；其他语言根据销量逐步添加 |
| 移动端性能问题 | 低 | 中 | 2D 游戏性能开销可控；注意 UI Draw Call 优化 |
| 主题敏感度引发争议 | 低 | 高 | 咨询营养/心理专业人士审阅；免责声明；避免医学化 |
| 单局时长流失 | 中 | 中 | 7天模式控制在20分钟内；提供中途保存 |
| 全平台适配工作量大 | 高 | 中 | 手机竖屏优先设计；PC 用自适应布局而非单独重做 |

---

## 18. 附录：关键技术决策

### 18.1 为什么用 UI Toolkit 而非 uGUI？

- UI Toolkit 支持 CSS-like 样式，多分辨率适配更方便
- 但学习曲线较高
- **备选方案**: uGUI（如果团队更熟悉），配合 Content Size Fitter + Layout Group 做自适应

### 18.2 为什么用 ScriptableObject 而非纯 JSON？

- SO 在 Unity 编辑器中可视化编辑，调参方便
- 运行时引用效率高
- JSON 用于存档（玩家进度、设置）
- 可以在 Editor 中写工具脚本将 SO 数据导出为 JSON 供外部工具分析

### 18.3 数据驱动架构

```
所有游戏内容（卡牌、角色、事件、组合）都使用 ScriptableObject 配置
所有 Formula 都在 FormulaCalculator 中集中管理（便于测试和调参）
游戏状态使用单例 GameState (运行时不跨场景)
存档使用 JSON 序列化 GameState（只保存必要字段）
UI 通过 EventBus 订阅状态变化，而非直接引用
```

---

## 19. 给实现 AI 的快速上手指南

如果将此文档交给 CodeX、Cursor 或 Claude Code 进行实现，建议按以下顺序进行：

### Step 1: 理解核心数据结构
阅读 3.2 中的数据结构定义。在 Unity 中创建对应的 C# 类和 ScriptableObject。

### Step 2: 实现基础状态机
阅读 2.2 和 2.3，实现 DayManager 中的每日流程状态机。这是游戏的骨架。

### Step 3: 实现指标系统
阅读第 4 节，在 StatsSystem 中实现所有公式。先用硬编码数值测试。

### Step 4: 创建 ScriptableObject 配置
阅读第 5-9 节，将一张食物卡、一个角色、一个组合做成 ScriptableObject 配置并测试流程。

### Step 5: 搭建 UI
阅读第 11 节，创建主界面和卡牌组件。先用占位美术。

### Step 6: 填充内容
按第 5-9 节的完整数据表，创建所有 ScriptableObject 配置文件。

### Step 7: 实现剩余系统
心理卡 → 组合 → 生活事件 → 结局 → 解锁 → 图鉴

### Step 8: 数值平衡
用第 16 节的检查清单进行平衡性测试和调整。

---

> **文档版本**: v2.0.0  
> **最后更新**: 2026-07-08  
> **作者**: Claude (Anthropic Opus 4.8)  
> **使用许可**: 本设计文档供项目实现参考，可自由修改和分发。
