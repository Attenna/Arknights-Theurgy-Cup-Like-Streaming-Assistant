# mod_template.gd
# Template for creating new mods
# Copy this file and rename to your mod's ID

extends ModInterface

# Mod metadata - override in your mod
var _mod_id: String = "template_mod"
var _mod_name: String = "Template Mod"
var _mod_version: String = "1.0.0"
var _mod_author: String = "Unknown"
var _mod_description: String = "A mod template"
var _dependencies: Array = []
var _load_priority: int = 0
var _autoload: bool = false

func get_metadata() -> ModInterface.ModMetadata:
	var metadata = ModInterface.ModMetadata.new()
	metadata.id = _mod_id
	metadata.name = _mod_name
	metadata.version = _mod_version
	metadata.author = _mod_author
	metadata.description = _mod_description
	metadata.dependencies = _dependencies
	metadata.load_priority = _load_priority
	metadata.autoload = _autoload
	return metadata

# Called when mod is being loaded
func on_load() -> bool:
	print("[%s] Loading..." % _mod_id)
	return true

# Called after all mods are loaded and content is ready
func on_initialize() -> bool:
	print("[%s] Initializing..." % _mod_id)
	
	# Access core loader using inherited method
	var registry = get_content_registry()
	if registry:
		print("[%s] Content available" % _mod_id)

	return true

# Called when mod becomes active
func on_activate() -> void:
	print("[%s] Activated" % _mod_id)

# Called when mod is paused
func on_pause() -> void:
	print("[%s] Paused" % _mod_id)

# Called when mod resumes from pause
func on_resume() -> void:
	print("[%s] Resumed" % _mod_id)

# Called when mod is being unloaded
func on_unload() -> void:
	print("[%s] Unloading..." % _mod_id)

# Called when core content is loaded
func on_content_loaded(players: Array, teams: Array, selections: Array) -> void:
	print("[%s] Content update: %d players, %d teams" % [_mod_id, players.size(), teams.size()])

# Called when scene is about to change
func on_scene_change(from_scene: String, to_scene: String) -> void:
	print("[%s] Scene change: %s -> %s" % [_mod_id, from_scene, to_scene])
