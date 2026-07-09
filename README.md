# 撑过这一周

《撑过这一周》是一款以营养、预算、复习和情绪管理为核心的生活策略原型。玩家需要在一周内安排三餐、餐后行动和睡眠选择，在有限金钱与状态波动中撑到周末。

## 在线测试

GitHub Pages 发布后，可通过以下链接测试 HTML 版本：

https://xinyaowang0126-coder.github.io/nutrition_life_strategy_game/Play/

根目录 `index.html` 会自动跳转到 `Play/`。

## 项目结构

- `life-strategy/`：Godot 4.7 游戏项目。
  - `scripts/`：运行逻辑与数据加载。
  - `data/cards/`：食物卡、行动卡、睡眠选项 XML 数据。
  - `assets/generated/`：已接入的生成美术素材。
  - `scenes/`：启动、主菜单和游戏场景。
  - `tests/`：MCP/Godot 冒烟测试。
- `Play/`：GitHub Pages HTML 测试包，由 Godot Web 导出生成。
- `docs/`：项目设计、流程规范、素材说明和项目概述文档。
- `tools/`：文档与素材辅助脚本。

## 本地缓存

`.cache/`、`life-strategy/.godot/`、`docs/.tmp_render/` 等目录是本地运行或渲染缓存，已被 `.gitignore` 忽略，可按需重新生成。
