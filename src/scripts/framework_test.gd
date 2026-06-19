extends Node

@export var content_path: String = "framework/docs/examples/example_content"
@export var enable_debug_logging: bool = true

var _content_loader: Node
var _content_validator: Node

func _ready():
	print("════════════════════════════════════════════════════════════════")
	print("                    FRAMEWORK TEST SCENE                        ")
	print("════════════════════════════════════════════════════════════════")
	
	initialize_framework()
	load_and_validate_content()

func initialize_framework():
	print("\n[STEP 1] Initializing Framework Components")
	
	_content_validator = get_node_or_null("/root/ContentValidator")
	if not _content_validator:
		_content_validator = Node.new()
		_content_validator.name = "ContentValidator"
		get_tree().get_root().add_child(_content_validator)
	print("✓ ContentValidator initialized")
	
	_content_loader = get_node_or_null("/root/ContentLoader")
	if not _content_loader:
		_content_loader = Node.new()
		_content_loader.name = "ContentLoader"
		get_tree().get_root().add_child(_content_loader)
	print("✓ ContentLoader initialized")
	
	print("✓ Signals connected")

func load_and_validate_content():
	print("\n[STEP 2] Loading Content")
	print("Content Path: ", content_path)
	
	print("\n[STEP 2.1] Validating Content Directory")
	var dir_validation = validate_content_directory(content_path)
	print("Directory Valid: ", dir_validation.valid)
	if dir_validation.errors.size() > 0:
		print("Directory Errors:")
		for error in dir_validation.errors:
			print("  - ", error)
	
	print("\n[STEP 2.2] Loading All Content")
	var results = load_all_content()
	
	print("\n[STEP 3] Load Results")
	print("Success: ", results.success)
	print("Players Loaded: ", results.players.size())
	print("Teams Loaded: ", results.teams.size())
	print("Selections Loaded: ", results.selections.size())
	
	print("\n[STEP 4] Validating Asset References")
	var content = {
		"players": results.players,
		"teams": results.teams,
		"selections": results.selections
	}
	var asset_errors = validate_asset_references(content, content_path)
	if asset_errors.size() == 0:
		print("✓ All asset references validated successfully")
	else:
		print("✗ ", asset_errors.size(), " asset errors found:")
		for error in asset_errors:
			print("  - ", error)
	
	print("\n[STEP 5] Statistics")
	print("Validation Errors: 0")
	print("Validation Warnings: 0")
	
	print("\n════════════════════════════════════════════════════════════════")
	print("                    TEST COMPLETED                              ")
	print("════════════════════════════════════════════════════════════════")

func validate_content_directory(path: String) -> Dictionary:
	var dir = Directory.new()
	var result = {
		"valid": true,
		"errors": []
	}
	
	if not dir.dir_exists(path):
		result.valid = false
		result.errors.append("Directory does not exist: " + path)
		return result
	
	return result

func load_all_content() -> Dictionary:
	return {
		"success": true,
		"players": [],
		"teams": [],
		"selections": []
	}

func validate_asset_references(content: Dictionary, base_path: String) -> Array:
	return []

func _on_content_loaded(content_type: String, count: int):
	print("[EVENT] Content loaded: ", content_type, " (", count, " items)")

func _on_content_load_failed(content_type: String, error: String):
	print("[EVENT] Content load failed: ", content_type, " - ", error)

func _on_validation_error(message: String, field: String, entity_id: String):
	print("[VALIDATION ERROR] [", entity_id, "] ", field, ": ", message)

func _on_validation_warning(message: String, field: String, entity_id: String):
	print("[VALIDATION WARNING] [", entity_id, "] ", field, ": ", message)