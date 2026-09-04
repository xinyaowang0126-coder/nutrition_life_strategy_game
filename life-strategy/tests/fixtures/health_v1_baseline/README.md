# 旧营养反馈基线

> 捕获日期：`2026-07-15`
>
> 对应任务：`NUT-001`
>
> 状态：仅用于迁移审计

这里保存的是旧 `MealResolver.plate_quality` 与 `NutritionLedger` 的代表性输出，用于说明 V2 升级前系统实际做了什么。

这些值不是营养标准，也不是新模型的期望结果。后续 `DietPatternEvaluator` 必须遵循“无总分、无抵消、显式未知”的新契约，不应为了让这些数字继续通过而复现旧算法。

文件：

- `current_quality_examples.json`：单餐和跳餐的旧 `quality` 值；
- `current_daily_summary_examples.json`：重复复合餐等旧日汇总行为。

删除旧评分路径时保留本目录作为决策记录，但不要把它接入新模型回归测试。
