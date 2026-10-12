# main_scene_loader_v2.gd
# Attached to your Main node.

extends Node

# Export variable to set the path of the MainContentRoot node in the editor.
# This is the parent node for all dynamically loaded scenes.
@export var main_content_root_path: NodePath = "MainContentRoot"

# New: Export variable to set the path of the control_panel scene.
# Please set this path to your control_panel.tscn file path.
@export var control_panel_scene_path: String = "res://src/scenes/ui/control_panel.tscn" # Example path

# Preload all mutually exclusive child scene resources.
# Please replace these paths with your actual scene file paths.
# For example: res://scenes/MainVisionScene.tscn, res://scenes/StreamingArenaScene.tscn, res://scenes/WaitingScene.tscn
const MAIN_VISION_SCENE = preload("res://src/scenes/main_vision.tscn")
const STREAMING_ARENA_SCENE = preload("res://src/scenes/streaming_arena.tscn")
const WAITING_SCENE = preload("res://src/scenes/waiting_scene.tscn")

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

			# Connect every node in the control panel that requests scene transitions.
			# The built-in SceneManager and the mod ModManager both expose
			# a 'transition_requested' signal, so we discover them generically.
			_connect_transition_sources(control_panel_instance)
			
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

func _connect_transition_sources(root: Node) -> void:
	"""Recursively connect any descendant exposing a 'transition_requested' signal."""
	var found := 0
	for node in _find_nodes_with_signal(root, "transition_requested"):
		if not node.transition_requested.is_connected(_on_transition_requested):
			node.transition_requested.connect(_on_transition_requested)
			found += 1
	if found > 0:
		print("Connected %d scene transition source(s)." % found)
	else:
		print("Warning: No node with a 'transition_requested' signal found in the control panel.")

func _find_nodes_with_signal(node: Node, signal_name: String) -> Array:
	var result: Array = []
	if node.has_signal(signal_name):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes_with_signal(child, signal_name))
	return result

func _on_transition_requested(target_scene_id: String):
	"""
	Loads and displays the requested child scene. Built-in scenes come from scene_map,
	mod-provided streaming scenes are resolved through the ModLoader autoload.
	"""
	print("Received scene transition request for: %s" % target_scene_id)

	# If the target scene ID is the same as the current scene ID, do nothing.
	if current_scene_id == target_scene_id:
		print("Scene '%s' is already loaded. No transition needed." % target_scene_id)
		return

	var is_builtin := scene_map.has(target_scene_id)
	var mod_loader := _get_mod_loader()
	var is_mod_scene: bool = mod_loader != null and mod_loader.has_streaming_scene(target_scene_id)

	if not is_builtin and not is_mod_scene:
		print("Error: Unknown scene ID '%s'." % target_scene_id)
		return

	# Remove the currently loaded scene instance (if it exists).
	if current_scene_instance and is_instance_valid(current_scene_instance):
		current_scene_instance.queue_free() # Free the old scene.
		current_scene_instance = null
		current_scene_id = ""
		print("Removed old scene.")

	# Instantiate the new scene.
	if is_mod_scene:
		current_scene_instance = mod_loader.instantiate_streaming_scene(target_scene_id)
	elif is_builtin:
		var new_scene_resource = scene_map[target_scene_id]
		current_scene_instance = new_scene_resource.instantiate()

	if current_scene_instance:
		main_content_root.add_child(current_scene_instance)
		current_scene_id = target_scene_id
		print("Loaded and added new scene: %s" % target_scene_id)
	else:
		print("Error: Failed to instantiate scene resource for '%s'." % target_scene_id)

func _get_mod_loader() -> Node:
	return get_node_or_null("/root/ModLoader")

func _on_control_panel_close_requested():
	"""
	This function is called when the control_panel (Window) requests to close.
	It will directly quit the application without confirmation.
	"""
	print("Control panel close requested. Quitting application directly.")
	get_tree().quit() # Quits the application immediately
