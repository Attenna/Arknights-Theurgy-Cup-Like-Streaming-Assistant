# event_catalog.gd
# 事件目录（autoload 名：EventCatalog）：全部跨插件事件名的唯一登记处。
# 铁律 3：禁止裸字符串事件名 —— 发布 / 订阅一律引用本目录常量；
# 新增事件必须在此登记，并写明 payload 字段契约（必填 / 可选 / 类型）。
# 事件命名规范：`领域_动作` 过去式（如 player_changed / data_reloaded），
# 禁止进行时与祈使句；新增事件先在本目录登记再发布。

extends Node

# ── 存量领域事件 ─────────────────────────────────────────────────────────────
# 当前经 EventBus 类型化信号发布（signal 直连，参数见 event_bus.gd）；
# 通用通道 emit_event 负载格式一并登记，供后续迁移对照。

# 选手变化。payload：player_data: Dictionary
#   必填：id: String, name: String
#   可选：captain: int, icon_path: String, team_id: String, stats: Dictionary
const PLAYER_CHANGED := &"player_changed"

# 解说变化。payload：announcer_data: Dictionary
#   必填：id: String, name: String
#   可选：icon_path: String
const ANNOUNCER_CHANGED := &"announcer_changed"

# 直播场景切换。类型化信号参数：from_scene: String, to_scene: String
# 通用通道 payload：{ "from_scene": String, "to_scene": String }（to_scene 必填）
const SCENE_CHANGED := &"scene_changed"

# 数据重载（热重载）。类型化信号参数：scope: String（插件 id 或数据域标识）
# 通用通道 payload：{ "scope": String }
const DATA_RELOADED := &"data_reloaded"

# ── 测试协作事件（issue #6 集成测试，插件对 mods/_test_pair_*） ────────────────
# 测试插件对纯 EventBus 协作闭环（铁律 1 活教材）：发布方发 ping，订阅方回 pong。
# 供集成测试断言协作收发与热重载订阅守恒。

# 测试协作 ping。payload：{ "seq": int }
const TEST_PAIR_PINGED := &"test_pair_pinged"

# 测试协作 pong。payload：{ "seq": int, "by": String }
const TEST_PAIR_PONGED := &"test_pair_ponged"

# ── 已登记事件名全集（emit_event 的 debug 校验依据） ─────────────────────────
const REGISTERED: Array[StringName] = [
	PLAYER_CHANGED,
	ANNOUNCER_CHANGED,
	SCENE_CHANGED,
	DATA_RELOADED,
	TEST_PAIR_PINGED,
	TEST_PAIR_PONGED,
]

## 事件名是否已登记（EventBus debug 构建校验用）。
func is_registered(event_name: StringName) -> bool:
	return REGISTERED.has(event_name)

# ── payload 契约（机器可读，issue #5） ───────────────────────────────────────
# 与上方注释契约一一对应，供 EventBus debug 校验（validate_payload）与契约测试共用；
# 字段格式同 DataSchema：{ 字段名: { "type": TYPE_x, "required": bool } }。
# 选手 / 解说事件负载即数据实体字典，直接复用 DataSchema 实体 schema（单一事实源）；
# 类型化信号（signal 直连）不经 emit_event 校验，schema 供契约测试与生产侧自查。

const PAYLOAD_SCHEMAS := {
	PLAYER_CHANGED: DataSchema.PLAYER,
	ANNOUNCER_CHANGED: DataSchema.ANNOUNCER,
	SCENE_CHANGED: {
		&"to_scene": {"type": TYPE_STRING, "required": true},
		&"from_scene": {"type": TYPE_STRING, "required": false},
	},
	DATA_RELOADED: {
		&"scope": {"type": TYPE_STRING, "required": true},
	},
	TEST_PAIR_PINGED: {
		&"seq": {"type": TYPE_INT, "required": true},
	},
	TEST_PAIR_PONGED: {
		&"seq": {"type": TYPE_INT, "required": true},
		&"by": {"type": TYPE_STRING, "required": true},
	},
}
