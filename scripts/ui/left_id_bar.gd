extends Control

var user_data_path: String = AppData.get_exe_dir()

# 文件路径
var CURRENT_PLAYER_DATA_PATH = user_data_path + "/userdata/players/current_player.json"

# 数据存储
var current_player_data: Dictionary = {}

# UI节点引用
@onready var player_icon: TextureRect = get_node_or_null("Player/PlayerIcon")
@onready var player_name: Label = get_node_or_null("Player/PlayerName")
@onready var team_icon: TextureRect = get_node_or_null("Team/TeamIcon")
@onready var team_id: Label = get_node_or_null("Team/TeamID")
@onready var operator_icon: TextureRect = get_node_or_null("OpeningOperator/OperatorIcon")
@onready var operator_name: Label = get_node_or_null("OpeningOperator/OperatorName")
@onready var squad_icon: TextureRect = get_node_or_null("OpeningSquad/SquadIcon")
@onready var squad_name: Label = get_node_or_null("OpeningSquad/SquadName")

func _ready() -> void:
	# 连接到选手数据更新信号
	_connect_to_player_signals()
	
	# 初始加载当前选手数据
	_load_current_player_data()
	
	# 更新UI显示
	_update_ui_display()

func _connect_to_player_signals() -> void:
	"""连接到选手相关的信号"""
	# 延迟连接，确保所有节点都已准备好
	call_deferred("_delayed_connect_to_signals")

func _delayed_connect_to_signals() -> void:
	"""延迟连接到相关信号"""
	var connected_count = 0
	
	# 查找 now_player 节点并连接其信号
	var now_player_nodes = _find_nodes_with_script("now_player.gd")
	for node in now_player_nodes:
		if node.has_signal("player_selected"):
			if not node.player_selected.is_connected(_on_player_selected):
				node.player_selected.connect(_on_player_selected)
				print("Connected to player_selected signal from: " + node.name)
				connected_count += 1
	
	# 也可以连接到编辑器的更新信号
	var editor_nodes = get_tree().get_nodes_in_group("player_editors")
	for editor in editor_nodes:
		if editor.has_signal("player_data_updated"):
			if not editor.player_data_updated.is_connected(_on_player_data_updated):
				editor.player_data_updated.connect(_on_player_data_updated)
				print("Connected to player_data_updated signal from: " + editor.name)
				connected_count += 1
	
	if connected_count > 0:
		print("Successfully connected to " + str(connected_count) + " player signal(s)")
	else:
		print("Warning: Could not find player-related signals to connect")

func _find_nodes_with_script(script_name: String) -> Array:
	"""查找具有指定脚本的节点"""
	var result = []
	_search_nodes_recursive(get_tree().root, script_name, result)
	return result

func _search_nodes_recursive(node: Node, script_name: String, result: Array) -> void:
	"""递归搜索节点"""
	if node.get_script():
		var script_path = node.get_script().resource_path
		if script_path.ends_with(script_name):
			result.append(node)
	
	for child in node.get_children():
		_search_nodes_recursive(child, script_name, result)

func _on_player_selected(player_data: Dictionary) -> void:
	"""处理选手选择信号"""
	print("🎯 接收到选手选择信号，更新左侧ID栏...")
	current_player_data = player_data
	_update_ui_display()

func _on_player_data_updated() -> void:
	"""处理选手数据更新信号"""
	print("🔄 接收到选手数据更新信号，重新加载当前选手...")
	_load_current_player_data()
	_update_ui_display()

func _load_current_player_data() -> void:
	"""从current_player.json加载当前选手数据"""
	print("Loading current player data from: " + CURRENT_PLAYER_DATA_PATH)
	
	if not FileAccess.file_exists(CURRENT_PLAYER_DATA_PATH):
		print("Current player data file not found")
		current_player_data = {}
		return
	
	var file = FileAccess.open(CURRENT_PLAYER_DATA_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			print("Error: Failed to parse current player JSON")
			current_player_data = {}
		elif data is Dictionary:
			current_player_data = data
			print("Loaded current player data: " + str(data.get("id", "Unknown")))
		else:
			print("Error: Invalid current player data format")
			current_player_data = {}
	else:
		print("Error: Could not open current player data file")
		current_player_data = {}

func _update_ui_display() -> void:
	"""更新UI显示"""
	print("Updating left ID bar UI display...")
	
	# 调试当前选手数据
	debug_current_player_data()
	
	if current_player_data.is_empty():
		_clear_ui_display()
		return
	
	# 更新选手信息
	_update_player_info()
	
	# 更新队伍信息
	_update_team_info()
	
	# 更新开局干员信息
	_update_operator_info()
	
	# 更新开局分队信息
	_update_squad_info()
	
	print("Left ID bar UI updated successfully")

func _clear_ui_display() -> void:
	"""清空UI显示"""
	print("Clearing left ID bar display")
	
	if player_name:
		player_name.text = "未选择选手"
	
	if team_id:
		team_id.text = "未选择队伍"
	
	if operator_name:
		operator_name.text = "未选择干员"
	
	if squad_name:
		squad_name.text = "未选择分队"
	
	# 清空图标
	if player_icon:
		player_icon.texture = null
	
	if team_icon:
		team_icon.texture = null
	
	if operator_icon:
		operator_icon.texture = null
	
	if squad_icon:
		squad_icon.texture = null

func _update_player_info() -> void:
	"""更新选手信息"""
	var player_name_str = current_player_data.get("name", "")
	
	# 更新选手姓名
	if player_name:
		if not player_name_str.is_empty():
			player_name.text = player_name_str
		else:
			player_name.text = "Unknown Player"
	
	# 更新选手头像 - 按照新规范：/userdata/players/player_icons/{选手名字}.jpg
	if player_icon:
		if not player_name_str.is_empty():
			var player_icon_path = AppData.get_exe_dir() + "/userdata/players/player_icons/" + player_name_str + ".jpg"
			print("Attempting to load player icon from: " + player_icon_path)
			
			# 检查文件是否存在
			if not FileAccess.file_exists(player_icon_path):
				print("Player icon file does not exist: " + player_icon_path)
				player_icon.texture = null
				return
			
			var texture = _load_texture_from_path(player_icon_path)
			if texture:
				player_icon.texture = texture
				print("Player icon loaded successfully: " + player_icon_path)
			else:
				player_icon.texture = null
				print("Failed to load player icon texture: " + player_icon_path)
		else:
			player_icon.texture = null
			print("No player name specified for icon loading")

func _update_team_info() -> void:
	"""更新队伍信息"""
	var team_id_str = current_player_data.get("team_id", "")
	
	# 更新队伍名称
	if team_id:
		if not team_id_str.is_empty():
			team_id.text = team_id_str
		else:
			team_id.text = "Unknown Team"
	
	# 加载队伍图标 - 按照新规范：/userdata/teams/team_icons/{队伍ID}.jpg
	if team_icon and not team_id_str.is_empty():
		var team_icon_path = AppData.get_exe_dir() + "/userdata/teams/team_icons/" + team_id_str + ".jpg"
		print("Attempting to load team icon from: " + team_icon_path)
		
		var texture = _load_texture_from_path(team_icon_path)
		if texture:
			team_icon.texture = texture
			print("Team icon loaded: " + team_icon_path)
		else:
			team_icon.texture = null
			print("Failed to load team icon: " + team_icon_path)
	elif team_icon:
		team_icon.texture = null

func _update_operator_info() -> void:
	"""更新开局干员信息"""
	var operator_choice = current_player_data.get("starting_operator_choice", "")
	
	# 更新干员名称
	if operator_name:
		if not operator_choice.is_empty():
			operator_name.text = operator_choice
		else:
			operator_name.text = "Unknown Operator"
	
	# 加载干员图标 - 按照新规范：data/operators/{星级}/头像_{干员名}.png
	if operator_icon and not operator_choice.is_empty():
		var operator_icon_path = _get_operator_icon_path(operator_choice)
		var texture = _load_texture_from_path(operator_icon_path)
		if texture:
			operator_icon.texture = texture
			print("Operator icon loaded: " + operator_icon_path)
		else:
			operator_icon.texture = null
			print("Failed to load operator icon: " + operator_icon_path)
	elif operator_icon:
		operator_icon.texture = null

func _update_squad_info() -> void:
	"""更新开局分队信息"""
	var squad_choice = current_player_data.get("starting_squad_choice", "")
	
	# 更新分队名称
	if squad_name:
		if not squad_choice.is_empty():
			squad_name.text = squad_choice
		else:
			squad_name.text = "Unknown Squad"
	
	# 加载分队图标 - 按照新规范：data/squads/{分队名}.png
	if squad_icon and not squad_choice.is_empty():
		var squad_icon_path = AppData.get_exe_dir() + "/data/squads/" + squad_choice + ".png"
		print("Attempting to load squad icon from: " + squad_icon_path)
		
		var texture = _load_texture_from_path(squad_icon_path)
		if texture:
			squad_icon.texture = texture
			print("Squad icon loaded: " + squad_icon_path)
		else:
			squad_icon.texture = null
			print("Failed to load squad icon: " + squad_icon_path)
	elif squad_icon:
		squad_icon.texture = null

func _load_texture_from_path(path: String) -> Texture2D:
	"""
	从指定路径加载纹理。
	此方法经过简化，以提高稳定性和兼容性。
	它能处理 res:// 和 user:// 跂径。
	"""
	if path.is_empty():
		print("Texture path is empty, cannot load.")
		return null

	# 首先检查文件是否存在，这是一个基本的健全性检查
	if not FileAccess.file_exists(path):
		print("Texture file does not exist at path: " + path)
		return null

	# 对于 res:// 路径，Godot的 `load` 函数是最高效、最可靠的方法
	if path.begins_with("res://"):
		var texture = load(path)
		if texture is Texture2D:
			print("Successfully loaded texture from res:// path: " + path)
			return texture
		else:
			print("Failed to load texture from res:// path, or it's not a Texture2D: " + path)
			return null

	# 对于 user:// 或其他绝对路径，使用 Image.load()
	# 这是在运行时加载非项目内部图像的标准方法
	var image = Image.new()
	var error = image.load(path)

	# 如果常规加载失败，特别是出现“文件损坏”或“格式无法识别”的错误时，
	# 启动备用加载方案。这通常是因为文件扩展名与实际内容不匹配。
	if error != OK:
		print("Initial image load failed for: " + path + ". Error: " + _get_error_description(error))
		print("Attempting fallback loading methods...")
		
		# 从文件读取原始字节数据
		var file_bytes = FileAccess.get_file_as_bytes(path)
		
		if file_bytes.is_empty():
			print("Failed to read file bytes for fallback loading.")
			return null
		
		# 尝试作为PNG、JPG、WebP等常见格式加载
		# Godot会根据内容的“魔数”（magic number）来识别格式
		error = image.load_png_from_buffer(file_bytes)
		if error == OK:
			print("Fallback success: Loaded as PNG from buffer.")
		else:
			error = image.load_jpg_from_buffer(file_bytes)
			if error == OK:
				print("Fallback success: Loaded as JPG from buffer.")
			else:
				error = image.load_webp_from_buffer(file_bytes)
				if error == OK:
					print("Fallback success: Loaded as WebP from buffer.")

	if error != OK:
		# 使用现有的错误描述函数来提供更清晰的日志
		print("Error loading image from path: " + path)
		print("  Error Code: " + str(error))
		print("  Description: " + _get_error_description(error))
		return null

	# 检查图像加载后是否为空
	if image.is_empty():
		print("Image data is empty after loading from path: " + path)
		return null

	# 从加载的 Image 数据创建 ImageTexture
	var image_texture = ImageTexture.create_from_image(image)
	if image_texture:
		print("Successfully created texture from image at path: " + path)
		return image_texture
	else:
		print("Failed to create ImageTexture from image at path: " + path)
		return null

func _get_error_description(error_code: int) -> String:
	"""获取错误代码的描述"""
	match error_code:
		ERR_FILE_NOT_FOUND:
			return "File not found"
		ERR_FILE_BAD_DRIVE:
			return "Bad drive"
		ERR_FILE_BAD_PATH:
			return "Bad path"
		ERR_FILE_NO_PERMISSION:
			return "No permission"
		ERR_FILE_ALREADY_IN_USE:
			return "File already in use"
		ERR_FILE_CANT_OPEN:
			return "Cannot open file"
		ERR_FILE_CANT_WRITE:
			return "Cannot write to file"
		ERR_FILE_CANT_READ:
			return "Cannot read from file"
		ERR_FILE_UNRECOGNIZED:
			return "Unrecognized file format"
		ERR_FILE_CORRUPT:
			return "File is corrupted"
		ERR_FILE_MISSING_DEPENDENCIES:
			return "Missing dependencies"
		ERR_FILE_EOF:
			return "Unexpected end of file"
		_:
			return "Unknown error"

# 图标路径获取方法

func _get_operator_icon_path(op_name: String) -> String:
	"""获取干员头像路径 - 按照新规范：data/operators/{星级}/头像_{干员名}.png"""
	if op_name.is_empty():
		return ""
	
	# 首先需要确定干员的星级
	var star_level = _get_operator_star_level(op_name)
	if star_level == 0:
		print("Warning: Could not determine star level for operator: " + op_name)
		# 如果无法确定星级，尝试在所有可能的星级目录中查找
		var possible_stars = [5, 6, 4, 3]  # 按常见程度排序
		for star in possible_stars:
			var path = AppData.get_exe_dir() + "/data/operators/" + str(star) + "/头像_" + op_name + ".png"
			if FileAccess.file_exists(path):
				print("Found operator icon at: " + path)
				return path
		return ""
	
	# 根据星级构建路径
	var icon_path = AppData.get_exe_dir() + "/data/operators/" + str(star_level) + "/头像_" + op_name + ".png"
	print("Operator icon path: " + icon_path)
	return icon_path

func _get_operator_star_level(op_name: String) -> int:
	"""获取干员的星级"""
	if op_name.is_empty():
		return 0
	
	# 尝试在各个星级的namelist文件中查找干员
	var possible_stars = [5, 6, 4, 3]  # 按常见程度排序
	
	for star in possible_stars:
		var namelist_path = AppData.get_exe_dir() + "/data/operators/" + str(star) + "_star_namelist.json"
		if FileAccess.file_exists(namelist_path):
			var file = FileAccess.open(namelist_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				
				var data = JSON.parse_string(content)
				if data is Array:
					for operator in data:
						if str(operator) == op_name:
							print("Found operator " + op_name + " in " + str(star) + " star list")
							return star
	
	print("Warning: Operator " + op_name + " not found in any star list")
	return 0  # 未找到


func debug_current_player_data() -> void:
	"""打印当前选手数据的调试信息"""
	print("--- Debugging Current Player Data ---")
	print("  文件路径: " + CURRENT_PLAYER_DATA_PATH)
	print("  文件存在: " + str(FileAccess.file_exists(CURRENT_PLAYER_DATA_PATH)))
	
	if current_player_data.is_empty():
		print("  ⚠️ current_player_data 为空")
		return
	
	print("  📋 选手数据内容:")
	for key in current_player_data:
		var value = current_player_data[key]
		print("    " + key + ": " + str(value))
		
		# 如果是图标路径，检查文件是否存在
		if key == "icon_path" and value is String:
			var icon_path = value as String
			if not icon_path.is_empty():
				print("      文件存在: " + str(FileAccess.file_exists(icon_path)))
				if FileAccess.file_exists(icon_path):
					var file = FileAccess.open(icon_path, FileAccess.READ)
					if file:
						print("      文件大小: " + str(file.get_length()) + " 字节")
						file.close()
