# mod_interface.gd
# 【兼容别名】旧版模组契约，现等价于 Plugin（由 Plugin 演进而来）。
#
# 说明：新代码请直接 `extends Plugin`。本文件仅为兼容既有第三方模组而保留一版，
# 它把旧的生命周期方法（on_initialize / on_activate / on_pause / on_resume 等）
# 映射到新的 Plugin 契约之上。后续版本将移除。

class_name ModInterface
extends Plugin

# 旧版模组生命周期状态（保留以兼容 ModLoader）
enum ModState {
	UNLOADED,
	LOADING,
	LOADED,
	INITIALIZING,
	ACTIVE,
	PAUSED,
	UNLOADING,
	ERROR
}

# 旧版元数据结构：在 PluginMetadata 基础上追加模组专有字段。
class ModMetadata extends Plugin.PluginMetadata:
	var autoload: bool = false
	var scenes: Array = []
	var streaming_scenes: Array = []
	var data_files: Array = []
	var asset_paths: Array = []

# 模组 -> 内核 的旧版信号
signal mod_loaded(mod_id: String)
signal mod_unloaded(mod_id: String)
signal mod_initialized(mod_id: String)
signal mod_error(mod_id: String, error_message: String)
signal mod_event(mod_id: String, event_name: String, event_data: Dictionary)

# 内核 -> 模组 的旧版信号
signal core_content_loaded(content_type: String, count: int)
signal core_scene_requested(scene_id: String)
signal core_shutdown_requested()

func get_metadata() -> ModMetadata:
	var metadata := ModMetadata.new()
	metadata.id = get_script().get_global_name()
	metadata.name = "Unnamed Mod"
	return metadata

# ── 旧版生命周期（在 Plugin 契约上兼容保留） ────────────────────────────────

## 等价于 Plugin.on_enable()
func on_initialize() -> bool:
	return true

func on_activate() -> void:
	pass

func on_pause() -> void:
	pass

func on_resume() -> void:
	pass

# ── 旧版能力查询 ─────────────────────────────────────────────────────────────

func get_mod_scenes() -> Array:
	return []

func get_data_files() -> Array:
	return []

func get_asset_paths() -> Array:
	return []

func on_content_loaded(_players: Array, _teams: Array, _selections: Array) -> void:
	pass

func on_scene_change(_from_scene: String, _to_scene: String) -> void:
	pass

func on_custom_signal(_signal_name: String, _args: Array) -> void:
	pass

# ── 旧版工具方法 ─────────────────────────────────────────────────────────────

func get_mod_id() -> String:
	return get_metadata().id

func get_core() -> Node:
	var root := get_tree().get_root()
	if root.has_node("ModLoader"):
		return root.get_node("ModLoader")
	return null

func get_content_registry():
	var core := get_core()
	if core and core.has_method("get_content_registry"):
		return core.get_content_registry()
	return null

func emit_mod_signal(signal_name: String, data: Dictionary = {}) -> void:
	mod_event.emit(get_mod_id(), signal_name, data)