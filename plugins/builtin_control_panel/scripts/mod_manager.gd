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

	# 热重载：全局按钮
	var reload_all_button := Button.new()
	reload_all_button.text = "重载全部插件 (F5)"
	reload_all_button.tooltip_text = "重新加载所有插件（脚本 / 场景 / 数据）"
	reload_all_button.pressed.connect(_on_reload_all_pressed)
	add_child(reload_all_button)

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

		var row := HBoxContainer.new()
		var mod_label := Label.new()
		mod_label.text = "◆ " + title
		mod_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mod_label)

		var reload_button := Button.new()
		reload_button.text = "重载"
		reload_button.tooltip_text = "热重载该模组"
		reload_button.pressed.connect(_on_reload_mod_pressed.bind(str(mod_id)))
		row.add_child(reload_button)
		add_child(row)

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

func _on_reload_all_pressed() -> void:
	var kernel := get_node_or_null("/root/Kernel")
	if kernel and kernel.plugin_manager:
		kernel.plugin_manager.reload_all()

func _on_reload_mod_pressed(mod_id: String) -> void:
	var kernel := get_node_or_null("/root/Kernel")
	if kernel and kernel.plugin_manager:
		kernel.plugin_manager.reload_plugin(mod_id)

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