# plugin.gd
# 内置插件：数据录入编辑器（builtin_editors）。
# 仅通过清单声明 panels 能力，实际装载由控制面板按 slot=editor 动态完成。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "builtin_editors"
	metadata.name = "数据录入编辑器"
	metadata.description = "内置编辑器插件：选手 / 队伍 / 解说信息录入面板"
	return metadata

func on_enable() -> void:
	print("[builtin_editors] 已启用")