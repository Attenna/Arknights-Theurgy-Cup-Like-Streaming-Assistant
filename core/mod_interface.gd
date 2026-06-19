# mod_interface.gd
# Defines the interface contract between core loader and mods
# All mods should extend this base class

class_name ModInterface
extends Node

# Mod lifecycle states
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

# Mod metadata structure
class ModMetadata:
	var id: String = ""
	var name: String = ""
	var version: String = ""
	var author: String = ""
	var description: String = ""
	var dependencies: Array = []
	var load_priority: int = 0
	var autoload: bool = false
	var scenes: Array = []
	var data_files: Array = []
	var asset_paths: Array = []

# Signals that mods emit to core
signal mod_loaded(mod_id: String)
signal mod_unloaded(mod_id: String)
signal mod_initialized(mod_id: String)
signal mod_error(mod_id: String, error_message: String)
signal mod_event(mod_id: String, event_name: String, event_data: Dictionary)

# Signals that core sends to mods
signal core_content_loaded(content_type: String, count: int)
signal core_scene_requested(scene_id: String)
signal core_shutdown_requested()

# Methods that mods MUST implement
func get_metadata() -> ModMetadata:
	# Override in your mod to return metadata
	var metadata = ModMetadata.new()
	metadata.id = get_script().get_global_name()
	metadata.name = "Unnamed Mod"
	return metadata

func on_load() -> bool:
	# Called when mod is being loaded
	# Return true to proceed, false to abort
	return true

func on_initialize() -> bool:
	# Called after all mods are loaded and content is ready
	# Return true to proceed, false to abort
	return true

func on_activate() -> void:
	# Called when mod becomes active
	pass

func on_pause() -> void:
	# Called when mod is paused
	pass

func on_resume() -> void:
	# Called when mod resumes from pause
	pass

func on_unload() -> void:
	# Called when mod is being unloaded
	pass

# Methods that mods CAN override
func get_mod_scenes() -> Array:
	# Return list of scene paths this mod provides
	return []

func get_data_files() -> Array:
	# Return list of data file paths this mod provides
	return []

func get_asset_paths() -> Array:
	# Return list of asset paths this mod provides
	return []

func on_content_loaded(players: Array, teams: Array, selections: Array) -> void:
	# Called when core content is loaded
	# Override to react to content changes
	pass

func on_scene_change(from_scene: String, to_scene: String) -> void:
	# Called when scene is about to change
	pass

func on_custom_signal(signal_name: String, args: Array) -> void:
	# Called when a custom signal is emitted
	pass

# Utility methods provided by base class
func get_mod_id() -> String:
	return get_metadata().id

func get_core() -> Node:
	var root = get_tree().get_root()
	if root.has_node("CoreLoader"):
		return root.get_node("CoreLoader")
	return null

func get_content_registry():
	# Get content registry from core
	var core = get_core()
	if core and core.has_method("get_content_registry"):
		return core.get_content_registry()
	return null

func emit_mod_signal(signal_name: String, data: Dictionary = {}) -> void:
	emit_signal("mod_event", get_mod_id(), signal_name, data)
