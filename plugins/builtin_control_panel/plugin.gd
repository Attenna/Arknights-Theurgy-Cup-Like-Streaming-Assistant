# plugin.gd
# 内置插件：控制面板（builtin_control_panel）。
# 通过清单声明 main_window 面板能力，由引导壳从 PluginRegistry 注入。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "builtin_control_panel"
	metadata.name = "控制面板"
	metadata.description = "内置控制面板插件：主窗口控制面板"
	return metadata

func on_enable() -> void:
	print("[builtin_control_panel] 已启用")