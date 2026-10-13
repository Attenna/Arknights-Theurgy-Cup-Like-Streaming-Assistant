# tests/test_event_catalog.gd
# 事件契约测试（issue #5）：全部已登记事件有 payload schema + 示例负载通过校验。

extends TestCase

func run() -> bool:
	_test_completeness()
	_test_samples()
	return summary("test_event_catalog")

func _test_completeness() -> void:
	# 每个已登记事件都有机器可读 payload 契约
	for event_name in EventCatalog.REGISTERED:
		ok(EventCatalog.PAYLOAD_SCHEMAS.has(event_name), "事件 %s 已登记 payload schema" % event_name)
	# 目录自身可查询
	ok(EventCatalog.is_registered(EventCatalog.PLAYER_CHANGED), "is_registered 对已登记事件返回 true")
	ok(not EventCatalog.is_registered(&"not_a_real_event"), "is_registered 对未登记事件返回 false")

func _test_samples() -> void:
	# 选手事件示例负载（即数据实体，复用 DataSchema.PLAYER）
	var player_sample := {"id": "player_001", "name": "小明", "captain": 1, "team_id": "team_001"}
	var player_issues: Array[String] = DataSchema.validate_item(
		player_sample, EventCatalog.PAYLOAD_SCHEMAS[EventCatalog.PLAYER_CHANGED], "player_changed")
	eq(player_issues.size(), 0, "player_changed 示例负载通过校验 " + str(player_issues))
	# 解说事件示例负载
	var announcer_sample := {"id": "a1", "name": "解说员", "icon_path": "a.jpg"}
	var announcer_issues: Array[String] = DataSchema.validate_item(
		announcer_sample, EventCatalog.PAYLOAD_SCHEMAS[EventCatalog.ANNOUNCER_CHANGED], "announcer_changed")
	eq(announcer_issues.size(), 0, "announcer_changed 示例负载通过校验 " + str(announcer_issues))
	# 场景切换示例负载（必填 to_scene）
	var scene_sample := {"from_scene": "", "to_scene": "streaming_arena"}
	var scene_issues: Array[String] = DataSchema.validate_item(
		scene_sample, EventCatalog.PAYLOAD_SCHEMAS[EventCatalog.SCENE_CHANGED], "scene_changed")
	eq(scene_issues.size(), 0, "scene_changed 示例负载通过校验 " + str(scene_issues))
	# 数据重载示例负载
	var reloaded_issues: Array[String] = DataSchema.validate_item(
		{"scope": "userdata"}, EventCatalog.PAYLOAD_SCHEMAS[EventCatalog.DATA_RELOADED], "data_reloaded")
	eq(reloaded_issues.size(), 0, "data_reloaded 示例负载通过校验 " + str(reloaded_issues))
	# 反例：缺必填字段被拒
	eq(DataSchema.validate_item({}, EventCatalog.PAYLOAD_SCHEMAS[EventCatalog.DATA_RELOADED], "bad").size(), 1, "缺必填 payload 字段报问题")
