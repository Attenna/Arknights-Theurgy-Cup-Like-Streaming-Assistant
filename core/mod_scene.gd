# mod_scene.gd
# Base class for mod-provided streaming (live) scenes.
#
# A mod developer creates a scene whose root node uses a script that `extends ModScene`.
# The ModLoader will call `setup_mod_scene()` before the scene enters the tree, and the
# helpers below give read-only access to the current show data (players / team / announcer).

class_name ModScene
extends Node2D

# Emitted when the current player changes (hooked to the control panel's NowPlayer).
signal player_changed(player_data: Dictionary)
signal announcer_changed(announcer_data: Dictionary)

# Identity, filled in by ModLoader.setup_mod_scene().
var mod_id: String = ""
var scene_id: String = ""
var scene_name: String = ""

func _ready() -> void:
	add_to_group("mod_scenes")
	_connect_core_signals()
	_on_mod_scene_ready()

# Called by the ModLoader before this node is added to the tree.
func setup_mod_scene(p_mod_id: String, p_scene_id: String, p_scene_name: String) -> void:
	mod_id = p_mod_id
	scene_id = p_scene_id
	scene_name = p_scene_name

# ── Overridable hooks ────────────────────────────────────────────────────────

# Override to build your live scene. Called once when the scene is ready.
func _on_mod_scene_ready() -> void:
	pass

# Override to react to the current player changing.
func _on_player_changed(_player_data: Dictionary) -> void:
	pass

# Override to react to the current announcer changing.
func _on_announcer_changed(_announcer_data: Dictionary) -> void:
	pass

# ── Signal wiring ────────────────────────────────────────────────────────────

func _connect_core_signals() -> void:
	# Defer so the control panel's NowPlayer / NowAnnouncer nodes can finish loading.
	call_deferred("_delayed_connect")

func _delayed_connect() -> void:
	for node in get_tree().get_nodes_in_group("now_player"):
		if node.has_signal("player_selected") and not node.player_selected.is_connected(_on_player_selected):
			node.player_selected.connect(_on_player_selected)
	for node in get_tree().get_nodes_in_group("now_announcer"):
		if node.has_signal("announcer_selected") and not node.announcer_selected.is_connected(_on_announcer_selected):
			node.announcer_selected.connect(_on_announcer_selected)

func _on_player_selected(player_data: Dictionary) -> void:
	player_changed.emit(player_data)
	_on_player_changed(player_data)

func _on_announcer_selected(announcer_data: Dictionary) -> void:
	announcer_changed.emit(announcer_data)
	_on_announcer_changed(announcer_data)

# ── Data access helpers (read-only) ──────────────────────────────────────────

func get_userdata_dir() -> String:
	var app_data = get_node_or_null("/root/AppData")
	if app_data and app_data.has_method("get_exe_dir"):
		return app_data.get_exe_dir()
	return OS.get_executable_path().get_base_dir()

func get_current_player() -> Dictionary:
	var data = _read_json(get_userdata_dir() + "/userdata/players/current_player.json")
	return data if data is Dictionary else {}

func get_current_announcer() -> Dictionary:
	var data = _read_json(get_userdata_dir() + "/userdata/announcers/current_announcer.json")
	return data if data is Dictionary else {}

func get_players() -> Array:
	var data = _read_json(get_userdata_dir() + "/userdata/players/players.json")
	return data if data is Array else []

func get_teams() -> Array:
	var data = _read_json(get_userdata_dir() + "/userdata/teams/teams.json")
	return data if data is Array else []

func get_team_by_id(team_id: String) -> Dictionary:
	for team in get_teams():
		if team is Dictionary and str(team.get("id", "")) == team_id:
			return team
	return {}

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text = file.get_as_text()
	file.close()
	return JSON.parse_string(text)