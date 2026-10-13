# plugin.gd —— 协作测试插件 A（发布方，issue #6 集成测试活教材）
#
# 与测试插件 B 组成纯 EventBus 协作闭环（铁律 1 活教材：插件间零脚本引用、零节点访问）：
# 本插件启用后订阅 pong，并在帧末发布一次 ping（call_deferred，确保同批加载的
# 后续插件已完成订阅）；每收到一次 pong 计数 +1。
# 集成测试（tests/test_integration.gd）断言：闭环收发、热重载后订阅数守恒。
# 目录名 _ 前缀：export_mods.ps1 排除，不进分发 zip。

extends Plugin

const PLUGIN_ID := "test_pair_a"

var pong_count := 0
var _seq := 0

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = PLUGIN_ID
	metadata.name = "协作测试插件 A（发布方）"
	metadata.description = "issue #6 集成测试：纯 EventBus 协作闭环的发布方"
	return metadata

func on_enable() -> void:
	get_event_bus().subscribe(EventCatalog.TEST_PAIR_PONGED, _on_ponged, StringName(PLUGIN_ID))
	# 帧末自启动闭环：deferred 到本帧结束时发布，此时全部插件均已加载订阅
	call_deferred("_emit_ping")

func _emit_ping() -> void:
	_seq += 1
	get_event_bus().emit_event(EventCatalog.TEST_PAIR_PINGED, {"seq": _seq})

func _on_ponged(payload: Dictionary) -> void:
	pong_count += 1
