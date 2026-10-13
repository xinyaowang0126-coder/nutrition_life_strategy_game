# G4A1：单餐组成与短文案接口

版本1.0，2026-10-08。状态：独立工程切片完成，生产界面未接入，资料/规则/正向文案未获专业签署。对应NUT-301及NUT-302/306的一部分；不将本切片当作完整多维引擎或可行建议服务。

> G4A2文案更新：下文五个例句是G4A1历史输出，保留当时证据。当前模板改为短句，开发界面直接列原料，“份量未标”独立显示，说明移入详情；审核和变量门保持。详见[G4A2](../process/G4A2_PREVIEW_AND_GAME_COPY_2026-10-08.md)。

## 1. 本切片做什么

接收已冻结的MealHealthSnapshot，判断一餐有哪些可支持的组成记录、哪些仍未知，再选择一条受控短句。组成与份量分别描述：知道食材，不意味着吃够；份量未知，也不会抹掉已经得到支持的组成。

当前只做单餐进餐事实、组成、资料边界和文案门控。日/周规律、多样性聚合、糖/钠/油炸/咖啡因因素规则、营养建议和玩家UI留后续。它们返回not_evaluated或null，不假装为零、正常或没有风险。

## 2. 三个接口

| 接口 | 输入 / 输出 | 副作用 |
| --- | --- | --- |
| HealthGuidanceConfig.defaults/validate | 版本化餐盘映射及审核元数据；默认draft | 每次返回独立字典，不写配置 |
| DietPatternEvaluator.evaluate(snapshot, config, registry, as_of_date) | 既有schema1健康快照、配置、明确证据上下文和日期 → 单餐结构化结果 | 不读当前卡牌/配方、不写档案、不调用玩法结算 |
| GuidanceComposer.load_catalog/compose_meal | 受控XML模板；compose重新校验给定快照，不接受外部声称已批准的评估 → 一条primary及评估/门控依据 | 只读模板，变量来自已验证结果，无实际调整动作 |

HealthGuidanceConfig支持schema1、model_version=diet-pattern-v2.0、rules_version=meal-composition-v1、scope=meal_composition。角色映射不能在同一rules版本中任意改动。当前配置是运行时字典，不是新增游戏存档格式。

输入复用原MealHealthSnapshot.build/validate，没有升级快照/档案schema。旧记录必须使用既有legacy转换；未经转换的quality、游戏数值、恢复字段或诊断/评分输入被拒绝，不从旧字段推回组成。

## 3. 组成与未知语义

| 食物组 | 本切片处理 |
| --- | --- |
| grains_tubers | staple主食 |
| vegetables | vegetable蔬菜 |
| eggs / soy_products / poultry_livestock / fish_seafood | protein_source这一结构角色；显示实际对应类别 |
| fruits / dairy / nuts_seeds / beverages | 分别记录，不填主食/蔬菜位，不生成饮水量或充分性结论 |
| other / unknown | 不补主要组成；unknown会保留资料缺口 |

按稳定ingredient_id合并，保留全部来源food_id及被选线索的selected_food_id。至少medium置信度的线索才支持结构；有效置信度不高于其profile和component任一层。trace不占主要组成位，small与material/dominant分别保留。

同一原料在不同菜品中的贡献可以不同。在已足以支持窄事实的线索中选较明确的贡献，等贡献选更高置信度，仍相同则按food_id固定顺序。不会将克数相加，也不会让另一道菜的高置信度trace抹掉已有material。没有可靠线索时保留较可靠的原始信息，仍不生成肯定性观察。

supported表示能支持一个窄的组成记录，不表示三类齐全或摄入达标。缺少食物资料/审核、估算或低置信度时可以保留已知部分，但未出现的角色写unknown。只有可支持的完整组成记录才把未记录类别写not_recorded，不能等同现实中绝对没有。

结构status与data_quality.status独立：完整已知组成、未知份量可以是结构supported、资料partial；部分类别已知与其余配料未知是结构partial。所有状态有文字语义，不以颜色或数字等级替代。

## 4. 输出摘要

```text
valid / errors / scope=meal / day / phase
model_version / rules_version
dimensions:
  regularity: supported / attention / unknown + record_status
  plate_structure: status + 三个role的presence/confidence/ingredient_ids
  diversity / attention_factors: not_evaluated
ingredients: 原料ID、类别、贡献、置信度、选用来源、全部来源
food_group_ids / separate_food_groups
data_quality: status、缺口food_id、未知份量food_id、门控原因
observations: 零条或一条copy_id及已记录类别
primary_suggestion / fallback_suggestion: null
provenance: 配置/各profile的版本及证据检查
scope_notice_id=GENERAL_EDUCATION_NOT_MEDICAL
```

没有总分、quality、grade、疾病/缺乏判断、健康好坏标签或睡眠/饮水抵消项。跳餐保留attention记录，餐盘not_applicable，不与任何食物作分数比较。

## 5. 审核和证据门

| 层 | 必需条件 |
| --- | --- |
| 配置/映射 | expert_reviewed、具名/代号、有效且不晚于检查日的日期；引用可用并支持MEAL_DIVERSITY_EDUCATION |
| profile | 同样审核元数据；引用可用。menu_recipe须SIMULATED_INGREDIENT_COMPOSITION，package_label须SIMULATED_PACKAGE_LABEL；其他估算/品类须对应一般组成教育能力，unknown依据不肯定推断 |
| 正向组成短句 | 模板expert_reviewed且元数据有效；所用证据同时支持MEAL_DIVERSITY_EDUCATION和PLAYER_GUIDANCE |
| 中性边界/进餐事实 | 文本和变量限定于固定、安全的记录含义；不能通过把正向营养句改名boundary来绕开专业门 |

check_references必须显式请求能力。空引用、过期、needs_review、superseded、缺失或不支持的引用均不能放行。替代链只作诊断，不自动替换原引用。内部配方可支持模拟组成，但不能单独支持PLAYER_GUIDANCE或健康阈值。

当前生产profile全部draft，默认配置draft，guidance_copy.xml两条正向模板draft；全流程不会生成生产肯定性组成观察。四个健康开关保持关闭，控制器没有调用这些模块。

## 6. 文案约束与例子

模板schema1、zh-CN，仅六个固定ID。正向模板只允许food_groups_text；它由有效组成映射为固定类别文字，不插入调用方的自由文本、食物名或游戏数值。重查模板版本、错误列表、type、占位符和审核信息，不能信任valid=true这一声明。

| 独立测试情境 | 生成短句 |
| --- | --- |
| 组成可支持、份量未知 | “这餐记录了主食、蔬菜、蛋类。出现过，不代表份量已经足够。” |
| 已知米饭，另一份资料缺失 | “这餐已有主食记录，其余配料还待核对。” |
| 只有水果和奶类 | “这餐记录了水果、奶类。出现过，不代表份量已经足够。”不据此填三类角色 |
| 旧历史 | “这段历史没有成分记录，暂时看不出这一餐的组成。” |
| 当前生产默认 | “这餐已经记下，成分资料还待核对。” |

前四行的正向例子使用tests/fixtures/g4_meal里的**模拟审核元数据**，不是实际审核，更没有接入玩家UI。[示例机器输出](../process/G4A1_EXAMPLES_2026-10-08.json)。进餐事实/边界句没有营养断言，文本范围固定；修改此类文本须同步准则和校验。

## 7. 后续承接

下一项G4A2用这些接口做隔离开发预览：显示已知组成/未知份量，展开原料来源与一条短观察；再接真实选餐记录和建议可行性过滤。生产入口仍等待八份资料、配置与文案的专业意见。日/周、因素阈值、正式Presenter/NUT-308及完整G01–G19仍单独验收。
