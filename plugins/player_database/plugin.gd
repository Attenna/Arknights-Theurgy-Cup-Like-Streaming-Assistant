# plugin.gd
# 选手数据库插件（player_database）：SQLite 主库 + DataService 契约 JSON 同步 + 二级管理面板。
# 原生扩展自携带：godot-sqlite 的 .gdextension 与 Windows DLL 位于 native/，
# on_load 时经 GDExtensionManager 按插件目录绝对 / res:// 路径运行时加载，核心无需安装 addon。
# 数据访问约定：其它插件不直接调用本插件；经 DataService 读取导出的契约 JSON，
# 并订阅 player_changed / announcer_changed / data_reloaded 事件。

extends Plugin

const PLUGIN_ID := "player_database"
const EXT_REL_PATH := "native/gdsqlite.gdextension"
const SERVICE_GROUP := &"player_database_service"
const PANEL_ID := "player_database_panel"
const BASE_GROUP := "control_panel_base"
const PANEL_SLOT := "control_panel"

var _service: Node = null
var _extension_path: String = ""

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = PLUGIN_ID
	metadata.name = "选手数据库"
	metadata.description = "SQLite 选手 / 解说 / 队伍数据管理，自动同步 DataService 契约 JSON"
	return metadata

func on_load() -> bool:
	if not _ensure_sqlite():
		push_error("[player_database] godot-sqlite 原生扩展加载失败，插件不加载")
		return false
	# CACHE_MODE_IGNORE：热重载时强制读取最新脚本（服务实例存活，PluginManager 的脚本重载会跳过它）。
	var script = ResourceLoader.load(_plugin_file("scripts/database/player_database_service.gd"), "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (script is GDScript):
		push_error("[player_database] 数据库服务脚本加载失败")
		return false
	_service = (script as GDScript).new()
	_service.name = "PlayerDatabaseService"
	_service.set("plugin_id", PLUGIN_ID)
	add_child(_service)
	if not _service.call("open"):
		push_error("[player_database] 数据库打开失败，插件不加载")
		return false
	_service.add_to_group(SERVICE_GROUP)
	return true

func on_enable() -> void:
	_mount()
	if _service != null:
		_service.call("import_from_json")
		_service.call("export_to_json")
	print("[player_database] 已启用（%s）" % _service.call("get_database_path"))

func on_disable() -> void:
	_unmount()

func on_before_reload() -> void:
	# 面板由基底在 on_disable / on_unload 时卸载；这里只保证数据库连接干净关闭。
	if _service != null:
		_service.call("close")

func on_after_reload() -> void:
	_mount()
	if _service != null:
		_service.call("import_from_json")
		_service.call("export_to_json")

func on_unload() -> void:
	_unmount()
	if _service != null:
		_service.call("close")
		_service.queue_free()
		_service = null

# ── 原生扩展加载 ─────────────────────────────────────────────────────────────

func _ensure_sqlite() -> bool:
	if ClassDB.class_exists("SQLite"):
		return true
	_extension_path = _plugin_file(EXT_REL_PATH)
	if not FileAccess.file_exists(_extension_path):
		push_error("[player_database] 原生扩展文件不存在: %s" % _extension_path)
		return false
	var status: int = GDExtensionManager.load_extension(_extension_path)
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		push_error("[player_database] GDExtension 加载返回状态 %d: %s" % [status, _extension_path])
		return false
	if not ClassDB.class_exists("SQLite"):
		push_error("[player_database] 扩展已加载但未注册 SQLite 类: %s" % _extension_path)
		return false
	print("[player_database] godot-sqlite 原生扩展已加载: %s" % _extension_path)
	return true

## 插件目录内的文件路径：开发期为 res://，导出后为 {exe}/mods/<id>/ 真实路径。
## get_script() 返回 Variant，必须显式标注 String（见 AGENTS.md 5.3）。
func _plugin_file(rel_path: String) -> String:
	var base: String = get_script().resource_path.get_base_dir()
	return base.path_join(rel_path).simplify_path()

# ── 面板挂载（控制面板基底约定） ──────────────────────────────────────────────

func _mount() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var base: Node = tree.get_first_node_in_group(BASE_GROUP)
	if base == null or not base.has_method("mount_panel"):
		return
	var registry := get_plugin_registry()
	if registry == null:
		return
	for entry in registry.get_panels_by_slot(PANEL_SLOT):
		if str(entry.get("id", "")) != PANEL_ID:
			continue
		var packed = entry.get("packed")
		if packed != null:
			base.mount_panel(PANEL_ID, packed, str(entry.get("name", "选手数据库")))
		return

func _unmount() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var base: Node = tree.get_first_node_in_group(BASE_GROUP)
	if base != null and base.has_method("unmount_panel"):
		base.unmount_panel(PANEL_ID)
