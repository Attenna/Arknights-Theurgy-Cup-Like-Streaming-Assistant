# plugin.gd —— 协作测试插件 B（订阅方，issue #6 集成测试活教材）
#
# 订阅 ping，收到后回发 pong（带 seq 与 by 字段），与插件 A 构成纯 EventBus 协作闭环。
# 目录名 _ 前缀：export_mods.ps1 排除，不进分发 zip。

extends Plugin

const PLUGIN_ID := "test_pair_b"

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = PLUGIN_ID
	metadata.name = "协作测试插件 B（订阅方）"
	metadata.description = "issue #6 集成测试：纯 EventBus 协作闭环的订阅方"
	return metadata

func on_enable() -> void:
	get_event_bus().subscribe(EventCatalog.TEST_PAIR_PINGED, _on_pinged, StringName(PLUGIN_ID))

func _on_pinged(payload: Dictionary) -> void:
	get_event_bus().emit_event(EventCatalog.TEST_PAIR_PONGED, {
		"seq": int(payload.get("seq", 0)),
		"by": PLUGIN_ID,
	})
