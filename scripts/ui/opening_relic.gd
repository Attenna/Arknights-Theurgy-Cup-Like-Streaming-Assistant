extends Label

var current_player_data_path: String
var relics_data_path: String
var relics_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 初始化路径变量
	current_player_data_path = AppData.get_exe_dir() + "/userdata/players/current_player.json"
	relics_data_path = AppData.get_exe_dir() + "/data/relics.json"
	
	# 加载藏品数据
	_load_relics_data()
	
	# Connect to signals that indicate player data has changed.
	_connect_to_player_signals()
	
	# Initial load of the current player's data to set the display.
	var initial_player_data = _load_current_player_data()
	_update_relic_display(initial_player_data)


# --- Signal Connection ---

func _connect_to_player_signals() -> void:
	"""Connects to player-related signals after a short delay."""
	call_deferred("_delayed_connect_to_signals")

func _delayed_connect_to_signals() -> void:
	"""
	Waits for the scene tree to be ready, then connects to signals from
	the player selection UI and player editors.
	"""
	var connected_count = 0
	
	# Find the 'now_player.gd' node and connect to its 'player_selected' signal.
	var now_player_nodes = _find_nodes_with_script("now_player.gd")
	for node in now_player_nodes:
		if node.has_signal("player_selected"):
			if not node.player_selected.is_connected(_on_player_selected):
				node.player_selected.connect(_on_player_selected)
				print("Relic Label: Connected to player_selected signal from: " + node.name)
				connected_count += 1
	
	# Connect to the 'player_data_updated' signal from editors.
	var editor_nodes = get_tree().get_nodes_in_group("player_editors")
	for editor in editor_nodes:
		if editor.has_signal("player_data_updated"):
			if not editor.player_data_updated.is_connected(_on_player_data_updated):
				editor.player_data_updated.connect(_on_player_data_updated)
				print("Relic Label: Connected to player_data_updated signal from: " + editor.name)
				connected_count += 1
	
	if connected_count == 0:
		print("Relic Label Warning: Could not find any player-related signals to connect.")


# --- Signal Handlers ---

func _on_player_selected(player_data: Dictionary) -> void:
	"""Handles the player_selected signal."""
	print("Relic Label: Received player_selected signal.")
	_update_relic_display(player_data)

func _on_player_data_updated() -> void:
	"""Handles the player_data_updated signal."""
	print("Relic Label: Received player_data_updated signal.")
	var player_data = _load_current_player_data()
	_update_relic_display(player_data)


# --- Data and UI Logic ---

func _load_relics_data() -> void:
	"""从 relics.json 文件加载藏品数据"""
	print("Loading relics data from: " + relics_data_path)
	
	if not FileAccess.file_exists(relics_data_path):
		print("Relic Label Warning: relics.json file not found at: " + relics_data_path)
		relics_data = {}
		return
	
	var file = FileAccess.open(relics_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			print("Relic Label Error: Failed to parse relics.json")
			relics_data = {}
		elif data is Dictionary:
			relics_data = data
			print("Loaded relics data with " + str(relics_data.size()) + " entries")
		elif data is Array:
			# 如果是数组格式，转换为字典（以 id 或 name 为键）
			relics_data = {}
			for relic in data:
				if relic is Dictionary:
					var relic_key = relic.get("id", relic.get("name", ""))
					if not relic_key.is_empty():
						relics_data[relic_key] = relic
			print("Converted relics array to dictionary with " + str(relics_data.size()) + " entries")
		else:
			print("Relic Label Error: Invalid relics.json format")
			relics_data = {}
	else:
		print("Relic Label Error: Could not open relics.json file")
		relics_data = {}

func _load_current_player_data() -> Dictionary:
	"""Loads the current player data from the JSON file."""
	if not FileAccess.file_exists(current_player_data_path):
		print("Relic Label: Current player data file not found.")
		return {}
	
	var file = FileAccess.open(current_player_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var data = JSON.parse_string(content)
		if data is Dictionary:
			return data
		else:
			print("Relic Label: Error parsing current player JSON or invalid format.")
			return {}
	else:
		print("Relic Label: Error opening current player data file.")
		return {}

func _update_relic_display(player_data: Dictionary) -> void:
	"""Updates the label's text with the player's chosen relic."""
	if player_data.is_empty():
		self.text = "未选择藏品"
		print("Relic Label: No player data available")
		return

	var relic_choice = player_data.get("starting_relic_choice", "")
	if relic_choice.is_empty():
		self.text = "未选择藏品"
		print("Relic Label: Player has not selected a starting relic.")
		return
	
	# 尝试从藏品数据中获取详细信息
	var relic_info = relics_data.get(relic_choice, {})
	
	if not relic_info.is_empty():
		# 如果找到藏品详细信息，显示藏品名称和描述
		var relic_name = relic_info.get("name", relic_choice)
		var relic_description = relic_info.get("description", "")
		var relic_rarity = relic_info.get("rarity", "")
		
		# 构建显示文本
		var display_text = "藏品：" + relic_name
		
		if not relic_rarity.is_empty():
			display_text += " [" + relic_rarity + "]"
		
		self.text = display_text
		
		# 如果有描述，可以考虑设置为提示文本（tooltip）
		if not relic_description.is_empty():
			self.tooltip_text = relic_description
		
		print("Relic Label updated to: " + relic_name + " (ID: " + relic_choice + ")")
	else:
		# 如果没有找到详细信息，只显示原始选择
		self.text = "藏品：" + relic_choice
		self.tooltip_text = ""
		print("Relic Label updated to: " + relic_choice + " (no detailed info found)")
	
	# 调试信息：显示当前选手的藏品相关数据
	_debug_relic_info(player_data)


# --- Utility Functions ---

func _debug_relic_info(player_data: Dictionary) -> void:
	"""调试函数：打印藏品相关信息"""
	print("--- Relic Debug Info ---")
	print("  Player ID: " + str(player_data.get("id", "Unknown")))
	print("  Player Name: " + str(player_data.get("name", "Unknown")))
	print("  Selected Relic: " + str(player_data.get("starting_relic_choice", "None")))
	print("  Relics Data Loaded: " + str(relics_data.size()) + " entries")
	
	if relics_data.size() > 0:
		print("  Available Relics: " + str(relics_data.keys()))

func _find_nodes_with_script(script_name: String) -> Array:
	"""Finds all nodes in the scene tree with a specific script attached."""
	var result = []
	_search_nodes_recursive(get_tree().root, script_name, result)
	return result

func _search_nodes_recursive(node: Node, script_name: String, result: Array) -> void:
	"""Recursively searches the scene tree for nodes with the specified script."""
	if node.get_script() and node.get_script().resource_path.ends_with(script_name):
		result.append(node)
	
	for child in node.get_children():
		_search_nodes_recursive(child, script_name, result)
