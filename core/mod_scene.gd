# mod_scene.gd
# 【兼容别名】旧版模组直播场景基类，现等价于 PluginScene（由 PluginScene 演进而来）。
#
# 说明：新代码请直接 `extends PluginScene`。本文件把旧钩子名
# （_on_mod_scene_ready / setup_mod_scene / mod_id）映射到新的 PluginScene 契约之上，
# 以便既有第三方模组直播场景继续工作。后续版本将移除。

class_name ModScene
extends PluginScene

# 旧字段名 mod_id -> 新字段 plugin_id 的兼容映射
var mod_id: String:
	get:
		return plugin_id
	set(value):
		plugin_id = value

# 旧版身份注入入口（ModLoader 使用）
func setup_mod_scene(p_mod_id: String, p_scene_id: String, p_scene_name: String) -> void:
	setup_plugin_scene(p_mod_id, p_scene_id, p_scene_name)

# 把新钩子 _on_scene_enter 桥接到旧钩子 _on_mod_scene_ready
func _on_scene_enter() -> void:
	_on_mod_scene_ready()

# 旧版钩子：场景就绪时调用
func _on_mod_scene_ready() -> void:
	pass