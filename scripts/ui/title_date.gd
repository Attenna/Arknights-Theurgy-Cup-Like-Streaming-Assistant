extends Label

var settings_path: String

func _ready() -> void:
	# 初始化路径变量
	settings_path = AppData.get_exe_dir() + "/userdata/settings.json"
	
	# Load and display initial game date
	_load_and_display_game_date()
	
	# Try to find and connect to the date component that emits settings_changed signal
	_connect_to_date_component()

func _connect_to_date_component() -> void:
	"""Try to find the date component and connect to its settings_changed signal"""
	# Look for the date component in the scene tree
	# This assumes the date component is somewhere in the scene tree
	var date_component = _find_date_component(get_tree().current_scene)
	
	if date_component and date_component.has_signal("settings_changed"):
		if not date_component.settings_changed.is_connected(_on_settings_changed):
			date_component.settings_changed.connect(_on_settings_changed)
			print("Successfully connected to date component's settings_changed signal")
	else:
		print("Date component not found or doesn't have settings_changed signal")
		# Use a timer to retry connection periodically
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.timeout.connect(_retry_connection)
		add_child(timer)
		timer.start()

func _retry_connection() -> void:
	"""Retry connecting to date component"""
	var date_component = _find_date_component(get_tree().current_scene)
	if date_component and date_component.has_signal("settings_changed"):
		if not date_component.settings_changed.is_connected(_on_settings_changed):
			date_component.settings_changed.connect(_on_settings_changed)
			print("Successfully connected to date component's settings_changed signal (retry)")
			# Remove the timer since we're connected now
			for child in get_children():
				if child is Timer:
					child.queue_free()

func _find_date_component(node: Node) -> Node:
	"""Recursively search for a node that has the settings_changed signal"""
	if node.has_signal("settings_changed"):
		return node
	
	for child in node.get_children():
		var result = _find_date_component(child)
		if result:
			return result
	
	return null

func _on_settings_changed(new_settings: Dictionary) -> void:
	"""Handle settings_changed signal from date component"""
	print("Received settings_changed signal: " + str(new_settings))
	
	if new_settings.has("game_date"):
		var game_date = new_settings["game_date"]
		_display_game_date(game_date)
	else:
		print("Warning: settings_changed signal received but no game_date found")

func _load_and_display_game_date() -> void:
	"""Load game date from settings file and display it"""
	var game_date = _load_game_date_from_file()
	_display_game_date(game_date)

func _load_game_date_from_file() -> String:
	"""Load game_date from settings.json file"""
	print("Loading game date from: " + settings_path)
	
	if not FileAccess.file_exists(settings_path):
		print("Settings file not found, using default game date: 1")
		return "1"
	
	var file = FileAccess.open(settings_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		
		if data == null:
			print("Error: Failed to parse settings JSON, using default game date: 1")
			return "1"
		elif data is Dictionary and data.has("game_date"):
			var game_date = str(data["game_date"])
			print("Game date loaded from file: " + game_date)
			return game_date
		else:
			print("Error: Invalid settings format or no game_date found, using default: 1")
			return "1"
	else:
		print("Error: Could not open settings file, using default game date: 1")
		return "1"

func _display_game_date(game_date: String) -> void:
	"""Display the game date in the label"""
	text = "冷水坑#2 Day" + game_date
	print("Displaying game date: " + text)

func update_display() -> void:
	"""Public method to manually update the display"""
	_load_and_display_game_date()
