# scene_manager_panel.gd —— 二级面板：列出全部已注册的直播场景，供选择播出。
# 数据源：SceneDirector.get_scenes_by_type("live")（由内核实时维护，
# 任何插件注册 / 注销场景后重载本面板即可刷新）。
# 交互：点击按钮 → SceneDirector.switch_to(id)；scene_changed 信号驱动高亮。

extends VBoxContainer

var _buttons: Dictionary = {}
var _director: SceneDirector = null

@onready var buttons_box: VBoxContainer = $Buttons

func _ready() -> void:
	# 本脚本非 Plugin 派生，经访问层 for_node 取内核服务（ADR-0001）。
	_director = PluginContext.for_node(self).scene_director
	if _director == null:
		return
	if not _director.scene_changed.is_connected(_on_scene_changed):
		_director.scene_changed.connect(_on_scene_changed)
	_rebuild()

func _exit_tree() -> void:
	if _director != null and _director.scene_changed.is_connected(_on_scene_changed):
		_director.scene_changed.disconnect(_on_scene_changed)

func _rebuild() -> void:
	for child in buttons_box.get_children():
		child.queue_free()
	_buttons.clear()

	if _director == null:
		return
	var director := _director
	var current := str(director.get_current_scene_id())

	for info in director.get_scenes_by_type("live"):
		var scene_id := str(info.get("id", ""))
		if scene_id.is_empty():
			continue
		var btn := Button.new()
		btn.text = str(info.get("name", scene_id))
		btn.toggle_mode = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var desc := str(info.get("description", ""))
		btn.tooltip_text = ("%s\n[%s]" % [desc, scene_id]) if not desc.is_empty() else scene_id
		btn.button_pressed = scene_id == current
		btn.pressed.connect(_on_scene_button_pressed.bind(scene_id))
		buttons_box.add_child(btn)
		_buttons[scene_id] = btn

	if _buttons.is_empty():
		var empty := Label.new()
		empty.text = "（暂无已注册的直播场景）"
		buttons_box.add_child(empty)

func _on_scene_button_pressed(scene_id: String) -> void:
	if _director != null:
		_director.switch_to(scene_id)

func _on_scene_changed(_from_scene: String, to_scene: String) -> void:
	for id in _buttons:
		var btn := _buttons[id] as Button
		btn.button_pressed = id == to_scene
