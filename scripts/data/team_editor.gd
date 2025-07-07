# team_editor_control.gd
# Attached to the root node of your TeamEditor scene.

extends Control

# This signal is emitted after the teams.json file has been successfully saved.
signal teams_data_saved

var user_data_path = AppData.get_exe_dir()

# UI Node Paths
@export var id_input_path: NodePath = "IDInput"
@export var team_name_input_path: NodePath = "TeamNameInput"
@export var select_icon_button_path: NodePath = "SelectIconButton"
@export var icon_path_label_path: NodePath = "IconPathLabel"
@export var save_button_path: NodePath = "SaveButton"

# File Paths
var LAST_TEAM_ICON_PATH_FILE = user_data_path + "/userdata/teams/last_team_icon_path.json"
var LAST_FILE_DIALOG_PATH_FILE = user_data_path + "/data/last_file_dialog_path.json" # Store last file dialog directory
var TEAM_ICONS_DIR = user_data_path + "/userdata/teams/team_icons/"
var TEAMS_DATA_PATH = user_data_path + "/userdata/teams/teams.json"

# UI Node References
@onready var id_input: LineEdit = get_node_or_null(id_input_path)
@onready var team_name_input: LineEdit = get_node_or_null(team_name_input_path)
@onready var select_icon_button: Button = get_node_or_null(select_icon_button_path)
@onready var icon_path_label: Label = get_node_or_null(icon_path_label_path)
@onready var save_button: Button = get_node_or_null(save_button_path)

var file_dialog: FileDialog = null # For selecting team icons
var cached_icon_path: String = "" # Cached path of selected icon file, saved to destination only when SaveButton is pressed

func _ready():
	# Print user data directory for debugging
	print("User data directory (user://) maps to: " + OS.get_user_data_dir())

	# Ensure all required UI nodes exist and provide specific error messages
	var all_nodes_found = true
	if not id_input: print("Error: IDInput node not found at path: " + str(id_input_path)); all_nodes_found = false
	if not team_name_input: print("Error: TeamNameInput node not found at path: " + str(team_name_input_path)); all_nodes_found = false
	if not select_icon_button: print("Error: SelectIconButton node not found at path: " + str(select_icon_button_path)); all_nodes_found = false
	if not icon_path_label: print("Error: IconPathLabel node not found at path: " + str(icon_path_label_path)); all_nodes_found = false
	if not save_button: print("Error: SaveButton node not found at path: " + str(save_button_path)); all_nodes_found = false

	if not all_nodes_found:
		print("Please correct the node paths in the TeamEditor script's exported variables.")
		return # Stop execution if critical nodes are missing

	# Connect signals
	select_icon_button.pressed.connect(_on_select_icon_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)

	# Initialize FileDialog for icon selection
	file_dialog = FileDialog.new()
	file_dialog.title = "Select Team Icon"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM # Allow access to entire filesystem
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.png,*.jpg,*.jpeg ; Image Files"]
	# Set custom window size to 900x800
	file_dialog.size = Vector2i(900, 800)
	file_dialog.dir_selected.connect(_on_file_dialog_dir_selected)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	add_child(file_dialog)

	# Ensure user data directories exist before loading data
	_ensure_user_data_directories()

	# Load last selected team icon path
	_load_last_team_icon_path()

func _ensure_user_data_directories():
	# Use DirAccess.make_dir_recursive_absolute() for creating directories recursively at absolute paths.
	print("Ensuring user data directories exist...")
	if not DirAccess.dir_exists_absolute(user_data_path + "/data/"):
		var error = DirAccess.make_dir_recursive_absolute(user_data_path + "/data/")
		if error != OK: print("Error creating user://data/: " + str(error))
		else: print("Created user://data/")

	if not DirAccess.dir_exists_absolute(user_data_path + "/userdata/teams/"):
		var error = DirAccess.make_dir_recursive_absolute(user_data_path + "/userdata/teams/")
		if error != OK: print("Error creating user://userdata/teams/: " + str(error))
		else: print("Created user://userdata/teams/")

	if not DirAccess.dir_exists_absolute(TEAM_ICONS_DIR):
		var error = DirAccess.make_dir_recursive_absolute(TEAM_ICONS_DIR)
		if error != OK: print("Error creating team icons directory: " + str(error))
		else: print("Created team icons directory: " + TEAM_ICONS_DIR)

func _load_last_team_icon_path():
	print("Attempting to load last team icon path from: " + LAST_TEAM_ICON_PATH_FILE)
	# If the file doesn't exist, create it with an empty JSON object
	if not FileAccess.file_exists(LAST_TEAM_ICON_PATH_FILE):
		print("Last team icon path file not found. Creating default last_team_icon_path.json file at: " + LAST_TEAM_ICON_PATH_FILE)
		var creation_file = FileAccess.open(LAST_TEAM_ICON_PATH_FILE, FileAccess.WRITE)
		if creation_file:
			creation_file.store_string("{}")
			creation_file.close()
			print("Successfully created default last_team_icon_path.json.")
		else:
			print("Error creating default last_team_icon_path.json file.")

	var read_file = FileAccess.open(LAST_TEAM_ICON_PATH_FILE, FileAccess.READ)
	if read_file:
		var content = read_file.get_as_text()
		read_file.close()
		var data = JSON.parse_string(content)
		if data == null: # JSON parsing failed
			print("Error: Failed to parse JSON from {}. Content: '{}'".format([LAST_TEAM_ICON_PATH_FILE, content]))
			icon_path_label.text = "JSON Error"
		elif data is Dictionary and data.has("last_icon_path"):
			var path = data["last_icon_path"]
			if FileAccess.file_exists(path):
				icon_path_label.text = path
				print("Last team icon path loaded: " + path)
			else:
				icon_path_label.text = "No icon selected"
				print("Last team icon file not found at: " + path)
		else:
			icon_path_label.text = "No icon selected"
			print("Warning: Last team icon path file is empty or invalid. Parsed data type: {}. Content: '{}'".format([typeof(data), content]))
	else:
		icon_path_label.text = "No icon selected"
		print("Warning: Could not open last team icon path file for reading: {}. Error code: {}".format([LAST_TEAM_ICON_PATH_FILE, FileAccess.get_open_error()]))

func _save_last_team_icon_path(path: String):
	var data = {"last_icon_path": path}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(LAST_TEAM_ICON_PATH_FILE, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Last team icon path saved: " + path)
	else:
		print("Error: Could not save last team icon path to file: " + LAST_TEAM_ICON_PATH_FILE + " Error code: " + str(FileAccess.get_open_error()))

func _load_last_file_dialog_path() -> String:
	"""
	Load the last used file dialog path from JSON file.
	Returns the last path or desktop path as fallback.
	"""
	print("Attempting to load last file dialog path from: " + LAST_FILE_DIALOG_PATH_FILE)
	
	# If the file doesn't exist, create it with desktop path as default
	if not FileAccess.file_exists(LAST_FILE_DIALOG_PATH_FILE):
		print("Last file dialog path file not found. Creating default file.")
		var desktop_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		_save_last_file_dialog_path(desktop_path)
		return desktop_path
	
	var file = FileAccess.open(LAST_FILE_DIALOG_PATH_FILE, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data == null:
			print("Error: Failed to parse JSON from {}. Content: '{}'".format([LAST_FILE_DIALOG_PATH_FILE, content]))
			return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		elif data is Dictionary and data.has("last_dialog_path"):
			var path = data["last_dialog_path"]
			if DirAccess.dir_exists_absolute(path):
				print("Last file dialog path loaded: " + path)
				return path
			else:
				print("Last file dialog path not found: " + path + ". Using desktop.")
				var desktop_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
				_save_last_file_dialog_path(desktop_path)
				return desktop_path
		else:
			print("Warning: Last file dialog path file is empty or invalid.")
			return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	else:
		print("Warning: Could not open last file dialog path file for reading.")
		return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

func _save_last_file_dialog_path(path: String):
	"""
	Save the current file dialog path to JSON file.
	"""
	var data = {"last_dialog_path": path}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(LAST_FILE_DIALOG_PATH_FILE, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Last file dialog path saved: " + path)
	else:
		print("Error: Could not save last file dialog path to file: " + LAST_FILE_DIALOG_PATH_FILE)
		print("Error code: " + str(FileAccess.get_open_error()))

func _on_select_icon_button_pressed():
	"""
	Shows the file dialog to select a team icon.
	Uses saved path or defaults to desktop.
	"""
	# Set the initial directory from saved path or desktop
	var initial_dir = _load_last_file_dialog_path()
	file_dialog.current_dir = initial_dir
	
	file_dialog.popup_centered()
	print("File dialog opened with initial directory: " + initial_dir)

func _on_file_dialog_dir_selected(dir: String):
	# This signal is emitted when a directory is selected.
	# We are interested in file_selected, but this can be useful for debugging.
	print("File dialog directory selected: " + dir)

func _on_file_dialog_file_selected(path: String):
	"""
	Called when a file is selected in the file dialog.
	Caches the selected icon path for later saving when Save button is pressed.
	Also saves the current directory for next time.
	"""
	print("File selected in dialog: " + path)
	
	# Save the directory of the selected file for next time
	var selected_dir = path.get_base_dir()
	_save_last_file_dialog_path(selected_dir)
	
	# Cache the selected file path for later saving
	cached_icon_path = path
	
	# Update the label to show that an icon has been selected (but not yet saved)
	var file_name = path.get_file()
	icon_path_label.text = "Selected: " + file_name + " (will be saved when you press Save)"
	
	print("Icon file cached: " + path)
	_show_message_dialog("Icon Selected", "Icon file selected: " + file_name + "\nIt will be saved when you press the Save button.")


func _on_save_button_pressed():
	"""
	Collects all team data, saves it to teams.json, appending or overwriting.
	Includes data validation.
	"""
	print("Save button pressed. Collecting team data...")

	# --- Data Validation ---
	var team_id = id_input.text.strip_edges()
	if team_id.is_empty():
		_show_message_dialog("Validation Error", "Team ID cannot be empty.")
		return
	if team_name_input.text.strip_edges().is_empty():
		_show_message_dialog("Validation Error", "Team Name cannot be empty.")
		return
	
	# --- Handle icon path ---
	var final_icon_path = ""
	if not cached_icon_path.is_empty():
		# A new icon was selected, copy it to the team_icons folder
		var dest_path = TEAM_ICONS_DIR.path_join(team_id + "." + cached_icon_path.get_extension())
		var err = DirAccess.copy_absolute(cached_icon_path, dest_path)
		if err == OK:
			final_icon_path = dest_path
			cached_icon_path = "" # Clear cache after successful copy
			icon_path_label.text = final_icon_path # Update label to show final path
			_save_last_team_icon_path(final_icon_path)
		else:
			_show_message_dialog("Error", "Could not copy icon file. Error: " + str(err))
			return
	elif not icon_path_label.text.strip_edges().is_empty() and icon_path_label.text != "No icon selected":
		# Use the existing path from the label if no new one is cached
		final_icon_path = icon_path_label.text
	else:
		# No new icon selected and no existing path in the label
		_show_message_dialog("Validation Error", "Please select an icon for the team.")
		return

	# --- Prepare Team Data ---
	var new_team_data = {
		"id": team_id,
		"name": team_name_input.text.strip_edges(),
		"icon_path": final_icon_path,
		"members": [],
		"captain": null,
		"balance": 200, # Default value
		"score": 0,     # Default value
		"rank": null    # Will be calculated by scoreboard
	}

	# --- Populate Members, Captain, and calculate totals from players.json ---
	var all_players = _load_all_players()
	var members = []
	var captain_name = null
	var team_total_score = 0
	var team_total_money_taken = 0
	
	for player in all_players:
		if player.get("team_id") == team_id:
			members.append(player.get("id"))
			if player.get("is_leader", false):
				captain_name = player.get("name")
			
			# 从选手的 stats 累计队伍总分和总取钱
			var player_stats = player.get("stats", {})
			team_total_score += player_stats.get("score", 0)
			team_total_money_taken += player_stats.get("money_taken", 0)
	
	new_team_data["members"] = members
	new_team_data["captain"] = captain_name
	
	# 根据选手 stats 计算队伍余额和分数
	new_team_data["score"] = team_total_score
	new_team_data["balance"] = 200 - team_total_money_taken  # 初始余额200减去总取钱

	# --- Read, Update, and Write teams.json ---
	var teams = []
	var file = FileAccess.open(TEAMS_DATA_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if not content.is_empty():
			var parse_result = JSON.parse_string(content)
			if parse_result is Array:
				teams = parse_result
			else:
				print("Warning: teams.json is not a valid JSON array. Starting with a new list.")

	# Check if team with same ID exists
	var found_index = -1
	for i in range(teams.size()):
		if teams[i].has("id") and teams[i]["id"] == team_id:
			found_index = i
			break

	if found_index != -1:
		# Overwrite existing team. 队伍的余额和分数现在从选手stats计算，不保留旧值
		teams[found_index] = new_team_data
		print("Overwriting team with ID: " + team_id + " (Score: " + str(team_total_score) + ", Balance: " + str(new_team_data["balance"]) + ")")
	else:
		# Append new team
		teams.append(new_team_data)
		print("Appending new team with ID: " + team_id + " (Score: " + str(team_total_score) + ", Balance: " + str(new_team_data["balance"]) + ")")

	# Write updated array back to file
	var json_string = JSON.stringify(teams, "	")
	file = FileAccess.open(TEAMS_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		_show_message_dialog("Success", "Team data saved successfully!")
		emit_signal("teams_data_saved") # Notify scoreboard
	else:
		_show_message_dialog("Error", "Failed to write to teams.json. Error: " + str(FileAccess.get_open_error()))


func _load_all_players() -> Array:
	var PLAYERS_DATA_PATH = user_data_path + "/userdata/players/players.json"
	var players = []
	if not FileAccess.file_exists(PLAYERS_DATA_PATH):
		print("Warning: players.json not found. Cannot populate team members.")
		return players
	
	var file = FileAccess.open(PLAYERS_DATA_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		if not content.is_empty():
			var parse_result = JSON.parse_string(content)
			if parse_result is Array:
				players = parse_result
			else:
				print("Warning: players.json is not a valid JSON array.")
	return players

func _show_message_dialog(title: String, message: String):
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered_ratio(0.3) # Use ratio for better sizing and centering relative to parent