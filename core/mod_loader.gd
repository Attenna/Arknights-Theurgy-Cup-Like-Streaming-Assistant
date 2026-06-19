# mod_loader.gd
# Core mod loading and management system

extends Node

signal mod_load_started(mod_id: String)
signal mod_load_completed(mod_id: String, success: bool)
signal mod_init_started(mod_id: String)
signal mod_init_completed(mod_id: String, success: bool)
signal mod_unloaded(mod_id: String)
signal all_mods_loaded()
signal all_mods_initialized()
signal core_ready()

signal content_load_requested(path: String)
signal scene_change_requested(scene_id: String)

const MOD_CONFIG_FILE = "mods.json"
const MOD_METADATA_FILE = "mod.json"

var _loaded_mods: Dictionary = {}
var _mod_scenes: Dictionary = {}
var _active_mod_id: String = ""
var _content_registry = null

func _ready():
	print("[ModLoader] Initializing...")
	_initialize_mod_system()

func _initialize_mod_system() -> void:
	print("[ModLoader] Creating mod directories...")
	_create_mod_directories()
	
	print("[ModLoader] Loading mods registry...")
	var mods_registry = _load_mods_registry()
	
	print("[ModLoader] Scanning for mods...")
	var discovered_mods = _scan_for_mods()
	
	print("[ModLoader] Found %d potential mods" % discovered_mods.size())
	
	# Load enabled mods
	for mod_id in discovered_mods.keys():
		if mods_registry.has("mods") and mod_id in mods_registry["mods"]:
			print("[ModLoader] Loading mod: %s" % mod_id)
			_load_mod(discovered_mods[mod_id])
	
	# Initialize mods in dependency order
	_initialize_mods()
	
	print("[ModLoader] Core ready!")
	emit_signal("core_ready")

func _create_mod_directories() -> void:
	var mods_dir = ProjectSettings.globalize_path("res://mods")
	var dir = DirAccess.open(mods_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(mods_dir)
		print("[ModLoader] Created mods directory: %s" % mods_dir)

func _load_mods_registry() -> Dictionary:
	var registry_path = ProjectSettings.globalize_path("res://mods/mods.json")
	if FileAccess.file_exists(registry_path):
		var file = FileAccess.open(registry_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var data = JSON.parse_string(content)
			if data is Dictionary:
				return data
	return {"mods": []}

func _save_mods_registry(registry: Dictionary) -> bool:
	var registry_path = ProjectSettings.globalize_path("res://mods/mods.json")
	var file = FileAccess.open(registry_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(registry, "\t"))
		file.close()
		return true
	return false

func _scan_for_mods() -> Dictionary:
	var discovered = {}
	var mods_dir = ProjectSettings.globalize_path("res://mods")
	
	var dir = DirAccess.open(mods_dir)
	if dir == null:
		push_warning("[ModLoader] Mods directory not found: %s" % mods_dir)
		return discovered
	
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var mod_path = mods_dir.path_join(entry)
			var metadata = _load_mod_metadata(mod_path)
			if metadata != null:
				discovered[metadata.id] = {
					"path": mod_path,
					"metadata": metadata
				}
				print("[ModLoader] Discovered mod: %s (v%s)" % [metadata.name, metadata.version])
		entry = dir.get_next()
	
	return discovered

func _load_mod_metadata(mod_path: String) -> ModInterface.ModMetadata:
	var metadata_path = mod_path.path_join(MOD_METADATA_FILE)
	if not FileAccess.file_exists(metadata_path):
		push_warning("[ModLoader] Mod metadata not found: %s" % metadata_path)
		return null
	
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return null
	
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	
	if data is Dictionary:
		var metadata = ModInterface.ModMetadata.new()
		metadata.id = data.get("id", "unknown")
		metadata.name = data.get("name", "Unnamed Mod")
		metadata.version = data.get("version", "1.0.0")
		metadata.author = data.get("author", "Unknown")
		metadata.description = data.get("description", "")
		metadata.dependencies = data.get("dependencies", [])
		metadata.load_priority = data.get("load_priority", 0)
		metadata.autoload = data.get("autoload", false)
		metadata.scenes = data.get("scenes", [])
		metadata.data_files = data.get("data_files", [])
		metadata.asset_paths = data.get("asset_paths", [])
		return metadata
	
	return null

func _load_mod(mod_info: Dictionary) -> bool:
	var mod_path = mod_info.path
	var metadata = mod_info.metadata
	
	emit_signal("mod_load_started", metadata.id)
	
	# Check dependencies
	if not _check_dependencies(metadata):
		push_error("[ModLoader] Mod %s failed dependency check" % metadata.id)
		emit_signal("mod_load_completed", metadata.id, false)
		return false
	
	# Load mod scripts
	var mod_script = _load_mod_script(mod_path, metadata.id)
	if mod_script == null:
		push_error("[ModLoader] Failed to load mod script for: %s" % metadata.id)
		emit_signal("mod_load_completed", metadata.id, false)
		return false
	
	# Create mod instance
	var mod_instance = Node.new()
	mod_instance.set_script(mod_script)
	mod_instance.name = metadata.id
	
	# Call mod's on_load
	if mod_instance.has_method("on_load"):
		var result = mod_instance.on_load()
		if not result:
			push_error("[ModLoader] Mod %s on_load() returned false" % metadata.id)
			mod_instance.queue_free()
			emit_signal("mod_load_completed", metadata.id, false)
			return false
	
	_loaded_mods[metadata.id] = {
		"instance": mod_instance,
		"metadata": metadata,
		"state": ModInterface.ModState.LOADED,
		"path": mod_path
	}
	
	# Preload mod scenes
	_mod_scenes[metadata.id] = _preload_mod_scenes(mod_path, metadata.scenes)
	
	print("[ModLoader] Mod loaded successfully: %s" % metadata.id)
	emit_signal("mod_load_completed", metadata.id, true)
	return true

func _load_mod_script(mod_path: String, mod_id: String) -> GDScript:
	# Look for main script
	var script_paths = [
		mod_path.path_join("mod.gd"),
		mod_path.path_join("%s.gd" % mod_id),
		mod_path.path_join("main.gd")
	]
	
	for script_path in script_paths:
		if FileAccess.file_exists(script_path):
			var script = load(script_path)
			if script is GDScript:
				return script
	
	return null

func _preload_mod_scenes(mod_path: String, scene_list: Array) -> Dictionary:
	var preloaded = {}
	for scene_path in scene_list:
		var full_path = mod_path.path_join(scene_path)
		if FileAccess.file_exists(full_path):
			preloaded[scene_path] = load(full_path)
			print("[ModLoader] Preloaded scene: %s" % scene_path)
	return preloaded

func _check_dependencies(metadata: ModInterface.ModMetadata) -> bool:
	for dep_id in metadata.dependencies:
		if not _loaded_mods.has(dep_id):
			push_error("[ModLoader] Missing dependency: %s for mod %s" % [dep_id, metadata.id])
			return false
		if _loaded_mods[dep_id].state != ModInterface.ModState.LOADED:
			push_error("[ModLoader] Dependency %s not in LOADED state" % dep_id)
			return false
	return true

func _initialize_mods() -> void:
	# Sort by load priority
	var sorted_mods = _loaded_mods.keys()
	sorted_mods.sort_custom(func(a, b): 
		return _loaded_mods[a].metadata.load_priority < _loaded_mods[b].metadata.load_priority
	)
	
	# Initialize each mod
	for mod_id in sorted_mods:
		var mod_data = _loaded_mods[mod_id]
		var mod_instance = mod_data.instance
		
		emit_signal("mod_init_started", mod_id)
		mod_data.state = ModInterface.ModState.INITIALIZING
		
		if mod_instance.has_method("on_initialize"):
			var result = mod_instance.on_initialize()
			if not result:
				push_error("[ModLoader] Mod %s on_initialize() returned false" % mod_id)
				mod_data.state = ModInterface.ModState.ERROR
				emit_signal("mod_init_completed", mod_id, false)
				continue
		
		mod_data.state = ModInterface.ModState.ACTIVE
		print("[ModLoader] Mod initialized: %s" % mod_id)
		emit_signal("mod_init_completed", mod_id, true)
	
	emit_signal("all_mods_initialized")

func load_mod(mod_id: String) -> bool:
	if _loaded_mods.has(mod_id):
		push_warning("[ModLoader] Mod already loaded: %s" % mod_id)
		return false
	
	var discovered_mods = _scan_for_mods()
	if not discovered_mods.has(mod_id):
		push_error("[ModLoader] Mod not found: %s" % mod_id)
		return false
	
	return _load_mod(discovered_mods[mod_id])

func unload_mod(mod_id: String) -> bool:
	if not _loaded_mods.has(mod_id):
		push_warning("[ModLoader] Mod not loaded: %s" % mod_id)
		return false
	
	var mod_data = _loaded_mods[mod_id]
	var mod_instance = mod_data.instance
	
	mod_data.state = ModInterface.ModState.UNLOADING
	
	if mod_instance.has_method("on_unload"):
		mod_instance.on_unload()
	
	mod_instance.queue_free()
	_loaded_mods.erase(mod_id)
	_mod_scenes.erase(mod_id)
	
	print("[ModLoader] Mod unloaded: %s" % mod_id)
	emit_signal("mod_unloaded", mod_id)
	return true

func activate_mod(mod_id: String) -> bool:
	if not _loaded_mods.has(mod_id):
		push_error("[ModLoader] Cannot activate - mod not loaded: %s" % mod_id)
		return false
	
	var mod_data = _loaded_mods[mod_id]
	if mod_data.state != ModInterface.ModState.ACTIVE:
		push_error("[ModLoader] Cannot activate - mod not in ACTIVE state: %s" % mod_id)
		return false
	
	# Deactivate current mod
	if not _active_mod_id.is_empty():
		deactivate_mod(_active_mod_id)
	
	_active_mod_id = mod_id
	var mod_instance = mod_data.instance
	
	if mod_instance.has_method("on_activate"):
		mod_instance.on_activate()
	
	print("[ModLoader] Mod activated: %s" % mod_id)
	return true

func deactivate_mod(mod_id: String) -> bool:
	if not _loaded_mods.has(mod_id):
		return false
	
	var mod_data = _loaded_mods[mod_id]
	var mod_instance = mod_data.instance
	
	if mod_instance.has_method("on_pause"):
		mod_instance.on_pause()
	
	print("[ModLoader] Mod deactivated: %s" % mod_id)
	_active_mod_id = ""
	return true

func get_mod(mod_id: String) -> Node:
	if _loaded_mods.has(mod_id):
		return _loaded_mods[mod_id].instance
	return null

func get_mod_metadata(mod_id: String) -> ModInterface.ModMetadata:
	if _loaded_mods.has(mod_id):
		return _loaded_mods[mod_id].metadata
	return null

func get_loaded_mods() -> Array:
	return _loaded_mods.keys()

func get_active_mod() -> String:
	return _active_mod_id

func get_mod_scene(mod_id: String, scene_path: String) -> PackedScene:
	if _mod_scenes.has(mod_id) and _mod_scenes[mod_id].has(scene_path):
		return _mod_scenes[mod_id][scene_path]
	return null

func instantiate_mod_scene(mod_id: String, scene_path: String) -> Node:
	var scene = get_mod_scene(mod_id, scene_path)
	if scene:
		return scene.instantiate()
	return null

func set_content_registry(registry):
	_content_registry = registry

func get_content_registry():
	return _content_registry
