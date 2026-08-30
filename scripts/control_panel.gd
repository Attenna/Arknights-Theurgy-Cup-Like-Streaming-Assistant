extends Window

signal mode_changed(mode: String)
signal scene_selected(scene_id: String)
signal stage_player(player_id: int, side: String)
signal stage_clear(side: String)
signal tournament_status_requested
signal countdown_started

# 红/蓝台上选手信息标签，在 _ready 里直接解析好，避免运行时查找实例化子场景节点
# （Godot 对「跨实例边界的根节点」用 get_node / find_child 查找很脆弱，曾导致卡片不刷新）。
var _stage_labels: Dictionary = {}  # side -> {name, nick, team, rating}

func _ready():
	# Mode buttons
	var red_btn = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/ModeSection/ModeButtons/RedBtn")
	var blue_btn = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/ModeSection/ModeButtons/BlueBtn")

	if red_btn:
		red_btn.pressed.connect(_on_red_pressed)

	if blue_btn:
		blue_btn.pressed.connect(_on_blue_pressed)

	# Scene buttons
	var btn_paths = {
		"MainVision": "MarginContainer/ScrollContainer/VBoxContainer/SceneSection/SceneButtons/MainVisionBtn",
		"StreamingArena": "MarginContainer/ScrollContainer/VBoxContainer/SceneSection/SceneButtons/StreamingBtn",
		"WaitingScene": "MarginContainer/ScrollContainer/VBoxContainer/SceneSection/SceneButtons/WaitingBtn",
		"ED": "MarginContainer/ScrollContainer/VBoxContainer/SceneSection/SceneButtons/EDBtn",
		"PK": "MarginContainer/ScrollContainer/VBoxContainer/SceneSection/SceneButtons/PKBtn"
	}

	for scene_id in btn_paths:
		var btn = get_node_or_null(btn_paths[scene_id])
		if btn:
			btn.pressed.connect(_on_scene_pressed.bind(scene_id))

	# 赛事状态（独立信号，打开赛事进度表格）
	var tournament_btn = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/SceneSection/TournamentStatusBtn")
	if tournament_btn:
		tournament_btn.pressed.connect(_on_tournament_status_pressed)

	# Stage clear buttons
	var red_clear = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/StageSection/StagePanels/RedStagePanel/RedStageVBox/RedStageClearBtn")
	var blue_clear = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/StageSection/StagePanels/BlueStagePanel/BlueStageVBox/BlueStageClearBtn")
	if red_clear:
		red_clear.pressed.connect(_on_stage_clear.bind("Red"))
	if blue_clear:
		blue_clear.pressed.connect(_on_stage_clear.bind("Blue"))

	# Exit
	var exit_btn = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/ControlSection/ExitBtn")
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

	# Countdown
	var countdown_btn = get_node_or_null("MarginContainer/ScrollContainer/VBoxContainer/CountdownSection/StartCountdownBtn")
	if countdown_btn:
		countdown_btn.pressed.connect(_on_countdown_pressed)

	_resolve_stage_labels()

func _resolve_stage_labels():
	for side in ["Red", "Blue"]:
		var base = "MarginContainer/ScrollContainer/VBoxContainer/StageSection/StagePanels/" + side + "StagePanel/" + side + "StageVBox/"
		_stage_labels[side] = {
			"name": get_node_or_null(base + side + "StageNameLabel"),
			"nick": get_node_or_null(base + side + "StageNickLabel"),
			"team": get_node_or_null(base + side + "StageTeamLabel"),
			"rating": get_node_or_null(base + side + "StageRatingLabel"),
		}
		for key in _stage_labels[side]:
			if _stage_labels[side][key] == null:
				print("[ControlPanel] WARN: stage label not found: ", base + side + "Stage" + key.capitalize() + "Label")

func _set_label(lbl: Node, text: String):
	if lbl != null:
		lbl.text = text

func update_stage_display(side: String, player: Variant = ""):
	if not _stage_labels.has(side):
		return
	var L = _stage_labels[side]

	if player is Dictionary:
		var username = str(player.get("username", "-"))
		var nick = str(player.get("nickname", ""))
		var team = str(player.get("team_name", ""))
		var rating = str(player.get("rating", "-"))
		_set_label(L.name, username)
		# nickname 为空时回退显示 username，保证总能识别选手
		_set_label(L.nick, nick if nick != "" else username)
		_set_label(L.team, team if team != "" else "-")
		_set_label(L.rating, rating)
	else:
		_set_label(L.name, "-")
		_set_label(L.nick, "-")
		_set_label(L.team, "-")
		_set_label(L.rating, "-")

func _on_red_pressed():
	emit_signal("mode_changed", "Red")

func _on_blue_pressed():
	emit_signal("mode_changed", "Blue")

func _on_scene_pressed(scene_id: String):
	emit_signal("scene_selected", scene_id)

func _on_stage_clear(side: String):
	update_stage_display(side, "")
	emit_signal("stage_clear", side)

func _on_exit_pressed():
	emit_signal("stage_clear", "Red")
	emit_signal("stage_clear", "Blue")
	get_tree().quit()

func _on_tournament_status_pressed():
	emit_signal("tournament_status_requested")

func _on_countdown_pressed():
	emit_signal("countdown_started")
