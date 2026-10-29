# 标题、人物选择、加载页与透明品牌图标

日期：2026-10-29。接续10月28日美术制作，已接入Godot工程和新的本地Web候选。当前保留学生、周阿姨两位可玩人物；后续人物通过资料和独立插画加入。

## 实际效果

标题页以人物生活插画为背景，每10秒轮换，0.8秒淡入。两位人物各3张：学生吃饭、校园路上、夜间书桌；周阿姨翻歌谱、逛集市、阳台照料植物。手机按每张图的焦点裁切，桌面保持人物在右、标题在左。切图前后按钮隐藏，只保留低调的暂停入口。

![桌面标题页](../assets/menu-redesign-2026-10-28/browser/01-title-desktop.png)

开始游戏后进入独立选人页。每个人物是一条完整竖幅插画，选中项展开；桌面右侧显示人物目标，手机在插画下方显示详情，开始/继续按钮固定在底部。背景使用场景图和奶油色遮罩。选人不会写入进度；存档按故事分别读取。人物介绍只读，不提供绕过重开确认的新开局按钮。保留其他存档、导入、重新开始确认和取消保护。

![桌面选人页](../assets/menu-redesign-2026-10-28/browser/02-zhou-desktop.png)

![手机选人页](../assets/menu-redesign-2026-10-28/browser/03-zhou-mobile.png)

品牌图标采用v3透明母版，陶碗和食物保持清晰，外围暖色阴影渐变到透明。四角alpha均为0；PNG各尺寸和Windows ICO均已重新生成，接入项目、原生启动图、选人页标记和Web图标/加载页。v1橙底、v2奶油渐变母版保留为历史版本。

加载页使用同一生活插画清单和轮播。网页在引擎下载前就能显示6张轻量JPEG；进度条按Godot下载回调的真实字节显示百分比。轨道与暖橙填充加粗，提高浅色背景下的可见度。无法确定总量时显示等待状态，失败可重试。原生启动页保留等待条，主线程完成菜单资源加载后填满并进入标题；没有虚构百分比或额外倒计时。

![网页加载页与真实进度](../assets/menu-redesign-2026-10-28/browser/07-loading-desktop.png)

![手机网页加载页](../assets/menu-redesign-2026-10-28/browser/06-loading-mobile.png)

## 扩展方式

- 人物在`data/characters/personas.xml`配置短名和`selection_art`，故事继续沿用`data/stories/stories.xml`。入口按`character_id`聚合；同一人物有多个故事时显示故事选择。
- 新生活插画加入`data/title_life_scenes.json`，配置人物、图片、手机焦点和网页文件名。导出辅助脚本从同一清单同步网页数据与JPEG。
- 横向人物长条支持滚动、触摸滑动和键盘焦点。10人物布局样例与12人物/同人多故事单元样例只用于验证扩展，不是新增可玩人物。
- `tools/verify_project.ps1 -ExportWeb`生成网页加载图片。单独从Godot手动导出时，还需运行`tools/prepare_title_web_assets.gd -- --output=<导出目录>`，保证6张外部JPEG在引擎加载前可用。

## 验证及边界

| 检查 | 结果与范围 |
| --- | --- |
| 完整回归 | 644/644，51套件；资源导入、主场景启动、Web导出通过。[原始结果](../assets/menu-redesign-2026-10-28/headless-results.json) |
| 最后进度条调整 | 再跑入口专项17/17、主场景启动与Web导出审计通过。[日志](../assets/menu-redesign-2026-10-28/progress-final-verification.log) |
| 原生双尺寸输入 | 1280×720、390×640：标题/选人/详情/空存档、Esc/Tab、10人物布局浏览和触摸滑动不误选、周阿姨真实新开局，错误0。[桌面](../assets/menu-redesign-2026-10-28/desktop-final/report.json)、[竖屏](../assets/menu-redesign-2026-10-28/mobile-final/report.json) |
| 存档入口回归 | 双尺寸真实输入：自动保存提示、手动槽、读档确认、返回新版菜单继续、取消重开；内存后端，错误0。[桌面](../assets/menu-redesign-2026-10-28/save-desktop/report.json)、[竖屏](../assets/menu-redesign-2026-10-28/save-mobile/report.json) |
| 既有周阿姨流程 | 更新旧视觉探针入口后，390×640从新版标题选人进入周阿姨，处置存粮、做饭、留存和再次取餐通过。[结果](../assets/menu-redesign-2026-10-28/story-mobile/report.json) |
| 加载脚本 | Node DOM/Engine模拟覆盖6图轮播、暂停、减少动画、手机焦点、真实/未知进度、启动交接与失败重试；通过。[结果](../assets/menu-redesign-2026-10-28/web-loading-shell.log) |
| 实际浏览器 | 本机内嵌浏览器1280×720及390×640；观察真实下载百分比/加载页退出、标题自动轮播、人物切换、透明图标和响应布局；从已有周阿姨旧档继续到第1天睡前，刷新后继续入口仍存在；最终人物介绍仅提供返回选人。所检查页面控制台无警告/错误。截图不是设计合成图。[观察记录](../assets/menu-redesign-2026-10-28/browser/report.json) |
| 最终Web包 | 15文件，含6张外部加载JPEG；PCK约91.83MiB，准确字节大小和哈希以[最终清单](../assets/menu-redesign-2026-10-28/web-manifest.json)为准，低于100MiB门禁。测试/工具开发内容隔离审计通过。 |
| 最终包内运行 | 匹配的原生Godot 4.7.2直接加载最终Web PCK，6张场景纹理、2张人物竖图、图标透明、双篇分别新开局和内存存档继续通过，错误0。[结果](../assets/menu-redesign-2026-10-28/pack-runtime.json) |

实际浏览器检查覆盖本次入口与一个旧档的继续/刷新；尚未替代真实手机、多浏览器，以及双篇连续七日、成功/失败/重开的完整验收。本轮未重跑550局策略，也未修改玩法数值。美术与入口完成不代表专业审校或真人学习/趣味验证完成。

Godot编辑器初始化与导出仍出现Windows `Safe save failed`日志，未提供具体文件路径，来源尚待定位。最终导出命令、配置/资源审计与直接加载该包的运行检查通过；原始诊断保留在上方验证日志中。

候选位于`artifacts/menu-redesign-2026-10-28-web/`；`Play/`与线上版本未替换。素材尺寸、透明通道、Windows ICO规格及哈希见[美术元数据](../assets/menu-redesign-2026-10-28/asset-metadata.json)，生成记录见[提示词](../design/ENTRY_ART_PROMPTS_2026-10-28.md)。
