# 《撑过这一周》MVP 素材清单与生成说明

本文记录本轮 MVP 已生成、切分并接入 Godot 的游戏素材。所有图片素材都保持同一套温暖手绘卡牌风格：低饱和暖色、纸感边框、轻水彩质感、生活策略游戏 UI 取向。中文文本不直接写入图片，统一由 Godot 使用 `NotoSansSC-VF.ttf` 渲染，避免生成图中文字不可读。

## 已接入素材

### 场景背景

- `life-strategy/assets/generated/backgrounds/dorm_background.png`
- 用途：主菜单和游戏主界面背景。
- 内容：大学宿舍/书桌环境，承载“考试周、生存策略、低预算生活”的整体氛围。

### 角色画像

- `life-strategy/assets/generated/characters/student_portrait.png`
- 用途：左侧状态栏角色头像。
- 内容：疲惫但仍在坚持的学生主角，和结局图保持同一人物气质。

### 食物卡牌 15 张

目录：`life-strategy/assets/generated/cards/`

- `rice_plain.png`：白米饭，低价主食。
- `oatmeal.png`：燕麦，低价高饱腹主食。
- `egg.png`：鸡蛋，低价蛋白。
- `tofu.png`：豆腐，低价蛋白/清淡。
- `greens.png`：青菜，降低饮食负担。
- `tomato.png`：番茄，蔬果补充。
- `apple.png`：苹果，心情和纤维补充。
- `banana.png`：香蕉，快速补能。
- `milk.png`：牛奶，温和蛋白饮品。
- `coffee.png`：咖啡，短期提神。
- `bubble_tea.png`：奶茶，高心情、高负担。
- `instant_noodles.png`：方便面，低价救场、高负担。
- `fried_chicken.png`：炸鸡，高心情、高预算压力。
- `salad_bowl.png`：沙拉碗，低负担但昂贵。
- `sandwich.png`：三明治，中等价格、较均衡。

### 行动卡牌 8 张

目录：`life-strategy/assets/generated/actions/`

- `study.png`：复习，推进目标但提高压力。
- `nap.png`：小睡，恢复精力。
- `walk.png`：散步，降低压力和饮食负担。
- `drink_water.png`：喝水，免费维护，每天限次。
- `go_cafeteria.png`：去食堂，影响明日均衡抽牌倾向。
- `convenience_store.png`：便利店，影响明日快乐速食抽牌倾向。
- `sleep_early.png`：早睡，恢复型行动/睡眠主题图。
- `allow_imperfection.png`：允许不完美，心理维护行动。

### 结局图 3 张

目录：`life-strategy/assets/generated/endings/`

- `stable_endurance.png`：稳定通过。
- `barely_survived.png`：勉强撑过。
- `collapsed.png`：状态崩盘。

### UI/字体辅助

- `life-strategy/assets/fonts/NotoSansSC-VF.ttf`
- 用途：所有中文 UI 文本。
- 预览联络表：
  - `life-strategy/assets/generated/ui/food_contact_sheet.png`
  - `life-strategy/assets/generated/ui/action_contact_sheet.png`
  - `life-strategy/assets/generated/ui/ending_contact_sheet.png`

## 原始图集

目录：`life-strategy/assets/generated/source/`

- `dorm_background.png`
- `student_portrait.png`
- `food_atlas.png`
- `action_atlas.png`
- `ending_atlas.png`

这些文件保留为生成源，便于后续重新切图、做高分辨率替换或追溯统一风格。

## MVP 外的后续素材缺口

- 事件插图：考试突发、社交邀约、身体不适、预算变动等。
- NPC 头像：室友、同学、老师、家人，用于关系系统。
- 地点背景：食堂、便利店、操场、教室、图书馆。
- 音频：按钮反馈、抽牌、结算、低稳定度提示、结局音乐。
- UI 图标：预算、精力、心情、压力、饮食负担、复习进度的专用小图标。
- 动效素材：卡牌选中、状态变化、结局揭示。

当前 MVP 已具备可试玩所需的核心视觉资产；后续扩展优先补事件/NPC/地点，以支撑更完整的叙事与系统深度。
