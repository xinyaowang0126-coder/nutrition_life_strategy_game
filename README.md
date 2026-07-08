# 撑过这一周

《撑过这一周》是一款以营养、预算、复习和情绪管理为核心的生活策略原型。玩家需要在一周内安排三餐、餐后行动和睡眠选择，在有限金钱与状态波动中撑到周末。

## 在线测试

GitHub Pages 发布后，可通过以下链接测试 HTML 版本：

https://xinyaowang0126-coder.github.io/nutrition_life_strategy_game/Play/

## 项目结构

- `life-strategy/`：Godot 4.7 游戏项目与运行数据
  - `scripts/`：运行逻辑与数据加载
  - `data/cards/`：食物卡、行动卡、睡眠选项 XML 数据
  - `assets/generated/`：已接入的生成美术素材
  - `tests/`：MCP/Godot 冒烟测试
- `docs/`：项目文档和系统预览
  - `design/`：GDD、Godot 方案、原始玩法设计
  - `process/`：CodeX/MCP 协作规范
  - `assets/`：MVP 素材清单
  - `project_overview_assets/`：项目概述文档配图与 UI 参考图
- `Play/`：GitHub Pages HTML 测试版
- `tools/`：文档与素材辅助脚本
