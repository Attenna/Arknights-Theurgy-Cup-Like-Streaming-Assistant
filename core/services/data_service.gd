# data_service.gd
# 统一数据访问服务：集中封装 userdata 路径与 JSON 读写。
# 所有插件（内置 / 第三方）都通过本服务读写数据，避免各自拼接路径。
# 路径约定与既有代码保持一致：可执行文件目录 + /userdata/...

class_name DataService
extends Node

var event_bus: EventBus = null

## userdata 根目录（可执行文件所在目录）
func get_userdata_dir() -> String:
	var app_data := get_node_or_null("/root/AppData")
	if app_data and app_data.has_method("get_exe_dir"):
		return app_data.get_exe_dir()
	return OS.get_executable_path().get_base_dir()

## 读取 JSON。文件不存在或解析失败时返回 null。
func read_json(rel_path: String) -> Variant:
	var path := get_userdata_dir().path_join(rel_path)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

## 写入 JSON（自动创建上级目录）。成功返回 true。
func write_json(rel_path: String, data: Variant) -> bool:
	var path := get_userdata_dir().path_join(rel_path)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[DataService] 无法写入: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func get_current_player() -> Dictionary:
	var data = read_json("userdata/players/current_player.json")
	return data if data is Dictionary else {}

func get_current_announcer() -> Dictionary:
	var data = read_json("userdata/announcers/current_announcer.json")
	return data if data is Dictionary else {}

func get_players() -> Array:
	var data = read_json("userdata/players/players.json")
	return data if data is Array else []

func get_teams() -> Array:
	var data = read_json("userdata/teams/teams.json")
	return data if data is Array else []

func get_team_by_id(team_id: String) -> Dictionary:
	for team in get_teams():
		if team is Dictionary and str(team.get("id", "")) == team_id:
			return team
	return {}

## 通知数据已重新加载（热重载时由 FileWatcher / PluginManager 调用）。
func notify_reloaded(scope: String) -> void:
	if event_bus:
		event_bus.data_reloaded.emit(scope)