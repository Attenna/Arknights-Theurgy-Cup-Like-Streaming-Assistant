# plugin_manager.gd
# 插件管理器：发现 / 加载 / 启用 / 禁用 / 卸载插件，并把插件声明的能力注册到内核服务。
# 内置插件位于 res://plugins，第三方插件位于 res://mods，二者同构（同一套清单与生命周期）。
#
# P1 阶段仅扫描 res://plugins（内置插件目录，尚为空）；mods/ 仍由旧 ModLoader 处理，
# 待 P2 / P3 完成契约统一后再整体接管。

class_name PluginManager
extends Node

signal plugin_loaded(plugin_id: String, success: bool)
signal plugin_enabled(plugin_id: String)
signal plugin_disabled(plugin_id: String)
signal plugin_unloaded(plugin_id: String)
signal all_plugins_ready()

const PLUGIN_MANIFEST := "plugin.json"
const LEGACY_MANIFEST := "mod.json"
const BUILTIN_ROOT := "res://plugins"
const THIRD_PARTY_ROOT := "res://mods"

# 默认监听路径（清单未声明 watch 时使用）
const DEFAULT_WATCH := ["scenes/", "scripts/", "panels/", "data/"]

var _kernel: Node = null

# plugin_id -> { manifest, res_path, provides, instance, state }
var _plugins: Dictionary = {}

func setup(kernel: Node) -> void:
	_kernel = kernel
	discover_and_load(BUILTIN_ROOT)
	all_plugins_ready.emit()

## 扫描指定根目录下的所有插件并加载。
func discover_and_load(root_path: String) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		print("[PluginManager] 插件目录不存在，跳过: %s" % root_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var res_dir := root_path.path_join(entry)
			var manifest := _read_manifest(res_dir)
			if manifest.is_empty():
				print("[PluginManager] 未找到清单，跳过: %s" % res_dir)
			else:
				_load_plugin(res_dir, manifest)
		entry = dir.get_next()
	dir.list_dir_end()

func get_plugin_ids() -> Array:
	return _plugins.keys()

func is_loaded(plugin_id: String) -> bool:
	return _plugins.has(plugin_id)

# ── 加载 ─────────────────────────────────────────────────────────────────────

func _load_plugin(res_dir: String, manifest: Dictionary) -> bool:
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

	_register_scenes(plugin_id, res_dir, provides)
	_register_provides(plugin_id, res_dir, manifest, provides)
	_register_watch_paths(res_dir, manifest)

	# 生命周期：on_enable
	if instance and instance.has_method("on_enable"):
		instance.on_enable()

	_plugins[plugin_id] = {
		"manifest": manifest,
		"res_path": res_dir,
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

func _register_scenes(plugin_id: String, res_dir: String, provides: Dictionary) -> void:
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
		var packed = load(full_path)
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

func _register_provides(plugin_id: String, res_dir: String, manifest: Dictionary, provides: Dictionary) -> void:
	if _kernel == null or _kernel.plugin_registry == null:
		return
	_kernel.plugin_registry.register_plugin(plugin_id, provides, {
		"name": manifest.get("name", plugin_id),
		"path": res_dir,
	})

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