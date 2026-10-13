# event_catalog.gd
# 事件目录（autoload 名：EventCatalog）：全部跨插件事件名的唯一登记处。
# 铁律 3：禁止裸字符串事件名 —— 发布 / 订阅一律引用本目录常量；
# 新增事件必须在此登记，并写明 payload 字段契约（必填 / 可选 / 类型）。

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

# ── 已登记事件名全集（emit_event 的 debug 校验依据） ─────────────────────────
const REGISTERED: Array[StringName] = [
	PLAYER_CHANGED,
	ANNOUNCER_CHANGED,
	SCENE_CHANGED,
	DATA_RELOADED,
]

## 事件名是否已登记（EventBus debug 构建校验用）。
func is_registered(event_name: StringName) -> bool:
	return REGISTERED.has(event_name)
