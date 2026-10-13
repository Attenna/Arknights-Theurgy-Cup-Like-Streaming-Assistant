# data_schema.gd
# 数据 schema 定义与校验（class_name：DataSchema）：契约的机器可读本体。
# - schema 定义与 README「数据规范（DataService 契约）」一一对应，键一律取 DataKeys 常量；
# - DataService 加载时经 validate_item 校验，问题仅告警不阻断（优雅降级）；
# - 字段结构变更：编写 _migrate_vN_to_vN1 迁移函数 → 递增 SCHEMA_VERSION_CURRENT →
#   同步更新 README 契约示例。
# 类型约定：JSON 无整型概念（解析后数字一律 float），故 "int" 规则同时接受 int / float。

class_name DataSchema

const SCHEMA_VERSION_CURRENT := 1

# ── schema 定义（值格式：{ "type": TYPE_x, "required": bool, "fields": 子schema? }） ──

# 选手 stats 子字段
const PLAYER_STATS := {
	DataKeys.STATS_SCORE: {"type": TYPE_INT, "required": false},
	DataKeys.STATS_MONEY_TAKEN: {"type": TYPE_INT, "required": false},
	DataKeys.STATS_SLOGAN: {"type": TYPE_STRING, "required": false},
}

# 选手（players.json 条目 / current_player.json 单实体）
const PLAYER := {
	DataKeys.PLAYER_ID: {"type": TYPE_STRING, "required": true},
	DataKeys.PLAYER_NAME: {"type": TYPE_STRING, "required": true},
	DataKeys.PLAYER_TEAM_ID: {"type": TYPE_STRING, "required": false},
	DataKeys.PLAYER_CAPTAIN: {"type": TYPE_INT, "required": false},
	DataKeys.PLAYER_ICON_PATH: {"type": TYPE_STRING, "required": false},
	DataKeys.PLAYER_STARTING_OPERATOR_CHOICE: {"type": TYPE_STRING, "required": false},
	DataKeys.PLAYER_STARTING_RELIC_CHOICE: {"type": TYPE_STRING, "required": false},
	DataKeys.PLAYER_STARTING_SQUAD_CHOICE: {"type": TYPE_STRING, "required": false},
	DataKeys.PLAYER_STATS: {"type": TYPE_DICTIONARY, "required": false, "fields": PLAYER_STATS},
}

# 队伍（teams.json 条目；captain / rank 允许 null，null 视同缺省不告警）
const TEAM := {
	DataKeys.TEAM_ID: {"type": TYPE_STRING, "required": true},
	DataKeys.TEAM_NAME: {"type": TYPE_STRING, "required": true},
	DataKeys.TEAM_CAPTAIN: {"type": TYPE_INT, "required": false},
	DataKeys.TEAM_RANK: {"type": TYPE_INT, "required": false},
	DataKeys.TEAM_BALANCE: {"type": TYPE_INT, "required": false},
	DataKeys.TEAM_SCORE: {"type": TYPE_INT, "required": false},
	DataKeys.TEAM_ICON_PATH: {"type": TYPE_STRING, "required": false},
	DataKeys.TEAM_MEMBERS: {"type": TYPE_ARRAY, "required": false},
}

# 解说（current_announcer.json 单实体）
const ANNOUNCER := {
	DataKeys.ANNOUNCER_ID: {"type": TYPE_STRING, "required": true},
	DataKeys.ANNOUNCER_NAME: {"type": TYPE_STRING, "required": true},
	DataKeys.ANNOUNCER_ICON_PATH: {"type": TYPE_STRING, "required": false},
}

# ── 版本迁移 ─────────────────────────────────────────────────────────────────

## 把任意版本的契约数据迁移为当前版本的信封结构 { "schema_version": N, <items_key>: 数据 }。
## 旧版裸数据（无 schema_version 的数组 / 字典）→ _migrate_v0_to_v1；
## 已带版本信封的数据原样返回（未来在此按版本逐步调用迁移函数升级）。
static func migrate(data: Variant, items_key: StringName) -> Dictionary:
	if data is Dictionary and data.has(DataKeys.SCHEMA_VERSION):
		return data
	return _migrate_v0_to_v1(data, items_key)

## v0 → v1：裸数组（列表实体）/ 裸字典（单实体）包上版本信封。
static func _migrate_v0_to_v1(data: Variant, items_key: StringName) -> Dictionary:
	var items: Variant = data if (data is Array or data is Dictionary) else null
	return {DataKeys.SCHEMA_VERSION: SCHEMA_VERSION_CURRENT, items_key: items}

# ── 校验 ─────────────────────────────────────────────────────────────────────

## 校验单个数据条目，返回问题列表（空列表 = 通过）。
## 约定：可选字段缺省或值为 null 不告警；必填字段缺失 / 类型不符记为问题；
## 规则含 "fields" 时递归校验子字典。
static func validate_item(item: Variant, schema: Dictionary, label: String) -> Array[String]:
	var issues: Array[String] = []
	if not (item is Dictionary):
		issues.append("%s: 条目应为 Dictionary，实际为 %s" % [label, type_string(typeof(item))])
		return issues
	for field_key in schema:
		var rule: Dictionary = schema[field_key]
		var value: Variant = item.get(field_key)
		if value == null:
			if rule.get("required", false):
				issues.append("%s: 缺少必填字段 %s" % [label, field_key])
			continue
		var want: int = rule["type"]
		var got: int = typeof(value)
		var number_ok := want == TYPE_INT and (got == TYPE_INT or got == TYPE_FLOAT)
		if got != want and not number_ok:
			issues.append("%s: 字段 %s 类型应为 %s，实际为 %s" % [label, field_key, type_string(want), type_string(got)])
		elif rule.has("fields") and value is Dictionary:
			issues.append_array(validate_item(value, rule["fields"], "%s.%s" % [label, field_key]))
	return issues
