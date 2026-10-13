# tests/test_data_contract.gd
# 仓库种子数据契约测试（issue #4 验收项）：userdata 选手 / 队伍示例文件须符合 DataSchema。

extends TestCase

func run() -> bool:
	_check_file("res://userdata/players/players.json", DataKeys.PLAYERS, DataSchema.PLAYER)
	_check_file("res://userdata/teams/teams.json", DataKeys.TEAMS, DataSchema.TEAM)
	return summary("test_data_contract")

func _check_file(path: String, items_key: StringName, schema: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		ok(false, "契约文件存在: " + path)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	ok(data != null, "契约文件 JSON 可解析: " + path)
	if data == null:
		return
	var items: Variant = DataSchema.migrate(data, items_key).get(items_key)
	if not (items is Array):
		ok(false, "契约文件内容应为数组: " + path)
		return
	ok(items.size() > 0, "契约文件非空（%d 条）: %s" % [items.size(), path])
	for i in items.size():
		var issues := DataSchema.validate_item(items[i], schema, "%s[%d]" % [path.get_file(), i])
		eq(issues.size(), 0, "条目 %d 符合 schema %s" % [i, str(issues)])
