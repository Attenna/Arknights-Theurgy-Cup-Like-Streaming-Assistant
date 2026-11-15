# ADR-0002：EventBus 订阅 owner 机制（issue #1）

状态：**已实施（2026-10-13）** ｜ 关联：[架构演进路线.md](../架构演进路线.md) 铁律 3、issue #1 ｜ 日期：2026-10-13

## 背景

当前 EventBus 基于 GDScript signal 直连：`bus_event` 通用信号 + 4 个类型化领域信号。
插件热重载/卸载时订阅由各插件自行断开，无机制保证，存在悬空订阅风险；
事件名为裸字符串（如 `"match_stage_changed"`），拼写错误只能运行时发现。

## 方案

1. **EventCatalog.gd**（`core/`，autoload）：全部事件名常量 + payload 契约注释
   （必填/可选/类型）。存量事件（player_changed / announcer_changed / scene_changed /
   data_reloaded + 通用 bus_event 用法）全部入册。
2. **EventBus 增加封装订阅**：
   - `subscribe(event_name: StringName, callback: Callable, owner: StringName) -> void`
     —— 内部记入 `_subs: Dictionary[event_name -> Array[{cb, owner}]]`
   - `unsubscribe_all(owner: StringName) -> void` —— 按属主批量清理
   - 保留现有类型化 signal 不破坏存量；新代码统一走 subscribe/emit_event
3. **PluginManager 集成**：插件卸载与热重载的实例销毁点调用
   `kernel.event_bus.unsubscribe_all(plugin_id)`，保证热重载零悬空订阅。
4. **校验**：debug 构建下 emit_event 校验事件名已登记（未登记 push_warning）；
   release 构建跳过校验（性能）。

## 影响面

- `core/services/event_bus.gd`（改造，向后兼容——类型化 signal 保留）
- `core/event_catalog.gd`（新增 autoload）
- `core/plugin_manager.gd`（卸载点 1-2 处调用）
- `project.godot`（新增 autoload）
- 存量插件：仅在用到裸字符串事件名处改用常量（当前 mods/ 无 EventBus 直接使用点，迁移量为零）

## 备选被否

- 纯 signal + 手动断开（现状）：无机制保证，靠纪律——正是铁律要消除的
- 引入第三方事件框架：超出最小改动，且 GDScript 生态无维护良好的方案

## 验收

对齐 issue #1 清单：目录建立、热重载订阅清理可测（后续 issue #6 集成测试）、
插件开发指南同步订阅用法、`api_version` 评估（无契约破坏则维持 2.0.0）。

> **验收完成（2026-10-14，issue #6）**：热重载订阅清理已由集成测试验证——
> `tests/test_integration.gd` 断言测试插件对热重载 N 次后订阅数守恒
> （直查 `_subs` 按 owner 计数），随 CI 无头执行。

## 补充（2026-10-23）：场景节点订阅残留修复

**问题**：`unsubscribe_all(owner)` 仅在插件卸载 / 热重载时由 PluginManager 调用。
场景切换时 SceneDirector 对旧场景 `queue_free()`，场景内 UI 子节点在 `_ready` 里按
owner=插件 id 订阅后，其回调条目滞留 `_subs`（Callable 绑定已释放节点，靠
`cb.is_valid()` 兜底跳过），反复切换场景会持续累积死条目。

**修复**（纯增量，`api_version` 维持 2.0.0）：
- `EventBus.unsubscribe(event_name: StringName, callback: Callable) -> void`
  —— 只移除该事件下回调相同的条目，不影响同 owner 的其它订阅；条目不存在时静默忽略，
  可安全重复调用（与 `unsubscribe_all` 清理顺序无关）。
- `mods/streaming_arena` 的三个场景脚本改为**命名方法回调**（原匿名 lambda 无法匹配退订），
  并新增 `_exit_tree()` 精确退订本节点订阅。
- 契约测试：`tests/test_event_bus.gd` 的 `_test_unsubscribe_precise()` 断言
  「精确退订不影响同事件其它订阅者」「重复退订不误删条目」。
