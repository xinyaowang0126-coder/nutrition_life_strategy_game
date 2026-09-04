# HealthDataStore fixtures

这些 XML 只验证 schema 读取和降级行为，不是可发布的营养资料，也不支持任何玩家健康结论。

- `normal.xml`：包含一条虚构 profile，用于验证根版本、份量、组成状态、component、做法、factor、咖啡因状态、confidence 和 review status。
- `empty_catalog.xml`：合法 schema，但没有 profile。
- `empty_file.xml`：没有 XML 根节点。
- `legacy_schema.xml`：低于当前支持版本；必须失败关闭。
- `future_schema.xml`：高于当前支持版本；必须失败关闭。

缺失文件通过测试中的不存在路径覆盖，不创建占位文件。
