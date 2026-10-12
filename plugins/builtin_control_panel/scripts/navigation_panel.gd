# navigation_panel.gd
# 控制面板的"导航面板"：动态列出所有已注册的直播场景，点击即请求切换。
#
# 替代旧 scene_manager.gd（它把三个场景 ID 硬编码进按钮）。
# 现在按钮完全由内核 SceneDirector 中注册的场景驱动 —— 新增场景（内置或第三方）
# 无需改动本文件，即可自动出现在导航面板中。

extends VBoxContainer

signal transition_requested(target_scene_id: String)

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "直播场景"
	add_child(header)

	var kernel := get_node_or_null("/root/Kernel")
	if kernel == null or kernel.scene_director == null:
		_add_info("场景系统未就绪")
		return

	var scenes: Array = kernel.scene_director.get_scenes_by_type("live")
	if scenes.is_empty():
		_add_info("暂无可用场景")
		return

	for info in scenes:
		var scene_id := str(info.get("id", ""))
		var button := Button.new()
		button.text = "转场至%s" % str(info.get("name", scene_id))
		button.tooltip_text = str(info.get("description", ""))
		button.pressed.connect(_on_scene_pressed.bind(scene_id))
		add_child(button)

func _add_info(text: String) -> void:
	var label := Label.new()
	label.text = text
	add_child(label)

func _on_scene_pressed(scene_id: String) -> void:
	if scene_id.is_empty():
		return
	print("[NavigationPanel] Requesting transition to scene: %s" % scene_id)
	transition_requested.emit(scene_id)