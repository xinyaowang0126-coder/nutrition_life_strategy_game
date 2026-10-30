# 双篇结局反馈Web发布

日期：2026-10-30。用户授权提交并推送GitHub，确保线上试玩。目标为现有`main`和GitHub Pages；根入口跳转`Play/`。

## 提交范围

发布[双篇结局反馈](ENDING_FEEDBACK_2026-10-29.md)：独立结局页、人物回应、实际选择与效果、具体下次尝试、整周回顾及旧档兼容。保留原结局判定和玩法数值。8类主要收尾与普通周末的两种正文共9条整局场景路线已有合法可复现的触发前与结局存档。

将已验证的本地候选`artifacts/ending-feedback-2026-10-29-web/`同步至`Play/`。15份运行文件的大小与SHA-256见[文件清单](../assets/ending-release-2026-10-29/web-files.json)。PCK为97,346,280字节（92.84MiB），完整Pages目录约132.24MiB，均通过现有体积门禁。实际变化为HTML中的包大小及PCK，其余运行文件与上一版相同。

## 提交前证据

- 完整回归663/663、52套件；最终文案调整后的19项结局专项、主场景和导出检查再次通过。发布门禁50项，校园510局与周阿姨40局玩法保护无差异。[工程摘要](../assets/endings-feedback-2026-10-29/verification.json)
- 原生四尺寸、网页桌面/竖屏、9条整局场景路线、存档导入/刷新/重开与旧档检查见[工程记录](ENDING_FEEDBACK_2026-10-29.md)；这些证据不替代真人体验或教育效果验证。
- 对同步后的`Play/index.pck`执行包审计，并以Godot直接加载真实PCK检查9条结局及配图、只读回顾和旧档解析，错误0。[包运行结果](../assets/ending-release-2026-10-29/pack-runtime.json)
- 实际执行`.github/workflows/pages.yml`内站点准备代码，15份文件与候选指纹一致；故意缺少轮播背景或使用越界文件名时正确拒绝。[准备结果](../assets/ending-release-2026-10-29/local-release.json)
- 真实浏览器访问这一Pages目录：根跳转、下载进度、标题、继续第1天、进入食堂，选择鸡蛋/白米饭并确认，余额从150变为146。完整刷新后继续，仍为早餐后、余额146、余力57；所检查页面控制台警告/错误0。[浏览器记录](../assets/ending-release-2026-10-29/browser-local.json)

![发布目录刷新后恢复的真实餐后状态](../assets/ending-release-2026-10-29/local-campus-restored.jpg)

Godot沙盒初始化诊断与一次未复现的原生指针注入失效按[工程记录](ENDING_FEEDBACK_2026-10-29.md)保留。真人反馈、真实手机触摸、专业审校与教育验证仍待单独完成。

## 推送后验收方法

推送后必须确认远端`main`、Pages工作流`head_sha`与站点根目录`release.json`为同一提交，工作流结论为`completed/success`。逐项核验15份运行文件的HTTP状态、长度与清单，下载完整PCK并计算SHA-256，与该提交的Git文件字节比较；HTML的Git换行标准化单独核验。最后通过真实线上浏览器检查加载、双篇入口、正常操作和刷新继续，并保留截图及执行结果。

此提交中的记录为提交前证据和验收方法；推送后结果保存在本机忽略目录`.cache/ending-publish-2026-10-29/`，避免将发布提交自身的标识写回同一提交。线上版本以根目录`release.json`中的`commit`为准。

正式入口：[好好吃饭](https://xinyaowang0126-coder.github.io/nutrition_life_strategy_game/)。
