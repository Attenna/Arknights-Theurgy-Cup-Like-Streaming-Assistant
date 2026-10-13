# plugin.gd
# 实例模板插件：比赛场（streaming_arena）。
# 演示资源自携带：assets/textures、assets/fonts、assets/shaders 全部随插件分发，
# 场景以相对路径引用，脚本以 get_script().resource_path 为基准加载。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "streaming_arena"
	metadata.name = "比赛场（模板示例）"
	metadata.description = "实例模板插件：比赛场，资源自携带"
	return metadata

func on_enable() -> void:
	print("[streaming_arena] 已启用")