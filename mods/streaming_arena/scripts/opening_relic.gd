extends Label

var current_player_data_path: String
var relics_data_path: String
var relics_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 初始化路径变量
	current_player_data_path = AppData.get_user_dir() + "/userdata/players/current_player.json"
	relics_data_path = AppData.get_exe_dir() + "/data/relics.json"
	
	# 加载藏品数据
	_load_relics_data()

	# 订阅内核契约事件（铁律1/2/3：插件协作只走 EventBus，服务经 PluginContext 获取）
	var ctx := PluginContext.for_node(self)
	if ctx.event_bus:
		ctx.event_bus.subscribe(EventCatalog.PLAYER_CHANGED, _on_player_selected, &"streaming_arena")
		ctx.event_bus.subscribe(EventCatalog.DATA_RELOADED, func(_p: Dictionary) -> void: _on_player_data_updated(), &"streaming_arena")

	# Initial load of the current player's data to set the display.
	var initial_player_data = _load_current_player_data()
	_update_relic_display(initial_player_data)


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

	var relic_choice = player_data.get(DataKeys.PLAYER_STARTING_RELIC_CHOICE, "")
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
	print("  Player ID: " + str(player_data.get(DataKeys.PLAYER_ID, "Unknown")))
	print("  Player Name: " + str(player_data.get(DataKeys.PLAYER_NAME, "Unknown")))
	print("  Selected Relic: " + str(player_data.get(DataKeys.PLAYER_STARTING_RELIC_CHOICE, "None")))
	print("  Relics Data Loaded: " + str(relics_data.size()) + " entries")
	
	if relics_data.size() > 0:
		print("  Available Relics: " + str(relics_data.keys()))
