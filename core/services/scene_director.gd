# scene_director.gd
# 场景调度中枢：维护"场景注册表"，并负责场景实例的构建与切换。
# 内核不认识任何具体场景，只认识注册进来的 scene_id —— 一切场景皆由插件提供。

class_name SceneDirector
extends Node

signal scene_changed(from_scene: String, to_scene: String)

var event_bus: EventBus = null

# 场景挂载点（由引导壳设置，通常是 main.tscn 的 MainContentRoot）
var _host: Node = null

# scene_id -> { id, name, type, description, plugin_id, scene: PackedScene }
var _scenes: Dictionary = {}

var _current_id: String = ""
var _current_instance: Node = null

func set_host(node: Node) -> void:
	_host = node

func get_host() -> Node:
	return _host

# ── 注册表 ───────────────────────────────────────────────────────────────────

func register_scene(info: Dictionary) -> bool:
	var scene_id := str(info.get("id", ""))
	if scene_id.is_empty():
		push_error("[SceneDirector] 注册失败：缺少 id")
		return false
	if not (info.get("scene") is PackedScene):
		push_error("[SceneDirector] 注册失败：scene 不是 PackedScene (%s)" % scene_id)
		return false
	if _scenes.has(scene_id):
		push_warning("[SceneDirector] 场景 id 重复，已跳过: %s" % scene_id)
		return false
	_scenes[scene_id] = {
		"id": scene_id,
		"name": info.get("name", scene_id),
		"type": info.get("type", "live"),
		"description": info.get("description", ""),
		"plugin_id": info.get("plugin_id", info.get("mod_id", "")),
		"scene": info.get("scene", null),
	}
	return true

func unregister_scene(scene_id: String) -> void:
	if _scenes.has(scene_id):
		_scenes.erase(scene_id)

## 注销某个插件（或旧概念"模组"）提供的全部场景。
func unregister_by_plugin(plugin_id: String) -> void:
	for scene_id in _scenes.keys():
		if str(_scenes[scene_id].get("plugin_id", "")) == plugin_id:
			_scenes.erase(scene_id)

func has_scene(scene_id: String) -> bool:
	return _scenes.has(scene_id)

func get_scene(scene_id: String) -> Dictionary:
	return _scenes.get(scene_id, {})

## 返回场景信息列表（不含 PackedScene，便于 UI 展示）。
func get_scenes() -> Array:
	var result: Array = []
	for scene_id in _scenes.keys():
		var info: Dictionary = _scenes[scene_id]
		result.append({
			"id": info.id,
			"name": info.name,
			"type": info.type,
			"description": info.description,
			"plugin_id": info.plugin_id,
		})
	return result

func get_scenes_by_type(type: String) -> Array:
	var result: Array = []
	for info in get_scenes():
		if info.type == type:
			result.append(info)
	return result

func get_current_scene_id() -> String:
	return _current_id

func get_current_instance() -> Node:
	return _current_instance

# ── 实例化 / 切换 ────────────────────────────────────────────────────────────

## 构建场景实例（不挂载）。失败返回 null。
func instantiate_scene(scene_id: String) -> Node:
	if not _scenes.has(scene_id):
		push_error("[SceneDirector] 场景未注册: %s" % scene_id)
		return null
	var packed: PackedScene = _scenes[scene_id].scene
	if packed == null:
		return null
	var instance := packed.instantiate()
	_pump_identity(instance, _scenes[scene_id])
	return instance

## 切换当前场景。采用"先构建、后替换"策略：新实例构建成功后才销毁旧实例，绝不黑屏。
func switch_to(scene_id: String) -> bool:
	if scene_id == _current_id:
		return true
	if not _scenes.has(scene_id):
		push_error("[SceneDirector] 未知场景 id: %s" % scene_id)
		return false
	if _host == null:
		push_error("[SceneDirector] 未设置 host，无法切换场景")
		return false

	var new_instance := instantiate_scene(scene_id)
	if new_instance == null:
		push_error("[SceneDirector] 场景实例化失败，保留当前场景: %s" % scene_id)
		return false

	var old_id := _current_id
	var old_instance := _current_instance

	_host.add_child(new_instance)
	_current_instance = new_instance
	_current_id = scene_id

	if old_instance and is_instance_valid(old_instance):
		old_instance.queue_free()

	if event_bus:
		event_bus.scene_changed.emit(old_id, scene_id)
	print("[SceneDirector] 场景切换: %s -> %s" % [old_id, scene_id])
	return true

## 释放当前场景实例（热重载 / 卸载时使用），不触发新场景加载。
func clear_current() -> void:
	if _current_instance and is_instance_valid(_current_instance):
		_current_instance.queue_free()
	_current_instance = null
	_current_id = ""

# 为场景实例注入身份信息（兼容 PluginScene.setup_plugin_scene 与 ModScene.setup_mod_scene）。
func _pump_identity(instance: Node, info: Dictionary) -> void:
	if instance == null:
		return
	var plugin_id := str(info.get("plugin_id", ""))
	var scene_id := str(info.get("id", ""))
	var scene_name := str(info.get("name", scene_id))
	if instance.has_method("setup_plugin_scene"):
		instance.setup_plugin_scene(plugin_id, scene_id, scene_name)
	elif instance.has_method("setup_mod_scene"):
		instance.setup_mod_scene(plugin_id, scene_id, scene_name)