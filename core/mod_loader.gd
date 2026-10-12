# mod_loader.gd
# 【兼容别名】旧版模组加载器 autoload（名：ModLoader）。
#
# 自 core 2.0.0 起，"模组"已是"插件"的一种（Everything is a Plugin）：
# 所有插件（含 mods/ 下的旧模组）统一由 Kernel.PluginManager 发现与加载。
# 本节点不再自行扫描或加载，仅作为 Kernel / SceneDirector 的转发门面保留，
# 供既有引用（如 ModManager 面板、第三方模组）继续工作。后续版本将移除。

extends Node

func _kernel() -> Node:
	return get_node_or_null("/root/Kernel")

# ── 插件（旧"模组"）清单 ─────────────────────────────────────────────────────

func get_loaded_mods() -> Array:
	var kernel := _kernel()
	if kernel == null or kernel.plugin_manager == null:
		return []
	return kernel.plugin_manager.get_plugin_ids()

func get_mod(mod_id: String) -> Node:
	var kernel := _kernel()
	if kernel == null or kernel.plugin_manager == null:
		return null
	return kernel.plugin_manager.get_plugin_instance(mod_id)

## 返回兼容旧 ModMetadata 用法的最小型元数据（仅 id/name/version 有意义）。
func get_mod_metadata(mod_id: String) -> Plugin.PluginMetadata:
	var kernel := _kernel()
	if kernel == null or kernel.plugin_registry == null:
		return null
	var info: Dictionary = kernel.plugin_registry.get_plugin(mod_id)
	if info.is_empty():
		return null
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = mod_id
	metadata.name = str(info.get("name", mod_id))
	metadata.version = _read_version(str(info.get("path", "")))
	return metadata

func get_active_mod() -> String:
	return ""

# ── 直播场景（旧名 streaming_scenes）转发到 SceneDirector ──────────────────────

func get_streaming_scenes() -> Array:
	var kernel := _kernel()
	if kernel == null or kernel.scene_director == null:
		return []
	var result: Array = []
	for info in kernel.scene_director.get_scenes_by_type("live"):
		result.append({
			"id": info.id,
			"name": info.name,
			"description": info.description,
			"mod_id": info.plugin_id,
		})
	return result

func get_streaming_scene(scene_id: String) -> Dictionary:
	var kernel := _kernel()
	if kernel == null or kernel.scene_director == null:
		return {}
	var info: Dictionary = kernel.scene_director.get_scene(scene_id)
	if info.is_empty():
		return {}
	return {
		"id": info.id,
		"name": info.name,
		"description": info.description,
		"mod_id": info.plugin_id,
		"scene": info.scene,
	}

func has_streaming_scene(scene_id: String) -> bool:
	var kernel := _kernel()
	return kernel != null and kernel.scene_director != null and kernel.scene_director.has_scene(scene_id)

func instantiate_streaming_scene(scene_id: String) -> Node:
	var kernel := _kernel()
	if kernel == null or kernel.scene_director == null:
		return null
	return kernel.scene_director.instantiate_scene(scene_id)

# ── 旧版内容注册表（C# 侧接入点，本期未启用） ─────────────────────────────────

func get_content_registry():
	return null

func set_content_registry(_registry) -> void:
	pass

# ── 内部 ─────────────────────────────────────────────────────────────────────

func _read_version(plugin_dir: String) -> String:
	if plugin_dir.is_empty():
		return "1.0.0"
	for filename in ["plugin.json", "mod.json"]:
		var path := plugin_dir.path_join(filename)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if data is Dictionary:
			return str(data.get("version", "1.0.0"))
	return "1.0.0"