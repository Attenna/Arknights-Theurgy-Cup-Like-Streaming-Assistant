# player_info.gd
extends Control

# UI Node References - 根据新的场景结构调整
@onready var player_name_value: Label = get_node_or_null("PlayerName")
@onready var team_name_value: Label = get_node_or_null("Team")
@onready var squad_value: Label = get_node_or_null("Squad")
@onready var relic_value: Label = get_node_or_null("Relic")
@onready var operator_value: Label = get_node_or_null("Operator")
@onready var slogan_value: Label = get_node_or_null("Slogan")
@onready var player_avatar: TextureRect = get_node_or_null("PlayerIcon")
@onready var operator_portrait: TextureRect = get_node_or_null("OperatorPortrait")

# 当前选手数据
var current_player_data: Dictionary = {}

# 文件路径
var players_data_path: String
var current_player_data_path: String
const DEFAULT_AVATAR_PATH = "res://assets/textures/default_avatar.png"

func _ready() -> void:
	# 初始化路径变量
	players_data_path = AppData.get_exe_dir() + "/userdata/players/players.json"
	current_player_data_path = AppData.get_exe_dir() + "/userdata/players/current_player.json"
	
	print("PlayerInfo: 初始化候场选手信息显示")
	
	# 检查节点是否正确获取
	_validate_ui_nodes()
	
	# 从缓存加载当前选手数据
	_load_current_player_from_cache()
	
	# 连接到 now_player 节点的信号（用于实时更新）
	_connect_to_now_player()
	
	# 更新显示
	_update_player_display()

func _validate_ui_nodes() -> void:
	"""验证UI节点是否正确获取"""
	var missing_nodes = []
	
	if not player_name_value: missing_nodes.append("PlayerName")
	if not team_name_value: missing_nodes.append("Team")
	if not squad_value: missing_nodes.append("Squad")
	if not relic_value: missing_nodes.append("Relic")
	if not operator_value: missing_nodes.append("Operator")
	if not slogan_value: missing_nodes.append("Slogan")
	if not player_avatar: missing_nodes.append("PlayerIcon")
	if not operator_portrait: missing_nodes.append("OperatorPortrait")
	
	if missing_nodes.size() > 0:
		print("PlayerInfo: Warning - Missing UI nodes: ", missing_nodes)
	else:
		print("PlayerInfo: All UI nodes found successfully")

func _load_current_player_from_cache() -> void:
	"""从current_player.json加载当前选手数据"""
	print("PlayerInfo: 加载当前选手缓存...")
	
	if not FileAccess.file_exists(current_player_data_path):
		print("PlayerInfo: 当前选手缓存文件不存在")
		current_player_data = {}
		return
	
	var file = FileAccess.open(current_player_data_path, FileAccess.READ)
	if not file:
		print("PlayerInfo: 无法打开当前选手缓存文件")
		current_player_data = {}
		return
	
	var content = file.get_as_text()
	file.close()
	
	if content.is_empty():
		print("PlayerInfo: 当前选手缓存文件为空")
		current_player_data = {}
		return
	
	var data = JSON.parse_string(content)
	if data == null:
		print("PlayerInfo: 当前选手缓存JSON解析失败")
		current_player_data = {}
		return
	
	if data is Dictionary:
		current_player_data = data
		print("PlayerInfo: 成功加载当前选手: ", current_player_data.get("name", "Unknown"))
	else:
		print("PlayerInfo: 当前选手缓存数据格式不正确")
		current_player_data = {}

func _connect_to_now_player() -> void:
	# 尝试通过不同方式找到 now_player 节点
	var now_player_node = null
	
	# 方法1: 通过组查找
	var now_player_nodes = get_tree().get_nodes_in_group("now_player")
	if now_player_nodes.size() > 0:
		now_player_node = now_player_nodes[0]
		print("PlayerInfo: Found now_player via group")
	
	# 方法2: 通过路径查找（如果方法1失败）
	if not now_player_node:
		var possible_paths = [
			"/root/Main/NowPlayer",
			"/root/StreamingManager/NowPlayer", 
			"../NowPlayer",
			"../../NowPlayer"
		]
		
		for path in possible_paths:
			var node = get_node_or_null(path)
			if node:
				now_player_node = node
				print("PlayerInfo: Found now_player via path: " + path)
				break
	
	# 连接信号
	if now_player_node:
		if now_player_node.has_signal("player_selected"):
			now_player_node.player_selected.connect(_on_player_selected)
			print("PlayerInfo: Connected to player_selected signal")
		
		if now_player_node.has_signal("team_data_changed"):
			now_player_node.team_data_changed.connect(_on_team_data_changed)
			print("PlayerInfo: Connected to team_data_changed signal")
	else:
		print("PlayerInfo: Warning - Could not find now_player node to connect signals")

func _on_player_selected(player_data: Dictionary) -> void:
	"""当选手被选择时更新显示"""
	print("PlayerInfo: Player selected - ", player_data.get("name", "Unknown"))
	current_player_data = player_data
	_update_player_display()

func _on_team_data_changed() -> void:
	"""当队伍数据改变时刷新显示"""
	print("PlayerInfo: Team data changed, refreshing display")
	if not current_player_data.is_empty():
		# 重新加载选手数据以获取最新的统计信息
		_reload_current_player_data()
		_update_player_display()

func _reload_current_player_data() -> void:
	"""重新加载当前选手数据"""
	if current_player_data.is_empty():
		return
	
	var player_name = current_player_data.get("name", "")
	if player_name == "":
		return
	
	# 从文件重新加载选手数据
	if not FileAccess.file_exists(players_data_path):
		return
	
	var file = FileAccess.open(players_data_path, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json_string)
	if data == null or not (data is Array):
		return
	
	# 查找当前选手
	for player in data:
		if player.get("name", "") == player_name:
			current_player_data = player
			print("PlayerInfo: 重新加载选手数据: ", player_name)
			break

func _update_player_display() -> void:
	"""更新选手信息显示"""
	if current_player_data.is_empty():
		_reset_display()
		return
	
	print("PlayerInfo: 更新选手显示: ", current_player_data.get("name", "Unknown"))
	
	# 更新基本信息
	if player_name_value:
		player_name_value.text = current_player_data.get("name", "未知选手")
	
	if team_name_value:
		team_name_value.text = current_player_data.get("team_id", "无队伍")
	
	# 更新感言
	if slogan_value:
		var stats = current_player_data.get("stats", {})
		var slogan = stats.get("slogan", "")
		slogan_value.text = slogan if slogan != "" else "暂无感言"
	
	# 更新头像
	_update_avatar()
	
	# 更新游戏信息
	_update_game_info()

func _update_avatar() -> void:
	"""更新选手头像"""
	if not player_avatar:
		return
		
	var icon_path = current_player_data.get("icon_path", "")
	print("PlayerInfo: 尝试加载头像路径: ", icon_path)
	
	if icon_path == "":
		print("PlayerInfo: 头像路径为空")
		_load_default_avatar()
		return
	
	# 使用鲁棒性的纹理加载方法
	var texture = _load_texture_from_path(icon_path)
	if texture:
		player_avatar.texture = texture
		print("PlayerInfo: 成功加载选手头像: ", icon_path)
	else:
		print("PlayerInfo: 头像加载失败，使用默认头像")
		_load_default_avatar()

func _load_default_avatar() -> void:
	"""加载默认头像"""
	if not player_avatar:
		return
		
	if FileAccess.file_exists(DEFAULT_AVATAR_PATH):
		var texture = load(DEFAULT_AVATAR_PATH)
		if texture:
			player_avatar.texture = texture
			print("PlayerInfo: 加载默认头像")
		else:
			player_avatar.texture = null
			print("PlayerInfo: 无法加载默认头像")
	else:
		player_avatar.texture = null
		print("PlayerInfo: 默认头像文件不存在")

func _update_game_info() -> void:
	"""更新游戏信息"""
	# 更新干员选择
	if operator_value:
		var operator = current_player_data.get("starting_operator_choice", "")
		operator_value.text = "开局干员：" + operator if operator != "" else "未选择"
	
	# 更新干员立绘
	_update_operator_portrait()
	
	# 更新分队
	if squad_value:
		var squad = current_player_data.get("starting_squad_choice", "")
		squad_value.text = squad if squad != "" else "未分队"
	
	# 更新圣遗物
	if relic_value:
		var relic = current_player_data.get("starting_relic_choice", "")
		relic_value.text = relic if relic != "" else "无"

func _reset_display() -> void:
	"""重置显示到默认状态"""
	print("PlayerInfo: 重置显示到默认状态")
	
	if player_name_value: player_name_value.text = "未选择选手"
	if team_name_value: team_name_value.text = "无队伍"
	if operator_value: operator_value.text = "未选择"
	if squad_value: squad_value.text = "未分队"
	if relic_value: relic_value.text = "无"
	if slogan_value: slogan_value.text = "暂无感言"
	
	# 加载默认头像
	_load_default_avatar()
	
	# 清空干员立绘
	if operator_portrait: operator_portrait.texture = null

# 公共方法，供外部调用刷新显示
func refresh_display() -> void:
	"""刷新显示（外部调用）"""
	print("PlayerInfo: 外部请求刷新显示")
	_load_current_player_from_cache()
	_update_player_display()

func force_update_with_player(player_data: Dictionary) -> void:
	"""强制使用指定的选手数据更新显示"""
	print("PlayerInfo: 强制更新选手数据: ", player_data.get("name", "Unknown"))
	current_player_data = player_data
	_update_player_display()

func _load_texture_from_path(path: String) -> Texture2D:
	"""
	从指定路径加载纹理。
	此方法经过简化，以提高稳定性和兼容性。
	它能处理 res:// 和 user:// 路径。
	"""
	if path.is_empty():
		print("PlayerInfo: Texture path is empty, cannot load.")
		return null

	# 首先检查文件是否存在，这是一个基本的健全性检查
	if not FileAccess.file_exists(path):
		print("PlayerInfo: Texture file does not exist at path: " + path)
		return null

	# 对于 res:// 路径，Godot的 `load` 函数是最高效、最可靠的方法
	if path.begins_with("res://"):
		var texture = load(path)
		if texture is Texture2D:
			print("PlayerInfo: Successfully loaded texture from res:// path: " + path)
			return texture
		else:
			print("PlayerInfo: Failed to load texture from res:// path, or it's not a Texture2D: " + path)
			return null

	# 对于 user:// 或其他绝对路径，使用 Image.load()
	# 这是在运行时加载非项目内部图像的标准方法
	var image = Image.new()
	var error = image.load(path)

	# 如果常规加载失败，特别是出现"文件损坏"或"格式无法识别"的错误时，
	# 启动备用加载方案。这通常是因为文件扩展名与实际内容不匹配。
	if error != OK:
		print("PlayerInfo: Initial image load failed for: " + path + ". Error: " + _get_error_description(error))
		print("PlayerInfo: Attempting fallback loading methods...")
		
		# 从文件读取原始字节数据
		var file_bytes = FileAccess.get_file_as_bytes(path)
		
		if file_bytes.is_empty():
			print("PlayerInfo: Failed to read file bytes for fallback loading.")
			return null
		
		# 尝试作为PNG、JPG、WebP等常见格式加载
		# Godot会根据内容的"魔数"（magic number）来识别格式
		error = image.load_png_from_buffer(file_bytes)
		if error == OK:
			print("PlayerInfo: Fallback success: Loaded as PNG from buffer.")
		else:
			error = image.load_jpg_from_buffer(file_bytes)
			if error == OK:
				print("PlayerInfo: Fallback success: Loaded as JPG from buffer.")
			else:
				error = image.load_webp_from_buffer(file_bytes)
				if error == OK:
					print("PlayerInfo: Fallback success: Loaded as WebP from buffer.")

	if error != OK:
		# 使用现有的错误描述函数来提供更清晰的日志
		print("PlayerInfo: Error loading image from path: " + path)
		print("PlayerInfo: Error Code: " + str(error))
		print("PlayerInfo: Description: " + _get_error_description(error))
		return null

	# 检查图像加载后是否为空
	if image.is_empty():
		print("PlayerInfo: Image data is empty after loading from path: " + path)
		return null

	# 从加载的 Image 数据创建 ImageTexture
	var image_texture = ImageTexture.create_from_image(image)
	if image_texture:
		print("PlayerInfo: Successfully created texture from image at path: " + path)
		return image_texture
	else:
		print("PlayerInfo: Failed to create ImageTexture from image at path: " + path)
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
			return "Unknown error (code: " + str(error_code) + ")"

func _update_operator_portrait() -> void:
	"""更新干员立绘"""
	if not operator_portrait:
		return
		
	var operator_name = current_player_data.get("starting_operator_choice", "")
	print("PlayerInfo: 尝试加载干员立绘，干员名: ", operator_name)
	
	if operator_name == "":
		print("PlayerInfo: 干员名为空，清空立绘显示")
		operator_portrait.texture = null
		return
	
	# 构造立绘文件路径：exe_dir/data/operators/portraits/立绘_（名称）_1.png
	var portrait_path = AppData.get_exe_dir() + "/data/operators/portraits/立绘_" + operator_name + "_1.png"
	print("PlayerInfo: 尝试加载干员立绘路径: ", portrait_path)
	
	# 检查文件是否存在
	if not FileAccess.file_exists(portrait_path):
		print("PlayerInfo: 干员立绘文件不存在: ", portrait_path)
		operator_portrait.texture = null
		return
	
	# 使用鲁棒性加载方法
	var texture = _load_texture_from_path(portrait_path)
	if texture:
		operator_portrait.texture = texture
		print("PlayerInfo: 成功加载干员立绘: ", portrait_path)
	else:
		print("PlayerInfo: 干员立绘加载失败: ", portrait_path)
		operator_portrait.texture = null
