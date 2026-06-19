# main_scene_loader_v2.gd
# Attached to your Main node.

extends Node

# Export variable to set the path of the MainContentRoot node in the editor.
# This is the parent node for all dynamically loaded scenes.
@export var main_content_root_path: NodePath = "MainContentRoot"

# New: Export variable to set the path of the control_panel scene.
# Please set this path to your control_panel.tscn file path.
@export var control_panel_scene_path: String = "res://scene/ui/control_panel.tscn" # Example path

# Preload all mutually exclusive child scene resources.
# Please replace these paths with your actual scene file paths.
# For example: res://scenes/MainVisionScene.tscn, res://scenes/StreamingArenaScene.tscn, res://scenes/WaitingScene.tscn
const MAIN_VISION_SCENE = preload("res://scene/main_vision.tscn")
const STREAMING_ARENA_SCENE = preload("res://scene/streaming_arena.tscn")
const WAITING_SCENE = preload("res://scene/waiting_scene.tscn")

# Preload the control_panel scene resource.
var CONTROL_PANEL_SCENE = null # Will be loaded in the _ready function.

# Stores a mapping of scene names to preloaded resources.
# The key is the unique identifier (string) of the scene, and the value is the preloaded scene resource.
var scene_map = {
	"MainVision": MAIN_VISION_SCENE,
	"StreamingArena": STREAMING_ARENA_SCENE,
	"WaitingScene": WAITING_SCENE,
	# Add more scenes here if you have them.
}

var current_scene_instance: Node = null # Current loaded scene instance.
var current_scene_id: String = ""      # Identifier of the currently loaded scene.
var control_panel_instance: Window = null # Instance of the control_panel scene, assuming its root node is a Window.

@onready var main_content_root: Node = get_node(main_content_root_path)

func _ready():
	# Set main window title
	get_window().title = "Streaming Scene"
	
	# Ensure the main_content_root node exists.
	if not main_content_root:
		print("Error: MainContentRoot node not found. Please check 'main_content_root_path' setting.")
		return

	# Load and instantiate the control_panel scene.
	if not control_panel_scene_path.is_empty():
		CONTROL_PANEL_SCENE = load(control_panel_scene_path)
		if CONTROL_PANEL_SCENE:
			control_panel_instance = CONTROL_PANEL_SCENE.instantiate()
			# Add the control_panel as a child of the Main node.
			# If the control_panel's root node is a Window, it will automatically manage its own display behavior.
			add_child(control_panel_instance)
			
			# Center the control panel window if it's a Window
			if control_panel_instance is Window:
				# Set control panel window title
				control_panel_instance.title = "Control Panel"
				# Wait for the window to be ready, then center it
				control_panel_instance.call_deferred("popup_centered")
				print("Control panel window centered on screen.")
			
			print("Control panel loaded and added as child.")

			# Connect to the SceneManager's signal from the instantiated control_panel.
			# Assuming SceneManager is a child (or deeper descendant) of control_panel_instance.
			# find_child(name, recursive, owned_by_scene) is used to find child nodes.
			var scene_manager = control_panel_instance.find_child("SceneManager", true, false)
			if scene_manager:
				if scene_manager.has_signal("transition_requested"):
					scene_manager.transition_requested.connect(_on_transition_requested)
					print("Successfully connected to SceneManager's 'transition_requested' signal.")
				else:
					print("Error: SceneManager node in control_panel does not have a 'transition_requested' signal.")
			else:
				print("Error: SceneManager node not found within the instantiated control_panel. Please check its path.")
			
			# Connect the close_requested signal of the control_panel_instance
			if control_panel_instance is Window:
				control_panel_instance.close_requested.connect(_on_control_panel_close_requested)
				print("Successfully connected to control_panel_instance's 'close_requested' signal.")
			else:
				print("Warning: Control panel root node is not a Window. 'close_requested' signal cannot be connected.")
		else:
			print("Error: Failed to load control_panel scene from path: " + control_panel_scene_path)
	else:
		print("Warning: control_panel_scene_path is empty. Control panel will not be loaded.")

	# Optionally, load a default scene initially.
	# _on_transition_requested("MainVision") # For example, load MainVision scene by default.

func _on_transition_requested(target_scene_id: String):
	"""
	This function is called when the SceneManager emits the 'transition_requested' signal.
	It loads and displays the corresponding child scene based on the provided target scene ID.
	"""
	print("Received scene transition request for: {target_scene_id}")

	# If the target scene ID is the same as the current scene ID, do nothing.
	if current_scene_id == target_scene_id:
		print("Scene '{target_scene_id}' is already loaded. No transition needed.")
		return

	if not scene_map.has(target_scene_id):
		print("Error: Unknown scene ID '{target_scene_id}'.")
		return

	# Remove the currently loaded scene instance (if it exists).
	if current_scene_instance and is_instance_valid(current_scene_instance):
		current_scene_instance.queue_free() # Free the old scene.
		current_scene_instance = null
		current_scene_id = ""
		print("Removed old scene.")

	# Instantiate the new scene.
	var new_scene_resource = scene_map[target_scene_id]
	if new_scene_resource:
		current_scene_instance = new_scene_resource.instantiate()
		main_content_root.add_child(current_scene_instance)
		current_scene_id = target_scene_id
		print("Loaded and added new scene: {target_scene_id}")
	else:
		print("Error: Failed to instantiate scene resource for '{target_scene_id}'.")

func _on_control_panel_close_requested():
	"""
	This function is called when the control_panel (Window) requests to close.
	It will directly quit the application without confirmation.
	"""
	print("Control panel close requested. Quitting application directly.")
	get_tree().quit() # Quits the application immediately
