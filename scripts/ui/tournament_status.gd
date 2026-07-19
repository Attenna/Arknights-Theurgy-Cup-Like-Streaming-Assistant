extends Window

# 冷水坑杯赛事状态表格：从 TournamentApiClient 拉取 /tournament/ 数据并展示，
# 提供「刷新」按钮主动向服务器询问最新赛事进度。

var _client = null

var _title_label: Label
var _refresh_btn: Button
var _fetched_label: Label
var _status_label: Label
var _bonus_label: Label
var _stats_grid: GridContainer
var _leaderboard_grid: GridContainer
var _advance_label: Label
var _error_label: Label

var _stats_order = ["总比赛", "待处理", "待确认", "已确认", "已提交", "争议中", "已结束"]

func _ready():
	title = "冷水坑杯赛事状态"
	size = Vector2i(560, 840)
	close_requested.connect(_on_close)
	_build_ui()
	_init_client()
	_refresh()

func _on_close():
	queue_free()

func _build_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# 标题 + 刷新按钮
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)
	_title_label = Label.new()
	_title_label.text = "赛事状态"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)
	_refresh_btn = Button.new()
	_refresh_btn.text = "刷新"
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	title_row.add_child(_refresh_btn)

	_fetched_label = Label.new()
	_fetched_label.text = "尚未拉取"
	_fetched_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_fetched_label)

	# 赛事状态 + 加成倍率
	var status_panel = PanelContainer.new()
	vbox.add_child(status_panel)
	var status_vbox = VBoxContainer.new()
	status_panel.add_child(status_vbox)
	_status_label = Label.new()
	_status_label.text = "状态：—"
	_status_label.add_theme_font_size_override("font_size", 16)
	status_vbox.add_child(_status_label)
	_bonus_label = Label.new()
	_bonus_label.text = "加成倍率：—"
	status_vbox.add_child(_bonus_label)

	# 比赛统计网格
	var stats_title = Label.new()
	stats_title.text = "比赛统计"
	stats_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(stats_title)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", 8)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_stats_grid)

	# 排行榜表格
	var lb_title = Label.new()
	lb_title.text = "排行榜"
	lb_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lb_title)
	_leaderboard_grid = GridContainer.new()
	_leaderboard_grid.columns = 3
	_leaderboard_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_grid.add_theme_constant_override("h_separation", 8)
	_leaderboard_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_leaderboard_grid)
	_add_grid_header(_leaderboard_grid, ["排名", "队伍", "积分"])

	# 晋级区
	_advance_label = Label.new()
	_advance_label.text = "晋级区：—"
	_advance_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_advance_label)

	# 错误提示
	_error_label = Label.new()
	_error_label.text = ""
	_error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_error_label.visible = false
	vbox.add_child(_error_label)

func _add_grid_header(grid: GridContainer, headers: Array):
	for h in headers:
		var lbl = Label.new()
		lbl.text = h
		lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		grid.add_child(lbl)

func _init_client():
	var script = load("res://scripts/TournamentApiClient.cs")
	_client = script.new()
	add_child(_client)
	_client.connect("tournament_updated", _on_tournament_updated)
	_client.connect("tournament_error", _on_tournament_error)

func _refresh():
	_error_label.visible = false
	_refresh_btn.disabled = true
	_refresh_btn.text = "拉取中…"
	if _client != null and _client.has_method("RequestStatus"):
		_client.RequestStatus()

func _on_refresh_pressed():
	_refresh()

func _on_tournament_updated(data: Dictionary):
	_refresh_btn.disabled = false
	_refresh_btn.text = "刷新"
	_error_label.visible = false
	_populate(data)

func _on_tournament_error(err: String):
	_refresh_btn.disabled = false
	_refresh_btn.text = "刷新"
	_error_label.text = "错误：" + err
	_error_label.visible = true

func _populate(data: Dictionary):
	_title_label.text = "赛事状态：" + str(data.get("name", ""))
	_fetched_label.text = "更新时间：" + str(data.get("fetched_at", ""))

	var note = str(data.get("status_note", ""))
	_status_label.text = "状态：" + str(data.get("status", "—")) + ((" · " + note) if note != "" else "")
	_bonus_label.text = "加成倍率：×" + str(data.get("bonus_multiplier", "—"))

	# 比赛统计
	for c in _stats_grid.get_children():
		c.queue_free()
	var stats = data.get("stats", {})
	for label in _stats_order:
		var key_label = Label.new()
		key_label.text = label
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(key_label)
		var val_label = Label.new()
		val_label.text = str(stats.get(label, "—"))
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats_grid.add_child(val_label)

	# 排行榜
	for c in _leaderboard_grid.get_children():
		c.queue_free()
	_add_grid_header(_leaderboard_grid, ["排名", "队伍", "积分"])
	var lb = data.get("leaderboard", [])
	if lb.size() == 0:
		var empty = Label.new()
		empty.text = "暂无队伍"
		_leaderboard_grid.add_child(empty)
		_leaderboard_grid.add_child(Label.new())
		_leaderboard_grid.add_child(Label.new())
	else:
		for row in lb:
			var rank = Label.new()
			rank.text = str(row.get("rank", ""))
			rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_leaderboard_grid.add_child(rank)
			var team = Label.new()
			team.text = str(row.get("team", ""))
			team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_leaderboard_grid.add_child(team)
			var pts = Label.new()
			pts.text = str(row.get("points", ""))
			pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_leaderboard_grid.add_child(pts)

	# 晋级区
	_advance_label.text = "晋级区：" + str(data.get("advance", "—"))
