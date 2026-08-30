extends Control

# 轮播页：赛事分数排名。自建 TournamentApiClient 周期性向服务器询问 /tournament/ 进度，
# 展示状态/加成倍率与排行榜（排名/队伍/积分）。

# 字号常量，方便统一修改
const HEADER_FONT_SIZE := 36   # 表头字号
const ROW_FONT_SIZE := 32      # 排行内容字号
const STATUS_FONT_SIZE := 38   # 顶部状态文字字号

var _client = null
var _status_label: Label
var _grid: GridContainer
var _timer: Timer

func _ready():
	_status_label = get_node_or_null("StatusRow/StatusLabel")
	_grid = get_node_or_null("RankGrid")
	_rebuild_header()

	# 设置顶部状态文字字号
	if _status_label:
		_status_label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)

	_init_client()

	# 周期刷新（即便本页不可见也保持数据新鲜，轮到时即可直接展示）
	_timer = Timer.new()
	_timer.wait_time = 60.0
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_refresh()

func _init_client():
	var script = load("res://scripts/TournamentApiClient.cs")
	_client = script.new()
	add_child(_client)
	_client.connect("tournament_updated", _on_updated)
	_client.connect("tournament_error", _on_error)

func _refresh():
	if _client != null and _client.has_method("RequestStatus"):
		_client.RequestStatus()

func _clear_grid():
	if _grid == null:
		return
	for c in _grid.get_children():
		c.free()

func _rebuild_header():
	if _grid == null:
		return
	_clear_grid()
	for h in ["排名", "队伍", "积分"]:
		var l = Label.new()
		l.text = h
		# 表头字号
		l.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
		l.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		_grid.add_child(l)

func _on_updated(data: Dictionary):
	if _status_label:
		_status_label.text = "状态：%s   加成倍率：×%s" % [str(data.get("status", "—")), str(data.get("bonus_multiplier", "—"))]

	_rebuild_header()
	var lb = data.get("leaderboard", [])
	if lb.size() == 0:
		var e = Label.new()
		e.text = "暂无队伍"
		e.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		_grid.add_child(e)
		_grid.add_child(Label.new())
		_grid.add_child(Label.new())
	else:
		for row in lb:
			var r = Label.new()
			r.text = str(row.get("rank", ""))
			r.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_grid.add_child(r)

			var t = Label.new()
			t.text = str(row.get("team", ""))
			t.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_grid.add_child(t)

			var p = Label.new()
			p.text = str(row.get("points", ""))
			p.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
			p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_grid.add_child(p)

func _on_error(err: String):
	if _status_label:
		_status_label.text = "拉取失败：%s" % err
