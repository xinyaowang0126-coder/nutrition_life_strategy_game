# 开发交接记录

记录日期：2026-09-04。用于在新的 Codex 任务中续接开发；开工前以实际文件和 Git 状态核对本记录。

## 1. 工作位置与当前约定

- 仓库：`E:\nutrition_life_strategy_game`。
- Godot 项目：`E:\nutrition_life_strategy_game\life-strategy`。
- 当前分支：`codex/nutrition-health-m2`。
- 当前 HEAD：`8d4345c`，为已提交的 NUT-206 文档检查点；此前源码提交为 `fe441ef`，插件导出设置修复为 `51c21d2`。这些提交此前已推送到开发分支。
- **NUT-207、Godot AI 3.2.5 插件升级及本交接记录仍在本地工作区，尚未提交或推送。** 新任务先读 `git status --short` 和相关差异，保留修改与未跟踪文件。
- 用户当前要求继续开发、暂不发布。换对话本身不触发提交、推送、合并或导出；后续按用户指令处理。
- `main` 与 `Play/` 保持原样，线上包仍为 2026-07-14 的 v0.3。源码开发进度不能当作线上版本。
- 续接当前未提交成果时，使用本机同一目录；若另建工作树或换机器，必须确认最新修改和未跟踪文件实际已带入。避免两个任务同时修改此目录。

## 2. 已完成的工作

游戏已有七天闭环、四种用餐来源、宿舍补货、周内事件、次日状态和结局。旧原型计划中的同名功能不应重新当作缺失功能。

- **NUT-205**：23 项食物均有独立健康资料，13 项固定游戏规格、10 项保守品类资料；全部仍为 `draft`。
- **NUT-206**：不可变用餐健康快照、独立 JSON 历史和 V2 用餐接入完成。历史读取不重算、不混入当前局；这不是完整游戏存档或断点续玩。
- **NUT-207**：已完成工程及验收。23 项食物原 `mood` 迁入 `data/characters/default_food_preferences.xml`；默认值保持，只有奶茶、方便面、炸鸡显式配置 `comfort`。V1/V2 展示与结算共用本局角色偏好，健康快照不包含口味。显式空/非法偏好按未知、中性处理，不回退到食物旧字段或营养标签。
- 食物卡和详情显示角色口味；详情弹窗旧折行高度缓存造成的越界、换卡/关闭的异步显隐竞态已修复。

重点实现位于 `life-strategy/scripts/systems/FoodPreferenceService.gd`、`MealResolver.gd`、`scripts/ui_v2/GameRootV2.gd` 和 `StickyNotePopup.gd`；不要把食物顶层 `mood` 或 `favorite/mood` 标签加回。

## 3. 验证基线

Godot AI 更新到 3.2.5 后，Godot 4.7.2 完成：

- 全量 **180/180**、19 个套件通过，发布配置静态检查和主场景烟测通过。
- `food_preferences` 7/7、`food_preference_flow` 7/7、`food_preference_ui` 9/9；`export_strip` 7/7 已包含在全量中。
- 1920×1080 与 720×1280 各核验青菜默认、沙拉碗默认、青菜改为 +7，合计六张实际渲染截图；文字完整、详情均在视口内。
- 全量日志：`life-strategy/.godot/logs/nut207-post-upgrade-verification.log`。
- 截图和报告：`life-strategy/.godot/nut207-visual/`；可用 `life-strategy/tests/food_preference_visual_probe.gd` 在显示驱动下复现。
- 日志和截图属于忽略的本机缓存，不保证新工作树或新机器中存在。此轮未做 Web 导出或发布。

常用验证入口（在仓库根目录执行）：

```powershell
.\tools\verify_project.ps1 -GodotPath 'E:\Program\GodotEngine\Godot_v4.7.2-stable_win64_console.exe'
```

按实际改动选择相关专项，再在需要收口时全量验证。测试历史读写应使用隔离路径；保留真实用户存档。当前环境偶有根证书存储读取告警，不能将其与脚本解析/测试失败混为一谈。

## 4. Godot AI 升级与连接

- 用户自行将 `life-strategy/addons/godot_ai` 更新到 **3.2.5**；大量插件差异属于该升级，应保留。
- 升级曾覆盖导出设置清理修复，已恢复。`export/mcp_export_plugin.gd` 仍应在导出时移除开发 autoload 与 editor 插件设置，并正确还原；不得用旧版插件目录整体覆盖。
- 截图中的冲突是插件 3.2.5 与旧服务 3.1.5 占据同一端口。上次检查已由插件管理的 3.2.5 服务接管 HTTP 8000、WebSocket 9500。
- 本机 Codex 配置已固定 `godot-ai==3.2.5` 的 `attach` 命令。按该配置启动的新客户端已读到本项目 `ready`，插件/服务均为 3.2.5。
- 原任务仍持有旧 3.1.5 MCP 连接并返回 `NEW_CLIENT_SESSION_REQUIRED`，已告知用户重启 Codex MCP 连接或重开应用。新任务先通过 `session_manage(op="list")` 核对当前连接、版本、项目路径和就绪状态；不沿用旧 session ID，不绕过版本检查。

## 5. 下一步：NUT-208A

**NUT-208 尚未实现。** 当前先做 A，之后依次推进 B–D，再进入 M3、M4。

1. **208A**：盘点旧 `diet_burden` / “角色健康”的全部生产者、消费者，覆盖食物、行动、睡眠、跨日、稳定度、结局和 HUD。形成现状影响清单、新状态规则表、迁移与测试方案；按 Backlog 完成规则确认后实施结算迁移。
2. **208B**：新增独立恢复状态，处理数据版本与旧记录迁移/降级。
3. **208C**：改接行动、睡眠、跨日、稳定度和结局。
4. **208D**：移除旧“角色健康”HUD 表达，完成说明、七天流程及桌面/移动回归。

目标：恢复规则服务游戏状态；饮食资料独立形成多维观察。饮水、散步、早睡不能清除或抵消饮食记录。

之后：NUT-301–308 实现评估、聚合、可行建议与影子验证；NUT-401–407 接入餐盘预览、详情、日结与周回顾。UI 与玩法打磨并行做收尾验收，不把已实现的七天流程、补货和事件重复列为新增功能。

## 6. 仍需跟进的边界

- 新健康功能 `data/engine/ui/weekly` 默认全部关闭；专业签署与证据审计尚未完成。
- `CDC-SLEEP` 和 `PRODUCT-RECIPE-PENDING` 原复核期限为 2026-08-15，仍到期。资料覆盖率不能解除这两个缺口，也不能自动改为专业审核通过。
- 旧 `quality`、`NutritionLedger` 与 `diet_burden` 仍需按 NUT-208/304/308/605 分步迁移。M2 尚未整体完成；M3 正式评估与建议、M4 正式健康输出尚未开始。

## 7. 阅读入口

从仓库根目录依次阅读：

1. `README.md` 的当前进度。
2. `life-strategy/docs/plans/nutrition_health_guidance/06_implementation_backlog.md` 的 NUT-208 与后续依赖。
3. 同目录的 `01_data_model_and_schema.md`、`02_assessment_and_coaching_engine.md` 中旧状态拆分规则。
4. 同目录的 `05_testing_review_and_measurement.md` 5.5 节与 `07_profile_review_queue.md`。
5. `docs/process/CodeX_方案审查与MCP开发规范.md`；通用 UI 现状看 `life-strategy/docs/UI_REMAKE_PLAN.md`。

本记录是交接时的状态快照；续接任务应更新实际进展，不把旧验证结果当作后续代码已通过验证。
