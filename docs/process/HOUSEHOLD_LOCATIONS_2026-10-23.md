# 周阿姨篇：独立用餐场景与集市

日期：2026-10-23。按本轮要求，做饭、冰箱与外出使用各自的生活场景，外出地点改为集市中的日常店铺。

## 当前体验

家中保留做饭、存粮和购物袋入口；购物袋标为“去集市”。做饭进入有菜板、灶台、炒锅和炖锅的厨房近景，准备配方时留在厨房。存粮选餐及库存工作台均显示打开的冰箱，关闭库存后恢复之前的位置和选择。

去集市直接进入街巷场景，点击店面或名牌查看菜单。店内“回集市”返回街巷，“回家看看”或Esc返回家里；下一餐从家中开始。桌面与竖屏分别使用集市构图，手机厨房另有专用竖屏图，冰箱及店铺按主体位置裁切。

| 地点 | 营业餐次 | 当前菜单 |
| --- | --- | --- |
| 早餐店 | 早餐 | 馒头、小米粥、鸡蛋、蒸蛋、未开封常温纯牛奶 |
| 家常小馆 | 午餐、晚餐 | 米饭及小份家常菜；有独立小馆背景 |
| 水果摊 | 三餐时段 | 苹果、香蕉；有独立水果摊背景 |

新界面、介绍与邀约中不再使用社区食堂／小超市的名称。家常小馆和水果摊沿用旧来源ID，保存的旧餐次名称不被改写，旧版正在选择的菜单与餐盘仍可恢复；再次进店时过滤旧菜单缓存。老陈原来的外出晚餐邀约对应家常小馆，仍须实际同桌才记为完成。

浏览、换地点、查看库存和取消不结算餐次；确认购买后才按餐食及来源扣费／精力。新早餐店耗2精力，其余来源的原有制作／取用／外出消耗保持。

## 插画与提示词

九张素材均用内置ImageGen生成，保留原图，项目文件在`life-strategy/assets/generated/stories/locations/`。完整提示词、参照、尺寸、保存路径和SHA256见[素材清单](../../life-strategy/assets/generated/stories/locations/manifest.json)。

- 厨房：`zhou-kitchen-v1.png`、`zhou-kitchen-portrait-v1.png`。
- 开门冰箱：`zhou-open-fridge-v1.png`。
- 集市：`zhou-market-wide-v1.png`、`zhou-market-portrait-v1.png`。
- 店铺：`zhou-breakfast-shop-v1.png`、`zhou-homestyle-diner-v1.png`、`zhou-fruit-stall-v1.png`。
- 早餐食物卡：`steamed-bun-v1.png`，保留透明背景。

## 验证与试玩

完整回归**523/523、45套**，导出门禁**41项**通过。覆盖营业时间与菜单对应、免费往返、确认支付、工作台背景恢复、下一餐回家、旧来源及冻结记录兼容，并将早餐店加入双篇共用卡牌与成本预览检查。[测试报告](../assets/household-locations-2026-10-23/tests-report.json)。

1280×720、640×960、390×640三个独立原生窗口，以真实视口鼠标／键盘操作检查全部地点、配方／存粮及返回，并确认一顿小馆购买。午餐为明确的阶段夹具，校园选餐用于跨篇复查；没有把该探针当作完整日／周游玩。[原生报告](../assets/household-locations-2026-10-23/native-report.json)。

- [桌面厨房](../assets/household-locations-2026-10-23/1280x720-02-kitchen.png)、[桌面冰箱](../assets/household-locations-2026-10-23/1280x720-05-fridge-foods.png)、[桌面集市](../assets/household-locations-2026-10-23/1280x720-06-market-breakfast.png)。
- [窄屏厨房](../assets/household-locations-2026-10-23/390x640-02-kitchen.png)、[窄屏冰箱](../assets/household-locations-2026-10-23/390x640-05-fridge-foods.png)、[窄屏集市](../assets/household-locations-2026-10-23/390x640-06-market-breakfast.png)。
- [早餐店](../assets/household-locations-2026-10-23/1280x720-07-breakfast-shop.png)、[家常小馆](../assets/household-locations-2026-10-23/1280x720-10-homestyle-diner.png)、[水果摊](../assets/household-locations-2026-10-23/1280x720-08-fruit-stall.png)。

Web候选为`artifacts/household-locations-2026-10-23-web/`，PCK **127.21 MiB、430个条目**。项目设置文件头、九张新图及两个新脚本均通过包内检查；匹配Godot运行时直接从导出包加载图片并走通集市、早餐菜单、厨房及库存返回，无运行错误。[包内报告](../assets/household-locations-2026-10-23/pack-report.json)。导出仍有既有的编辑器设置保存诊断，包内启动与审计单独通过。

浏览器在1280×720和390×640下，实际从原有第2天早餐进度进入厨房、冰箱、集市、早餐店、水果摊与库存，再返回。没有注入游戏状态、确认购买或推进当前餐次；余额204、排练8/70和人物状态保持。小馆的午餐开放与购买由原生探针验证。[浏览器记录](../assets/household-locations-2026-10-23/browser/report.json)。

[打开本机预览](http://127.0.0.1:8881/)，当前服务已更新为本轮候选，保留浏览器页。原Play／Windows演示包及前一版候选没有覆盖，未提交、推送或对外发布。
