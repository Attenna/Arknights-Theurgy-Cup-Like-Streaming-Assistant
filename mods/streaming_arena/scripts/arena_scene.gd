# arena_scene.gd
# 比赛场直播场景根脚本（内置插件 builtin_streaming_arena）。
# 继承 PluginScene，获得插件身份与统一数据接口。
# 计时器 / 开局藏品 / 解说名单等子组件由场景内的脚本自行处理。

extends PluginScene

func _on_scene_enter() -> void:
	print("[StreamingArena] 比赛场场景进入（plugin=%s scene=%s）" % [plugin_id, scene_id])