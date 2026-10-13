# data_keys.gd
# 数据键常量目录（class_name：DataKeys）：全部跨插件共享数据字段名的唯一登记处。
# 铁律 3 数据侧：插件访问共享数据字段一律引用本目录常量，禁止裸字符串字段名。
# 字段类型 / 必填定义、加载校验与版本迁移见 data_schema.gd（DataSchema）；
# 契约本体（示例数据 / 字段说明）见 README「数据规范（DataService 契约）」。

class_name DataKeys

# ── 版本信封字段（契约文件顶层结构） ─────────────────────────────────────────
# 契约文件统一为 { "schema_version": N, <实体键>: 数据 } 信封结构；
# 旧版裸数组 / 裸字典读取时自动迁移（见 DataSchema.migrate）。
const SCHEMA_VERSION := &"schema_version"

# 实体键：players.json / teams.json 列表键，current_player.json / current_announcer.json 单实体键
const PLAYERS := &"players"
const TEAMS := &"teams"
const PLAYER := &"player"
const ANNOUNCER := &"announcer"

# ── 选手字段（players.json 条目 / current_player.json / player_changed payload） ──
const PLAYER_ID := &"id"
const PLAYER_NAME := &"name"
const PLAYER_TEAM_ID := &"team_id"
const PLAYER_CAPTAIN := &"captain"                      # 0 / 1
const PLAYER_ICON_PATH := &"icon_path"
const PLAYER_STARTING_OPERATOR_CHOICE := &"starting_operator_choice"
const PLAYER_STARTING_RELIC_CHOICE := &"starting_relic_choice"
const PLAYER_STARTING_SQUAD_CHOICE := &"starting_squad_choice"
const PLAYER_STATS := &"stats"                          # Dictionary，子字段见下

# ── 选手 stats 子字段 ────────────────────────────────────────────────────────
const STATS_SCORE := &"score"
const STATS_MONEY_TAKEN := &"money_taken"
const STATS_SLOGAN := &"slogan"

# ── 队伍字段（teams.json 条目） ──────────────────────────────────────────────
const TEAM_ID := &"id"
const TEAM_NAME := &"name"
const TEAM_CAPTAIN := &"captain"                        # 可为 null
const TEAM_RANK := &"rank"                              # 可为 null
const TEAM_BALANCE := &"balance"
const TEAM_SCORE := &"score"
const TEAM_ICON_PATH := &"icon_path"
const TEAM_MEMBERS := &"members"                        # Array[String]（选手 id）

# ── 解说字段（current_announcer.json / announcer_changed payload） ───────────
const ANNOUNCER_ID := &"id"
const ANNOUNCER_NAME := &"name"
const ANNOUNCER_ICON_PATH := &"icon_path"
