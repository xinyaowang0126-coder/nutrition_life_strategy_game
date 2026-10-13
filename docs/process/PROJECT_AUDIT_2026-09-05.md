# 项目审查记录 · 2026-09-05

## 1. 结论

项目已达到可继续迭代的完整游戏原型阶段：七日循环、四类餐食来源、有限存粮与补货、行动/睡眠、周内事件、次日状态和结局均有实现与测试。当前主要问题是恢复新旧规则尚未接完、平衡与实际试玩证据不足、规划重心被健康专项拉长，以及验证/数据边界存在遗漏。

本轮遵循用户确认的 **玩法优先，营养科普辅助**，修复五类已证实的工程隐患，建立可复现策略样本，并将未来顺序收敛到 [开发路线](../ROADMAP.md)。本记录不宣称项目已无风险、可直接上线或完成专业审核。

## 2. 审查范围与基线

- 审查对象：V2 主流程和旧 V1 的关系、纯规则服务、数据/健康历史、恢复服务及迁移、现有测试、启动和导出配置、开发插件隔离、README/交接/GDD/专项 Backlog 的目标一致性。
- 本地分支 `codex/nutrition-health-m2`，HEAD `f4f0efe`。开始时已有 NUT-208A/B 的修改和未跟踪文件，全部保留。
- Godot `4.7.2.stable.official.ed1daf0bf`。本轮起始统一验证为 **217/217、22 个套件**，主入口烟测通过。
- 当前生产玩法仍走旧恢复逻辑。B 的独立服务通过测试不等于 C/D 已接入；四个新健康开关均关闭。
- 仓库 `Play/` 仍对应 2026-07-14 的 v0.3；本轮未联网核对远端部署状态，没有提交、推送、合并、导出或发布。
- 本轮未新增真人试玩、实际截图或浏览器验收；已有截图属于此前检查，不能替代将来 UI 修改后的验收。

## 3. 已确认并修复的工程问题

严重度：P1 表示影响核心结算或验证可信度，P2 表示需要在相应交付路径使用前修复。编号用于后续追踪，不是现存未修复问题列表。

| 编号 | 严重度 | 触发与后果 | 本轮处理与证据 |
| --- | --- | --- | --- |
| AUD-01 | P1 | 来源节点 `queue_free()` 前先发跳餐、再发选择来源信号，早餐行动回退为早餐，可形成两条早餐记录和额外结算 | V2 来源入口要求正确阶段，信号核对当前节点；退场节点立即停止发信号并隐藏。实际场景复现由“2条早餐、余额117”变为“1条早餐、余额120”；增加同帧退场来源、跨餐及当前节点正常选择回归 |
| AUD-02 | P1 | 测试 suite_setup 报 `SCRIPT ERROR`，插件仍返回 passed=1/failed=0、进程退出0；原统一脚本接受假绿 | 统一入口在解释测试结果前扫描脚本错误，并检查通过数与总数一致；真实隔离 probe 证明旧漏洞，门禁回归覆盖初始化/清理错误及零测试等情况。保持第三方插件不变 |
| AUD-03 | P2 | 没有 `.godot` 类缓存的新副本直接运行 headless_runner，找不到 McpTestSuite/McpTestRunner | 统一入口先执行 headless editor import，生成资源和全局类缓存。完整资源的无缓存隔离副本重新验证 **223/223** 并通过主入口烟测 |
| AUD-04 | P2 | Web include_filter 漏 `data/health/*.xml`；运行时 XML 不会凭字符串路径成为场景依赖。旧 PCK 文本搜索还可能把源码路径常量误当资源存在 | 补两份 XML 的导出清单和必需项；PCK 必需资源改查真实目录，支持普通未加密 v2/v3/v4。合成目录回归证明“只有路径常量”不能蒙混通过；读取已有 Play 包验证目录解析。实际新 Web 导出仍待模板 |
| AUD-05 | P2 | XML 缺根闭合、错配闭合或尾接第二根，资料读取器仍可返回 ready，Validator/audit 可判有效 | 两个健康读取器先用同一份缓冲区检查单根、嵌套闭合和根外文本，再解析资料；损坏时清空整份记录并返回 invalid_xml。新增5项测试、114个断言，同时覆盖合法嵌套、自闭合、尾注释 |

实现入口：

- [GameRootV2](../../life-strategy/scripts/ui_v2/GameRootV2.gd)、[V2 流程回归](../../life-strategy/tests/test_v2_flow.gd)。
- [统一验证](../../tools/verify_project.ps1)、[门禁回归](../../tools/test_verification_gates.ps1)、[导出预设](../../life-strategy/export_presets.cfg)。
- [XML 结构检查](../../life-strategy/scripts/health/HealthXmlStructure.gd)、[资料读取](../../life-strategy/scripts/health/HealthDataStore.gd)、[证据读取](../../life-strategy/scripts/health/HealthEvidenceRegistry.gd)、[XML 回归](../../life-strategy/tests/test_health_xml_structure.gd)。

技术依据：Godot 将 [XMLParser](https://docs.godotengine.org/en/stable/classes/class_xmlparser.html) 定义为低层节点读取接口，本次闭合行为以本机复现为准；PCK 目录字段与官方 [file_access_pack.cpp](https://github.com/godotengine/godot/blob/master/core/io/file_access_pack.cpp) 对照，并用本机已有产物检查。目录审计不验证内容 MD5，也不能替代真正运行导出游戏。

## 4. 玩法样本与含义

新增 [gameplay_strategy_probe.gd](../../life-strategy/tests/gameplay_strategy_probe.gd)，不进入场景树、关闭健康开关、历史路径为空。全部策略通过真实来源/用餐/行动/睡眠入口执行；使用初始预算120、默认口味和真实库存，餐食选择检查总费用与上限；无钱时尝试备用来源后才跳餐。

种子为 `0, 1, 2, 3, 7, 13, 42, 73, 101, 211, 997, 20260905`。每种策略12局，共72局，全部在步数上限内正常结束，没有负余额、负库存或同日重复餐次。

| 策略 | 结局（12局） | 结束天 | 剩余预算 | 余力 | 复习 | 跳餐 |
| --- | --- | --- | --- | --- | --- | --- |
| 食堂两样、尽量三次复习、早睡 | 12次稳稳到周末 | 7 | 16–19 | 72–76 | 100 | 0 |
| 食堂两样、晨读/散步/歇息安排、早睡 | 12次稳稳到周末 | 7 | 16–19 | 87–89 | 82–91 | 0 |
| 食堂两样、按精力压力选择行动、早睡 | 12次稳稳到周末 | 7 | 16–19 | 74–79 | 100 | 0 |
| 优先消耗存粮、按状态行动、早睡 | 12次稳稳到周末 | 7 | 39–44 | 80–82 | 100 | 0 |
| 外卖优先、备用食堂/存粮、按状态行动、早睡 | 12次总算到周末 | 7 | 0–1 | 38–41 | 86–100 | 7–10 |
| 全跳餐和餐后行动、晚间复习 | 12次提前结束 | 2 | 120 | 0 | 32 | 6 |

解释限于这些脚本策略：已有多条成功安排，不能据此断言只有唯一最优解；不过存粮的经济收益、外卖优先的预算耗尽、复习容易触顶值得复核。便利店、补货和事件的独立策略价值尚未充分比较。三次复习并早睡在旧规则下稳定成功，新 R2 对 overworked 有明确处理，接入后必须重跑，不能把本表当新恢复验收标准。

此处是诊断样本，不是随机玩家、真人测试或健康效果研究。旧冻结基线固定餐食顺序与本探针不同，不能把余额20与本表16–19的差别直接认定为规则回归。

## 5. 尚未解决的风险和决策

| 事项 | 已知事实/影响 | 后续处理 |
| --- | --- | --- |
| 恢复生产迁移未完成 | `RecoveryRules/StateService/Migration` 独立存在；当前 `diet_burden/character_health` 和旧次日规则仍在使用 | G1 / NUT-208C/D，属于已明确的待开发范围，不是本轮漏修 |
| 控制器偏大、双轨维护 | 审查起始 V2 1572行、V1 1019行；V2 集中日终、轨迹、结局和界面路由 | 随 G1 逐步抽离改动边界，V2 主线，V1 仅必要兼容；不做全仓重写 |
| 结局陈述未必符合轨迹 | 固定副标题声称“饭也没落下”或“熬了几个夜”，判定条件并未核实这些事实 | G1D/G3 改中性或记录驱动文案 |
| 旧膳食提示仍存在 | 新健康开关 off 不会关掉旧 NutritionLedger；其旧标签推断不等于新资料已审校 | G3 先清楚收口旧输出，G4 再上经审核观察；NUT-308/605 保留专门迁移与清理任务 |
| 健康资料仍是草稿 | 23/23覆盖，13份固定游戏规格、10份品类资料，均 draft | 不因覆盖率改审核状态；以少量可靠资料做辅助切片 |
| 两项证据到期 | 2026-09-05 审计仍报 CDC-SLEEP、PRODUCT-RECIPE-PENDING，原到期日2026-08-15，退出1 | 保留限制和复核队列；不擅自延长期限或补专业签署 |
| 健康接口的防御性校验仍可加强 | 内存直接传入的 NAN/INF、宽松版本类型可被 Validator 接受；手工拼快照额外加 balance/stress 也可被档案采纳，正常构建路径未生成这些值 | 在 G4 开启健康输出/增加外部导入前补有限数、精确类型与完整隔离契约回归。本轮不扩大为全 schema 重写 |
| 无完整游戏续玩 | 已有独立健康历史与恢复 envelope，不保存整局所需全部状态 | G3 按实际中断需要决定是否实现；不能在文档称“已有游戏存档” |
| 测试/发布自动化仍不完整 | 没有仓库 CI 配置；实际浏览器、多设备、发布包运行未在本轮验证 | G3/G5 补适用检查；脚本测试通过不替代人工验收 |
| 本机缺匹配 Web 模板 | 当前目录有4.6.2、4.7、4.7.1模板，没有4.7.2模板 | G5 使用匹配模板后临时导出/包审计/浏览器运行，再按授权更新 Play |

本轮日志中的系统根证书读取错误仍可复现；它没有造成脚本解析失败或离线测试失败。尚未验证网络功能，不把离线通过写成网络环境正常。

## 6. 最终验证

| 检查 | 结果 | 本地日志 |
| --- | --- | --- |
| 修复前统一入口 | 217/217、22套件，烟测通过 | `artifacts/project-audit-baseline-2026-09-05.log` |
| 修复后统一入口 | **223/223、23套件**，资源导入、静态发布配置、主入口烟测通过 | `artifacts/project-audit-final-2026-09-05.log` |
| 无 `.godot` 缓存的完整隔离副本 | 资源导入、223/223和烟测通过 | `artifacts/project-audit-cold-2026-09-05.log` |
| 验证门禁回归 | **17项通过**；包含合成PCK和既有Play目录读取 | `tools/test_verification_gates.ps1` 的输出 |
| 真实规则策略样本 | **72/72**结束，errors为空 | `artifacts/project-audit-strategies-2026-09-05.log` |
| 当前日期证据审计 | **按预期失败：退出1，2项到期** | `artifacts/project-audit-evidence-2026-09-05.log` |
| Git 内容检查 | 冻结旧 JSON 保持原哈希；project.godot/插件/Play 无本轮差异；diff空白检查通过 | 以收口时实际 Git 状态为准 |

上述日志在忽略的 artifacts/ 或 .godot/，不保证换机器仍存在；可复现脚本已保留。测试数由原217加1条V2回归、5条XML回归得到223；门禁17项和策略72局分别计数，不混入单元测试总数。

复现命令（仓库根目录）：

```powershell
.\tools\verify_project.ps1 -GodotPath 'E:\Program\GodotEngine\Godot_v4.7.2-stable_win64_console.exe'
.\tools\test_verification_gates.ps1
& 'E:\Program\GodotEngine\Godot_v4.7.2-stable_win64_console.exe' --headless --path life-strategy --script res://tests/gameplay_strategy_probe.gd
& 'E:\Program\GodotEngine\Godot_v4.7.2-stable_win64_console.exe' --headless --path life-strategy --script res://tests/evidence_audit_runner.gd -- --as-of=2026-09-05
```

本轮目标是审查、排除已证实的局部隐患和重规划。下一项工作按新路线进入 NUT-208C1，不能把本报告当成 C/D 已实施或发布已批准。
