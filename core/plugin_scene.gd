# plugin_scene.gd
# 场景插件基类：所有可切换场景（内置与第三方一视同仁）的统一底座。
#
# 由旧版 ModScene 演进而来；ModScene 仍作为兼容别名保留（见 mod_scene.gd）。
# 使用方式：让你的直播场景根节点脚本 `extends PluginScene`，
# SceneDirector 会在场景进入树之前调用 setup_plugin_scene() 注入身份。

class_name PluginScene
extends Node2D

# 当前选手 / 解说变化（由内核事件转发）
signal player_changed(player_data: Dictionary)
signal announcer_changed(announcer_data: Dictionary)

# 身份信息，由 SceneDirector.setup_plugin_scene() 填充
var plugin_id: String = ""
var scene_id: String = ""
var scene_name: String = ""

func _ready() -> void:
	add_to_group("plugin_scenes")
	add_to_group("mod_scenes") # 兼容旧代码对 "mod_scenes" 分组的引用
	_connect_core_signals()
	_on_scene_enter()

# 由 SceneDirector 在加入场景树之前调用
func setup_plugin_scene(p_plugin_id: String, p_scene_id: String, p_scene_name: String) -> void:
	plugin_id = p_plugin_id
	scene_id = p_scene_id
	scene_name = p_scene_name

# ── 可重写钩子 ───────────────────────────────────────────────────────────────

## 场景进入时调用（等价于旧版 _on_mod_scene_ready）。
func _on_scene_enter() -> void:
	pass

## 场景退出时调用（场景被替换 / 卸载前触发）。
func _on_scene_exit() -> void:
	pass

func _on_player_changed(_player_data: Dictionary) -> void:
	pass

func _on_announcer_changed(_announcer_data: Dictionary) -> void:
	pass

# ── 信号接线 ─────────────────────────────────────────────────────────────────

func _connect_core_signals() -> void:
	# 延迟连接，等待控制面板的 NowPlayer / NowAnnouncer 节点加载完成。
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

# ── 数据访问（统一经 DataService） ───────────────────────────────────────────

func get_userdata_dir() -> String:
	var data_service := _get_data_service()
	if data_service:
		return data_service.get_userdata_dir()
	return OS.get_executable_path().get_base_dir()

func get_current_player() -> Dictionary:
	var data_service := _get_data_service()
	return data_service.get_current_player() if data_service else {}

func get_current_announcer() -> Dictionary:
	var data_service := _get_data_service()
	return data_service.get_current_announcer() if data_service else {}

func get_players() -> Array:
	var data_service := _get_data_service()
	return data_service.get_players() if data_service else []

func get_teams() -> Array:
	var data_service := _get_data_service()
	return data_service.get_teams() if data_service else []

func get_team_by_id(team_id: String) -> Dictionary:
	var data_service := _get_data_service()
	return data_service.get_team_by_id(team_id) if data_service else {}

func _get_data_service() -> DataService:
	var kernel := get_node_or_null("/root/Kernel")
	if kernel == null:
		return null
	return kernel.data_service as DataService