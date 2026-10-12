# plugin.gd
# 内置插件：比赛场（builtin_streaming_arena）。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "builtin_streaming_arena"
	metadata.name = "比赛场"
	metadata.description = "内置直播场景插件：比赛场"
	return metadata

func on_enable() -> void:
	print("[builtin_streaming_arena] 已启用")