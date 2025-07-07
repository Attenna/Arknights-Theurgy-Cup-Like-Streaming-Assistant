# editor_manager_control.gd
# Attached to your EditorManager node.

extends Control # Or Node, depending on your EditorManager node type.

# Export variable to set the path of the EditorContainer node in the editor.
# This is the parent node for all dynamically loaded editor scenes.
@export var editor_container_path: NodePath = "EditorContainer"

# Export variables for button paths.
# Please replace these paths with your actual button node paths.
@export var player_button_path: NodePath = "PlayerButton"
@export var team_button_path: NodePath = "TeamButton"
@export var announcer_button_path: NodePath = "AnnouncerButton"

# Scene paths for dynamic loading
# Please replace these paths with your actual scene file paths.
var editor_scene_paths = {
	"PlayerEditor": "res://scene/ui/player_editor.tscn",
	"TeamEditor": "res://scene/ui/team_editor.tscn", 
	"AnnouncerEditor": "res://scene/ui/announcer_editor.tscn",
	# Add more editor scenes here if you have them.
}

var current_editor_scene_instance: Node = null # Current loaded editor scene instance.
var current_editor_scene_id: String = ""      # Identifier of the currently loaded editor scene.

@onready var editor_container: Node = get_node(editor_container_path)
@onready var player_button: Button = get_node(player_button_path)
@onready var team_button: Button = get_node(team_button_path)
@onready var announcer_button: Button = get_node(announcer_button_path)


func _ready():
	# Ensure the editor_container node exists.
	if not editor_container:
		print("Error: EditorContainer node not found. Please check 'editor_container_path' setting.")
		return

	# Connect button 'pressed' signals to their respective handler functions.
	if player_button:
		player_button.pressed.connect(_on_player_button_pressed)
	else:
		print("Error: 'PlayerButton' node not found.")

	if team_button:
		team_button.pressed.connect(_on_team_button_pressed)
	else:
		print("Error: 'TeamButton' node not found.")

	if announcer_button:
		announcer_button.pressed.connect(_on_announcer_button_pressed)
	else:
		print("Error: 'AnnouncerButton' node not found.")

	# Optionally, load a default editor scene initially.
	# _load_editor_scene("PlayerEditor") # For example, load PlayerEditor scene by default.

func _on_player_button_pressed():
	"""
	Called when the 'PlayerButton' is pressed.
	Requests to load the "PlayerEditor" scene.
	"""
	print("PlayerButton pressed. Requesting to load PlayerEditor scene.")
	_load_editor_scene("PlayerEditor")

func _on_team_button_pressed():
	"""
	Called when the 'TeamButton' is pressed.
	Requests to load the "TeamEditor" scene.
	"""
	print("TeamButton pressed. Requesting to load TeamEditor scene.")
	_load_editor_scene("TeamEditor")

func _on_announcer_button_pressed():
	"""
	Called when the 'AnnouncerButton' is pressed.
	Requests to load the "AnnouncerEditor" scene.
	"""
	print("AnnouncerButton pressed. Requesting to load AnnouncerEditor scene.")
	_load_editor_scene("AnnouncerEditor")

func _load_editor_scene(target_editor_scene_id: String):
	"""
	Loads and displays the corresponding editor child scene based on the provided ID.
	Ensures only one editor scene is loaded at a time.
	"""
	print("Received editor scene load request for: " + target_editor_scene_id)

	# If the target scene ID is the same as the current scene ID, do nothing.
	if current_editor_scene_id == target_editor_scene_id:
		print("Editor scene '" + target_editor_scene_id + "' is already loaded. No reload needed.")
		return

	if not editor_scene_paths.has(target_editor_scene_id):
		print("Error: Unknown editor scene ID '" + target_editor_scene_id + "'.")
		return

	# Remove the currently loaded editor scene instance (if it exists).
	if current_editor_scene_instance and is_instance_valid(current_editor_scene_instance):
		current_editor_scene_instance.queue_free() # Free the old editor scene.
		current_editor_scene_instance = null
		current_editor_scene_id = ""
		print("Removed old editor scene.")

	# Dynamically load and instantiate the new editor scene.
	var scene_path = editor_scene_paths[target_editor_scene_id]
	var new_editor_scene_resource = load(scene_path)
	
	if new_editor_scene_resource:
		current_editor_scene_instance = new_editor_scene_resource.instantiate()
		editor_container.add_child(current_editor_scene_instance)
		current_editor_scene_id = target_editor_scene_id
		print("Loaded and added new editor scene: " + target_editor_scene_id)
	else:
		print("Error: Failed to load editor scene resource from '" + scene_path + "'.")
