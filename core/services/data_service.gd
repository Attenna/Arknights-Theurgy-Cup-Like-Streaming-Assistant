# data_service.gd
# 统一数据访问服务：集中封装 userdata 路径与 JSON 读写。
# 所有插件（内置 / 第三方）都通过本服务读写数据，避免各自拼接路径。
# 路径约定与既有代码保持一致：用户数据目录（user://） + /userdata/...

class_name DataService
extends Node

var event_bus: EventBus = null

## userdata 根目录（用户数据目录 user://）
func get_userdata_dir() -> String:
	var app_data := get_node_or_null("/root/AppData")
	if app_data and app_data.has_method("get_user_dir"):
		return app_data.get_user_dir()
	return OS.get_user_data_dir()

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

# ── 契约数据读取（schema 校验 + 版本迁移，issue #4） ─────────────────────────
# 读取链路：read_json → DataSchema.migrate 迁移到当前版本信封 → 逐条 validate_item；
# 校验问题仅 push_warning 不阻断（优雅降级），缺文件 / 解析失败返回空值（与旧版一致）。

func get_current_player() -> Dictionary:
	return _load_single("userdata/players/current_player.json", DataKeys.PLAYER, DataSchema.PLAYER)

func get_current_announcer() -> Dictionary:
	return _load_single("userdata/announcers/current_announcer.json", DataKeys.ANNOUNCER, DataSchema.ANNOUNCER)

func get_players() -> Array:
	return _load_list("userdata/players/players.json", DataKeys.PLAYERS, DataSchema.PLAYER)

func get_teams() -> Array:
	return _load_list("userdata/teams/teams.json", DataKeys.TEAMS, DataSchema.TEAM)

func get_team_by_id(team_id: String) -> Dictionary:
	for team in get_teams():
		if team is Dictionary and str(team.get(DataKeys.TEAM_ID, "")) == team_id:
			return team
	return {}

## 读取列表实体文件并逐条校验；内容非数组时告警并返回空数组。
func _load_list(rel_path: String, items_key: StringName, item_schema: Dictionary) -> Array:
	var data = read_json(rel_path)
	if data == null:
		return []
	var items: Variant = DataSchema.migrate(data, items_key).get(items_key)
	if items is Array:
		for i in items.size():
			_warn_schema_issues(DataSchema.validate_item(items[i], item_schema, "%s[%d]" % [rel_path, i]))
		return items
	push_warning("[DataService] %s 内容应为数组，实际为 %s" % [rel_path, type_string(typeof(items))])
	return []

## 读取单实体文件并校验；内容非字典时告警并返回空字典。
func _load_single(rel_path: String, items_key: StringName, item_schema: Dictionary) -> Dictionary:
	var data = read_json(rel_path)
	if data == null:
		return {}
	var item: Variant = DataSchema.migrate(data, items_key).get(items_key)
	if item is Dictionary:
		_warn_schema_issues(DataSchema.validate_item(item, item_schema, rel_path))
		return item
	if item != null:
		push_warning("[DataService] %s 内容应为字典，实际为 %s" % [rel_path, type_string(typeof(item))])
	return {}

func _warn_schema_issues(issues: Array[String]) -> void:
	for issue in issues:
		push_warning("[DataService] schema 校验: " + issue)

## 通知数据已重新加载（热重载时由 FileWatcher / PluginManager 调用）。
func notify_reloaded(scope: String) -> void:
	if event_bus:
		event_bus.data_reloaded.emit(scope)