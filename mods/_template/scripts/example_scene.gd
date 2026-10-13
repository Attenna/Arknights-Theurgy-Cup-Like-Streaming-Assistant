# example_scene.gd —— 直播场景脚本模板（extends PluginScene）
# PluginScene 提供：plugin_id / scene_id / scene_name 身份注入，
# get_current_player() / get_players() / get_team_by_id() 数据访问，
# player_changed / announcer_changed 信号。

extends PluginScene

@onready var title_label: Label = $TitleLabel

func _on_scene_enter() -> void:
	title_label.text = scene_name

func _on_player_changed(player_data: Dictionary) -> void:
	# 数据字段名必须从 DataKeys 常量取（未建立前先集中登记，见 issue #4）
	title_label.text = str(player_data.get("name", scene_name))
