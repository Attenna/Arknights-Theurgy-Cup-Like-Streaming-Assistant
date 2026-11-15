# plugin.gd
# 插件：主视觉（main_vision）。
# 通过 provides.scenes[type=live] 向内核注册可切换的直播场景。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "main_vision"
	metadata.name = "主视觉"
	metadata.description = "直播场景插件：主视觉画面"
	return metadata

func on_enable() -> void:
	print("[main_vision] 已启用")
