extends TextureRect

# 解说员名单显示管理
# 监听解说员选择确认并显示当前解说员

# 文件路径
var current_announcer_data_path: String

# UI节点引用
@onready var announcers_list_label: Label = get_node_or_null("AnnouncersList")

# 数据存储
var current_confirmed_announcers: Array = []

func _ready() -> void:
	# 初始化路径变量
	current_announcer_data_path = AppData.get_user_dir() + "/userdata/announcers/current_announcer.json"
	
	# 连接到解说员确认信号
	_connect_to_announcer_signals()
	
	# 初始加载当前解说员数据
	_load_current_announcer_data()
	
	# 更新显示
	_update_announcers_display()

func _connect_to_announcer_signals() -> void:
	# 连接到解说员相关信号
	# 延迟连接，确保所有节点都已准备好
	call_deferred("_delayed_connect_to_signals")

func _delayed_connect_to_signals() -> void:
	# 延迟连接到解说员确认信号
	var connected_count = 0
	
	# 查找 StreamingManager 中的 NowAnnouncer 节点
	var now_announcer_nodes = _find_nodes_with_script("now_announcer.gd")
	for node in now_announcer_nodes:
		if node.has_signal("announcer_selected"):
			if not node.announcer_selected.is_connected(_on_announcer_confirmed):
				node.announcer_selected.connect(_on_announcer_confirmed)
				print("Connected to announcer_selected signal from: " + node.name)
				connected_count += 1
	
	if connected_count > 0:
		print("Successfully connected to " + str(connected_count) + " announcer confirmation signal(s)")
	else:
		print("Warning: Could not find announcer confirmation signals to connect")

func _find_nodes_with_script(script_name: String) -> Array:
	# 查找具有指定脚本的节点
	var result = []
	_search_nodes_recursive(get_tree().root, script_name, result)
	return result

func _search_nodes_recursive(node: Node, script_name: String, result: Array) -> void:
	# 递归搜索节点
	if node.get_script():
		var script_path = node.get_script().resource_path
		if script_path.ends_with(script_name):
			result.append(node)
	
	for child in node.get_children():
		_search_nodes_recursive(child, script_name, result)

func _on_announcer_confirmed(announcer_data: Dictionary) -> void:
	# 处理解说员确认信号
	print("🎯 接收到解说员确认信号: " + str(announcer_data))
	
	# 直接从信号数据提取解说员名称
	if announcer_data.has("announcers") and announcer_data["announcers"] is Array:
		# 新格式 {"announcers": [...], "count": 3, "timestamp": ...}
		var announcers_array = announcer_data["announcers"]
		current_confirmed_announcers = []
		
		for announcer in announcers_array:
			if announcer is Dictionary and announcer.has(DataKeys.ANNOUNCER_NAME):
				current_confirmed_announcers.append(announcer[DataKeys.ANNOUNCER_NAME])
		
		print("📋 从信号提取的解说员: " + str(current_confirmed_announcers))
		
		# 更新显示
		_update_announcers_display()
	else:
		# 如果信号数据格式不正确，尝试从文件加载
		print("⚠️ 信号数据格式不正确，尝试从文件加载..")
		_load_current_announcer_data()
		_update_announcers_display()

func _load_current_announcer_data() -> void:
	# 从current_announcer.json加载当前确认的解说员数据
	print("Loading current announcer data from: " + current_announcer_data_path)
	
	if not FileAccess.file_exists(current_announcer_data_path):
		print("Current announcer data file not found")
		current_confirmed_announcers = []
		return
	
	var file = FileAccess.open(current_announcer_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			print("Error: Failed to parse current announcer JSON")
			current_confirmed_announcers = []
		elif data is Dictionary:
			# 支持多种格式
			if data.has("names") and data["names"] is Array:
				# 格式1: {"names": ["b", "A", "刚刚"]}
				current_confirmed_announcers = data["names"]
				print("Loaded " + str(current_confirmed_announcers.size()) + " confirmed announcer(s): " + str(current_confirmed_announcers))
			elif data.has("announcers") and data["announcers"] is Array:
				# 格式2: {"announcers": [{"name": "b", "id": "...", ...}, ...]}
				current_confirmed_announcers = []
				for announcer in data["announcers"]:
					if announcer is Dictionary and announcer.has(DataKeys.ANNOUNCER_NAME):
						current_confirmed_announcers.append(announcer[DataKeys.ANNOUNCER_NAME])
				print("Loaded " + str(current_confirmed_announcers.size()) + " confirmed announcer(s) from announcer objects: " + str(current_confirmed_announcers))
			else:
				print("Error: Invalid current announcer data format - missing 'names' or 'announcers' field")
				print("Data structure: " + str(data.keys()) + " | Data: " + str(data))
				current_confirmed_announcers = []
		else:
			print("Error: Current announcer data is not a Dictionary")
			current_confirmed_announcers = []
	else:
		print("Error: Could not open current announcer data file")
		current_confirmed_announcers = []

func _update_announcers_display() -> void:
	# 更新解说员名单显示
	if not announcers_list_label:
		print("Warning: AnnouncersList label not found")
		return
	
	print("Updating announcers display...")
	
	if current_confirmed_announcers.is_empty():
		announcers_list_label.text = "暂无解说员"
		return
	
	# 生成解说员名单文本
	var display_text = _generate_announcers_text()
	announcers_list_label.text = display_text
	
	print("Announcers display updated: " + str(current_confirmed_announcers.size()) + " announcer(s)")

func _generate_announcers_text() -> String:
	# 生成解说员名单显示文本
	var text_parts = []
	
	# current_confirmed_announcers 是字符串数组，直接使用
	for announcer_name in current_confirmed_announcers:
		if announcer_name and announcer_name != "":
			text_parts.append(announcer_name)
	
	# 格式：四个空格)(名字)(两个空格)|(两个空格)(名字)…
	return "    " + "  |  ".join(text_parts)

# 公共API方法
func refresh_announcers_display() -> void:
	# 外部调用的刷新接口
	_load_current_announcer_data()
	_update_announcers_display()

func get_current_announcers() -> Array:
	# 获取当前解说员数据
	return current_confirmed_announcers

func debug_announcers_data() -> void:
	# 调试解说员数据
	print("🔍 调试解说员数据")
	print("  文件路径: " + current_announcer_data_path)
	print("  文件存在: " + str(FileAccess.file_exists(current_announcer_data_path)))
	print("  解说员数量: " + str(current_confirmed_announcers.size()))
	
	if not current_confirmed_announcers.is_empty():
		print("  📋 解说员列表:")
		for i in range(current_confirmed_announcers.size()):
			var announcer_name = current_confirmed_announcers[i]
			print("    " + str(i + 1) + ". " + str(announcer_name))

# 手动连接方法
func connect_to_now_announcer(announcer_node: Node) -> void:
	# 手动连接到解说员选择节点的信号
	if announcer_node and announcer_node.has_signal("announcer_selected"):
		if not announcer_node.announcer_selected.is_connected(_on_announcer_confirmed):
			announcer_node.announcer_selected.connect(_on_announcer_confirmed)
			print("Manually connected to announcer_selected signal from: " + announcer_node.name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
