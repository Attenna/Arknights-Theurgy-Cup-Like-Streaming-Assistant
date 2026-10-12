# plugin.gd
# 内置插件：候场页（builtin_waiting_scene）。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "builtin_waiting_scene"
	metadata.name = "候场页"
	metadata.description = "内置直播场景插件：候场页"
	return metadata

func on_enable() -> void:
	print("[builtin_waiting_scene] 已启用")