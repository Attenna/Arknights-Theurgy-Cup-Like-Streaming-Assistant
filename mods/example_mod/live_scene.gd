# live_scene.gd
# Example plugin streaming (live) scene.
# Demonstrates how a plugin builds a live scene on top of the PluginScene base class:
# it reads the current show data and reacts to player changes in real time.

extends PluginScene

@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle
@onready var player_label: Label = $PlayerLabel
@onready var team_label: Label = $TeamLabel
@onready var score_label: Label = $ScoreLabel
@onready var opening_label: Label = $OpeningLabel

func _on_scene_enter() -> void:
	title_label.text = scene_name if not scene_name.is_empty() else "插件直播场景"
	subtitle_label.text = "由 %s 提供 · 演示插件直播场景开发" % plugin_id
	_refresh(get_current_player())
	print("[ExampleMod] Live scene ready: %s (%s)" % [scene_name, scene_id])

func _on_player_changed(player_data: Dictionary) -> void:
	_refresh(player_data)

func _refresh(player_data: Dictionary) -> void:
	if player_data.is_empty():
		player_label.text = "选手：—"
		team_label.text = "队伍：—"
		score_label.text = "分数：—"
		opening_label.text = "开局：—"
		return

	player_label.text = "选手：%s" % str(player_data.get("name", "未知"))

	var team_id := str(player_data.get("team_id", ""))
	var team := get_team_by_id(team_id)
	if team.is_empty():
		team_label.text = "队伍：%s" % (team_id if not team_id.is_empty() else "—")
	else:
		team_label.text = "队伍：%s (%s)" % [str(team.get("name", team_id)), team_id]

	var stats: Dictionary = player_data.get("stats", {})
	score_label.text = "分数：%s" % str(stats.get("score", 0))

	var operator := str(player_data.get("starting_operator_choice", ""))
	var squad := str(player_data.get("starting_squad_choice", ""))
	opening_label.text = "开局：%s / %s" % [
		operator if not operator.is_empty() else "—",
		squad if not squad.is_empty() else "—"
	]