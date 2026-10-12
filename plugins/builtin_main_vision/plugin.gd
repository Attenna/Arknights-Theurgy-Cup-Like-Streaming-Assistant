# plugin.gd
# 内置插件：主视觉（builtin_main_vision）。
# 通过 provides.scenes[type=live] 向内核注册可切换的直播场景。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "builtin_main_vision"
	metadata.name = "主视觉"
	metadata.description = "内置直播场景插件：主视觉画面"
	return metadata

func on_enable() -> void:
	print("[builtin_main_vision] 已启用")