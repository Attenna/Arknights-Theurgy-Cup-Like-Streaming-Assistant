# main_vision_scene.gd
# 主视觉直播场景根脚本（内置插件 builtin_main_vision）。
# 继承 PluginScene，获得插件身份与统一数据接口（当前选手 / 队伍 / 解说）。
# 主视觉本身只是静态画面，这里保留最小实现，供后续扩展时覆写钩子。

extends PluginScene

func _on_scene_enter() -> void:
	print("[MainVision] 主视觉场景进入（plugin=%s scene=%s）" % [plugin_id, scene_id])