# tests/test_event_bus.gd
# EventBus 契约测试（issue #5）：封装订阅 / owner 清理 / payload 校验。

extends TestCase

func run() -> bool:
	_test_subscribe_roundtrip()
	_test_unsubscribe_all()
	_test_duplicate_subscribe()
	_test_validate_payload()
	return summary("test_event_bus")

func _bus() -> EventBus:
	return load("res://core/services/event_bus.gd").new()

func _test_subscribe_roundtrip() -> void:
	var bus := _bus()
	var received := []
	bus.subscribe(EventCatalog.DATA_RELOADED, func(p): received.append(p), &"test_owner")
	bus.emit_event(EventCatalog.DATA_RELOADED, {"scope": "test"})
	eq(received.size(), 1, "订阅者收到事件负载")
	eq(received[0].get("scope"), "test", "负载内容一致")
	bus.emit_event(EventCatalog.SCENE_CHANGED, {"to_scene": "x"})
	eq(received.size(), 1, "未订阅事件不分发到该回调")
	bus.free()

func _test_unsubscribe_all() -> void:
	var bus := _bus()
	var received := []
	bus.subscribe(EventCatalog.DATA_RELOADED, func(p): received.append(p), &"test_owner")
	bus.unsubscribe_all(&"test_owner")
	bus.emit_event(EventCatalog.DATA_RELOADED, {"scope": "after"})
	eq(received.size(), 0, "unsubscribe_all 后不再分发")
	bus.free()

func _test_duplicate_subscribe() -> void:
	var bus := _bus()
	var received := []
	var cb := func(p): received.append(p)
	bus.subscribe(EventCatalog.DATA_RELOADED, cb, &"o1")
	bus.subscribe(EventCatalog.DATA_RELOADED, cb, &"o1")
	bus.emit_event(EventCatalog.DATA_RELOADED, {"scope": "dup"})
	eq(received.size(), 1, "重复订阅同一回调只生效一次")
	bus.free()

func _test_validate_payload() -> void:
	var bus := _bus()
	# 合法负载通过
	eq(bus.validate_payload(EventCatalog.DATA_RELOADED, {"scope": "x"}).size(), 0, "合法 payload 通过校验")
	# 缺必填字段报问题（含事件名与字段名）
	var issues: Array[String] = bus.validate_payload(EventCatalog.DATA_RELOADED, {})
	eq(issues.size(), 1, "缺必填 payload 字段报问题")
	ok(issues[0].contains("data_reloaded") and issues[0].contains("scope"), "问题信息含事件名与字段名")
	# 事件名未登记
	eq(bus.validate_payload("no_such_event", {}).size(), 1, "未登记事件名报问题")
	bus.free()
