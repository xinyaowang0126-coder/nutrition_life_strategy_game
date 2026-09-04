# 撑过这一周

《撑过这一周》是一款以营养、预算、复习和情绪管理为核心的生活策略原型。玩家需要在一周内安排三餐、餐后行动和睡眠选择，在有限金钱与状态波动中撑到周末。

当前版本已经形成完整的七日闭环：每顿饭可以去食堂、点外卖、逛便利店或翻宿舍存粮，不同来源拥有独立选择上限、费用、精力代价与开放时段，也可以花钱补充有限存粮。前一天的饮食结构、行动、睡眠、精力和压力会生成次日学习状态，直接改变复习收益；第 2–6 天还有可提前预判的周内事件。进入新一天时会用图文弹窗同时展示学习状态与今日事件；每日结算的详细膳食记录可独立滚动，底部操作始终可见；周末则回顾七天轨迹。

## 在线测试

GitHub Pages 发布后，可通过以下链接测试 HTML 版本：

https://xinyaowang0126-coder.github.io/nutrition_life_strategy_game/Play/

根目录 `index.html` 会自动跳转到 `Play/`。

GitHub Pages 直接发布 `main` 分支根目录，真正运行的是仓库内的 `Play/` Web 导出包。只推送 `life-strategy/` 源码不会改变线上游戏；发布前需要重新导出并提交 `Play/`：

```powershell
.\tools\verify_project.ps1 -ExportWeb -ExportOutput .\Play
git add Play
git commit -m "Update web build"
git push
```

## 本地测试与发布验证

项目提供统一的 PowerShell 验证入口，依次运行数据/流程测试和主场景烟测。Godot 4.7 的控制台程序可通过参数传入，也可写入 `GODOT_BIN` 环境变量：

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7-stable_win64_console.exe"
.\tools\verify_project.ps1
```

只运行指定测试套件时使用 `-Suite`；不存在的套件或零测试会返回失败状态：

```powershell
.\tools\verify_project.ps1 -Suite meal_systems
```

发布前使用 `-ExportWeb`。脚本会导出到临时目录，检查 Web PCK 不含 MCP 开发插件、测试和旧版游戏场景，完成后清理临时文件，不会覆盖 `Play/`：

```powershell
.\tools\verify_project.ps1 -ExportWeb
```

如需保留验证后的导出文件，可指定输出目录：

```powershell
.\tools\verify_project.ps1 -ExportWeb -ExportOutput .\artifacts\web
```

CI 中执行同一脚本即可；它不下载依赖，任何测试、主场景启动、导出或发布包审计失败都会返回非零退出码。

Web 导出需要与当前 Godot 引擎版本匹配的导出模板；例如 4.7.2 引擎需要安装 4.7.2 模板，现有 4.7 或 4.7.1 模板不能算作本机已具备完整导出环境。

## 当前开发进度（2026-09-04）

营养健康升级已完成 NUT-206 的工程部分：23 个食物条目均有独立资料，13 项为固定游戏规格、10 项为保守品类资料，全部仍是 draft；用餐快照和独立健康历史存取已接入 V2 用餐流程，保留当餐资料与版本，加载历史不会用新资料重算，也不会恢复或混入本局游戏状态。四个新健康功能开关保持关闭；下一步是角色偏好、旧状态拆分与评估引擎。任务状态见 [专项 Backlog](life-strategy/docs/plans/nutrition_health_guidance/06_implementation_backlog.md)，未知项和到期证据见 [复核队列](life-strategy/docs/plans/nutrition_health_guidance/07_profile_review_queue.md)。

当前全量测试 157/157、发布配置静态检查和主场景烟测通过，包含完整七天 21 餐记录及开关前后玩法结果一致性验证；两项证据仍待到期复核。当前源码检查点位于开发分支 `codex/nutrition-health-m2`，未合并 main，未导出或发布；仓库 Play/ 包仍对应 2026-07-14 的 v0.3。

## 项目结构

- `life-strategy/`：Godot 4.7 游戏项目。
  - `scripts/`：运行逻辑与数据加载。
  - `scripts/systems/`：抽牌、餐食结算、营养记录、周内事件与次日状态等纯逻辑服务。
  - `scripts/ui_v2/`：当前游戏界面和七日流程控制脚本。
  - `data/cards/`：餐食来源、食物卡、行动卡、睡眠选项 XML 数据。
  - `assets/generated/`：已接入的生成美术素材。
  - `scenes/game_v2/`：当前游戏场景、卡牌组件、阶段视图和结算界面。
  - `scenes/`：启动、主菜单和游戏场景。
  - `tests/`：MCP/Godot 冒烟测试。
  - `docs/plans/`：玩法、UI、文案和 Godot 架构四份后续工作方案。
- `Play/`：GitHub Pages HTML 测试包，由 Godot Web 导出生成。
- `docs/`：项目设计、流程规范、素材说明和项目概述文档。
- `tools/`：文档与素材辅助脚本。

## 本地缓存

`.cache/`、`life-strategy/.godot/`、`docs/.tmp_render/` 等目录是本地运行或渲染缓存，已被 `.gitignore` 忽略，可按需重新生成。
