# example_mod.gd
# Example mod script demonstrating the mod interface

extends ModInterface

# Override to provide mod metadata
func get_metadata() -> ModInterface.ModMetadata:
	var metadata = ModInterface.ModMetadata.new()
	metadata.id = "example_mod"
	metadata.name = "Example Mod"
	metadata.version = "1.0.0"
	metadata.author = "Framework Author"
	metadata.description = "An example mod demonstrating mod functionality"
	metadata.dependencies = []
	metadata.load_priority = 0
	metadata.autoload = true
	metadata.scenes = ["scenes/main_menu.tscn", "scenes/settings.tscn"]
	metadata.streaming_scenes = [{
		"id": "example_live_scene",
		"name": "示例直播场景",
		"scene": "scenes/live_scene.tscn",
		"description": "演示模组直播场景：实时显示当前选手、队伍、分数与开局选择"
	}]
	metadata.data_files = ["data/mod_config.json"]
	metadata.asset_paths = ["assets/"]
	return metadata

# Called when mod is being loaded
func on_load() -> bool:
	print("[ExampleMod] Loading...")
	return true

# Called after all mods are loaded and content is ready
func on_initialize() -> bool:
	print("[ExampleMod] Initializing...")
	
	# Access content registry
	var registry = get_content_registry()
	if registry:
		var players = registry.GetAllPlayers()
		var teams = registry.GetAllTeams()
		print("[ExampleMod] Content loaded: %d players, %d teams" % [players.size(), teams.size()])
	
	return true

# Called when mod becomes active
func on_activate() -> void:
	print("[ExampleMod] Activated")

# Called when mod is paused
func on_pause() -> void:
	print("[ExampleMod] Paused")

# Called when mod resumes from pause
func on_resume() -> void:
	print("[ExampleMod] Resumed")

# Called when mod is being unloaded
func on_unload() -> void:
	print("[ExampleMod] Unloading...")

# Called when core content is loaded
func on_content_loaded(players: Array, teams: Array, selections: Array) -> void:
	print("[ExampleMod] Content update: %d players, %d teams, %d selections" % [players.size(), teams.size(), selections.size()])

# Called when scene is about to change
func on_scene_change(from_scene: String, to_scene: String) -> void:
	print("[ExampleMod] Scene change: %s -> %s" % [from_scene, to_scene])
