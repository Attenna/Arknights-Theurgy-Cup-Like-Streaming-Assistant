extends Node2D

const MAIN_VISION_SCENE = preload("res://scene/main_vision.tscn")
const STREAMING_ARENA_SCENE = preload("res://scene/streaming_arena.tscn")
const WAITING_SCENE = preload("res://scene/waiting_scene.tscn")
const ED_SCENE = preload("res://scene/ED.tscn")
const PK_SCENE = preload("res://scene/PK.tscn")
const TOURNAMENT_STATUS_SCENE = preload("res://scene/ui/tournament_status.tscn")

@onready var main_content_root: Node2D = $MainContentRoot
@onready var player_api_client: Node = $PlayerApiClient
@onready var player_manager: Node = $PlayerManager
@onready var commentator_manager: Node = $CommentatorManager

var current_scene_instance: Node = null
var current_scene_id: String = ""
var control_panel_window: Window = null
var tournament_status_window: Window = null
var current_mode: String = "Red"
var players_data: Dictionary = {}

# Stage tracking
var staged_red_player_id: int = -1
var staged_blue_player_id: int = -1

var scene_map = {
	"MainVision": MAIN_VISION_SCENE,
	"StreamingArena": STREAMING_ARENA_SCENE,
	"WaitingScene": WAITING_SCENE,
	"ED": ED_SCENE,
	"PK": PK_SCENE
}

# Cached display nodes so selection/stage updates don't have to walk the whole
# scene tree on every signal. Rebuilt whenever a scene is (re)loaded.
var _display_nodes: Array = []  # nodes that implement Display / DisplayPlayer
var _commentator_nodes: Array = []  # nodes that implement DisplayCommentator

func _ready():
	load_initial_scene()
	call_deferred("create_control_panel_window")
	setup_player_api()

func load_initial_scene():
	_on_transition_requested("MainVision")

func create_control_panel_window():
	var panel_scene = load("res://scene/ui/control_panel.tscn")
	if not panel_scene:
		print("ERROR: Cannot load control_panel.tscn")
		return

	control_panel_window = panel_scene.instantiate()
	get_tree().root.add_child(control_panel_window)

	control_panel_window.close_requested.connect(_on_control_panel_close)

	if control_panel_window.has_signal("scene_selected"):
		control_panel_window.scene_selected.connect(_on_transition_requested)

	if control_panel_window.has_signal("mode_changed"):
		control_panel_window.mode_changed.connect(_on_mode_changed)

	if control_panel_window.has_signal("stage_player"):
		control_panel_window.stage_player.connect(_on_stage_player)

	if control_panel_window.has_signal("stage_clear"):
		control_panel_window.stage_clear.connect(_on_stage_clear)

	if control_panel_window.has_signal("tournament_status_requested"):
		control_panel_window.tournament_status_requested.connect(_on_tournament_status_requested)

	var screen_size = DisplayServer.screen_get_size()
	control_panel_window.position = (screen_size - Vector2i(420, 650)) / 2
	control_panel_window.show()

func _on_transition_requested(scene_id: String):
	if current_scene_id == scene_id:
		return

	if current_scene_instance and is_instance_valid(current_scene_instance):
		current_scene_instance.queue_free()
		current_scene_instance = null

	if not scene_map.has(scene_id):
		return

	var scene_resource = scene_map[scene_id]
	current_scene_instance = scene_resource.instantiate()
	main_content_root.add_child(current_scene_instance)
	current_scene_id = scene_id

	# Build the display-node cache once for this scene (deep + method-agnostic).
	_refresh_display_cache()
	apply_mode_to_scene(current_scene_instance)
	# Re-apply staged players to newly loaded scene
	_apply_staged_players()

func _on_mode_changed(mode: String):
	current_mode = mode

	if current_scene_instance and is_instance_valid(current_scene_instance):
		apply_mode_to_scene(current_scene_instance)

func apply_mode_to_scene(scene_node: Node):
	_apply_mode_recursive(scene_node)
	_apply_staged_players()

func _apply_mode_recursive(node: Node):
	toggle_red_blue_visibility(node)
	if node.has_method("UpdateWithMode"):
		node.UpdateWithMode(current_mode)
	for child in node.get_children():
		_apply_mode_recursive(child)

func toggle_red_blue_visibility(node: Node):
	# 信息卡片（实现 Display / DisplayPlayer）始终可见：其内容由红蓝路由决定，
	# 不应随模式切换被显隐。模式显隐仅作用于背景、装饰等元素。
	if node.has_method("Display") or node.has_method("DisplayPlayer"):
		return

	var node_name = str(node.name).to_lower()
	var is_red = "red" in node_name or node_name.begins_with("r_") or node_name.ends_with("_r")
	var is_blue = "blue" in node_name or node_name.begins_with("b_") or node_name.ends_with("_b")

	if is_red or is_blue:
		node.visible = (is_red and current_mode == "Red") or (is_blue and current_mode == "Blue")

	if "方胜纹" in str(node.name):
		update_pattern_color(node)

	for child in node.get_children():
		toggle_red_blue_visibility(child)

func update_pattern_color(node: Node):
	var material = node.material
	if material and material is ShaderMaterial:
		var red_color = Color(1, 0.3, 0.3, 1)
		var blue_color = Color(0.223034, 0.57082, 0.770943, 1)
		material.set_shader_parameter("line_tint", red_color if current_mode == "Red" else blue_color)

func _on_control_panel_close():
	get_tree().quit()

func _on_tournament_status_requested():
	if tournament_status_window != null and is_instance_valid(tournament_status_window):
		tournament_status_window.show()
		tournament_status_window.grab_focus()
		return

	var win = TOURNAMENT_STATUS_SCENE.instantiate()
	win.set_script(load("res://scripts/ui/tournament_status.gd"))
	get_tree().root.add_child(win)
	tournament_status_window = win
	win.close_requested.connect(_on_tournament_status_close)
	var screen_size = DisplayServer.screen_get_size()
	win.position = (screen_size - Vector2i(560, 840)) / 2
	win.show()

func _on_tournament_status_close():
	if tournament_status_window and is_instance_valid(tournament_status_window):
		tournament_status_window.queue_free()
		tournament_status_window = null

func setup_player_api():
	if player_api_client and player_api_client.has_method("FetchPlayers"):
		player_api_client.connect("players_loaded", _on_players_loaded)
		player_api_client.connect("load_failed", _on_load_failed)
		print("PlayerApiClient initialized - waiting for user login")
	else:
		print("WARNING: PlayerApiClient not found or invalid")

	if player_manager:
		player_manager.connect("player_selected", _on_player_selected)
		player_manager.connect("players_updated", _on_players_updated)
		print("PlayerManager initialized")

	if commentator_manager:
		commentator_manager.connect("commentator_selected", _on_commentator_selected)
		commentator_manager.connect("commentators_updated", _on_commentators_updated)
		print("CommentatorManager initialized")

func _on_players_loaded(data: Dictionary):
	players_data = data
	print("Players loaded successfully")
	print("Player count: ", data.size())

	if player_manager and player_manager.has_method("LoadPlayers"):
		player_manager.LoadPlayers(data)

	if commentator_manager and commentator_manager.has_method("LoadCommentators"):
		commentator_manager.LoadCommentators(data)

func _on_load_failed(error: String):
	print("ERROR: Failed to load players - ", error)

func _on_player_selected(player_id):
	if player_manager and player_manager.has_method("GetPlayerDictionary"):
		var player_data = player_manager.GetPlayerDictionary(player_id)
		update_player_displays(player_data)

func _on_players_updated():
	if player_manager:
		print("Players updated, total: ", len(player_manager.Players))

func _on_commentator_selected(commentator_id):
	if commentator_manager and commentator_manager.has_method("GetCommentatorDictionary"):
		var commentator_data = commentator_manager.GetCommentatorDictionary(commentator_id)
		update_commentator_displays(commentator_data)

func _on_commentators_updated():
	if commentator_manager:
		print("Commentators updated, total: ", len(commentator_manager.Commentators))

# --- Stage (上台) handlers ---

func _on_stage_player(player_id: int, side: String):
	if side == "Red":
		staged_red_player_id = player_id
	else:
		staged_blue_player_id = player_id
	_apply_staged_players()
	# Keep the control panel's staged-player card in sync.
	if control_panel_window and control_panel_window.has_method("update_stage_display"):
		var pdict = null
		if player_manager and player_manager.has_method("GetPlayerDictionary"):
			pdict = player_manager.GetPlayerDictionary(player_id)
		control_panel_window.update_stage_display(side, pdict)

func _on_stage_clear(side: String):
	if side == "Red":
		staged_red_player_id = -1
		print("[Stage] Red stage cleared")
	else:
		staged_blue_player_id = -1
		print("[Stage] Blue stage cleared")

	_apply_staged_players()
	# Clear the control panel's staged-player card too.
	if control_panel_window and control_panel_window.has_method("update_stage_display"):
		control_panel_window.update_stage_display(side, "")

func _apply_staged_players():
	"""Apply staged players to cached scene display nodes, routing by side."""
	var red_player = null
	var blue_player = null

	if player_manager and player_manager.has_method("GetPlayerDictionary"):
		if staged_red_player_id > 0:
			red_player = player_manager.GetPlayerDictionary(staged_red_player_id)
		if staged_blue_player_id > 0:
			blue_player = player_manager.GetPlayerDictionary(staged_blue_player_id)

	for entry in _display_nodes:
		var node = entry.node
		if not is_instance_valid(node):
			continue
		if entry.is_red:
			_dispatch_display_player(node, red_player)
		elif entry.is_blue:
			_dispatch_display_player(node, blue_player)
		else:
			# Neutral nodes: show based on current mode
			var player_to_show = red_player if current_mode == "Red" else blue_player
			_dispatch_display_player(node, player_to_show)

func update_player_displays(player_data):
	for entry in _display_nodes:
		var node = entry.node
		if is_instance_valid(node):
			_dispatch_display_player(node, player_data)

func update_commentator_displays(commentator_data):
	for node in _commentator_nodes:
		if is_instance_valid(node):
			node.DisplayCommentator(commentator_data)

# --- Display node cache (built per scene load) ---

func _dispatch_display_player(node: Node, data):
	if node.has_method("DisplayPlayer"):
		node.DisplayPlayer(data)
	elif node.has_method("Display"):
		node.Display(data)

func _node_is_red_blue(node: Node):
	var name_lower = str(node.name).to_lower()
	var is_red = "red" in name_lower or name_lower.begins_with("r_") or name_lower.ends_with("_r")
	var is_blue = "blue" in name_lower or name_lower.begins_with("b_") or name_lower.ends_with("_b")
	return {"is_red": is_red, "is_blue": is_blue}

func _refresh_display_cache():
	_display_nodes.clear()
	_commentator_nodes.clear()
	if not current_scene_instance or not is_instance_valid(current_scene_instance):
		return
	_collect_display_nodes(current_scene_instance)

func _collect_display_nodes(node: Node):
	if node.has_method("DisplayPlayer") or node.has_method("Display"):
		var side = _node_is_red_blue(node)
		_display_nodes.append({"node": node, "is_red": side.is_red, "is_blue": side.is_blue})
	if node.has_method("DisplayCommentator"):
		_commentator_nodes.append(node)
	for child in node.get_children():
		_collect_display_nodes(child)
