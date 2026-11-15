# plugin.gd
# 控制面板基底插件（control_panel_base）。
# 只提供面板骨架：窗口 + 二级面板装载槽。自身不实现任何业务功能。
# 二级面板插件以 slot="control_panel" 注册（如 scene_manager_panel）。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "control_panel_base"
	metadata.name = "控制面板基底"
	metadata.description = "提供控制面板骨架，装载二级面板"
	return metadata

func on_enable() -> void:
	print("[control_panel_base] 已启用")
