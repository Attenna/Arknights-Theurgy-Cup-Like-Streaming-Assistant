# tests/test_data_schema.gd
# DataSchema 契约测试：版本迁移 + 字段校验（示例数据取自 README「数据规范」）。

extends TestCase

func run() -> bool:
	_test_migrate()
	_test_validate_player()
	_test_validate_team()
	return summary("test_data_schema")

func _test_migrate() -> void:
	# v0 裸数组 → v1 信封
	var env := DataSchema.migrate([{"id": "a"}], DataKeys.PLAYERS)
	eq(env.get(DataKeys.SCHEMA_VERSION), DataSchema.SCHEMA_VERSION_CURRENT, "v0 数组迁移携带 schema_version")
	eq(env.get(DataKeys.PLAYERS).size(), 1, "v0 数组迁移保留条目")
	# v0 裸字典 → v1 信封（单实体）
	var env2 := DataSchema.migrate({"id": "a", "name": "x"}, DataKeys.PLAYER)
	eq(env2.get(DataKeys.PLAYER).get(DataKeys.PLAYER_ID), "a", "v0 字典迁移保留单实体")
	# v1 信封原样返回
	var v1 := {DataKeys.SCHEMA_VERSION: 1, DataKeys.PLAYERS: []}
	eq(DataSchema.migrate(v1, DataKeys.PLAYERS), v1, "v1 信封原样返回")
	# 其它类型 → 条目置 null
	eq(DataSchema.migrate("bad", DataKeys.PLAYERS).get(DataKeys.PLAYERS), null, "非数组/字典迁移为 null 条目")

func _test_validate_player() -> void:
	# README players.json 示例条目（JSON 数字解析后为 float，int 规则须兼容）
	var sample := {
		"id": "小明", "name": "小明", "captain": 0.0, "team_id": "IGP",
		"icon_path": "{exe_path}/userdata/players/player_icons/小明.jpg",
		"starting_operator_choice": "史尔特尔",
		"starting_relic_choice": "希望时代的涂鸦",
		"starting_squad_choice": "魂灵护送分队",
		"stats": {"score": 325.0, "money_taken": 20.0, "slogan": "这是感言"},
	}
	eq(DataSchema.validate_item(sample, DataSchema.PLAYER, "player").size(), 0, "选手示例条目校验通过")
	# 缺必填字段
	eq(DataSchema.validate_item({"id": "a"}, DataSchema.PLAYER, "p").size(), 1, "缺必填字段报 1 项问题")
	# 类型错误（含 stats 嵌套）
	var bad := {"id": "a", "name": 123, "stats": {"score": "x"}}
	eq(DataSchema.validate_item(bad, DataSchema.PLAYER, "p").size(), 2, "类型错 + 嵌套 stats 类型错报 2 项问题")
	# 可选字段 null 视同缺省
	eq(DataSchema.validate_item({"id": "a", "name": "x", "team_id": null}, DataSchema.PLAYER, "p").size(), 0, "可选字段 null 视同缺省")
	# 条目非字典
	eq(DataSchema.validate_item("bad", DataSchema.PLAYER, "p").size(), 1, "条目非字典报问题")

func _test_validate_team() -> void:
	# README teams.json 示例条目（captain / rank 允许 null）
	var sample := {
		"id": "IGP", "name": "集批战术分队", "captain": null, "rank": null,
		"balance": 180.0, "score": 325.0,
		"icon_path": "{exe_path}/userdata/teams/team_icons/IGP.jpg",
		"members": ["小明"],
	}
	eq(DataSchema.validate_item(sample, DataSchema.TEAM, "team").size(), 0, "队伍示例条目（含 null 字段）校验通过")
	# 队伍缺必填
	eq(DataSchema.validate_item({"name": "x"}, DataSchema.TEAM, "t").size(), 1, "队伍缺必填 id 报问题")
