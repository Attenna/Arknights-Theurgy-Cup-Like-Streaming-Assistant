# player_database_service.gd
# SQLite 主库 + DataService 契约 JSON 同步（选手 / 解说 / 队伍）。
#
# 本脚本由 plugin.gd 在原生扩展加载成功后动态 load()，因此对 SQLite 原生类
# 全部走 ClassDB 动态实例化与 call()，避免扩展缺失时 GDScript 解析期报错。
#
# 数据权威：先写 SQLite，再导出 userdata 下的契约 JSON（DataKeys / DataSchema），
# 现有直播场景与其它插件继续经 DataService 读取，无需认识本插件。
# 输入 / 输出接口：
#   - 写入 / 查询：create_* / update_* / delete_* / list_* / get_*
#   - 当前选中：set_current_* / get_current_* / clear_current_*
#   - 批量同步：import_from_json() / export_to_json()
#   - CSV 快速录入：import_from_csv() / export_to_csv() / ensure_csv_templates()
#   - 状态查询：get_stats() / get_database_path() / get_csv_dir() / is_open()
# 所有写操作返回 { ok: bool, error: String, issues: Array[String], data: Dictionary, synced: bool }。
# CSV 中未识别的列会保存到各表的 extra_json，并自动出现在 JSON 导出与 CSV 导出中。

extends Node

const CsvCodec = preload("csv_codec.gd")

const DB_REL_PATH := "userdata/player_database/player_database.db"
const CSV_DIR_REL_PATH := "userdata/player_database/csv"
const CSV_PLAYERS_FILE := "players.csv"
const CSV_TEAMS_FILE := "teams.csv"
const CSV_ANNOUNCERS_FILE := "announcers.csv"
const PLAYERS_JSON := "userdata/players/players.json"
const TEAMS_JSON := "userdata/teams/teams.json"
const CURRENT_PLAYER_JSON := "userdata/players/current_player.json"
const CURRENT_ANNOUNCER_JSON := "userdata/announcers/current_announcer.json"

const STATE_CURRENT_PLAYER := "current_player_id"
const STATE_CURRENT_ANNOUNCER := "current_announcer_id"
const DB_SCHEMA_VERSION := 1

# 契约字段集合：用于区分“已知字段”与 CSV 自适应扩展列。
const PLAYER_ENTITY_KEYS := [
	DataKeys.PLAYER_ID, DataKeys.PLAYER_NAME, DataKeys.PLAYER_TEAM_ID, DataKeys.PLAYER_CAPTAIN,
	DataKeys.PLAYER_ICON_PATH, DataKeys.PLAYER_STARTING_OPERATOR_CHOICE,
	DataKeys.PLAYER_STARTING_RELIC_CHOICE, DataKeys.PLAYER_STARTING_SQUAD_CHOICE, DataKeys.PLAYER_STATS,
]
const TEAM_ENTITY_KEYS := [
	DataKeys.TEAM_ID, DataKeys.TEAM_NAME, DataKeys.TEAM_CAPTAIN, DataKeys.TEAM_RANK,
	DataKeys.TEAM_BALANCE, DataKeys.TEAM_SCORE, DataKeys.TEAM_ICON_PATH, DataKeys.TEAM_MEMBERS,
]
const ANNOUNCER_ENTITY_KEYS := [
	DataKeys.ANNOUNCER_ID, DataKeys.ANNOUNCER_NAME, DataKeys.ANNOUNCER_ICON_PATH,
]

# CSV 表头别名（小写匹配；中文表头直接使用）。
const PLAYER_CSV_ALIASES := {
	"id": DataKeys.PLAYER_ID, "选手id": DataKeys.PLAYER_ID, "编号": DataKeys.PLAYER_ID, "选手编号": DataKeys.PLAYER_ID,
	"name": DataKeys.PLAYER_NAME, "名称": DataKeys.PLAYER_NAME, "姓名": DataKeys.PLAYER_NAME,
	"选手名": DataKeys.PLAYER_NAME, "昵称": DataKeys.PLAYER_NAME,
	"team_id": DataKeys.PLAYER_TEAM_ID, "team": DataKeys.PLAYER_TEAM_ID, "队伍": DataKeys.PLAYER_TEAM_ID,
	"队伍id": DataKeys.PLAYER_TEAM_ID, "队伍编号": DataKeys.PLAYER_TEAM_ID,
	"captain": DataKeys.PLAYER_CAPTAIN, "队长": DataKeys.PLAYER_CAPTAIN,
	"is_captain": DataKeys.PLAYER_CAPTAIN, "是否队长": DataKeys.PLAYER_CAPTAIN,
	"icon_path": DataKeys.PLAYER_ICON_PATH, "头像": DataKeys.PLAYER_ICON_PATH,
	"头像路径": DataKeys.PLAYER_ICON_PATH, "选手头像": DataKeys.PLAYER_ICON_PATH,
	"starting_operator_choice": DataKeys.PLAYER_STARTING_OPERATOR_CHOICE,
	"开局干员": DataKeys.PLAYER_STARTING_OPERATOR_CHOICE, "干员": DataKeys.PLAYER_STARTING_OPERATOR_CHOICE,
	"初始干员": DataKeys.PLAYER_STARTING_OPERATOR_CHOICE,
	"starting_relic_choice": DataKeys.PLAYER_STARTING_RELIC_CHOICE,
	"开局藏品": DataKeys.PLAYER_STARTING_RELIC_CHOICE, "藏品": DataKeys.PLAYER_STARTING_RELIC_CHOICE,
	"初始藏品": DataKeys.PLAYER_STARTING_RELIC_CHOICE,
	"starting_squad_choice": DataKeys.PLAYER_STARTING_SQUAD_CHOICE,
	"开局分队": DataKeys.PLAYER_STARTING_SQUAD_CHOICE, "分队": DataKeys.PLAYER_STARTING_SQUAD_CHOICE,
	"初始分队": DataKeys.PLAYER_STARTING_SQUAD_CHOICE,
	"score": DataKeys.STATS_SCORE, "积分": DataKeys.STATS_SCORE,
	"分数": DataKeys.STATS_SCORE, "得分": DataKeys.STATS_SCORE,
	"money_taken": DataKeys.STATS_MONEY_TAKEN, "取钱": DataKeys.STATS_MONEY_TAKEN,
	"取钱数": DataKeys.STATS_MONEY_TAKEN, "拿钱": DataKeys.STATS_MONEY_TAKEN,
	"slogan": DataKeys.STATS_SLOGAN, "感言": DataKeys.STATS_SLOGAN,
	"口号": DataKeys.STATS_SLOGAN, "宣言": DataKeys.STATS_SLOGAN,
}

const TEAM_CSV_ALIASES := {
	"id": DataKeys.TEAM_ID, "队伍id": DataKeys.TEAM_ID, "编号": DataKeys.TEAM_ID, "队伍编号": DataKeys.TEAM_ID,
	"name": DataKeys.TEAM_NAME, "名称": DataKeys.TEAM_NAME, "队伍名": DataKeys.TEAM_NAME, "队名": DataKeys.TEAM_NAME,
	"captain": DataKeys.TEAM_CAPTAIN, "队长序号": DataKeys.TEAM_CAPTAIN, "队长": DataKeys.TEAM_CAPTAIN,
	"rank": DataKeys.TEAM_RANK, "排名": DataKeys.TEAM_RANK, "名次": DataKeys.TEAM_RANK, "顺位": DataKeys.TEAM_RANK,
	"balance": DataKeys.TEAM_BALANCE, "资金": DataKeys.TEAM_BALANCE, "余额": DataKeys.TEAM_BALANCE,
	"score": DataKeys.TEAM_SCORE, "积分": DataKeys.TEAM_SCORE, "分数": DataKeys.TEAM_SCORE,
	"icon_path": DataKeys.TEAM_ICON_PATH, "图标": DataKeys.TEAM_ICON_PATH,
	"图标路径": DataKeys.TEAM_ICON_PATH, "队伍图标": DataKeys.TEAM_ICON_PATH,
	"members": DataKeys.TEAM_MEMBERS, "成员": DataKeys.TEAM_MEMBERS, "队员": DataKeys.TEAM_MEMBERS,
}

const ANNOUNCER_CSV_ALIASES := {
	"id": DataKeys.ANNOUNCER_ID, "解说id": DataKeys.ANNOUNCER_ID, "编号": DataKeys.ANNOUNCER_ID,
	"name": DataKeys.ANNOUNCER_NAME, "名称": DataKeys.ANNOUNCER_NAME,
	"姓名": DataKeys.ANNOUNCER_NAME, "解说名": DataKeys.ANNOUNCER_NAME,
	"icon_path": DataKeys.ANNOUNCER_ICON_PATH, "头像": DataKeys.ANNOUNCER_ICON_PATH,
	"头像路径": DataKeys.ANNOUNCER_ICON_PATH, "解说头像": DataKeys.ANNOUNCER_ICON_PATH,
}

# CSV 导出表头（扩展列会追加在其后）。
const PLAYER_CSV_HEADERS := [
	"id", "name", "team_id", "captain", "icon_path", "starting_operator_choice",
	"starting_relic_choice", "starting_squad_choice", "score", "money_taken", "slogan",
]
const TEAM_CSV_HEADERS := ["id", "name", "captain", "rank", "balance", "score", "icon_path", "members"]
const ANNOUNCER_CSV_HEADERS := ["id", "name", "icon_path"]

var plugin_id: String = "player_database"

var _db: Variant = null
var _db_path: String = ""
var _open: bool = false
var _data_service: DataService = null
var _event_bus: EventBus = null

# ── 生命周期 ─────────────────────────────────────────────────────────────────

func open() -> bool:
	if _open:
		return true
	var ctx := PluginContext.for_node(self)
	_data_service = ctx.data_service
	_event_bus = ctx.event_bus
	var user_root: String = _data_service.get_userdata_dir() if _data_service != null else OS.get_user_data_dir()
	_db_path = user_root.path_join(DB_REL_PATH)
	var db_dir := _db_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(db_dir):
		var dir_err := DirAccess.make_dir_recursive_absolute(db_dir)
		if dir_err != OK:
			push_error("[player_database] 无法创建数据库目录: %s (错误码 %d)" % [db_dir, dir_err])
			return false
	var db: Variant = ClassDB.instantiate(&"SQLite")
	if db == null:
		push_error("[player_database] 无法实例化 SQLite，原生扩展未加载")
		return false
	_db = db
	db.set("path", _db_path)
	if not bool(db.call("open_db")):
		push_error("[player_database] 打开数据库失败: %s (%s)" % [_db_path, _db_error()])
		_db = null
		return false
	_open = true
	_create_schema()
	return true

func close() -> void:
	if _db != null:
		_db.call("close_db")
		_db = null
	_open = false

func is_open() -> bool:
	return _open

func get_database_path() -> String:
	return _db_path

# ── 选手接口 ─────────────────────────────────────────────────────────────────

func list_players() -> Array:
	var result: Array = []
	for row in _select("SELECT * FROM players ORDER BY id"):
		result.append(_row_to_player(row))
	return result

func get_player(player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	var rows := _select("SELECT * FROM players WHERE id = ? LIMIT 1", [player_id])
	return _row_to_player(rows[0]) if not rows.is_empty() else {}

func create_player(player: Dictionary) -> Dictionary:
	var issues := _validate_entity(player, DataSchema.PLAYER, DataKeys.PLAYER_ID, DataKeys.PLAYER_NAME, "player")
	if not issues.is_empty():
		return _fail("选手数据不合法", issues)
	var player_id := _text(player, DataKeys.PLAYER_ID)
	if not get_player(player_id).is_empty():
		return _fail("选手 id 已存在: %s" % player_id)
	var team_error := _check_team_exists(_text(player, DataKeys.PLAYER_TEAM_ID))
	if not team_error.is_empty():
		return _fail(team_error)
	if not _upsert_player(player):
		return _fail("写入选手失败: %s" % _db_error())
	return _finish_write(_ok({"player": get_player(player_id)}))

func update_player(player_id: String, patch: Dictionary) -> Dictionary:
	var existing := get_player(player_id)
	if existing.is_empty():
		return _fail("选手不存在: %s" % player_id)
	var merged := existing.duplicate(true)
	for key in patch:
		if key == DataKeys.PLAYER_STATS and patch[key] is Dictionary:
			var stats: Dictionary = (merged.get(DataKeys.PLAYER_STATS, {}) as Dictionary).duplicate()
			for stat_key in patch[key]:
				stats[stat_key] = patch[key][stat_key]
			merged[DataKeys.PLAYER_STATS] = stats
		elif key != DataKeys.PLAYER_ID:
			merged[key] = patch[key]
	var issues := _validate_entity(merged, DataSchema.PLAYER, DataKeys.PLAYER_ID, DataKeys.PLAYER_NAME, "player")
	if not issues.is_empty():
		return _fail("选手数据不合法", issues)
	var team_error := _check_team_exists(_text(merged, DataKeys.PLAYER_TEAM_ID))
	if not team_error.is_empty():
		return _fail(team_error)
	if not _upsert_player(merged):
		return _fail("更新选手失败: %s" % _db_error())
	return _finish_write(_ok({"player": get_player(player_id)}))

func delete_player(player_id: String) -> Dictionary:
	if get_player(player_id).is_empty():
		return _fail("选手不存在: %s" % player_id)
	if not _exec("DELETE FROM players WHERE id = ?", [player_id]):
		return _fail("删除选手失败: %s" % _db_error())
	if _get_state(STATE_CURRENT_PLAYER) == player_id:
		_clear_state(STATE_CURRENT_PLAYER)
	return _finish_write(_ok({"deleted": player_id}), &"player")

func set_current_player(player_id: String) -> Dictionary:
	var player := get_player(player_id)
	if player.is_empty():
		return _fail("选手不存在: %s" % player_id)
	_set_state(STATE_CURRENT_PLAYER, player_id)
	var result := _finish_write(_ok({"player": player}), &"player")
	return result

func clear_current_player() -> Dictionary:
	_clear_state(STATE_CURRENT_PLAYER)
	return _finish_write(_ok({}), &"player")

func get_current_player() -> Dictionary:
	var state_id := _get_state(STATE_CURRENT_PLAYER)
	return get_player(state_id) if not state_id.is_empty() else {}

# ── 解说接口 ─────────────────────────────────────────────────────────────────

func list_announcers() -> Array:
	var result: Array = []
	for row in _select("SELECT * FROM announcers ORDER BY id"):
		result.append(_row_to_announcer(row))
	return result

func get_announcer(announcer_id: String) -> Dictionary:
	if announcer_id.is_empty():
		return {}
	var rows := _select("SELECT * FROM announcers WHERE id = ? LIMIT 1", [announcer_id])
	return _row_to_announcer(rows[0]) if not rows.is_empty() else {}

func create_announcer(announcer: Dictionary) -> Dictionary:
	var issues := _validate_entity(announcer, DataSchema.ANNOUNCER, DataKeys.ANNOUNCER_ID, DataKeys.ANNOUNCER_NAME, "announcer")
	if not issues.is_empty():
		return _fail("解说数据不合法", issues)
	var announcer_id := _text(announcer, DataKeys.ANNOUNCER_ID)
	if not get_announcer(announcer_id).is_empty():
		return _fail("解说 id 已存在: %s" % announcer_id)
	if not _upsert_announcer(announcer):
		return _fail("写入解说失败: %s" % _db_error())
	return _finish_write(_ok({"announcer": get_announcer(announcer_id)}))

func update_announcer(announcer_id: String, patch: Dictionary) -> Dictionary:
	var existing := get_announcer(announcer_id)
	if existing.is_empty():
		return _fail("解说不存在: %s" % announcer_id)
	var merged := existing.duplicate(true)
	for key in patch:
		if key != DataKeys.ANNOUNCER_ID:
			merged[key] = patch[key]
	var issues := _validate_entity(merged, DataSchema.ANNOUNCER, DataKeys.ANNOUNCER_ID, DataKeys.ANNOUNCER_NAME, "announcer")
	if not issues.is_empty():
		return _fail("解说数据不合法", issues)
	if not _upsert_announcer(merged):
		return _fail("更新解说失败: %s" % _db_error())
	return _finish_write(_ok({"announcer": get_announcer(announcer_id)}))

func delete_announcer(announcer_id: String) -> Dictionary:
	if get_announcer(announcer_id).is_empty():
		return _fail("解说不存在: %s" % announcer_id)
	if not _exec("DELETE FROM announcers WHERE id = ?", [announcer_id]):
		return _fail("删除解说失败: %s" % _db_error())
	if _get_state(STATE_CURRENT_ANNOUNCER) == announcer_id:
		_clear_state(STATE_CURRENT_ANNOUNCER)
	return _finish_write(_ok({"deleted": announcer_id}), &"announcer")

func set_current_announcer(announcer_id: String) -> Dictionary:
	var announcer := get_announcer(announcer_id)
	if announcer.is_empty():
		return _fail("解说不存在: %s" % announcer_id)
	_set_state(STATE_CURRENT_ANNOUNCER, announcer_id)
	return _finish_write(_ok({"announcer": announcer}), &"announcer")

func clear_current_announcer() -> Dictionary:
	_clear_state(STATE_CURRENT_ANNOUNCER)
	return _finish_write(_ok({}), &"announcer")

func get_current_announcer() -> Dictionary:
	var state_id := _get_state(STATE_CURRENT_ANNOUNCER)
	return get_announcer(state_id) if not state_id.is_empty() else {}

# ── 队伍接口（members 由 players.team_id 派生，不存冗余字段） ────────────────

func list_teams() -> Array:
	var members := _team_members_map()
	var result: Array = []
	for row in _select("SELECT * FROM teams ORDER BY id"):
		result.append(_row_to_team(row, members.get(str(row.get("id", "")), [])))
	return result

func get_team(team_id: String) -> Dictionary:
	if team_id.is_empty():
		return {}
	var rows := _select("SELECT * FROM teams WHERE id = ? LIMIT 1", [team_id])
	if rows.is_empty():
		return {}
	return _row_to_team(rows[0], _team_member_ids(team_id))

func create_team(team: Dictionary) -> Dictionary:
	var issues := _validate_entity(team, DataSchema.TEAM, DataKeys.TEAM_ID, DataKeys.TEAM_NAME, "team")
	if not issues.is_empty():
		return _fail("队伍数据不合法", issues)
	var team_id := _text(team, DataKeys.TEAM_ID)
	if _team_exists(team_id):
		return _fail("队伍 id 已存在: %s" % team_id)
	if not _upsert_team(team):
		return _fail("写入队伍失败: %s" % _db_error())
	return _finish_write(_ok({"team": get_team(team_id)}))

func update_team(team_id: String, patch: Dictionary) -> Dictionary:
	var existing := get_team(team_id)
	if existing.is_empty():
		return _fail("队伍不存在: %s" % team_id)
	var merged := existing.duplicate(true)
	for key in patch:
		if key != DataKeys.TEAM_ID and key != DataKeys.TEAM_MEMBERS:
			merged[key] = patch[key]
	var issues := _validate_entity(merged, DataSchema.TEAM, DataKeys.TEAM_ID, DataKeys.TEAM_NAME, "team")
	if not issues.is_empty():
		return _fail("队伍数据不合法", issues)
	if not _upsert_team(merged):
		return _fail("更新队伍失败: %s" % _db_error())
	return _finish_write(_ok({"team": get_team(team_id)}))

func delete_team(team_id: String) -> Dictionary:
	if not _team_exists(team_id):
		return _fail("队伍不存在: %s" % team_id)
	if not _exec("BEGIN"):
		return _fail("开启事务失败: %s" % _db_error())
	if not _exec("UPDATE players SET team_id = '' WHERE team_id = ?", [team_id]):
		_exec("ROLLBACK")
		return _fail("清除选手队伍引用失败: %s" % _db_error())
	if not _exec("DELETE FROM teams WHERE id = ?", [team_id]):
		_exec("ROLLBACK")
		return _fail("删除队伍失败: %s" % _db_error())
	if not _exec("COMMIT"):
		_exec("ROLLBACK")
		return _fail("提交事务失败: %s" % _db_error())
	return _finish_write(_ok({"deleted": team_id}))

## 设置队伍成员：按选手 id 列表重写 players.team_id（不在列表中的现成员清空队伍）。
func set_team_members(team_id: String, player_ids: Array) -> Dictionary:
	if not _team_exists(team_id):
		return _fail("队伍不存在: %s" % team_id)
	for player_id in player_ids:
		if get_player(str(player_id)).is_empty():
			return _fail("选手不存在: %s" % str(player_id))
	if not _exec("BEGIN"):
		return _fail("开启事务失败: %s" % _db_error())
	if not _exec("UPDATE players SET team_id = '' WHERE team_id = ?", [team_id]):
		_exec("ROLLBACK")
		return _fail("清空原成员失败: %s" % _db_error())
	for player_id in player_ids:
		if not _exec("UPDATE players SET team_id = ? WHERE id = ?", [team_id, str(player_id)]):
			_exec("ROLLBACK")
			return _fail("设置成员失败: %s" % _db_error())
	if not _exec("COMMIT"):
		_exec("ROLLBACK")
		return _fail("提交事务失败: %s" % _db_error())
	return _finish_write(_ok({"team": get_team(team_id)}))

# ── 导入 / 导出（DataService 契约） ──────────────────────────────────────────

## 从 userdata 契约 JSON 合并导入（同名 id 覆盖），不清空数据库。
## 队伍先于选手导入，保证选手 team_id 可解析；缺失队伍时清空该引用并记录问题。
func import_from_json() -> Dictionary:
	if _data_service == null:
		return _fail("DataService 不可用")
	var issues: Array[String] = []
	var counts := {"players": 0, "teams": 0, "announcers": 0}
	var teams_data = _read_contract(TEAMS_JSON, DataKeys.TEAMS)
	if teams_data is Array:
		for i in teams_data.size():
			var item = teams_data[i]
			var item_issues := _validate_entity(item, DataSchema.TEAM, DataKeys.TEAM_ID, DataKeys.TEAM_NAME, "teams[%d]" % i)
			if not item_issues.is_empty():
				issues.append_array(item_issues)
				continue
			if _upsert_team(item):
				counts.teams += 1
			else:
				issues.append("队伍写入失败: %s" % _db_error())
	var players_data = _read_contract(PLAYERS_JSON, DataKeys.PLAYERS)
	if players_data is Array:
		for i in players_data.size():
			var item = players_data[i]
			var item_issues := _validate_entity(item, DataSchema.PLAYER, DataKeys.PLAYER_ID, DataKeys.PLAYER_NAME, "players[%d]" % i)
			if not item_issues.is_empty():
				issues.append_array(item_issues)
				continue
			if not _text(item, DataKeys.PLAYER_TEAM_ID).is_empty() \
					and not _team_exists(_text(item, DataKeys.PLAYER_TEAM_ID)):
				issues.append("players[%d]: 队伍不存在，已清空 team_id %s" % [i, _text(item, DataKeys.PLAYER_TEAM_ID)])
				item = item.duplicate(true)
				item[DataKeys.PLAYER_TEAM_ID] = ""
			if _upsert_player(item):
				counts.players += 1
			else:
				issues.append("选手写入失败: %s" % _db_error())
	var announcer_raw = _data_service.read_json(CURRENT_ANNOUNCER_JSON)
	if announcer_raw is Dictionary:
		var announcer_data = DataSchema.migrate(announcer_raw, DataKeys.ANNOUNCER).get(DataKeys.ANNOUNCER)
		if announcer_data == null:
			_clear_state(STATE_CURRENT_ANNOUNCER)
		elif announcer_data is Dictionary and not announcer_data.is_empty():
			var item_issues := _validate_entity(announcer_data, DataSchema.ANNOUNCER, DataKeys.ANNOUNCER_ID, DataKeys.ANNOUNCER_NAME, "current_announcer")
			if item_issues.is_empty():
				var announcer_id := _text(announcer_data, DataKeys.ANNOUNCER_ID)
				# 已存在的解说保留数据库完整字段，不用 current 文件的局部副本覆盖。
				if get_announcer(announcer_id).is_empty():
					if _upsert_announcer(announcer_data):
						counts.announcers += 1
					else:
						issues.append("解说写入失败: %s" % _db_error())
				_set_state(STATE_CURRENT_ANNOUNCER, announcer_id)
			else:
				issues.append_array(item_issues)
	var current_raw = _data_service.read_json(CURRENT_PLAYER_JSON)
	if current_raw is Dictionary:
		var current_data = DataSchema.migrate(current_raw, DataKeys.PLAYER).get(DataKeys.PLAYER)
		if current_data == null:
			_clear_state(STATE_CURRENT_PLAYER)
		elif current_data is Dictionary and not current_data.is_empty():
			var item_issues := _validate_entity(current_data, DataSchema.PLAYER, DataKeys.PLAYER_ID, DataKeys.PLAYER_NAME, "current_player")
			if item_issues.is_empty():
				var current_player_id := _text(current_data, DataKeys.PLAYER_ID)
				# 已存在的选手保留数据库完整字段，不用 current 文件的局部副本覆盖。
				if get_player(current_player_id).is_empty():
					if not _text(current_data, DataKeys.PLAYER_TEAM_ID).is_empty() \
							and not _team_exists(_text(current_data, DataKeys.PLAYER_TEAM_ID)):
						issues.append("current_player: 队伍不存在，已清空 team_id %s" % _text(current_data, DataKeys.PLAYER_TEAM_ID))
						current_data = current_data.duplicate(true)
						current_data[DataKeys.PLAYER_TEAM_ID] = ""
					if _upsert_player(current_data):
						counts.players += 1
					else:
						issues.append("当前选手写入失败: %s" % _db_error())
				_set_state(STATE_CURRENT_PLAYER, current_player_id)
			else:
				issues.append_array(item_issues)
	return {"ok": issues.is_empty(), "error": "" if issues.is_empty() else "部分数据导入失败", "issues": issues, "counts": counts}

## 把 SQLite 全量导出为 DataService 契约 JSON（版本信封，字段取 DataKeys）。
func export_to_json() -> Dictionary:
	if _data_service == null:
		return _fail("DataService 不可用")
	var version := DataSchema.SCHEMA_VERSION_CURRENT
	var ok := true
	ok = _data_service.write_json(PLAYERS_JSON, {
		DataKeys.SCHEMA_VERSION: version,
		DataKeys.PLAYERS: list_players(),
	}) and ok
	ok = _data_service.write_json(TEAMS_JSON, {
		DataKeys.SCHEMA_VERSION: version,
		DataKeys.TEAMS: list_teams(),
	}) and ok
	var current_player := get_current_player()
	ok = _data_service.write_json(CURRENT_PLAYER_JSON, {
		DataKeys.SCHEMA_VERSION: version,
		DataKeys.PLAYER: current_player if not current_player.is_empty() else null,
	}) and ok
	var current_announcer := get_current_announcer()
	ok = _data_service.write_json(CURRENT_ANNOUNCER_JSON, {
		DataKeys.SCHEMA_VERSION: version,
		DataKeys.ANNOUNCER: current_announcer if not current_announcer.is_empty() else null,
	}) and ok
	if ok:
		_data_service.notify_reloaded(plugin_id)
		if _event_bus != null:
			# 类型化信号是旧通道；新代码经 EventBus.subscribe 订阅，需同时走通用事件。
			_event_bus.emit_event(EventCatalog.DATA_RELOADED, {"scope": plugin_id})
	else:
		push_error("[player_database] 契约 JSON 导出失败")
	return {"ok": ok, "error": "" if ok else "契约 JSON 导出失败", "issues": []}

## 供面板 / 诊断使用：数据库状态与各表数量。
func get_stats() -> Dictionary:
	return {
		"db_path": _db_path,
		"open": _open,
		"players": _count("players"),
		"teams": _count("teams"),
		"announcers": _count("announcers"),
		"current_player_id": _get_state(STATE_CURRENT_PLAYER),
		"current_announcer_id": _get_state(STATE_CURRENT_ANNOUNCER),
	}

# ── CSV 快速录入（导入 / 导出 / 模板） ───────────────────────────────────────

func get_csv_dir() -> String:
	var root: String = _data_service.get_userdata_dir() if _data_service != null else OS.get_user_data_dir()
	return root.path_join(CSV_DIR_REL_PATH)

## 生成表头模板（已存在的文件不覆盖）。用户在任意表格软件填行后调用 import_from_csv。
func ensure_csv_templates(dir_path: String = "") -> Dictionary:
	var dir := _resolve_csv_dir(dir_path)
	if not _ensure_dir(dir):
		return {"ok": false, "error": "无法创建 CSV 目录: %s" % dir, "files": [], "created": []}
	var files: Array = []
	var created: Array = []
	var specs := [
		{"file": CSV_PLAYERS_FILE, "headers": PLAYER_CSV_HEADERS},
		{"file": CSV_TEAMS_FILE, "headers": TEAM_CSV_HEADERS},
		{"file": CSV_ANNOUNCERS_FILE, "headers": ANNOUNCER_CSV_HEADERS},
	]
	for spec in specs:
		var path := dir.path_join(str(spec["file"]))
		if FileAccess.file_exists(path):
			continue
		if _write_csv_file(path, [spec["headers"]]):
			files.append(path)
			created.append(path)
	return {"ok": true, "error": "", "dir": dir, "files": files, "created": created}

## 合并导入 CSV：只覆盖 CSV 中出现的列；未出现的列保持不变；空单元格清空该列。
## 未识别的新列写入 extra_json，并在 JSON / CSV 导出中自动带回。
func import_from_csv(dir_path: String = "") -> Dictionary:
	var dir := _resolve_csv_dir(dir_path)
	var players_path := dir.path_join(CSV_PLAYERS_FILE)
	var teams_path := dir.path_join(CSV_TEAMS_FILE)
	var announcers_path := dir.path_join(CSV_ANNOUNCERS_FILE)
	var files: Array = []
	for path in [players_path, teams_path, announcers_path]:
		if FileAccess.file_exists(path):
			files.append(path)
	var counts := {"players": 0, "teams": 0, "announcers": 0, "created": 0, "changed": 0}
	if files.is_empty():
		return {
			"ok": false, "error": "未找到 CSV 文件，请放到: %s" % dir,
			"issues": [], "files": [], "counts": counts, "synced": false,
		}
	var issues: Array[String] = []
	# 队伍先导入，保证选手 team_id 可解析。
	if FileAccess.file_exists(teams_path):
		_import_teams_csv(teams_path, issues, counts)
	if FileAccess.file_exists(players_path):
		_import_players_csv(players_path, issues, counts)
	if FileAccess.file_exists(announcers_path):
		_import_announcers_csv(announcers_path, issues, counts)
	var synced := false
	if int(counts["changed"]) > 0:
		var sync := export_to_json()
		synced = bool(sync.get("ok", false))
		if not synced:
			issues.append("契约 JSON 导出失败: %s" % str(sync.get("error", "")))
	return {
		"ok": issues.is_empty(), "error": "" if issues.is_empty() else "部分数据导入失败",
		"issues": issues, "files": files, "counts": counts, "synced": synced,
	}

## 导出当前数据库为 CSV（含 extra_json 中的自适应扩展列）。
func export_to_csv(dir_path: String = "") -> Dictionary:
	var dir := _resolve_csv_dir(dir_path)
	if not _ensure_dir(dir):
		return {"ok": false, "error": "无法创建 CSV 目录: %s" % dir, "files": [], "counts": {}}
	var files: Array = []
	var players_path := dir.path_join(CSV_PLAYERS_FILE)
	var teams_path := dir.path_join(CSV_TEAMS_FILE)
	var announcers_path := dir.path_join(CSV_ANNOUNCERS_FILE)
	var ok := _write_csv_file(players_path, _build_players_csv_rows())
	ok = _write_csv_file(teams_path, _build_teams_csv_rows()) and ok
	ok = _write_csv_file(announcers_path, _build_announcers_csv_rows()) and ok
	if ok:
		files.append_array([players_path, teams_path, announcers_path])
	return {
		"ok": ok, "error": "" if ok else "CSV 写入失败",
		"files": files,
		"counts": {"players": _count("players"), "teams": _count("teams"), "announcers": _count("announcers")},
	}

func _import_players_csv(path: String, issues: Array[String], counts: Dictionary) -> void:
	var table := _read_csv_table(path)
	if table.is_empty():
		issues.append("%s: 无法读取" % CSV_PLAYERS_FILE)
		return
	var headers: Array = table["headers"]
	var rows: Array = table["rows"]
	var created := 0
	var changed := 0
	for i in rows.size():
		var label := "%s 第 %d 行" % [CSV_PLAYERS_FILE, i + 2]
		var columns := _csv_row_to_columns(headers, rows[i], PLAYER_CSV_ALIASES, issues, label)
		var known: Dictionary = columns["known"]
		var present: Dictionary = columns["present"]
		var player_id := str(known.get(DataKeys.PLAYER_ID, "")).strip_edges()
		if player_id.is_empty():
			issues.append("%s: 缺少 id，已跳过" % label)
			continue
		var existing := get_player(player_id)
		var merged: Dictionary = existing.duplicate(true) if not existing.is_empty() else {DataKeys.PLAYER_ID: player_id}
		if present.has(DataKeys.PLAYER_NAME):
			merged[DataKeys.PLAYER_NAME] = str(known[DataKeys.PLAYER_NAME]).strip_edges()
		if present.has(DataKeys.PLAYER_TEAM_ID):
			merged[DataKeys.PLAYER_TEAM_ID] = str(known[DataKeys.PLAYER_TEAM_ID]).strip_edges()
		if present.has(DataKeys.PLAYER_CAPTAIN):
			merged[DataKeys.PLAYER_CAPTAIN] = _csv_bool_int(known[DataKeys.PLAYER_CAPTAIN], issues, label)
		if present.has(DataKeys.PLAYER_ICON_PATH):
			merged[DataKeys.PLAYER_ICON_PATH] = str(known[DataKeys.PLAYER_ICON_PATH]).strip_edges()
		if present.has(DataKeys.PLAYER_STARTING_OPERATOR_CHOICE):
			merged[DataKeys.PLAYER_STARTING_OPERATOR_CHOICE] = str(known[DataKeys.PLAYER_STARTING_OPERATOR_CHOICE]).strip_edges()
		if present.has(DataKeys.PLAYER_STARTING_RELIC_CHOICE):
			merged[DataKeys.PLAYER_STARTING_RELIC_CHOICE] = str(known[DataKeys.PLAYER_STARTING_RELIC_CHOICE]).strip_edges()
		if present.has(DataKeys.PLAYER_STARTING_SQUAD_CHOICE):
			merged[DataKeys.PLAYER_STARTING_SQUAD_CHOICE] = str(known[DataKeys.PLAYER_STARTING_SQUAD_CHOICE]).strip_edges()
		var stats: Dictionary = merged.get(DataKeys.PLAYER_STATS, {}) if merged.get(DataKeys.PLAYER_STATS) is Dictionary else {}
		stats = stats.duplicate()
		if present.has(DataKeys.STATS_SCORE):
			stats[DataKeys.STATS_SCORE] = _csv_int(known[DataKeys.STATS_SCORE], issues, label)
		if present.has(DataKeys.STATS_MONEY_TAKEN):
			stats[DataKeys.STATS_MONEY_TAKEN] = _csv_int(known[DataKeys.STATS_MONEY_TAKEN], issues, label)
		if present.has(DataKeys.STATS_SLOGAN):
			stats[DataKeys.STATS_SLOGAN] = str(known[DataKeys.STATS_SLOGAN]).strip_edges()
		merged[DataKeys.PLAYER_STATS] = stats
		for key in columns["extras"]:
			merged[key] = columns["extras"][key]
		var team_id := _text(merged, DataKeys.PLAYER_TEAM_ID)
		if not team_id.is_empty() and not _team_exists(team_id):
			issues.append("%s: 队伍不存在 %s，已清空 team_id" % [label, team_id])
			merged[DataKeys.PLAYER_TEAM_ID] = ""
		var validation := _validate_entity(merged, DataSchema.PLAYER, DataKeys.PLAYER_ID, DataKeys.PLAYER_NAME, label)
		if not validation.is_empty():
			issues.append_array(validation)
			continue
		if not _upsert_player(merged):
			issues.append("%s: 写入失败 %s" % [label, _db_error()])
			continue
		changed += 1
		if existing.is_empty():
			created += 1
	counts["players"] = int(counts["players"]) + changed
	counts["created"] = int(counts["created"]) + created
	counts["changed"] = int(counts["changed"]) + changed

func _import_teams_csv(path: String, issues: Array[String], counts: Dictionary) -> void:
	var table := _read_csv_table(path)
	if table.is_empty():
		issues.append("%s: 无法读取" % CSV_TEAMS_FILE)
		return
	var headers: Array = table["headers"]
	var rows: Array = table["rows"]
	var created := 0
	var changed := 0
	for i in rows.size():
		var label := "%s 第 %d 行" % [CSV_TEAMS_FILE, i + 2]
		var columns := _csv_row_to_columns(headers, rows[i], TEAM_CSV_ALIASES, issues, label)
		var known: Dictionary = columns["known"]
		var present: Dictionary = columns["present"]
		var team_id := str(known.get(DataKeys.TEAM_ID, "")).strip_edges()
		if team_id.is_empty():
			issues.append("%s: 缺少 id，已跳过" % label)
			continue
		var existing := get_team(team_id)
		var merged: Dictionary = existing.duplicate(true) if not existing.is_empty() else {DataKeys.TEAM_ID: team_id}
		if present.has(DataKeys.TEAM_NAME):
			merged[DataKeys.TEAM_NAME] = str(known[DataKeys.TEAM_NAME]).strip_edges()
		if present.has(DataKeys.TEAM_CAPTAIN):
			merged[DataKeys.TEAM_CAPTAIN] = _csv_nullable_int(known[DataKeys.TEAM_CAPTAIN], issues, label)
		if present.has(DataKeys.TEAM_RANK):
			merged[DataKeys.TEAM_RANK] = _csv_nullable_int(known[DataKeys.TEAM_RANK], issues, label)
		if present.has(DataKeys.TEAM_BALANCE):
			merged[DataKeys.TEAM_BALANCE] = _csv_int(known[DataKeys.TEAM_BALANCE], issues, label)
		if present.has(DataKeys.TEAM_SCORE):
			merged[DataKeys.TEAM_SCORE] = _csv_int(known[DataKeys.TEAM_SCORE], issues, label)
		if present.has(DataKeys.TEAM_ICON_PATH):
			merged[DataKeys.TEAM_ICON_PATH] = str(known[DataKeys.TEAM_ICON_PATH]).strip_edges()
		for key in columns["extras"]:
			merged[key] = columns["extras"][key]
		var validation := _validate_entity(merged, DataSchema.TEAM, DataKeys.TEAM_ID, DataKeys.TEAM_NAME, label)
		if not validation.is_empty():
			issues.append_array(validation)
			continue
		if not _upsert_team(merged):
			issues.append("%s: 写入失败 %s" % [label, _db_error()])
			continue
		changed += 1
		if existing.is_empty():
			created += 1
	counts["teams"] = int(counts["teams"]) + changed
	counts["created"] = int(counts["created"]) + created
	counts["changed"] = int(counts["changed"]) + changed

func _import_announcers_csv(path: String, issues: Array[String], counts: Dictionary) -> void:
	var table := _read_csv_table(path)
	if table.is_empty():
		issues.append("%s: 无法读取" % CSV_ANNOUNCERS_FILE)
		return
	var headers: Array = table["headers"]
	var rows: Array = table["rows"]
	var created := 0
	var changed := 0
	for i in rows.size():
		var label := "%s 第 %d 行" % [CSV_ANNOUNCERS_FILE, i + 2]
		var columns := _csv_row_to_columns(headers, rows[i], ANNOUNCER_CSV_ALIASES, issues, label)
		var known: Dictionary = columns["known"]
		var present: Dictionary = columns["present"]
		var announcer_id := str(known.get(DataKeys.ANNOUNCER_ID, "")).strip_edges()
		if announcer_id.is_empty():
			issues.append("%s: 缺少 id，已跳过" % label)
			continue
		var existing := get_announcer(announcer_id)
		var merged: Dictionary = existing.duplicate(true) if not existing.is_empty() else {DataKeys.ANNOUNCER_ID: announcer_id}
		if present.has(DataKeys.ANNOUNCER_NAME):
			merged[DataKeys.ANNOUNCER_NAME] = str(known[DataKeys.ANNOUNCER_NAME]).strip_edges()
		if present.has(DataKeys.ANNOUNCER_ICON_PATH):
			merged[DataKeys.ANNOUNCER_ICON_PATH] = str(known[DataKeys.ANNOUNCER_ICON_PATH]).strip_edges()
		for key in columns["extras"]:
			merged[key] = columns["extras"][key]
		var validation := _validate_entity(merged, DataSchema.ANNOUNCER, DataKeys.ANNOUNCER_ID, DataKeys.ANNOUNCER_NAME, label)
		if not validation.is_empty():
			issues.append_array(validation)
			continue
		if not _upsert_announcer(merged):
			issues.append("%s: 写入失败 %s" % [label, _db_error()])
			continue
		changed += 1
		if existing.is_empty():
			created += 1
	counts["announcers"] = int(counts["announcers"]) + changed
	counts["created"] = int(counts["created"]) + created
	counts["changed"] = int(counts["changed"]) + changed

# ── CSV 行 / 表头辅助 ────────────────────────────────────────────────────────

func _read_csv_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var rows := CsvCodec.parse(text)
	if rows.is_empty():
		return {}
	var headers: Array = []
	for cell in rows[0]:
		headers.append(str(cell).strip_edges())
	return {"headers": headers, "rows": rows.slice(1)}

## 把一行 CSV 拆成 { known: 契约字段, present: 出现的契约字段, extras: 新列 }。
func _csv_row_to_columns(headers: Array, row: Array, aliases: Dictionary, issues: Array[String], label: String) -> Dictionary:
	var known: Dictionary = {}
	var present: Dictionary = {}
	var extras: Dictionary = {}
	for i in headers.size():
		var header := str(headers[i])
		if header.is_empty():
			continue
		var cell := str(row[i]) if i < row.size() else ""
		var canonical = aliases.get(header.to_lower())
		if canonical is StringName and canonical != &"":
			if present.has(canonical):
				issues.append("%s: 表头 %s 重复映射字段 %s（后者覆盖前者）" % [label, header, canonical])
			known[canonical] = cell
			present[canonical] = true
		elif header.to_lower() == "stats":
			issues.append("%s: 保留列名 stats 不能作为扩展列，已忽略" % label)
		else:
			extras[header] = cell
	return {"known": known, "present": present, "extras": extras}

func _build_players_csv_rows() -> Array:
	var entities := list_players()
	var extra_keys := _collect_extra_keys(entities, PLAYER_ENTITY_KEYS)
	var headers: Array = PLAYER_CSV_HEADERS.duplicate()
	headers.append_array(extra_keys)
	var rows: Array = [headers]
	for player in entities:
		var stats: Dictionary = player.get(DataKeys.PLAYER_STATS, {}) if player.get(DataKeys.PLAYER_STATS) is Dictionary else {}
		var row: Array = [
			_csv_cell(player.get(DataKeys.PLAYER_ID)), _csv_cell(player.get(DataKeys.PLAYER_NAME)),
			_csv_cell(player.get(DataKeys.PLAYER_TEAM_ID)), _csv_cell(player.get(DataKeys.PLAYER_CAPTAIN)),
			_csv_cell(player.get(DataKeys.PLAYER_ICON_PATH)),
			_csv_cell(player.get(DataKeys.PLAYER_STARTING_OPERATOR_CHOICE)),
			_csv_cell(player.get(DataKeys.PLAYER_STARTING_RELIC_CHOICE)),
			_csv_cell(player.get(DataKeys.PLAYER_STARTING_SQUAD_CHOICE)),
			_csv_cell(stats.get(DataKeys.STATS_SCORE)), _csv_cell(stats.get(DataKeys.STATS_MONEY_TAKEN)),
			_csv_cell(stats.get(DataKeys.STATS_SLOGAN)),
		]
		for key in extra_keys:
			row.append(_csv_cell(player.get(key)))
		rows.append(row)
	return rows

func _build_teams_csv_rows() -> Array:
	var entities := list_teams()
	var extra_keys := _collect_extra_keys(entities, TEAM_ENTITY_KEYS)
	var headers: Array = TEAM_CSV_HEADERS.duplicate()
	headers.append_array(extra_keys)
	var rows: Array = [headers]
	for team in entities:
		var row: Array = [
			_csv_cell(team.get(DataKeys.TEAM_ID)), _csv_cell(team.get(DataKeys.TEAM_NAME)),
			_csv_cell(team.get(DataKeys.TEAM_CAPTAIN)), _csv_cell(team.get(DataKeys.TEAM_RANK)),
			_csv_cell(team.get(DataKeys.TEAM_BALANCE)), _csv_cell(team.get(DataKeys.TEAM_SCORE)),
			_csv_cell(team.get(DataKeys.TEAM_ICON_PATH)), _join_members(team.get(DataKeys.TEAM_MEMBERS)),
		]
		for key in extra_keys:
			row.append(_csv_cell(team.get(key)))
		rows.append(row)
	return rows

func _build_announcers_csv_rows() -> Array:
	var entities := list_announcers()
	var extra_keys := _collect_extra_keys(entities, ANNOUNCER_ENTITY_KEYS)
	var headers: Array = ANNOUNCER_CSV_HEADERS.duplicate()
	headers.append_array(extra_keys)
	var rows: Array = [headers]
	for announcer in entities:
		var row: Array = [
			_csv_cell(announcer.get(DataKeys.ANNOUNCER_ID)), _csv_cell(announcer.get(DataKeys.ANNOUNCER_NAME)),
			_csv_cell(announcer.get(DataKeys.ANNOUNCER_ICON_PATH)),
		]
		for key in extra_keys:
			row.append(_csv_cell(announcer.get(key)))
		rows.append(row)
	return rows

func _collect_extra_keys(entities: Array, known_keys: Array) -> Array:
	var known: Dictionary = {}
	for key in known_keys:
		known[str(key)] = true
	var extras: Dictionary = {}
	for entity in entities:
		if not (entity is Dictionary):
			continue
		for key in entity:
			var text_key := str(key)
			if not known.has(text_key):
				extras[text_key] = true
	var keys := extras.keys()
	keys.sort()
	return keys

func _join_members(value: Variant) -> String:
	if not (value is Array):
		return ""
	var members: PackedStringArray = []
	for member in value:
		members.append(str(member))
	return "|".join(members)

func _csv_cell(value: Variant) -> String:
	if value == null:
		return ""
	if value is bool:
		return "true" if value else "false"
	if value is Array or value is Dictionary:
		return JSON.stringify(value)
	return str(value)

func _write_csv_file(path: String, rows: Array) -> bool:
	var dir := path.get_base_dir()
	if not _ensure_dir(dir):
		push_error("[player_database] 无法创建 CSV 目录: %s" % dir)
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[player_database] 无法写入 CSV: %s" % path)
		return false
	file.store_string(String.chr(0xFEFF) + CsvCodec.encode(rows))
	file.close()
	return true

func _resolve_csv_dir(dir_path: String) -> String:
	if dir_path.is_empty():
		return get_csv_dir()
	if dir_path.begins_with("user://") or dir_path.begins_with("res://"):
		return ProjectSettings.globalize_path(dir_path)
	return dir_path

func _ensure_dir(dir_path: String) -> bool:
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	return DirAccess.make_dir_recursive_absolute(dir_path) == OK

func _csv_int(value: Variant, issues: Array[String], label: String, default_value: int = 0) -> int:
	var text := str(value).strip_edges()
	if text.is_empty():
		return default_value
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return int(float(text))
	issues.append("%s: 数值 '%s' 无效，按 %d 处理" % [label, text, default_value])
	return default_value

func _csv_nullable_int(value: Variant, issues: Array[String], label: String) -> Variant:
	var text := str(value).strip_edges()
	if text.is_empty():
		return null
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return int(float(text))
	issues.append("%s: 数值 '%s' 无效，已按空值处理" % [label, text])
	return null

func _csv_bool_int(value: Variant, issues: Array[String], label: String) -> int:
	var text := str(value).strip_edges().to_lower()
	if text.is_empty():
		return 0
	if ["1", "true", "yes", "y", "是", "队长"].has(text):
		return 1
	if ["0", "false", "no", "n", "否"].has(text):
		return 0
	issues.append("%s: 布尔值 '%s' 无法识别，按 0 处理" % [label, text])
	return 0

# ── 行映射 ───────────────────────────────────────────────────────────────────

func _row_to_player(row: Dictionary) -> Dictionary:
	var stats := {
		DataKeys.STATS_SCORE: int(row.get("score", 0)),
		DataKeys.STATS_MONEY_TAKEN: int(row.get("money_taken", 0)),
	}
	var slogan := str(row.get("slogan", ""))
	if not slogan.is_empty():
		stats[DataKeys.STATS_SLOGAN] = slogan
	var result := {
		DataKeys.PLAYER_ID: str(row.get("id", "")),
		DataKeys.PLAYER_NAME: str(row.get("name", "")),
		DataKeys.PLAYER_TEAM_ID: str(row.get("team_id", "")),
		DataKeys.PLAYER_CAPTAIN: int(row.get("captain", 0)),
		DataKeys.PLAYER_ICON_PATH: str(row.get("icon_path", "")),
		DataKeys.PLAYER_STARTING_OPERATOR_CHOICE: str(row.get("starting_operator_choice", "")),
		DataKeys.PLAYER_STARTING_RELIC_CHOICE: str(row.get("starting_relic_choice", "")),
		DataKeys.PLAYER_STARTING_SQUAD_CHOICE: str(row.get("starting_squad_choice", "")),
		DataKeys.PLAYER_STATS: stats,
	}
	_merge_extras(result, row)
	return result

func _row_to_announcer(row: Dictionary) -> Dictionary:
	var result := {
		DataKeys.ANNOUNCER_ID: str(row.get("id", "")),
		DataKeys.ANNOUNCER_NAME: str(row.get("name", "")),
		DataKeys.ANNOUNCER_ICON_PATH: str(row.get("icon_path", "")),
	}
	_merge_extras(result, row)
	return result

func _row_to_team(row: Dictionary, member_ids: Array) -> Dictionary:
	var result := {
		DataKeys.TEAM_ID: str(row.get("id", "")),
		DataKeys.TEAM_NAME: str(row.get("name", "")),
		DataKeys.TEAM_CAPTAIN: _nullable_int(row.get("captain")),
		DataKeys.TEAM_RANK: _nullable_int(row.get("rank")),
		DataKeys.TEAM_BALANCE: int(row.get("balance", 0)),
		DataKeys.TEAM_SCORE: int(row.get("score", 0)),
		DataKeys.TEAM_ICON_PATH: str(row.get("icon_path", "")),
		DataKeys.TEAM_MEMBERS: member_ids,
	}
	_merge_extras(result, row)
	return result

# ── SQLite 基础封装 ──────────────────────────────────────────────────────────

func _create_schema() -> void:
	_exec("CREATE TABLE IF NOT EXISTS players ("
		+ "id TEXT PRIMARY KEY, name TEXT NOT NULL, team_id TEXT NOT NULL DEFAULT '',"
		+ "captain INTEGER NOT NULL DEFAULT 0, icon_path TEXT NOT NULL DEFAULT '',"
		+ "starting_operator_choice TEXT NOT NULL DEFAULT '',"
		+ "starting_relic_choice TEXT NOT NULL DEFAULT '',"
		+ "starting_squad_choice TEXT NOT NULL DEFAULT '',"
		+ "score INTEGER NOT NULL DEFAULT 0, money_taken INTEGER NOT NULL DEFAULT 0,"
		+ "slogan TEXT NOT NULL DEFAULT '', extra_json TEXT NOT NULL DEFAULT '{}')")
	_exec("CREATE TABLE IF NOT EXISTS teams ("
		+ "id TEXT PRIMARY KEY, name TEXT NOT NULL, captain INTEGER, rank INTEGER,"
		+ "balance INTEGER NOT NULL DEFAULT 0, score INTEGER NOT NULL DEFAULT 0,"
		+ "icon_path TEXT NOT NULL DEFAULT '', extra_json TEXT NOT NULL DEFAULT '{}')")
	_exec("CREATE TABLE IF NOT EXISTS announcers ("
		+ "id TEXT PRIMARY KEY, name TEXT NOT NULL, icon_path TEXT NOT NULL DEFAULT '',"
		+ "extra_json TEXT NOT NULL DEFAULT '{}')")
	# 旧库迁移：CREATE TABLE IF NOT EXISTS 不会补列，逐表检查后 ALTER。
	_ensure_column("players", "extra_json", "TEXT NOT NULL DEFAULT '{}'")
	_ensure_column("teams", "extra_json", "TEXT NOT NULL DEFAULT '{}'")
	_ensure_column("announcers", "extra_json", "TEXT NOT NULL DEFAULT '{}'")
	_exec("CREATE TABLE IF NOT EXISTS app_state ("
		+ "key TEXT PRIMARY KEY, value TEXT NOT NULL)")
	_exec("INSERT OR IGNORE INTO app_state (key, value) VALUES ('db_schema_version', '%d')" % DB_SCHEMA_VERSION)

func _ensure_column(table: String, column: String, definition: String) -> void:
	for row in _select("PRAGMA table_info(%s)" % table):
		if str(row.get("name", "")) == column:
			return
	_exec("ALTER TABLE %s ADD COLUMN %s %s" % [table, column, definition])

## 提取实体字典中不属于契约字段的键，作为自适应扩展列写入 extra_json。
func _extract_extras(entity: Dictionary, known_keys: Array) -> Dictionary:
	var known: Dictionary = {}
	for key in known_keys:
		known[str(key)] = true
	var extras: Dictionary = {}
	for key in entity:
		var text_key := str(key)
		if not known.has(text_key):
			extras[text_key] = entity[key]
	return extras

## 把 extra_json 中的扩展列合并回实体字典（不覆盖契约字段）。
func _merge_extras(target: Dictionary, row: Dictionary) -> void:
	var raw := str(row.get("extra_json", ""))
	if raw.is_empty():
		return
	var extras = JSON.parse_string(raw)
	if not (extras is Dictionary):
		return
	var existing: Dictionary = {}
	for key in target:
		existing[str(key)] = true
	for key in extras:
		var text_key := str(key)
		if not existing.has(text_key):
			target[text_key] = extras[key]
			existing[text_key] = true

func _upsert_player(player: Dictionary) -> bool:
	var stats: Dictionary = player.get(DataKeys.PLAYER_STATS, {})
	return _exec("INSERT OR REPLACE INTO players (id, name, team_id, captain, icon_path,"
		+ " starting_operator_choice, starting_relic_choice, starting_squad_choice,"
		+ " score, money_taken, slogan, extra_json) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", [
			_text(player, DataKeys.PLAYER_ID),
			_text(player, DataKeys.PLAYER_NAME),
			_text(player, DataKeys.PLAYER_TEAM_ID),
			int(player.get(DataKeys.PLAYER_CAPTAIN, 0)),
			_text(player, DataKeys.PLAYER_ICON_PATH),
			_text(player, DataKeys.PLAYER_STARTING_OPERATOR_CHOICE),
			_text(player, DataKeys.PLAYER_STARTING_RELIC_CHOICE),
			_text(player, DataKeys.PLAYER_STARTING_SQUAD_CHOICE),
			int(stats.get(DataKeys.STATS_SCORE, 0)),
			int(stats.get(DataKeys.STATS_MONEY_TAKEN, 0)),
			_text(stats, DataKeys.STATS_SLOGAN),
			JSON.stringify(_extract_extras(player, PLAYER_ENTITY_KEYS)),
		])

func _upsert_team(team: Dictionary) -> bool:
	return _exec("INSERT OR REPLACE INTO teams (id, name, captain, rank, balance, score, icon_path, extra_json)"
		+ " VALUES (?,?,?,?,?,?,?,?)", [
			_text(team, DataKeys.TEAM_ID),
			_text(team, DataKeys.TEAM_NAME),
			_nullable_int(team.get(DataKeys.TEAM_CAPTAIN)),
			_nullable_int(team.get(DataKeys.TEAM_RANK)),
			int(team.get(DataKeys.TEAM_BALANCE, 0)),
			int(team.get(DataKeys.TEAM_SCORE, 0)),
			_text(team, DataKeys.TEAM_ICON_PATH),
			JSON.stringify(_extract_extras(team, TEAM_ENTITY_KEYS)),
		])

func _upsert_announcer(announcer: Dictionary) -> bool:
	return _exec("INSERT OR REPLACE INTO announcers (id, name, icon_path, extra_json) VALUES (?,?,?,?)", [
		_text(announcer, DataKeys.ANNOUNCER_ID),
		_text(announcer, DataKeys.ANNOUNCER_NAME),
		_text(announcer, DataKeys.ANNOUNCER_ICON_PATH),
		JSON.stringify(_extract_extras(announcer, ANNOUNCER_ENTITY_KEYS)),
	])

func _exec(sql: String, bindings: Array = []) -> bool:
	if _db == null:
		return false
	var raw = _db.call("query_with_bindings", sql, bindings)
	# godot-sqlite 4.7 的 error_message 在 SQLITE_OK/ROW/DONE 时也可能非空
	# （v4.9 才修复），因此成功与否以 query_with_bindings 的布尔返回值为准。
	if raw is bool:
		if not raw:
			push_error("[player_database] SQL 失败: %s — %s" % [sql, _db_error()])
		return raw
	return _db_error().is_empty()

func _select(sql: String, bindings: Array = []) -> Array:
	if not _exec(sql, bindings):
		return []
	var rows = _db.get("query_result")
	return rows if rows is Array else []

func _db_error() -> String:
	if _db == null:
		return "数据库未打开"
	return str(_db.get("error_message"))

func _count(table: String) -> int:
	var rows := _select("SELECT COUNT(*) AS n FROM %s" % table)
	if rows.is_empty():
		return 0
	return int(rows[0].get("n", 0))

# ── 当前选中状态 ─────────────────────────────────────────────────────────────

func _get_state(key: String) -> String:
	var rows := _select("SELECT value FROM app_state WHERE key = ? LIMIT 1", [key])
	return str(rows[0].get("value", "")) if not rows.is_empty() else ""

func _set_state(key: String, value: String) -> bool:
	return _exec("INSERT OR REPLACE INTO app_state (key, value) VALUES (?,?)", [key, value])

func _clear_state(key: String) -> bool:
	return _exec("DELETE FROM app_state WHERE key = ?", [key])

# ── 队伍引用辅助 ─────────────────────────────────────────────────────────────

func _team_exists(team_id: String) -> bool:
	if team_id.is_empty():
		return true
	return not _select("SELECT 1 FROM teams WHERE id = ? LIMIT 1", [team_id]).is_empty()

func _check_team_exists(team_id: String) -> String:
	if team_id.is_empty() or _team_exists(team_id):
		return ""
	return "队伍不存在: %s" % team_id

func _team_member_ids(team_id: String) -> Array:
	var ids: Array = []
	for row in _select("SELECT id FROM players WHERE team_id = ? ORDER BY id", [team_id]):
		ids.append(str(row.get("id", "")))
	return ids

func _team_members_map() -> Dictionary:
	var result: Dictionary = {}
	for row in _select("SELECT id, team_id FROM players WHERE team_id != '' ORDER BY id"):
		var team_id := str(row.get("team_id", ""))
		if not result.has(team_id):
			result[team_id] = []
		result[team_id].append(str(row.get("id", "")))
	return result

# ── 契约 JSON 读取 / 写入收尾 ────────────────────────────────────────────────

func _read_contract(rel_path: String, items_key: StringName) -> Variant:
	var data = _data_service.read_json(rel_path)
	if data == null:
		return null
	return DataSchema.migrate(data, items_key).get(items_key)

func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "error": "", "issues": [], "data": data, "synced": false}

## DataSchema 校验 + 业务约束：id / name 不允许空字符串（必填字段只校验存在性）。
func _validate_entity(entity: Dictionary, schema: Dictionary, id_key: StringName, name_key: StringName, label: String) -> Array[String]:
	var issues := DataSchema.validate_item(entity, schema, label)
	if _text(entity, id_key).strip_edges().is_empty():
		issues.append("%s: id 不能为空" % label)
	if _text(entity, name_key).strip_edges().is_empty():
		issues.append("%s: name 不能为空" % label)
	return issues

func _fail(message: String, issues: Array = []) -> Dictionary:
	return {"ok": false, "error": message, "issues": issues, "data": {}, "synced": false}

## 写操作收尾：导出契约 JSON；scope 非空时发布当前选手 / 解说变化事件。
func _finish_write(result: Dictionary, scope: StringName = &"") -> Dictionary:
	var sync := export_to_json()
	result["synced"] = bool(sync.get("ok", false))
	if not result["synced"]:
		result["ok"] = false
		result["error"] = "数据库已更新，但契约 JSON 导出失败: %s" % str(sync.get("error", ""))
	if not scope.is_empty():
		_emit_selection_changed(scope)
	return result

func _emit_selection_changed(scope: StringName) -> void:
	if _event_bus == null:
		return
	if scope == &"player":
		var player := get_current_player()
		_event_bus.player_changed.emit(player)
		# 取消选中时 payload 为空，不符合 PLAYER_CHANGED 的必填契约；
		# 清空场景由 export_to_json 的 DATA_RELOADED 驱动消费端重读。
		if not player.is_empty():
			_event_bus.emit_event(EventCatalog.PLAYER_CHANGED, player)
	elif scope == &"announcer":
		var announcer := get_current_announcer()
		_event_bus.announcer_changed.emit(announcer)
		if not announcer.is_empty():
			_event_bus.emit_event(EventCatalog.ANNOUNCER_CHANGED, announcer)

# ── 值转换 ───────────────────────────────────────────────────────────────────

func _text(source: Dictionary, key: StringName) -> String:
	var value = source.get(key)
	return "" if value == null else str(value)

func _nullable_int(value: Variant) -> Variant:
	if value == null:
		return null
	if value is String and (value as String).strip_edges().is_empty():
		return null
	return int(value)
