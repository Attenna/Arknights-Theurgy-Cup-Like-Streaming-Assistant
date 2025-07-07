extends VBoxContainer

@onready var date_input: LineEdit = $DateInput
@onready var date_input_button: Button = $DateInputButton
@onready var date_label: Label = $DateInputLabel

var user_data_path: String = AppData.get_exe_dir()

var settings_path: String = user_data_path + "/userdata/settings.json"
var current_settings: Dictionary = {}

# Signal emitted when settings are changed
signal settings_changed(new_settings: Dictionary)

func _ready() -> void:
	# Connect button signal
	date_input_button.pressed.connect(_on_date_input_button_pressed)
	
	# Load current settings
	_load_settings()
	
	# Update UI with current game_date
	_update_ui()

func _load_settings() -> void:
	"""Load settings from JSON file"""
	print("Loading settings from: " + settings_path)
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(user_data_path + "/userdata/"):
		var error = DirAccess.make_dir_recursive_absolute(user_data_path + "/userdata/")
		if error != OK:
			print("Error creating userdata directory: " + str(error))
	
	# If file doesn't exist, create default settings
	if not FileAccess.file_exists(settings_path):
		print("Settings file not found. Creating default settings.")
		current_settings = {
			"app_version": "1.0.0",
			"game_date": "1",
			"last_stream_time": ""
		}
		_save_settings()
		return
	
	# Load existing settings
	var file = FileAccess.open(settings_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		
		if data == null:
			print("Error: Failed to parse settings JSON. Using default settings.")
			current_settings = {
				"app_version": "1.0.0",
				"game_date": "1",
				"last_stream_time": ""
			}
		elif data is Dictionary:
			current_settings = data
			print("Settings loaded successfully: " + str(current_settings))
		else:
			print("Error: Settings file is not a valid JSON object. Using default settings.")
			current_settings = {
				"app_version": "1.0.0",
				"game_date": "1",
				"last_stream_time": ""
			}
	else:
		print("Error: Could not open settings file for reading. Using default settings.")
		current_settings = {
			"app_version": "1.0.0",
			"game_date": "1", 
			"last_stream_time": ""
		}

func _save_settings() -> void:
	"""Save settings to JSON file"""
	var json_string = JSON.stringify(current_settings, "\t")
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("Settings saved successfully: " + str(current_settings))
	else:
		print("Error: Could not save settings to file: " + settings_path)
		print("Error code: " + str(FileAccess.get_open_error()))

func _update_ui() -> void:
	"""Update UI elements with current game_date"""
	if current_settings.has("game_date"):
		var game_date = current_settings["game_date"]
		date_input.text = str(game_date)
		date_label.text = "Current Game Date: " + str(game_date)
	else:
		date_input.text = "1"
		date_label.text = "Current Game Date: 1"

func _on_date_input_button_pressed() -> void:
	"""Handle button press to update game_date"""
	var new_date = date_input.text.strip_edges()
	
	# Validate input
	if new_date.is_empty():
		_show_message_dialog("Validation Error", "Game date cannot be empty.")
		return
	
	# Check if it's a valid number (optional validation)
	if not new_date.is_valid_int() and not new_date.is_valid_float():
		_show_message_dialog("Validation Error", "Game date must be a valid number.")
		return
	
	# Update settings
	var old_date = current_settings.get("game_date", "1")
	current_settings["game_date"] = new_date
	
	# Save to file
	_save_settings()
	
	# Update UI
	_update_ui()
	
	# Emit signal
	settings_changed.emit(current_settings)
	
	# Show success message
	_show_message_dialog("Success", "Game date updated from '" + str(old_date) + "' to '" + new_date + "'")
	
	print("Game date changed from '" + str(old_date) + "' to '" + new_date + "'")

func get_current_game_date() -> String:
	"""Get the current game date"""
	return current_settings.get("game_date", "1")

func set_game_date(new_date: String) -> void:
	"""Set the game date programmatically"""
	current_settings["game_date"] = new_date
	_save_settings()
	_update_ui()
	settings_changed.emit(current_settings)

func _show_message_dialog(title: String, message: String):
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered_ratio(0.3) # Use ratio for better sizing and centering relative to parent
