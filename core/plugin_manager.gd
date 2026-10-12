# plugin_manager.gd
# 插件管理器：发现 / 加载 / 启用 / 禁用 / 卸载插件，并把插件声明的能力注册到内核服务。
# 内置插件位于 res://plugins，第三方插件位于 res://mods，二者同构（同一套清单与生命周期）。
#
# 自 P3 起，本管理器同时扫描 plugins/ 与 mods/，成为唯一加载入口；
# 旧 ModLoader 退化为转发本管理器 / SceneDirector 的兼容别名（见 core/mod_loader.gd）。

class_name PluginManager
extends Node

signal plugin_loaded(plugin_id: String, success: bool)
signal plugin_enabled(plugin_id: String)
signal plugin_disabled(plugin_id: String)
signal plugin_unloaded(plugin_id: String)
signal plugin_reloaded(plugin_id: String, success: bool)
signal all_plugins_ready()

const PLUGIN_MANIFEST := "plugin.json"
const LEGACY_MANIFEST := "mod.json"
const BUILTIN_ROOT := "res://plugins"
# 编辑器内的第三方插件根目录。res:// 在导出后只读（指向打包进 pck 的虚拟文件系统），
# 因此该路径仅供编辑器 / 开发期使用，不能作为导出后的用户插件入口。
const EDITOR_THIRD_PARTY_ROOT := "res://mods"
# 导出后第三方插件的目录名：与可执行文件同级的真实文件系统目录 `{exe}/mods`，
# 用户可直接增删插件文件夹；该目录不进 pck（导出预设 exclude_filter 排除 mods/*）。
const THIRD_PARTY_DIR_NAME := "mods"

# 默认监听路径（清单未声明 watch 时使用）
const DEFAULT_WATCH := ["scenes/", "scripts/", "panels/", "data/"]

# 去抖默认时长（毫秒），清单 hot_reload.debounce_ms 可覆盖
const DEBOUNCE_DEFAULT_MS := 300

# 开发模式启动参数：强制开启自动热重载并输出详细日志
const CMDLINE_HOT_RELOAD := "--plugin-hot-reload"

var _kernel: Node = null

# plugin_id -> { manifest, res_path, provides, instance, state }
var _plugins: Dictionary = {}

# 本次运行实际扫描的第三方插件根目录列表（编辑器内 res://mods + 始终包括 exe 同级 mods/）
var _third_party_roots: Array = []

# 依赖解析结果：本次 setup 的拓扑加载顺序（plugin_id 数组）
var _load_order: Array = []
# 依赖解析中被阻塞、未加载的插件：[{id, reason}]
var _blocked: Array = []
# 级联重载防重入标记（reload_plugin → _reload_single → 依赖方 reload_plugin）
var _in_cascade: bool = false

# ── 热重载状态 ───────────────────────────────────────────────────────────────
var auto_reload_enabled: bool = true        # 自动轮询热重载总开关（Q3：默认开）
var verbose_reload: bool = false            # 详细日志（--plugin-hot-reload）
var _debounce_timer: Timer = null           # 去抖定时器
var _pending_plugins: Dictionary = {}       # 待重载的 plugin_id 集合（去抖合并）

func setup(kernel: Node) -> void:
	_kernel = kernel

	if OS.get_cmdline_args().has(CMDLINE_HOT_RELOAD) or OS.get_cmdline_user_args().has(CMDLINE_HOT_RELOAD):
		auto_reload_enabled = true
		verbose_reload = true
		print("[PluginManager] 开发模式：强制开启热重载（verbose）")

	_create_debounce_timer()
	if _kernel != null and _kernel.file_watcher != null:
		_kernel.file_watcher.files_changed.connect(_on_files_changed)

	# 两阶段加载：先扫描全部根目录的清单，再做依赖校验与拓扑排序，最后按序加载。
	# 缺依赖 / 依赖被阻塞 / 环形依赖的插件不会产生任何半加载状态（不注册能力、不进 _plugins）。
	var all_manifests := _scan_manifests(BUILTIN_ROOT)
	_collect_third_party_roots()
	for root in _third_party_roots:
		all_manifests.append_array(_scan_manifests(str(root)))
	var ordered := _resolve_load_order(all_manifests)
	for info in ordered:
		_load_plugin(str(info.get("res_dir", "")), info.get("manifest", {}), str(info.get("origin", "")))
	all_plugins_ready.emit()

## 计算第三方插件根目录：
## - 编辑器内：项目内 res://mods（开发调试用，res:// 只读，仅编辑器期有效）；
## - 导出后：可执行文件同级的 mods/（真实文件系统目录，用户可直接增删）。
func _collect_third_party_roots() -> void:
	_third_party_roots.clear()
	if OS.has_feature("editor"):
		_third_party_roots.append(EDITOR_THIRD_PARTY_ROOT)
		return
	var external := _external_mods_root()
	if not external.is_empty():
		_third_party_roots.append(external)

## 可执行文件同级的 mods/ 目录绝对路径（取不到 exe 目录时返回空串）。
func _external_mods_root() -> String:
	var app_data := get_node_or_null("/root/AppData")
	if app_data != null and app_data.has_method("get_exe_dir"):
		var exe_dir := str(app_data.get_exe_dir())
		if not exe_dir.is_empty():
			return exe_dir.path_join(THIRD_PARTY_DIR_NAME)
	return ""

## 返回第三方（mods/）插件 id 列表，区别于随程序分发的内置 plugins/。
## 注意：导出后 exe 同级 mods/ 为真实路径、编辑器内为 res://mods，故按"根目录集合"判定而非固定字符串。
func get_third_party_plugin_ids() -> Array:
	var result: Array = []
	for plugin_id in _plugins.keys():
		if _third_party_roots.has(str(_plugins[plugin_id].get("origin", ""))):
			result.append(plugin_id)
	return result

func _create_debounce_timer() -> void:
	_debounce_timer = Timer.new()
	_debounce_timer.name = "ReloadDebounce"
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = float(DEBOUNCE_DEFAULT_MS) / 1000.0
	_debounce_timer.timeout.connect(_flush_pending_reloads)
	add_child(_debounce_timer)

## 手动开启 / 关闭自动轮询热重载。
func set_auto_reload(enabled: bool) -> void:
	auto_reload_enabled = enabled
	if _kernel != null and _kernel.file_watcher != null:
		_kernel.file_watcher.set_enabled(enabled)

func is_auto_reload_enabled() -> bool:
	return auto_reload_enabled

## 扫描指定根目录下的所有插件清单（只读取清单，不加载）。
## 返回 [{res_dir, manifest, origin}]，供依赖解析统一排序。
func _scan_manifests(root_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		print("[PluginManager] 插件目录不存在，跳过: %s" % root_path)
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var res_dir := root_path.path_join(entry)
			var manifest := _read_manifest(res_dir)
			if manifest.is_empty():
				print("[PluginManager] 未找到清单，跳过: %s" % res_dir)
			else:
				result.append({"res_dir": res_dir, "manifest": manifest, "origin": root_path})
		entry = dir.get_next()
	dir.list_dir_end()
	return result

## 归一化清单依赖声明：兼容字符串与 {id, ...} 对象。
## v1 仅按 id 校验存在性，不校验版本（项目无 semver 工具，避免误杀）。
func _manifest_dependencies(manifest: Dictionary) -> Array:
	var result: Array = []
	for dep in manifest.get("dependencies", []):
		if dep is String:
			result.append(dep)
		elif dep is Dictionary and dep.has("id"):
			result.append(str(dep["id"]))
	return result

## 依赖解析 + 拓扑排序：
## - 按 id 去重（先扫描者优先，重复项日志丢弃）；
## - 缺依赖 → 阻塞；依赖链上有人被阻塞 → 传递阻塞；剩余互相等待者 → 环形阻塞；
## - 加载顺序用 Kahn 算法确定，同一就绪层级按 load_priority 升序、目录名稳定排序；
## - 结果写入 _load_order（有序 id）与 _blocked（[{id, reason}]），返回按序的清单信息。
func _resolve_load_order(all: Array) -> Array:
	_load_order.clear()
	_blocked.clear()
	var by_id: Dictionary = {}   # id -> {res_dir, manifest, origin}
	for info in all:
		var id := str(info.get("manifest", {}).get("id", info.get("res_dir", "").get_file()))
		if by_id.has(id):
			print("[PluginManager] 插件 id 重复（后者忽略）: %s (%s)" % [id, str(info.get("res_dir", ""))])
			continue
		by_id[id] = info
	var deps: Dictionary = {}    # id -> Array[String]
	var priority: Dictionary = {}
	for id in by_id.keys():
		deps[id] = _manifest_dependencies(by_id[id].manifest)
		priority[id] = int(by_id[id].manifest.get("load_priority", 0))
	# 1) 缺失依赖 → 直接阻塞
	var blocked_ids: Dictionary = {}   # id -> reason
	for id in deps.keys():
		for dep in deps[id]:
			if not by_id.has(dep):
				blocked_ids[id] = "缺少依赖: %s" % dep
	# 2) Kahn：反复从待定集合中挑出"依赖全部就绪"的最优先者
	var pending: Array = []
	for id in by_id.keys():
		if not blocked_ids.has(id):
			pending.append(id)
	var done: Dictionary = {}
	while not pending.is_empty():
		pending.sort_custom(func(a, b):
			if int(priority.get(a, 0)) != int(priority.get(b, 0)):
				return int(priority.get(a, 0)) < int(priority.get(b, 0))
			return str(by_id[a].get("res_dir", "")) < str(by_id[b].get("res_dir", "")))
		var picked := ""
		for id in pending:
			var satisfied := true
			for dep in deps[id]:
				if not done.has(dep):
					satisfied = false
					break
			if satisfied:
				picked = id
				break
		if picked.is_empty():
			break   # 剩余节点互相等待 → 环形依赖
		_load_order.append(picked)
		done[picked] = true
		pending.erase(picked)
	# 3) 传递阻塞：待定集合中依赖了已阻塞节点的，逐轮扩散标记
	var changed := true
	while changed:
		changed = false
		for id in pending.duplicate():
			for dep in deps[id]:
				if blocked_ids.has(dep):
					blocked_ids[id] = "依赖被阻塞: %s" % dep
					pending.erase(id)
					changed = true
					break
	# 4) 仍留在待定集合中的 = 环形依赖成员
	if not pending.is_empty():
		var ring := str(", ".join(pending))
		for id in pending:
			blocked_ids[id] = "环形依赖，涉及: %s" % ring
	for id in blocked_ids.keys():
		_blocked.append({
			"id": id,
			"reason": blocked_ids[id],
			"res_dir": str(by_id[id].get("res_dir", "")),
			"manifest": by_id[id].get("manifest", {}),
			"origin": str(by_id[id].get("origin", "")),
		})
	_blocked.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for b in _blocked:
		push_warning("[PluginManager] 插件被阻塞，不加载: %s — %s" % [b.get("id", ""), b.get("reason", "")])
	# 返回按拓扑序排列的清单信息，供 setup 按序加载
	var ordered: Array = []
	for id in _load_order:
		ordered.append(by_id[id])
	return ordered

## 返回被阻塞（未加载）的插件列表：[{id, reason}]。供模组管理面板等 UI 查询。
func get_blocked_plugins() -> Array:
	return _blocked.duplicate(true)

func get_plugin_ids() -> Array:
	return _plugins.keys()

func is_loaded(plugin_id: String) -> bool:
	return _plugins.has(plugin_id)

## 返回插件入口节点实例（未加载返回 null）。供兼容别名 / 调试使用。
func get_plugin_instance(plugin_id: String) -> Node:
	if _plugins.has(plugin_id):
		return _plugins[plugin_id].instance
	return null

## 返回插件归一化后的能力声明。
func get_provides(plugin_id: String) -> Dictionary:
	if _plugins.has(plugin_id):
		return _plugins[plugin_id].provides
	return {}

## 返回指定根目录下加载的插件 id（用于区分内置 plugins/ 与第三方 mods/）。
func get_plugin_ids_by_root(root_path: String) -> Array:
	var result: Array = []
	for plugin_id in _plugins.keys():
		if str(_plugins[plugin_id].get("origin", "")) == root_path:
			result.append(plugin_id)
	return result

# ── 加载 ─────────────────────────────────────────────────────────────────────

func _load_plugin(res_dir: String, manifest: Dictionary, origin: String = "", fresh: bool = false) -> bool:
	var plugin_id := str(manifest.get("id", ""))
	if plugin_id.is_empty():
		plugin_id = res_dir.get_file()
	if _plugins.has(plugin_id):
		push_warning("[PluginManager] 插件 id 重复，跳过: %s" % plugin_id)
		return false

	var provides := _normalize_provides(manifest)
	var instance := _instantiate_entry(res_dir, plugin_id)

	# 生命周期：on_load（返回 false 则中止）
	if instance and instance.has_method("on_load"):
		var ok: bool = instance.on_load()
		if not ok:
			push_error("[PluginManager] 插件 on_load 失败: %s" % plugin_id)
			instance.queue_free()
			plugin_loaded.emit(plugin_id, false)
			return false

	_register_scenes(plugin_id, res_dir, provides, fresh)
	_register_provides(plugin_id, res_dir, manifest, provides, fresh)
	_register_watch_paths(res_dir, manifest)

	# 生命周期：on_enable
	if instance and instance.has_method("on_enable"):
		instance.on_enable()

	_plugins[plugin_id] = {
		"manifest": manifest,
		"res_path": res_dir,
		"origin": origin,
		"provides": provides,
		"instance": instance,
		"state": "enabled",
	}
	print("[PluginManager] 插件已加载并启用: %s" % plugin_id)
	plugin_loaded.emit(plugin_id, true)
	plugin_enabled.emit(plugin_id)
	return true

## 读取插件清单：优先 plugin.json，回退 mod.json。
func _read_manifest(res_dir: String) -> Dictionary:
	for filename in [PLUGIN_MANIFEST, LEGACY_MANIFEST]:
		var path := res_dir.path_join(filename)
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary:
				return data
	return {}

## 归一化能力声明：兼容旧清单的 streaming_scenes -> provides.scenes[type=live]。
func _normalize_provides(manifest: Dictionary) -> Dictionary:
	var provides: Dictionary = manifest.get("provides", {}).duplicate(true)
	var scenes: Array = provides.get("scenes", []).duplicate()
	for entry in manifest.get("streaming_scenes", []):
		if entry is Dictionary:
			scenes.append({
				"id": entry.get("id", ""),
				"name": entry.get("name", entry.get("id", "")),
				"type": "live",
				"scene": entry.get("scene", ""),
				"description": entry.get("description", ""),
			})
	provides["scenes"] = scenes
	if not provides.has("panels"):
		provides["panels"] = []
	return provides

## 实例化插件入口脚本（plugin.gd / mod.gd / <id>.gd）。
func _instantiate_entry(res_dir: String, plugin_id: String) -> Node:
	for candidate in ["plugin.gd", "mod.gd", "%s.gd" % plugin_id]:
		var script_path := res_dir.path_join(candidate)
		if not FileAccess.file_exists(script_path):
			continue
		var script = load(script_path)
		if script is GDScript:
			var node := Node.new()
			node.name = plugin_id
			node.set_script(script)
			add_child(node)
			return node
	return null

func _register_scenes(plugin_id: String, res_dir: String, provides: Dictionary, fresh: bool = false) -> void:
	if _kernel == null or _kernel.scene_director == null:
		return
	for entry in provides.get("scenes", []):
		if not (entry is Dictionary):
			continue
		var scene_id := str(entry.get("id", ""))
		var rel_path := str(entry.get("scene", ""))
		if scene_id.is_empty() or rel_path.is_empty():
			push_warning("[PluginManager] 场景项缺少 id/scene (插件 %s)" % plugin_id)
			continue
		var full_path := res_dir.path_join(rel_path)
		if not FileAccess.file_exists(full_path):
			push_error("[PluginManager] 场景文件不存在: %s" % full_path)
			continue
		var packed = _load_resource(full_path, fresh)
		if not (packed is PackedScene):
			push_error("[PluginManager] 场景不是 PackedScene: %s" % full_path)
			continue
		_kernel.scene_director.register_scene({
			"id": scene_id,
			"name": entry.get("name", scene_id),
			"type": entry.get("type", "live"),
			"description": entry.get("description", ""),
			"plugin_id": plugin_id,
			"scene": packed,
		})

func _register_provides(plugin_id: String, res_dir: String, manifest: Dictionary, provides: Dictionary, fresh: bool = false) -> void:
	if _kernel == null or _kernel.plugin_registry == null:
		return
	# 面板场景路径需相对插件目录解析为 res:// 绝对路径，并预加载 PackedScene，
	# 这样控制面板 / 导航面板可直接按 slot 取用，无需再认识插件目录结构。
	var resolved: Dictionary = provides.duplicate(true)
	var panels: Array = []
	for panel in resolved.get("panels", []):
		if not (panel is Dictionary):
			continue
		var entry: Dictionary = panel.duplicate()
		var rel := str(entry.get("scene", ""))
		if not rel.is_empty():
			var full_path := res_dir.path_join(rel)
			entry["res_path"] = full_path
			if FileAccess.file_exists(full_path):
				entry["packed"] = _load_resource(full_path, fresh)
			else:
				push_error("[PluginManager] 面板场景不存在: %s" % full_path)
		entry["plugin_id"] = plugin_id
		panels.append(entry)
	resolved["panels"] = panels
	_kernel.plugin_registry.register_plugin(plugin_id, resolved, {
		"name": manifest.get("name", plugin_id),
		"path": res_dir,
	})

## 加载资源：fresh=true 时绕过资源缓存，强制从磁盘重新读取（热重载用）。
func _load_resource(path: String, fresh: bool):
	if fresh:
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return load(path)

func _register_watch_paths(res_dir: String, manifest: Dictionary) -> void:
	if _kernel == null or _kernel.file_watcher == null:
		return
	var hot_reload: Dictionary = manifest.get("hot_reload", {})
	if not bool(hot_reload.get("enabled", true)):
		return
	var watch: Array = manifest.get("watch", [])
	if watch.is_empty():
		watch = DEFAULT_WATCH
	for rel in watch:
		_kernel.file_watcher.watch_path(res_dir.path_join(str(rel)))
	_kernel.file_watcher.set_enabled(true)

# ── 热重载 ───────────────────────────────────────────────────────────────────

## 重载插件；若其被其他已加载插件依赖，则按拓扑序级联重载全部（直接 + 间接）依赖方。
func reload_plugin(plugin_id: String) -> bool:
	if _in_cascade:
		return _reload_single(plugin_id)
	_in_cascade = true
	var ok := _reload_single(plugin_id)
	if ok:
		for dep_id in _dependents_of(plugin_id):
			if _plugins.has(dep_id):
				if not _reload_single(dep_id):
					push_error("[PluginManager] 依赖方级联重载失败: %s" % dep_id)
	_in_cascade = false
	return ok

## 重载单个插件：脚本尽力重载 → 注销旧能力 → 从磁盘重新加载 → 重建当前场景。
## 采用"先备份、失败回滚"策略：任何一步失败都恢复旧注册，绝不黑屏。
func _reload_single(plugin_id: String) -> bool:
	if not _plugins.has(plugin_id):
		push_warning("[PluginManager] 无法重载未加载的插件: %s" % plugin_id)
		return false

	var entry: Dictionary = _plugins[plugin_id]
	var res_dir: String = str(entry.get("res_path", ""))
	var origin: String = str(entry.get("origin", ""))
	var instance: Node = entry.get("instance")
	var old_name: String = str(entry.get("manifest", {}).get("name", plugin_id))

	var director: SceneDirector = null
	if _kernel != null:
		director = _kernel.scene_director as SceneDirector
	var current_scene: String = ""
	if director != null:
		current_scene = director.get_current_scene_id()
	var scene_was_ours: bool = (not current_scene.is_empty()) and _scene_provided_by(plugin_id, current_scene)

	# 1) 脚本层尽力重载（Q5：尽力而为）
	_reload_scripts(res_dir)

	# 2) 备份旧注册，用于失败回滚
	var old_provides: Dictionary = entry.get("provides", {}).duplicate(true)
	var old_scenes := _backup_scenes(plugin_id)

	# 3) 生命周期：on_before_reload
	if instance and instance.has_method("on_before_reload"):
		instance.on_before_reload()

	# 4) 注销旧能力
	if director:
		director.unregister_by_plugin(plugin_id)
	if _kernel and _kernel.plugin_registry:
		_kernel.plugin_registry.unregister_plugin(plugin_id)

	# 5) 卸载旧实例
	if instance and is_instance_valid(instance):
		if instance.has_method("on_disable"):
			instance.on_disable()
		if instance.has_method("on_unload"):
			instance.on_unload()
		instance.queue_free()
	_plugins.erase(plugin_id)

	# 6) 从磁盘重新读取清单并加载（fresh=true 绕过资源缓存）
	#    依赖必须仍处于已加载状态，否则视为失败并走回滚（依赖先于依赖方重载由级联保证）。
	var manifest := _read_manifest(res_dir)
	var success := false
	if manifest.is_empty():
		push_error("[PluginManager] 重载失败：清单缺失或损坏 (%s)" % res_dir)
	else:
		var deps_ok := true
		for dep in _manifest_dependencies(manifest):
			if not _plugins.has(dep):
				push_error("[PluginManager] 重载失败：依赖不可用 (%s 需要 %s)" % [plugin_id, dep])
				deps_ok = false
				break
		if deps_ok:
			success = _load_plugin(res_dir, manifest, origin, true)

	if not success:
		# 回滚：恢复旧场景与能力注册，保证当前画面与面板不丢失
		for info in old_scenes:
			if director:
				director.register_scene(info)
		if _kernel and _kernel.plugin_registry:
			_kernel.plugin_registry.register_plugin(plugin_id, old_provides, {"name": old_name, "path": res_dir})
		_plugins[plugin_id] = {
			"manifest": entry.get("manifest", {}),
			"res_path": res_dir,
			"origin": origin,
			"provides": old_provides,
			"instance": null,
			"state": "error",
		}
		push_error("[PluginManager] 插件重载失败，已回滚: %s" % plugin_id)
		if _kernel and _kernel.event_bus:
			_kernel.event_bus.data_reloaded.emit(plugin_id)
		plugin_reloaded.emit(plugin_id, false)
		return false

	# 7) 生命周期：on_after_reload
	var new_instance: Node = _plugins[plugin_id].get("instance")
	if new_instance and new_instance.has_method("on_after_reload"):
		new_instance.on_after_reload()

	# 8) 若当前场景由该插件提供 → 原位重建（先构建后替换）
	if scene_was_ours and director:
		director.rebuild_current()

	if _kernel and _kernel.event_bus:
		_kernel.event_bus.data_reloaded.emit(plugin_id)
	print("[PluginManager] 插件已热重载: %s" % plugin_id)
	plugin_reloaded.emit(plugin_id, true)
	return true

## 返回（直接 + 间接）依赖 plugin_id 的已加载插件，按 _load_order 拓扑序排列
## （保证依赖的依赖先重载）。
func _dependents_of(plugin_id: String) -> Array:
	var all: Array = []
	for other_id in _plugins.keys():
		if _manifest_dependencies(_plugins[other_id].get("manifest", {})).has(plugin_id):
			all.append(other_id)
	# 闭包：反复扫描直到不再新增（依赖方也可能被更下游依赖）
	var changed := true
	while changed:
		changed = false
		for other_id in _plugins.keys():
			if all.has(other_id):
				continue
			for dep in _manifest_dependencies(_plugins[other_id].get("manifest", {})):
				if all.has(dep):
					all.append(other_id)
					changed = true
					break
	var order_index := func(id: String) -> int:
		var idx := _load_order.find(id)
		return idx if idx >= 0 else (1 << 30)
	all.sort_custom(func(a, b): return int(order_index.call(a)) < int(order_index.call(b)))
	return all

## 重载全部已启用插件（快捷键 F5 / 控制面板按钮）。按 setup 时的拓扑序执行，
## 不触发级联（顺序本身已保证依赖先于依赖方重载）。
func reload_all() -> void:
	var ids: Array = []
	for plugin_id in _load_order:
		if _plugins.has(plugin_id):
			ids.append(plugin_id)
	# 不在 _load_order 中的异常恢复态插件兜底追加
	for plugin_id in _plugins.keys():
		if not ids.has(plugin_id):
			ids.append(plugin_id)
	print("[PluginManager] 重载全部插件（%d 个）" % ids.size())
	for plugin_id in ids:
		_reload_single(str(plugin_id))
	# 补加载被阻塞的插件（如用户已在磁盘修复依赖文件），修复后无需重启
	_try_load_blocked()

## 补加载被阻塞的插件：依赖已全部就绪者按轮次尝试加载。
## 被阻塞插件不在 _plugins 中，无法用 reload_plugin 单独重载；这是它们恢复加载的唯一入口。
func _try_load_blocked() -> void:
	if _blocked.is_empty():
		return
	var changed := true
	while changed:
		changed = false
		for entry in _blocked.duplicate(true):
			var ready := true
			for dep in _manifest_dependencies(entry.get("manifest", {})):
				if not _plugins.has(dep):
					ready = false
					break
			if not ready:
				continue
			if _load_plugin(str(entry.get("res_dir", "")), entry.get("manifest", {}), str(entry.get("origin", "")), true):
				_blocked.erase(entry)
				changed = true

# ── 变更检测 → 去抖 → 重载 ────────────────────────────────────────────────────

func _on_files_changed(paths: Array) -> void:
	if not auto_reload_enabled:
		return
	var affected := _plugin_ids_for_paths(paths)
	if affected.is_empty():
		return
	if verbose_reload:
		print("[PluginManager] 检测到变更文件 %d 个，命中插件: %s" % [paths.size(), affected])
	_schedule_reload(affected)

func _plugin_ids_for_paths(paths: Array) -> Array:
	var result: Array = []
	for plugin_id in _plugins.keys():
		var abs_dir := ProjectSettings.globalize_path(str(_plugins[plugin_id].get("res_path", "")))
		if abs_dir.is_empty():
			continue
		for path in paths:
			var p := str(path)
			if p == abs_dir or p.begins_with(abs_dir.path_join("")):
				if not result.has(plugin_id):
					result.append(plugin_id)
				break
	return result

func _schedule_reload(plugin_ids: Array) -> void:
	for plugin_id in plugin_ids:
		_pending_plugins[str(plugin_id)] = true
	if _debounce_timer == null:
		_flush_pending_reloads()
		return
	# 去抖时长取待重载插件中最大的 debounce_ms，确保半成品文件写完后再触发
	_debounce_timer.wait_time = float(_debounce_ms_for(_pending_plugins.keys())) / 1000.0
	_debounce_timer.start()

func _debounce_ms_for(plugin_ids: Array) -> int:
	var ms := DEBOUNCE_DEFAULT_MS
	for plugin_id in plugin_ids:
		var hot: Dictionary = _plugins[plugin_id].get("manifest", {}).get("hot_reload", {})
		ms = max(ms, int(hot.get("debounce_ms", DEBOUNCE_DEFAULT_MS)))
	return ms

func _flush_pending_reloads() -> void:
	var pending := _pending_plugins.keys()
	_pending_plugins.clear()
	for plugin_id in pending:
		if _plugins.has(plugin_id):
			reload_plugin(str(plugin_id))

# ── 重载辅助 ─────────────────────────────────────────────────────────────────

## 尽力重载插件目录下的脚本（GDScript.reload）。
## 注意：GDScript.reload() 对有存活实例的脚本会失败（引擎限制），
## 因此这里跳过"当前树中仍有实例"的脚本，交由整插件重载 / 场景重建兜底。
func _reload_scripts(res_dir: String) -> void:
	var active := _active_script_paths()
	for path in _collect_scripts(res_dir):
		if active.has(path):
			if verbose_reload:
				print("[PluginManager] 跳过（存在存活实例）: %s" % path)
			continue
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is GDScript:
			var err: int = res.reload()
			if verbose_reload:
				print("[PluginManager] 脚本重载 %s: %s" % [path, "OK" if err == OK else "ERR(%d)" % err])

## 收集当前场景树中所有已挂载脚本的 res:// 路径，用于跳过有实例的脚本。
func _active_script_paths() -> Dictionary:
	var paths: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return paths
	_collect_active_scripts(tree.root, paths)
	return paths

func _collect_active_scripts(node: Node, paths: Dictionary) -> void:
	var scr = node.get_script()
	if scr != null and scr.resource_path != "":
		paths[scr.resource_path] = true
	for child in node.get_children():
		_collect_active_scripts(child, paths)

func _collect_scripts(res_dir: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(res_dir)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := res_dir.path_join(entry)
		if dir.current_is_dir():
			result.append_array(_collect_scripts(path))
		elif entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result

## 备份某插件当前注册的全部场景信息（含 PackedScene 引用，用于回滚）。
func _backup_scenes(plugin_id: String) -> Array:
	var result: Array = []
	if _kernel == null or _kernel.scene_director == null:
		return result
	for info in _kernel.scene_director.get_scenes():
		if str(info.get("plugin_id", "")) == plugin_id:
			# get_scenes() 不含 PackedScene，需从内部注册表取回完整信息
			result.append(_kernel.scene_director.get_scene(str(info.get("id", ""))))
	return result

func _scene_provided_by(plugin_id: String, scene_id: String) -> bool:
	if _kernel == null or _kernel.scene_director == null:
		return false
	var info: Dictionary = _kernel.scene_director.get_scene(scene_id)
	return str(info.get("plugin_id", "")) == plugin_id