# event_bus.gd
# 全局事件总线：内核提供的唯一跨插件通信通道。
# 插件之间不应互相持有引用，而应通过事件总线发布 / 订阅，从而彻底解耦。
#
# 订阅约定（ADR-0002 / issue #1）：
# - 插件订阅一律走 subscribe(event_name, callback, owner)，owner 传插件 id；
#   插件卸载 / 热重载时 PluginManager 调用 unsubscribe_all(owner) 自动清理，杜绝悬空订阅。
# - 类型化信号保留向后兼容；新代码统一走 subscribe / emit_event。

class_name EventBus
extends Node

## 通用事件：插件可发布任意命名事件，payload 为字典。
signal bus_event(event_name: String, payload: Dictionary)

## 常用领域事件（内置插件与第三方插件共享的约定事件）
signal player_changed(player_data: Dictionary)               # 当前选手变化
signal announcer_changed(announcer_data: Dictionary)         # 当前解说变化
signal scene_changed(from_scene: String, to_scene: String)   # 直播场景切换
signal data_reloaded(scope: String)                          # 数据重载（热重载）

# 封装订阅注册表：event_name -> [{cb: Callable, owner: StringName}]
var _subs: Dictionary = {}

## 发布一个通用事件。
## debug 构建校验事件名已登记 + payload 契约（问题 push_warning，不阻断分发）；
## release 构建跳过全部校验（性能）。
func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	if OS.is_debug_build():
		for issue in validate_payload(event_name, payload):
			push_warning("[EventBus] " + issue)
	bus_event.emit(event_name, payload)
	# 封装订阅分发：仅通知订阅了该事件名的回调（回调只收 payload 字典）
	for sub in _subs.get(event_name, []):
		var cb: Callable = sub["cb"]
		if cb.is_valid():
			cb.call(payload)

## 校验事件 payload 契约，返回问题列表（空列表 = 通过）。
## 事件名未登记 / 未登记 payload schema 也会在此报出；测试与 debug 分发共用（issue #5）。
func validate_payload(event_name: String, payload: Dictionary) -> Array[String]:
	var sn := StringName(event_name)
	if not EventCatalog.is_registered(sn):
		return ["事件名未登记（请登记 event_catalog.gd）: %s" % event_name]
	var schema: Dictionary = EventCatalog.PAYLOAD_SCHEMAS.get(sn, {})
	if schema.is_empty():
		return []
	return DataSchema.validate_item(payload, schema, event_name)

## 带 owner 的封装订阅：callback 收到该事件的 payload 字典；owner 为插件 id。
## 同一回调重复订阅同一事件将被拒绝（防止清理错位）。
func subscribe(event_name: StringName, callback: Callable, owner: StringName) -> void:
	var subs: Array = _subs.get(event_name, [])
	for sub in subs:
		if sub["cb"] == callback:
			push_warning("[EventBus] 回调重复订阅事件 %s（owner: %s），已忽略" % [event_name, owner])
			return
	if not _subs.has(event_name):
		_subs[event_name] = []
	_subs[event_name].append({"cb": callback, "owner": owner})

## 按 owner（插件 id）批量清理其全部订阅。插件卸载 / 热重载时由 PluginManager 调用。
func unsubscribe_all(owner: StringName) -> void:
	for event_name in _subs.keys():
		var subs: Array = _subs[event_name]
		_subs[event_name] = subs.filter(func(sub): return sub["owner"] != owner)
