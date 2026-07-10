# 撑过这一周

《撑过这一周》是一款以营养、预算、复习和情绪管理为核心的生活策略原型。玩家需要在一周内安排三餐、餐后行动和睡眠选择，在有限金钱与状态波动中撑到周末。

当前版本已加入餐前来源选择：每顿饭可以去食堂、点外卖、逛便利店或翻宿舍存粮。不同来源拥有独立卡池、费用与开放时段，宿舍食物还会消耗有限库存。卡牌表面只保留关键数值，完整描述在悬停时显示；短期记录会以渐隐提示出现，来源与时间也会改变背景氛围。

## 在线测试

GitHub Pages 发布后，可通过以下链接测试 HTML 版本：

https://xinyaowang0126-coder.github.io/nutrition_life_strategy_game/Play/

根目录 `index.html` 会自动跳转到 `Play/`。

## 项目结构

- `life-strategy/`：Godot 4.7 游戏项目。
  - `scripts/`：运行逻辑与数据加载。
  - `scripts/systems/`：抽牌与餐食原子结算等纯逻辑服务。
  - `scripts/ui/`：Godot 场景组件的短控制脚本。
  - `data/cards/`：餐食来源、食物卡、行动卡、睡眠选项 XML 数据。
  - `assets/generated/`：已接入的生成美术素材。
  - `scenes/game/components/`：可在编辑器内独立调整的卡牌、阶段视图和提示组件。
  - `scenes/`：启动、主菜单和游戏场景。
  - `tests/`：MCP/Godot 冒烟测试。
  - `docs/plans/`：玩法、UI、文案和 Godot 架构四份后续工作方案。
- `Play/`：GitHub Pages HTML 测试包，由 Godot Web 导出生成。
- `docs/`：项目设计、流程规范、素材说明和项目概述文档。
- `tools/`：文档与素材辅助脚本。

## 本地缓存

`.cache/`、`life-strategy/.godot/`、`docs/.tmp_render/` 等目录是本地运行或渲染缓存，已被 `.gitignore` 忽略，可按需重新生成。
