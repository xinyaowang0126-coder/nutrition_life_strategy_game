# 《撑过这一周》Godot 4.7 游戏设计方案与实现路径

> 目标：把现有 GDD 转换为 Godot 4.7 可执行的制作方案。  
> 定位：2D 生活策略 + 卡牌构筑 + 轻度资源管理。  
> 第一优先级：先做出 7 天「熬夜学生」可玩原型，验证核心循环是否有趣。

---

## 1. 项目判断

### 1.1 为什么 Godot 4.7 适合本项目

本项目的主要复杂度不在 3D、物理或大型关卡，而在：

- 数据驱动的卡牌、角色、事件、结局配置。
- 大量 UI 状态切换与反馈。
- 轻量但频繁的数值结算。
- 移动端竖屏和 PC 横屏的响应式界面。
- 反复调参和快速原型迭代。

Godot 4.7 的节点/场景结构、GDScript、Resource、Control/Container UI 系统非常适合这个方向。项目不需要沉重的 ECS 或大型框架，应该保持「小而清楚」。

### 1.2 本方案的核心技术路线

| 方向 | 选择 | 说明 |
|---|---|---|
| 引擎 | Godot 4.7.x | 固定小版本，避免多人环境不一致 |
| 语言 | GDScript | 快速迭代、编辑器集成好、适合小团队 |
| 渲染 | Mobile Renderer 优先 | 2D/UI 项目足够，兼顾移动端性能 |
| UI | Control + Container | 移动竖屏优先，PC 横屏适配 |
| 数据 | 自定义 Resource `.tres` | 卡牌/角色/组合/事件/结局数据可视化调参 |
| 存档 | JSON | 玩家进度、设置、局外解锁 |
| 架构 | Autoload + 独立 Systems + Scene UI | 少量全局服务，游戏逻辑集中在系统层 |
| 测试 | Headless 脚本测试 | 用 `godot --headless` 验证公式和每日流程 |

### 1.3 Godot 4.7 特性使用边界

本项目应该使用 Godot 4.7 的稳定 UI 与工作流能力，但不要为了新特性增加风险。

建议使用：

- `Control` 节点的 offset transform 类能力：用于卡牌 hover、出牌、组合触发、弹窗进入等 UI 动画。
- 新 Asset Store 工作流：后期可挑选字体、音效、UI 插件，但核心项目不依赖第三方插件。
- Android 导出改进：移动端发布阶段再纳入，不影响原型。
- HDR 输出：本项目不是画面驱动型，首版不作为目标。

---

## 2. 游戏设计落地版

### 2.1 一句话版本

玩家扮演处在现实生活压力中的角色，在 7 或 14 天内通过吃饭、学习/工作、休息、社交和自我调节来维持「稳定度」，目标不是完美健康，而是在不理想条件下找到可持续节奏。

### 2.2 Godot 原型范围

第一版只做「能完整玩一局」。

包含：

- 1 个角色：熬夜学生。
- 7 天模式。
- 15 张食物卡。
- 4 张行动卡。
- 5 个主状态：稳定度、余额、精力、心情、饱腹感。
- 2 个半隐藏状态：压力、饮食负担。
- 1 个专属目标：复习进度。
- 2 个组合：均衡餐盘、快速饱腹。
- 3 种结局：稳稳撑过、勉强撑过、没撑住。
- 基础主界面、手牌、餐盘、行动、每日结算和结局界面。

暂不包含：

- 多角色。
- 心理卡完整系统。
- 库存/保质期。
- 复杂生活事件。
- 长期图鉴和解锁。
- 14 天模式。
- 正式美术和音频。

### 2.3 原型的核心体验要求

第一版必须回答三个问题：

1. 玩家是否能感到「我是在过一周生活」，而不是做营养题。
2. 奶茶、方便面、外卖等选择是否既有正面价值，也有后续代价。
3. 稳定度是否能自然表达「还能不能撑住」。

如果这三个问题没有成立，后续内容扩展没有意义。

---

## 3. 每日流程设计

### 3.1 单局结构

```text
主菜单
  -> 角色选择
  -> 模式选择
  -> 第 1 天开始
  -> 每日循环 x 7
  -> 结局判定
  -> 结局展示
  -> 返回主菜单
```

### 3.2 每日状态机

```text
DAY_START
  早晨简报，恢复少量状态，显示剧情或事件

BREAKFAST
  选择 1-2 张食物卡，结算早餐

LUNCH
  选择 1-2 张食物卡，结算午餐

DINNER
  选择 1-2 张食物卡，结算晚餐

ACTION
  使用 0-2 张行动卡，如复习、小睡、散步

SLEEP_CHOICE
  选择普通睡觉或早睡；原型中暂不做熬夜额外行动

DAY_SUMMARY
  展示今日状态变化、触发组合、风险提示

NEXT_DAY 或 ENDING
```

### 3.3 进餐规则

每餐最少选择 1 张食物卡，最多选择 2 张。

- 主食、蛋白、蔬菜、水果可以自由搭配。
- 饮品、零食、速食也视为食物卡。
- 不吃饭在原型中不开放为主动选项，避免第一版分支过多。
- 如果手牌无法满足进餐，系统自动给一张「白米饭」或「方便面」救急卡，作为后续库存系统前的简化兜底。

### 3.4 行动规则

每天自由行动阶段有 2 个行动格。

原型行动卡：

| ID | 名称 | 效果 |
|---|---|---|
| study | 复习 | 复习进度 +12，精力 -10，压力 +4 |
| nap | 小睡 | 精力 +18，压力 -5，消耗 1 行动格 |
| walk | 散步 | 心情 +3，压力 -6，消耗 1 行动格 |
| drink_water | 喝水 | 饱腹 +3，饮食负担 -2，不消耗行动格，每天最多 2 次 |

睡眠不是行动卡，作为每日末尾选择处理。

---

## 4. 指标系统

### 4.1 原型主界面指标

| 指标 | 范围 | 说明 |
|---|---:|---|
| 稳定度 | 0-100 | 总体状态，低于 10 连续两天进入没撑住 |
| 余额 | 0+ | 本周生活费，原型初始 120 |
| 精力 | 0-100 | 影响能否继续复习和行动 |
| 心情 | 0-100 | 影响稳定度和部分食物收益 |
| 饱腹感 | 0-100 | 太低会加压力，太高会加饮食负担 |
| 复习进度 | 0-100 | 学生角色目标 |

半隐藏但参与结算：

- 压力。
- 饮食负担。
- 今日饮食质量。

### 4.2 原型稳定度公式

第一版使用可解释的简化公式：

```text
mental_state = mood * 0.55 + (100 - stress) * 0.45
budget_safety = clamp(balance / (remaining_days * 10) * 100, 0, 100)
goal_pct = clamp(study_progress, 0, 100)
diet_control = 100 - diet_burden

stability =
  diet_quality_today * 0.20
  + mental_state * 0.25
  + energy * 0.20
  + satiety * 0.10
  + diet_control * 0.10
  + goal_pct * 0.10
  + budget_safety * 0.05

短板惩罚：
  energy < 15: -10
  mood < 15: -10
  satiety < 10: -8
  stress > 90: -10
  balance < remaining_days * 6: -8

最终 stability = clamp(stability - penalty, 0, 100)
```

### 4.3 饮食质量原型算法

每餐根据标签给分：

```text
base = 50
有 staple: +8
有 protein: +10
有 vegetable 或 fruit: +12
high_sugar 每张: -8
high_fat 每张: -8
high_sodium 每张: -6
instant 每张: -5
fastfood 每张: -8
favorite_food: +3 mood，不直接加 diet_quality

meal_diet_quality = clamp(base + modifiers, 0, 100)
今日饮食质量 = 三餐平均
```

设计意图：

- 喜欢的食物提升心情，不把它说成「健康」。
- 速食和外卖有代价，但不会一票否决。
- 搭配蔬果、蛋白、主食会自然形成较好结果。

### 4.4 每餐即时结算

食物卡结算字段：

```text
cost
satiety_delta
mood_delta
diet_burden_delta
energy_kcal
protein
fat_burden
sugar_burden
fiber
sodium_burden
tags
```

即时规则：

- 扣除 `cost`。
- 增加 `satiety_delta`。
- 增加 `mood_delta`。
- 增加 `diet_burden_delta`。
- 如果食物在角色偏好中，额外 `mood +5`。
- 如果饱腹感超过 90，额外 `diet_burden +3`。
- 如果饱腹感低于 15，额外 `stress +5`。

### 4.5 晚间结算

每日结束：

```text
stress += 3
satiety -= 20

if study_progress < day * 14:
  stress += 8

if balance < remaining_days * 10:
  stress += 5

if 今日饮食质量 >= 70:
  mood += 3
  diet_burden -= 2

if 今日饮食质量 <= 35:
  stress += 4

根据睡眠选择：
  普通睡觉：energy += 20, stress -= 2
  早睡：energy += 35, stress -= 8, mood += 2
```

---

## 5. 卡牌与组合

### 5.1 原型食物卡 15 张

| ID | 名称 | 角色 |
|---|---|---|
| rice_plain | 白米饭 | 便宜主食 |
| oatmeal | 燕麦 | 稳定早餐 |
| egg | 鸡蛋 | 高性价比蛋白 |
| tofu | 豆腐 | 便宜蛋白 |
| greens | 青菜 | 蔬菜基础卡 |
| tomato | 番茄 | 情绪更友好的蔬果 |
| apple | 苹果 | 水果与心情 |
| banana | 香蕉 | 饱腹与能量 |
| milk | 牛奶 | 饮品/蛋白 |
| coffee | 咖啡 | 学生提神但不解决睡眠 |
| bubble_tea | 奶茶 | 高心情、高糖、高花费 |
| instant_noodles | 方便面 | 便宜、省时、负担高 |
| fried_chicken | 炸鸡 | 高满足、高负担、高花费 |
| salad_bowl | 沙拉碗 | 饮食质量好但贵、满足感低 |
| sandwich | 三明治 | 中等便利选择 |

### 5.2 原型组合

#### 均衡餐盘

条件：

```text
staple >= 1
protein >= 1
vegetable_or_fruit >= 1
```

效果：

```text
satiety +10
mood +3
diet_quality_today +8
stability 结算时自然提高
```

#### 快速饱腹

条件：

```text
instant >= 1
```

效果：

```text
satiety +15
本餐不消耗额外时间
diet_burden +2
```

设计意图：方便面不是「错」，但它在长期饮食负担上有代价。

### 5.3 后续组合扩展顺序

Phase 2 再加入：

1. 省钱健康餐。
2. 高纤维组合。
3. 高蛋白组合。
4. 安慰餐。
5. 外卖补救。
6. 饮品平衡。

---

## 6. Godot 项目结构

### 6.1 目录结构

```text
res://
  project.godot

  scenes/
    boot/
      Boot.tscn
    main_menu/
      MainMenu.tscn
    run_setup/
      CharacterSelect.tscn
      ModeSelect.tscn
    game/
      GameRoot.tscn
      DaySummaryDialog.tscn
      EndingScreen.tscn
    ui/
      CardView.tscn
      HandView.tscn
      MealSlot.tscn
      StatBar.tscn
      ResourceStrip.tscn
      ComboToast.tscn
      EventToast.tscn

  scripts/
    autoload/
      App.gd
      DataRegistry.gd
      SaveManager.gd
      AudioManager.gd
      EventBus.gd
    core/
      GameEnums.gd
      RunState.gd
      StatValue.gd
      MealRecord.gd
      PlayedCardRecord.gd
    systems/
      RunController.gd
      DayManager.gd
      CardSystem.gd
      StatsSystem.gd
      ComboSystem.gd
      EndingSystem.gd
      EconomySystem.gd
      LifeEventSystem.gd
      NarrativeSystem.gd
    resources/
      CharacterConfig.gd
      CardConfig.gd
      EffectBundle.gd
      ComboConfig.gd
      LifeEventConfig.gd
      EndingConfig.gd
      DifficultyConfig.gd
    ui/
      GameHUD.gd
      CardView.gd
      HandView.gd
      MealSlot.gd
      DaySummaryDialog.gd
      EndingScreen.gd
      TweenHelper.gd
    tests/
      TestRunner.gd
      TestStatsSystem.gd
      TestComboSystem.gd
      TestDayFlow.gd

  data/
    characters/
      student_sleep_deprived.tres
    cards/
      food/
      action/
      psycho/
    combos/
    events/
    endings/
    difficulty/

  assets/
    art/
      characters/
      cards/
      backgrounds/
      ui/
    audio/
      bgm/
      sfx/
    fonts/

  localization/
    zh_CN.csv
    en.csv

  saves/
    README.md
```

### 6.2 Autoload 设计

只保留必要的全局服务。

| Autoload | 职责 |
|---|---|
| App | 应用启动、场景切换、全局设置 |
| DataRegistry | 加载所有 `.tres` 配置，提供按 ID 查询 |
| SaveManager | 保存/读取局外进度、设置、存档 |
| AudioManager | BGM/SFX 播放和音量管理 |
| EventBus | 跨 UI 与系统广播信号 |

不要把游戏全部逻辑塞进 Autoload。单局运行逻辑应该在 `RunController` 和各系统里。

### 6.3 Scene 设计

#### Boot.tscn

职责：

- 初始化 `DataRegistry`。
- 读取设置和存档。
- 检查必要资源是否缺失。
- 跳转主菜单。

#### MainMenu.tscn

职责：

- 开始游戏。
- 继续游戏。
- 图鉴入口，原型中可隐藏。
- 设置入口。

#### GameRoot.tscn

建议节点结构：

```text
GameRoot (Control)
  BackgroundLayer (TextureRect)
  MainLayout (MarginContainer)
    RootVBox (VBoxContainer)
      TopBar
      StabilityPanel
      ResourceStrip
      EventBanner
      CenterArea
        PCLayout / MobileLayout
      HandView
      BottomActionBar
  OverlayLayer (CanvasLayer)
    DaySummaryDialog
    EndingScreen
    ToastLayer
```

`GameRoot.gd` 不直接计算数值，只负责连接 UI 与 `RunController`。

---

## 7. 数据模型

### 7.1 Resource 类

#### CardConfig.gd

```gdscript
class_name CardConfig
extends Resource

@export var id: StringName
@export var type: StringName
@export var sub_type: StringName
@export var display_name_key: String
@export_multiline var description_key: String
@export var rarity: StringName = &"common"
@export var cost: int = 0
@export var effects: EffectBundle
@export var hidden_nutrition: Dictionary = {}
@export var tags: Array[StringName] = []
@export var shelf_life_days: int = -1
@export var icon: Texture2D
```

#### EffectBundle.gd

```gdscript
class_name EffectBundle
extends Resource

@export var time_delta: int = 0
@export var energy_delta: int = 0
@export var satiety_delta: int = 0
@export var mood_delta: int = 0
@export var stress_delta: int = 0
@export var diet_burden_delta: int = 0
@export var study_progress_delta: int = 0
@export var self_control_delta: int = 0
@export var diet_anxiety_delta: int = 0
```

#### CharacterConfig.gd

```gdscript
class_name CharacterConfig
extends Resource

@export var id: StringName
@export var display_name_key: String
@export_multiline var description_key: String
@export var total_days: int = 7
@export var base_stats: Dictionary = {}
@export var stability_weights: Dictionary = {}
@export var goal_metric_key: StringName
@export var goal_target: int = 100
@export var favorite_card_ids: Array[StringName] = []
@export var disliked_card_ids: Array[StringName] = []
@export var available_action_ids: Array[StringName] = []
@export var restricted_action_ids: Array[StringName] = []
```

#### ComboConfig.gd

```gdscript
class_name ComboConfig
extends Resource

@export var id: StringName
@export var display_name_key: String
@export_multiline var description_key: String
@export var required_tags: Dictionary = {}
@export var forbidden_tags: Array[StringName] = []
@export var effects: EffectBundle
@export var once_per_day: bool = true
```

### 7.2 运行时数据

运行时不直接修改 `.tres`。所有单局状态放在 `RunState.gd`。

```gdscript
class_name RunState
extends RefCounted

var character_id: StringName
var day: int = 1
var total_days: int = 7
var phase: StringName

var stats := {
  &"stability": 65,
  &"balance": 120,
  &"energy": 50,
  &"mood": 55,
  &"satiety": 60,
  &"stress": 55,
  &"diet_burden": 25,
  &"diet_quality_today": 50,
}

var goal_progress := {
  &"study_progress": 0
}

var hand: Array[StringName] = []
var draw_pile: Array[StringName] = []
var discard_pile: Array[StringName] = []
var today_meals: Array = []
var today_actions: Array = []
var triggered_combos_today: Array[StringName] = []
var combo_history: Array[StringName] = []
```

### 7.3 ID 规范

统一使用英文蛇形 ID：

```text
rice_plain
bubble_tea
student_sleep_deprived
balanced_meal
stable_endurance
```

显示文本全部通过 localization key：

```text
card.rice_plain.name
card.rice_plain.desc
character.student_sleep_deprived.name
ending.stable_endurance.text
```

---

## 8. 系统职责

### 8.1 RunController

单局总控制器。

职责：

- 创建新 RunState。
- 进入每日流程。
- 接收 UI 指令。
- 调用系统完成结算。
- 判断是否进入结局。

不负责：

- 具体公式。
- UI 动画。
- 文件保存。

### 8.2 DayManager

管理每日阶段状态机。

核心接口：

```gdscript
func start_day() -> void
func enter_meal_phase(meal_type: StringName) -> void
func play_food_cards(card_ids: Array[StringName]) -> void
func enter_action_phase() -> void
func play_action_card(card_id: StringName) -> void
func choose_sleep(sleep_type: StringName) -> void
func finish_day() -> void
```

### 8.3 CardSystem

职责：

- 初始化牌库。
- 抽牌、弃牌、补牌。
- 校验卡牌可否使用。
- 应用卡牌基础效果。
- 根据角色偏好修正效果。

原型简化：

- 每天开始补到 5 张手牌。
- 食物卡和行动卡可以在同一手牌中出现。
- 第一版不做构筑，只做固定牌池随机抽。

### 8.4 StatsSystem

职责：

- clamp 所有状态。
- 计算稳定度。
- 计算饮食质量。
- 应用每日结算。
- 输出状态变化日志给 UI。

核心原则：

- 所有公式集中在这里。
- UI 不直接改状态。
- 每次结算返回 `StatChangeLog`，便于动画和调试。

### 8.5 ComboSystem

职责：

- 根据本餐卡牌标签检测组合。
- 防止同一组合每天重复触发。
- 应用组合效果。
- 记录图鉴历史。

原型只实现：

- `balanced_meal`
- `quick_fill`

### 8.6 EndingSystem

原型结局：

```text
Collapsed:
  stability <= 10 持续 2 天
  或 Day 7 study_progress < 30

StableEndurance:
  stability >= 60
  且 study_progress >= 70
  且 mood >= 40
  且 diet_burden <= 55

BarelySurvived:
  Day 7
  且未满足以上结局
  且 study_progress >= 50
  且 stability >= 25

Collapsed fallback:
  Day 7 仍不满足 BarelySurvived
```

### 8.7 EconomySystem

原型职责很轻：

- 扣钱。
- 判断余额不足。
- 计算预算安全度。

采购和库存 Phase 2 再做。

### 8.8 NarrativeSystem

原型只做固定天数短文本：

| 天数 | 文本方向 |
|---:|---|
| Day 1 | 打开复习计划，发现时间不够 |
| Day 3 | 外卖满减与复习压力同时到来 |
| Day 5 | 意识到不能只靠奶茶硬撑 |
| Day 7 | 根据结局展示收尾 |

后续再加入状态触发剧情。

---

## 9. UI/UX 方案

### 9.1 移动端优先布局

基准分辨率：`390 x 844` 竖屏。

```text
TopBar
  第 X 天 / 7 天    设置

StabilityPanel
  稳定度条 + 文案

ResourceStrip
  余额 / 精力 / 心情 / 饱腹 / 复习

EventBanner
  今日状态或剧情短句

MealBoard
  早餐 / 午餐 / 晚餐槽位
  当前阶段高亮

HandView
  横向滚动卡牌

BottomActionBar
  确认 / 跳过 / 详情
```

### 9.2 PC 端布局

PC 不重做一套逻辑，只换布局容器：

```text
左侧：角色状态、今日记录、剧情
右侧：餐盘/行动区、手牌、操作按钮
顶部：天数、稳定度、余额
底部：组合提示和日志
```

### 9.3 交互原则

原型阶段采用「点击选择」而不是拖拽。

原因：

- 移动端更稳定。
- 实现成本低。
- 更容易做键鼠和触屏统一。

交互流程：

1. 点击手牌卡，卡牌进入候选区。
2. 再点击可取消选择。
3. 满足当前阶段限制后，确认按钮亮起。
4. 点击确认，卡牌飞入餐盘槽位并结算。

Phase 2 再补拖拽手感。

### 9.4 反馈层级

| 事件 | 反馈 |
|---|---|
| 打出普通卡 | 卡牌轻微缩放、滑入槽位 |
| 扣钱 | 余额数字跳动 |
| 心情/精力变化 | 对应资源条短暂发光 |
| 组合触发 | 屏幕中部 toast + 音效 |
| 稳定度危险 | 稳定度条变为暖红，但文案不羞辱 |
| 每日结束 | 日志总结，不显示营养报表 |

### 9.5 文案语气规则

禁止：

- “你吃错了。”
- “这个不健康。”
- “你失败了。”

建议：

- “这顿帮你撑过了晚上，但身体负担也上来了。”
- “今天没有很完美，不过节奏还在。”
- “吃得很克制，但压力已经有点高。”

---

## 10. 美术与音频路线

### 10.1 原型美术

第一版使用：

- 纯色 UI。
- 简单图标。
- 卡牌使用 emoji 或占位图标。
- 角色立绘用剪影或单张占位插画。

目标不是好看，而是可读、可玩、能测试数值。

### 10.2 正式美术方向

风格：

- 2D 手绘/插画。
- 暖色但不过度奶油。
- 生活物件质感：课桌、便利店袋子、食堂托盘、手机外卖界面。

卡牌图：

- Phase 3 前可用图标 + 色块。
- 正式版优先画高频食物和角色。
- 不需要每张卡都做复杂插画。

### 10.3 音频

原型只需要：

- UI 点击。
- 出牌。
- 组合触发。
- 低稳定度提示。

正式版再加入：

- Lo-fi 背景音乐。
- 角色主题氛围。
- 手机通知、纸张翻动、餐具轻响。

---

## 11. 实现路径

### 11.1 Phase 0：Godot 项目初始化（1-2 天）

目标：创建干净项目骨架。

任务：

- 创建 Godot 4.7 项目。
- 设置主场景 `Boot.tscn`。
- 设置窗口：移动竖屏基准，PC 可拉伸。
- 配置 renderer。
- 建立目录结构。
- 建立 Autoload。
- 加入基础字体，确保中文显示。
- 写 `DataRegistry` 空加载流程。

验收：

- 项目能启动到主菜单。
- 中文字体正常。
- headless 启动无错误。

### 11.2 Phase 1：纯逻辑原型（3-5 天）

目标：不做 UI，先让一局在日志中跑通。

任务：

- 实现 `RunState`。
- 实现 `CardConfig`、`CharacterConfig`、`ComboConfig`。
- 手写 15 张食物卡 `.tres`。
- 手写学生角色 `.tres`。
- 实现 `StatsSystem`。
- 实现 `CardSystem`。
- 实现 `ComboSystem`。
- 实现 `EndingSystem`。
- 写 `TestDayFlow.gd` 模拟 7 天。

验收：

- 能用固定输入跑完 7 天。
- 至少能跑出三种结局。
- 稳定度不会出现 NaN、负数溢出或异常飙升。

### 11.3 Phase 2：可玩 UI 原型（1-2 周）

目标：玩家能点卡、过天、看到结局。

任务：

- 搭建 `GameRoot.tscn`。
- 搭建 `CardView.tscn`。
- 搭建 `HandView.tscn`。
- 搭建 `MealSlot.tscn`。
- 实现进餐阶段 UI。
- 实现行动阶段 UI。
- 实现每日总结弹窗。
- 实现结局界面。
- 加入基础动画和 toast。

验收：

- 玩家可以从第 1 天玩到第 7 天。
- 每天流程不会卡死。
- 所有按钮在移动端尺寸可点。
- 状态变化能被玩家理解。

### 11.4 Phase 3：原型调参与体验验证（1 周）

目标：让核心循环有策略性。

任务：

- 连玩至少 10 局。
- 记录每局路线、结局、崩盘原因。
- 调整食物价格和效果。
- 调整复习进度压力。
- 调整稳定度权重。
- 加入更清楚的每日总结文案。

验收：

- 新手正常路线约 50% 能稳稳撑过。
- 完全放纵路线大概率崩盘或勉强撑过。
- 完全克制路线不一定最优。
- 奶茶、方便面、炸鸡至少在某些局面有合理价值。

### 11.5 Phase 4：系统完整体验（4-6 周）

目标：从原型变成完整核心游戏。

任务：

- 加入 5 个基础角色。
- 加入完整 30 张食物卡。
- 加入 12-18 张行为卡。
- 加入 8-12 张心理卡。
- 加入生活事件系统。
- 加入采购和轻库存。
- 加入 8 种组合。
- 加入 6+2 种结局。
- 加入 14 天模式。
- 加入局外解锁。
- 加入基本存档。

验收：

- 五个角色的玩法明显不同。
- 每个角色至少有一种独特困境。
- 生活事件能改变策略，而不是只加减数值。
- 心理卡能抵消“越克制越好”的错误倾向。

### 11.6 Phase 5：内容与表现打磨（4-8 周）

目标：把游戏从「能玩」提升到「愿意反复玩」。

任务：

- 正式 UI 风格。
- 角色立绘。
- 卡牌图标或插画。
- BGM/SFX。
- 食谱图鉴。
- 角色剧情。
- 可访问性设置。
- 本地化第一版。
- 移动端和 PC 适配。

验收：

- 外部玩家能不看说明完成第一局。
- UI 不像营养软件。
- 文案温和、有生活感。
- 移动端一局可在 15-25 分钟内完成。

### 11.7 Phase 6：发布准备（2-4 周）

目标：面向 Steam/移动端打包。

任务：

- 导出 Windows/macOS/Linux。
- 导出 Android 测试包。
- iOS 视团队设备决定。
- 性能测试。
- 存档兼容性测试。
- 字体授权和素材授权检查。
- 商店截图、宣传文案。
- 免责声明和健康主题审校。

---

## 12. 测试策略

### 12.1 逻辑测试

使用 Godot headless 跑脚本：

```text
godot --headless --path . --script res://scripts/tests/TestRunner.gd
```

覆盖：

- 卡牌效果结算。
- 饮食质量计算。
- 稳定度公式。
- 组合检测。
- 每日流程状态机。
- 结局判定。

### 12.2 数值模拟

至少写 5 条固定路线：

| 路线 | 行为 |
|---|---|
| 均衡路线 | 规律三餐、适度复习、偶尔休息 |
| 放纵路线 | 奶茶、炸鸡、方便面、高压力 |
| 省钱路线 | 白米饭、鸡蛋、青菜为主 |
| 硬卷路线 | 每天复习、不休息、饮食随便 |
| 摆烂路线 | 少复习、高安慰食物 |

每条路线输出：

- Day 1-7 状态。
- 触发组合。
- 最终结局。
- 关键风险提示。

### 12.3 UI 测试

手动检查：

- 390 x 844 移动竖屏。
- 375 x 812 小屏。
- 1920 x 1080 PC 横屏。
- 1366 x 768 低高度 PC。

重点：

- 卡牌文字是否溢出。
- 按钮是否可点。
- 资源条是否遮挡。
- 结算弹窗是否过长。
- 中文字体是否缺字。

---

## 13. 风险与对应措施

| 风险 | 影响 | 措施 |
|---|---|---|
| 第一版系统太大 | 原型迟迟不可玩 | 严格只做学生 7 天 |
| 变成营养计算器 | 主题跑偏 | 主界面隐藏营养细项，只显示生活状态 |
| 最优解单一 | 重玩价值低 | 价格、压力、复习进度共同制约 |
| UI 信息过载 | 玩家看不懂 | 每屏只强调当前阶段要做的事 |
| 文案说教 | 破坏气质 | 用生活化反馈，不做道德评价 |
| Godot Resource 太碎 | 管理困难 | 一卡一文件，但用 DataRegistry 汇总和校验 |
| 移动适配拖慢开发 | 排期膨胀 | 移动竖屏为主，PC 只是重排 |
| 数值平衡耗时 | 迭代困难 | 早期写 headless 模拟路线 |

---

## 14. 第一周具体任务清单

### Day 1

- 创建 Godot 4.7 项目。
- 建立目录结构。
- 创建 `Boot.tscn`、`MainMenu.tscn`。
- 配置 Autoload。
- 导入中文字体。

### Day 2

- 创建 Resource 脚本。
- 创建学生角色配置。
- 创建 15 张食物卡配置。
- 创建 4 张行动卡配置。
- DataRegistry 能加载并校验 ID。

### Day 3

- 实现 `RunState`。
- 实现 `StatsSystem`。
- 实现 `CardSystem`。
- 写基础测试：单张卡效果、扣钱、clamp。

### Day 4

- 实现 `DayManager` 状态机。
- 实现三餐流程。
- 实现行动流程。
- 实现睡眠选择。

### Day 5

- 实现 `ComboSystem`。
- 实现 `EndingSystem`。
- 写 5 条模拟路线。
- 输出第一份数值观察。

### Day 6-7

- 搭建最简 `GameRoot` UI。
- 卡牌可点击。
- 餐盘可确认。
- 每日可推进。
- 先不追求美术，只追求完整可玩。

---

## 15. 近期决策建议

### 15.1 先不要做的内容

不要在第一版做：

- 多角色。
- 完整心理卡。
- 库存保质期。
- 拖拽交互。
- 动态事件叠加。
- 复杂图鉴。
- 正式美术。

这些都很诱人，但会掩盖核心循环是否成立。

### 15.2 必须尽早做的内容

尽早做：

- Headless 数值模拟。
- 每日总结文案。
- 稳定度解释。
- 复习进度压力。
- 奶茶/方便面/炸鸡的正负两面。

这个游戏的灵魂不在卡牌数量，而在「玩家知道自己为什么这样选」。

### 15.3 最小可玩版本定义

当满足以下条件，就可以称为 MVP：

- 从主菜单进入游戏。
- 选择熬夜学生。
- 完成 7 天。
- 每天能吃三餐、做行动、睡觉。
- 稳定度、余额、精力、心情、饱腹、复习进度会变化。
- 至少触发均衡餐盘和快速饱腹。
- 最后出现合理结局。
- 玩家能在不看开发者解释的情况下理解「我为什么撑住/没撑住」。

---

## 16. 参考资料

- Godot 4.7 Release: https://godotengine.org/releases/4.7/
- Godot Resources: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
- Godot Autoload: https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- Godot UI Containers: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html
- Godot Internationalization: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html

