# CodeX Godot 4.7 方案审查 & Godot MCP 开发规范

> **文档用途**: 对 CodeX 生成的 Godot 方案进行问题审查，并基于 Godot MCP 工具能力制定 AI 辅助开发规范。

---

# 第一部分：CodeX 方案审查

## 总体评价：优秀，但需修正 12 处

CodeX 的方案整体质量很高。方向正确——优先原型、单角色、7天、验证核心循环。架构合理——Autoload 精简、系统层独立、配置与运行时分离。但有若干技术细节和设计遗漏需要修正。

---

## 问题清单

### 🔴 问题 1：RunState 不应使用 RefCounted

**位置**: §7.2 `RunState.gd`

**问题**: CodeX 的方案中 `RunState extends RefCounted`，但 RefCounted 的引用计数机制在 Godot 中容易因为信号绑定（Signal）导致过早释放或泄漏。`RunState` 作为单局核心状态会被多个 System 和 UI 引用，用 RefCounted 不安全。

**修正**: 改为 `extends Resource`。Resource 的生命周期由 Godot 的资源系统管理，更可控。或者直接作为普通 Object 由 RunController 持有。

```gdscript
# 修正后
class_name RunState
extends Resource  # 不是 RefCounted
```

**影响**: 中等。可能导致运行时偶发性 nil 引用崩溃。

---

### 🔴 问题 2：EffectBundle 设计不适用于多卡类型

**位置**: §7.1 `EffectBundle.gd`

**问题**: 当前 EffectBundle 把食物卡、行为卡、心理卡的字段都塞进同一个 Resource。但行为卡的 `study_progress_delta` 对食物卡毫无意义，食物卡的 `satiety_delta` 对心理卡也多余。所有字段设 @export 会让 `.tres` 文件出现大量无意义的 `= 0` 字段，增加维护负担。

**修正**: 拆分为 `FoodEffect`、`ActionEffect`、`PsychoEffect` 三个独立 Resource，CarConfig 中用 `@export var effects: Resource` 然后在代码中按 type 做类型检查。

```gdscript
# 更干净的方案
class_name FoodEffects
extends Resource
@export var satiety: int = 0
@export var mood: int = 0
@export var energy: int = 0
@export var stress: int = 0
@export var diet_burden: int = 0
@export var hidden_protein: int = 0
@export var hidden_sugar: int = 0
@export var hidden_fat: int = 0
@export var hidden_fiber: int = 0
@export var hidden_sodium: int = 0
@export var hidden_energy_kcal: int = 0

class_name ActionEffects
extends Resource
@export var time_cost: int = 0
@export var energy: int = 0
@export var stress: int = 0
@export var mood: int = 0
@export var goal_progress: int = 0
@export var satiety: int = 0

class_name PsychoEffects
extends Resource
@export var stress: int = 0
@export var mood: int = 0
@export var anxiety: int = 0
@export var self_control: int = 0
```

**影响**: 中等。当前设计在原型阶段可用，但随着卡牌种类增加会越来越难维护。

---

### 🟡 问题 3：缺睡眠质量和自控力指标

**位置**: §4.1 指标系统

**问题**: RunState.stats 字典和公式中都没有 `sleep_quality` 和 `self_control`，但这两个指标在原 GDD 中对熬夜学生角色至关重要：
- 睡眠质量影响次日精力恢复量
- 自控力影响高诱惑食物的选择成本

**修正**: 在 RunState.stats 中加入 `sleep_quality` 和 `self_control`（原型阶段可以设为半隐藏，不显示在主界面但参与结算）。

```gdscript
var stats := {
  &"stability": 65,
  &"balance": 120,
  &"energy": 50,
  &"mood": 55,
  &"satiety": 60,
  &"stress": 55,
  &"diet_burden": 25,
  &"diet_quality_today": 50,
  &"sleep_quality": 30,   # 新增
  &"self_control": 60,    # 新增
}
```

**影响**: 低（原型阶段可忽略，但 Phase 2 必须补）。缺少这两个指标会让稳定度公式的输入维度过少。

---

### 🟡 问题 4：牌库补牌机制不完整

**位置**: §8.3 "每天开始补到 5 张手牌"

**问题**: 只说了"补到 5 张"，但没有定义：
1. 抽牌堆耗尽时如何处理？（需要弃牌堆洗入）
2. 初始抽牌堆里有什么卡？（原型中手牌从哪里来？）
3. 食物卡和行动卡是否同一个牌库？（方案说"同一个手牌"，那牌库呢？）

**修正**: 明确定义原型阶段的牌库初始化规则：

```gdscript
# 原型阶段简化规则
# 1. 每天开始时从抽牌堆补充手牌至 5 张
# 2. 抽牌堆耗尽时，将弃牌堆洗入抽牌堆
# 3. 初始抽牌堆 = 15张食物卡 + 4张行动卡 = 19张
# 4. 食物卡和行动卡共用同一个牌库，手牌也是混合的
# 5. 不设牌库构筑——每局都是同一套卡
```

再加上"救急卡"机制（手牌没有食物卡时自动给白米饭/方便面）：

```gdscript
# CardSystem.gd
func ensure_meal_possible() -> void:
    var has_food = hand.any(func(cid): return card_type(cid) == "food")
    if not has_food:
        # 从救急池随机给一张
        var rescue = ["rice_plain", "instant_noodles"].pick_random()
        hand.append(rescue)
        emit_signal("rescue_card_added", rescue)
```

**影响**: 中等。没有补牌规则会导致 Day 3 以后手牌异常。

---

### 🟡 问题 5：缺少采购/获得食物的途径

**位置**: §3 每日流程

**问题**: 原型的每日流程只有 BREAKFAST → LUNCH → DINNER → ACTION → SLEEP，但**没有采购阶段**。学生角色虽然不能做饭，但应该能"去食堂"或"去便利店"获得食物。如果每顿饭只能从 19 张牌的池子里抽，玩家可能在第 4 天就打光了所有食物卡。

**修正**: 在进餐阶段之前加入一个简单的采购阶段（不消耗行动格，只是一个"今天吃啥"的选择界面）：

```gdscript
# 廉价采购选项（学生可用）：
# - 去食堂：花费 ¥8，获得 1 随机食堂菜 + 1 米饭
# - 便利店：花费 ¥10，获得 1 随机速食/零食
# - 不采购：全靠手牌（但可能不够）
# 采购在早晨发生之前执行
```

或者更简单的方案：每天早晨自动补牌时，不仅从弃牌堆洗入，还从"场景池"中额外加入 2-3 张卡（模拟可获得的食物选择）。

**影响**: 中等。没有食物补充途径会导致后期策略选择枯竭。

---

### 🟡 问题 6：移动端安全区域未适配

**位置**: §9.1 移动端布局

**问题**: 移动端基准 `390 x 844` 没有考虑刘海屏（notch）和底部 Home Indicator 的安全区域。2024 年以后发布的手机几乎全是全面屏，没有安全区域适配会导致 UI 元素被遮挡。

**修正**: 在 GameRoot 中增加安全区域适配：

```gdscript
# GameRoot.gd
func _ready():
    # 适配安全区域
    if OS.has_feature("mobile"):
        var safe_area = DisplayServer.get_display_safe_area()
        var margin_top = safe_area.position.y
        var margin_bottom = get_viewport().get_visible_rect().size.y - safe_area.end.y
        # 应用到 MainLayout
        main_layout.add_theme_constant_override("margin_top", margin_top)
        main_layout.add_theme_constant_override("margin_bottom", margin_bottom)
```

**影响**: 低（原型阶段可忽略，发布前必须修）。

---

### 🟡 问题 7：不吃饭的兜底逻辑需明确触发时机

**位置**: §3.3 "手牌无法满足进餐时给救急卡"

**问题**: 兜底逻辑的触发需要明确条件。如果玩家手上有 3 张食物卡但都因为余额不足用不了怎么办？如果玩家有食物卡但主动选择不吃呢？这些边缘情况会导致状态机卡住。

**修正**: 明确定义：

```gdscript
# DayManager.gd 进餐阶段
func enter_meal_phase(meal_type: StringName) -> void:
    var playable_food = hand.filter(func(cid):
        return DataRegistry.get_card(cid).type == "food"
            and DataRegistry.get_card(cid).cost <= RunState.stats["balance"]
    )

    if playable_food.is_empty():
        # 情况1: 没钱 → 给免费救急卡
        var rescue = ["rice_plain", "instant_noodles"].pick_random()
        RunState.hand.append(rescue)
        EventBus.emit_signal("rescue_card", rescue, "余额不足，凑合吃点")
    # else: 正常选择
```

**影响**: 低（但会导致原型阶段 bug）。

---

### 🟡 问题 8：测试框架选择不明确

**位置**: §12.1 "使用 Godot headless 跑脚本"

**问题**: CodeX 提到了 `TestRunner.gd` 但没有说明用什么测试框架。手写测试 Runner 在早期看似简单，但没有断言库、分组、mock 等基础设施，后期测试会很难维护。

**修正**: 推荐使用 **GdUnit4**（最成熟的 Godot 测试框架）：

```gdscript
# 示例: tests/TestStatsSystem.gd (GdUnit4 语法)
extends GdUnitTestSuite

func test_stability_clamp():
    var stats = StatsSystem.new()
    assert_that(stats.clamp_stat(120)).is_equal(100)
    assert_that(stats.clamp_stat(-10)).is_equal(0)

func test_diet_quality_calculation():
    # ... 
```

运行：
```bash
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd
```

如果没有时间集成 GdUnit4，至少用以下最简方案：

```gdscript
# scripts/tests/TestRunner.gd
extends Node

func _ready():
    var passed = 0
    var total = 0
    
    # 每个测试是一个方法调用 + assert
    total += 1
    if test_stability_clamp(): passed += 1
    
    print("Result: %d/%d passed" % [passed, total])
    if passed < total:
        get_tree().quit(1)
    else:
        get_tree().quit(0)
```

**影响**: 低（原型阶段不阻塞，Phase 3 前建议引入）。

---

### 🟡 问题 9：中文本地化方案不完整

**位置**: §6.1 目录结构中的 `localization/zh_CN.csv`

**问题**: Godot 原生支持 `.po`/`.pot` 和 `.csv` 两种格式。CodeX 方案使用了 `.csv`，但 Godot 的 CSV 本地化格式要求特定列结构 (`keys,zh_CN,en`)。没有说明导入设置和 failback 逻辑。

**修正**: 

```csv
# localization/base.csv (Godot Translation CSV 格式)
keys,zh_CN,en
card.rice_plain.name,白米饭,Plain Rice
card.rice_plain.desc,"便宜的碳水来源，暖胃。","A cheap source of carbs. Comforting."
character.student.name,小林,Xiao Lin
ending.stable.name,稳稳撑过,Stable Endurance
```

在 Project Settings → Localization → Auto Accept Languages 中设置 `zh_CN, en`。使用 `tr("card.rice_plain.name")` 获取翻译。

**一种更务实的做法**（原型阶段）：用 GDScript 字典做一个最小本地化层，不依赖 Godot 内置系统：

```gdscript
# autoload/Localization.gd
extends Node
var _dict := {}
func load_locale(locale: String):
    # 读取 CSV 构建字典
    pass
func t(key: String) -> String:
    return _dict.get(key, "MISSING:%s" % key)
```

**影响**: 低（原型阶段可全部用硬编码中文，Phase 4 再接入正式方案）。

---

### 🟢 问题 10：CardConfig 中用 Dictionary 存 hidden_nutrition 不够类型安全

**位置**: §7.1 `CardConfig.gd`

**问题**: `@export var hidden_nutrition: Dictionary = {}` 在 Godot 中导出 Dictionary 会在 Inspector 中显示为原始 JSON 编辑框，非常难用且容易写错 key。

**修正**: 改为独立的 Resource 类型：

```gdscript
class_name NutritionProfile
extends Resource
@export var energy_kcal: int = 0
@export var protein: int = 0
@export var fat_burden: int = 0
@export var sugar_burden: int = 0
@export var fiber: int = 0
@export var sodium_burden: int = 0
```

然后在 CardConfig 中：
```gdscript
@export var nutrition: NutritionProfile
```

这样 Inspector 中会以子属性展开，清晰且不易出错。

**影响**: 低（不影响功能，但影响配置效率）。

---

### 🟢 问题 11：ComboConfig.required_tags 用 Dictionary 检测逻辑不清晰

**位置**: §7.1 `ComboConfig.gd`

**问题**: `@export var required_tags: Dictionary = {}` 没有定义 key/value 分别代表什么。组合检测需要"标签名：最少数量"的映射，但 Dictionary 在 Godot Inspector 中不好编辑。

**修正**:

```gdscript
class_name TagRequirement
extends Resource
@export var tag: StringName
@export var min_count: int = 1

class_name ComboConfig
extends Resource
# ...
@export var must_have_tags: Array[TagRequirement] = []
@export var must_not_have_tags: Array[StringName] = []
```

这样 Inspector 中可以逐条添加/删除标签要求。

**影响**: 低（体验问题，不影响逻辑正确性）。

---

### 🟢 问题 12：Phase 0 缺少 Git 初始化

**位置**: §11.1

**问题**: Phase 0 任务列表中没有 `.gitignore` 和 `.gitattributes` 的创建。Godot 项目需要忽略 `/.godot/`、`*.translation`（编译产物）等。

**修正**: 在 Phase 0 中加入：

```text
- 创建 .gitignore:
    /.godot/
    *.translation
    .import/
    export_presets.cfg
    日志文件等
- 创建 .gitattributes (GDScript 二进制文件 diff 处理)
- git init && git commit -m "Initial Godot 4.7 project"
```

---

## CodeX 方案中值得保留的优秀设计

| 设计决策 | 评价 |
|---|---|
| Phase 0-6 渐进式路线 | **最佳部分**。先跑通逻辑再碰 UI，先做学生再做其他角色 |
| Autoload 只用 5 个 | 控制全局状态，防止 Godot 新手常见的 Autoload 爆炸 |
| "点击选择"而非拖拽 | 务实。拖拽的跨平台调优很耗时 |
| RunController + Systems 分离 | 清晰的职责边界，后续好定位 bug |
| Headless 数值模拟 | 早发现公式问题，避免 UI 做好后再大改数值 |
| 原型只做学生 7 天 | 严格的 MVP 思维，防止范围蔓延 |
| 移动竖屏为主，PC 只重排 | 先保证一个平台的体验正确 |
| ID 统一蛇形命名 + L10n Key | 工程规范好，方便全局搜索和重构 |

---

# 第二部分：Godot MCP 开发规范

## 1. MCP 能力列表

根据 CodeX 的配置，Godot MCP (`godot-ai`) 提供以下工具：

| 工具类别 | 工具名 | 功能 | 开发场景 |
|---|---|---|---|
| **场景** | `scene_get_hierarchy` | 读取场景节点结构 | 了解当前打开的场景结构，避免凭空猜测节点路径 |
| | `scene_open` | 打开 `.tscn` 文件 | 切换到目标场景开始工作 |
| | `scene_save` | 保存当前场景 | 完成修改后保存 |
| | `scene_manage` | 场景的创建/删除/重命名 | 创建新场景或管理场景文件 |
| **脚本** | `script_create` | 创建 GDScript 文件 | 新建 `.gd` 脚本 |
| | `script_manage` | 脚本的管理操作 | 移动/重命名脚本 |
| **项目管理** | `project_manage` | 项目管理（创建/打开） | 初始化 Godot 项目 |
| | `project_run` | 运行项目 | 测试游戏行为，观察运行时表现 |
| | `test_run` | 运行测试 | 执行测试套件 |
| | `filesystem_manage` | 文件系统操作 | 创建目录、移动文件、导入资源 |
| **编辑器** | `editor_state` | 获取编辑器状态 | 了解当前选中了什么、编辑器模式 |
| | `editor_manage` | 编辑器操作 | 切换编辑器布局、模式等 |
| | `editor_screenshot` | 编辑器截图 | 查看编辑器界面状态 |
| | `logs_read` | 读取输出日志 | 调试——查看错误和警告 |
| **会话** | `session_manage` | 会话管理 | |
| | `session_activate` | 激活会话 | |
| **游戏运行** | `game_manage` | 游戏实例管理 | 运行时操作 |

## 2. MCP 驱动的开发工作流

### 2.1 新建功能的标准流程

```text
Step 1: 了解现状
  - scene_get_hierarchy  → 看当前场景有哪些节点
  - editor_state         → 看编辑器当前状态
  - Glob/Grep            → 看相关脚本代码

Step 2: 创建资源（如需）
  - filesystem_manage    → 创建目录
  - script_create        → 创建新 GDScript
  - Write                → 写入脚本内容

Step 3: 修改场景（如需）
  - scene_open           → 打开目标场景
  - Edit/Write           → 修改场景文件（Godot .tscn 是文本格式，可直接编辑）
  - scene_save           → 保存

Step 4: 验证
  - project_run          → 运行游戏
  - logs_read            → 检查日志
  - preview_start        → 启动浏览器预览（如果是网页导出）
```

### 2.2 调试 Bug 的标准流程

```text
Step 1: 重现
  - project_run          → 运行项目
  - logs_read            → 读取错误日志

Step 2: 定位
  - Grep                 → 搜索相关代码
  - Read                 → 读取可疑文件
  - scene_get_hierarchy  → 确认节点结构

Step 3: 修复
  - Edit                 → 修改代码
  - project_run          → 重新运行验证

Step 4: 确认
  - logs_read            → 确认无新错误
  - test_run             → 运行测试确认无回归
```

### 2.3 新增卡牌/数据的标准流程

```text
Step 1: 创建配置文件
  - filesystem_manage    → 确保 data/cards/food/ 目录存在
  - Write                → 创建 .tres 文件

Step 2: 验证加载
  - 写一个简单的加载测试
  - test_run / project_run → 确认 DataRegistry 能正确加载新卡

Step 3: 更新相关系统
  - Edit                 → 修改 ComboSystem/StatsSystem 等
  - test_run             → 运行测试
```

## 3. MCP 使用原则

### 3.1 什么时候用 MCP，什么时候用文件操作

| 场景 | 用 MCP | 用 Write/Edit/Bash | 原因 |
|---|---|---|---|
| 创建 `.gd` 脚本 | `script_create` 或 `Write` | `Write` 也可以 | MCP 可以自动处理 class_name 和模板 |
| 读取场景结构 | `scene_get_hierarchy` | 不要读 `.tscn` 原文 | 场景文件冗长，MCP 返回结构化数据 |
| 创建 `.tres` 资源 | **直接 Write** | Write `.tres` 文件 | Godot Resource 本质是纯文本 `.tres`，直接写更快 |
| 运行游戏 | `project_run` | 不要用 Bash 运行 | MCP 会管理运行实例 |
| 修改代码 | **Read + Edit** | 不要用 MCP | 代码修改用文件操作最直接可靠 |
| 创建新场景 | `Write` 或 `scene_manage` | 两者都可以 | `.tscn` 本质是文本，可以直接手写结构 |
| 查看日志 | `logs_read` | 不要读日志文件 | MCP 格式化输出，更好读 |
| 移动/重命名 | `filesystem_manage` | `Bash mv` | 随喜好 |
| 编辑器截图 | `editor_screenshot` | - | 只有 MCP 能做到 |
| 运行测试 | `test_run` | 可以用 Bash | MCP 可能处理测试框架的调用细节 |

### 3.2 `.tres` 文件的直接编写规范

Godot `.tres` 文件是纯文本格式，AI 可以直接用 Write 工具创建，无需 Godot 编辑器交互。这比通过 MCP 逐字段创建更高效。

**标准 `.tres` 模板**：

```toml
[gd_resource type="Resource" script_class="CardConfig" load_steps=3 format=3 uid="uid://abc123"]

[ext_resource type="Script" path="res://scripts/resources/CardConfig.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/art/cards/rice_plain.png" id="2_icon"]
[ext_resource type="Resource" path="res://scripts/resources/EffectBundle.gd" id="3_effects"]

[resource]
script = ExtResource("1_script")
id = &"rice_plain"
type = &"food"
sub_type = &"staple"
display_name_key = "card.rice_plain.name"
description_key = "card.rice_plain.desc"
rarity = &"common"
cost = 2
effects = ExtResource("3_effects")
tags = Array[StringName]([&"staple", &"cheap", &"plain"])
```

但是 **UGC ID（uid）需要 Godot 编辑器自动生成**。绕过方法：

1. 最简单：不带 `uid`，Godot 打开时会自动分配
2. 或者：让 Godot 编辑器打开一次自动补齐

**推荐做法**：AI 直接 Write `.tres` 文件时不带 `uid` 行，Godot 编辑器打开时会自动分配。

### 3.3 `.tscn` 场景文件的直接编写规范

Godot `.tscn` 也是纯文本，但格式复杂。**原则：简单场景（≤ 10 个节点）直接 Write `.tscn`，复杂场景用 MCP `scene_manage` 一步步创建。**

**简单场景示例**（可以直接写）：

```toml
[gd_scene load_steps=1 format=3]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -100.0
offset_right = 150.0
offset_bottom = 100.0

[node name="Title" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "撑过这一周"
horizontal_alignment = 1

[node name="StartButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "开始游戏"
```

## 4. Git 与 AI 协作规范

### 4.1 每次 AI 操作后必须

1. **检查 `project.godot` 是否被意外修改**（Godot 有时会自动调整 Autoload 顺序、Input Map 等）
2. **确保 `.godot/` 不被提交**（必须在 `.gitignore` 中）
3. **`.tres` 和 `.tscn` 文件的 uid 冲突**——如果复制粘贴，记得删除 uid 行让 Godot 重新生成

### 4.2 Commit 规范

```text
游戏功能（玩家可见）:
  feat: 添加均衡餐盘组合
  feat: 实现每日结算
  fix: 修复稳定度 NaN 问题
  balance: 调整学生角色初始预算

技术改进（玩家不可见）:
  refactor: 拆分 EffectBundle 为 FoodEffect/ActionEffect
  chore: 创建 .gitignore
  test: 添加 StatsSystem 测试
```

### 4.3 Branch 策略（小团队）

```text
main       ← 始终可运行（至少能启动到主菜单）
  └─ prototype/student-7days  ← Phase 0-3 原型阶段全部在这里
  └─ feature/psychological-cards
  └─ fix/stability-nan
```

原型阶段可以不严格遵守，但 `main` 必须始终能跑。

## 5. AI 辅助开发的最佳实践

### 5.1 每次对话开始时

让 AI 先执行：
```text
1. scene_get_hierarchy  → 了解当前场景
2. Glob *.gd            → 了解脚本文件结构
3. Read project.godot   → 了解 Autoload 和项目配置
```

### 5.2 编写 GDScript 时的 AI 约束

```text
- 遵循 GDScript 风格指南（蛇形变量、帕斯卡类名）
- 所有 class_name 必须在文件开头
- 信号声明在 extends 之后、func 之前
- @onready 变量写在 _ready() 之前
- 每个 func 不超过 60 行
- 避免循环依赖（A 系统引 B，B 又引 A）
- 使用 EventBus 信号解耦，而不是系统间直接调用
```

### 5.3 单次 AI 操作的范围限制

```text
一次修改 ≤ 3 个文件（除非是批量创建配置文件）
一次修改在同一系统内（如都在 StatsSystem 内）
修改后 → project_run → logs_read → 确认无误 → 继续下一步
```

### 5.4 数值调参时

```text
1. 用 Edit 修改常量定义（集中在 StatsSystem.gd 或配置 Resource 中）
2. project_run 运行游戏
3. 不要依赖 AI 凭空判断数值——让 AI 运行 headless 模拟
4. 归档调参记录（每次改动前的值和改动原因）
```

## 6. 快速启动检查清单

用 AI 开始本项目的 Godot 开发时，按以下顺序检查：

```text
□ Godot 编辑器是否已打开？
□ MCP 是否连接？ → 尝试 scene_get_hierarchy
□ project.godot 是否存在？ → 确认引擎版本为 4.7
□ .gitignore 是否包含 .godot/？
□ Autoload 是否已配置？ → Read project.godot
□ 中文字体是否能正常显示？ → project_run 验证
□ DataRegistry 能加载 .tres 文件吗？ → test_run 或 headless 验证
```

---

> **文档版本**: v1.0  
> **最后更新**: 2026-07-08
