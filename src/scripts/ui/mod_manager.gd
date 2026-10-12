# mod_manager.gd
# Control-panel widget that lists loaded mods and their streaming (live) scenes,
# and lets the operator switch to any of them.

extends VBoxContainer

signal transition_requested(target_scene_id: String)

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "模组直播场景"
	add_child(header)

	var mod_loader = get_node_or_null("/root/ModLoader")
	if mod_loader == null:
		_add_info("模组系统未加载")
		return

	var mods: Array = mod_loader.get_loaded_mods()
	if mods.is_empty():
		_add_info("未加载任何模组")
		return

	var has_any := false
	for mod_id in mods:
		var metadata = mod_loader.get_mod_metadata(mod_id)
		var title := str(mod_id)
		if metadata != null:
			title = "%s v%s" % [metadata.name, metadata.version]
		var mod_label := Label.new()
		mod_label.text = "◆ " + title
		add_child(mod_label)

		var scenes: Array = _scenes_for_mod(mod_loader.get_streaming_scenes(), str(mod_id))
		if scenes.is_empty():
			continue
		has_any = true
		for scene_info in scenes:
			var button := Button.new()
			button.text = "  " + str(scene_info.get("name", scene_info.get("id", "?")))
			button.tooltip_text = "%s\n模组: %s" % [
				scene_info.get("description", ""), scene_info.get("mod_id", "")
			]
			button.pressed.connect(_on_scene_pressed.bind(str(scene_info.get("id", ""))))
			add_child(button)

	if not has_any:
		_add_info("已加载模组未提供直播场景")

func _scenes_for_mod(all_scenes: Array, mod_id: String) -> Array:
	var result: Array = []
	for scene_info in all_scenes:
		if str(scene_info.get("mod_id", "")) == mod_id:
			result.append(scene_info)
	return result

func _add_info(text: String) -> void:
	var label := Label.new()
	label.text = text
	add_child(label)

func _on_scene_pressed(scene_id: String) -> void:
	if scene_id.is_empty():
		return
	print("[ModManager] Requesting transition to mod scene: %s" % scene_id)
	transition_requested.emit(scene_id)