extends VBoxContainer

# 信号定义
signal announcer_selected(announcer_data: Dictionary)
signal announcers_loaded(announcers: Array)

# 文件路径
var ANNOUNCER_DATA_PATH: String
var CURRENT_ANNOUNCER_DATA_PATH: String

# 数据存储
var all_announcers: Array = []
var current_announcer_data: Dictionary = {}
var selected_announcers: Array = [{}] # 最多3个解说员的选择

# UI节点引用
@onready var announcer_selection_1: OptionButton = get_node_or_null("AnnouncerSelection1")
@onready var announcer_selection_2: OptionButton = get_node_or_null("AnnouncerSelection2")
@onready var announcer_selection_3: OptionButton = get_node_or_null("AnnouncerSelection3")
@onready var confirm_button: Button = get_node_or_null("ConfirmButton")
@onready var current_announcer_label: Label = get_node_or_null("CurrentAnnouncerLabel")

func _ready() -> void:
	# 初始化路径变量
	ANNOUNCER_DATA_PATH = AppData.get_exe_dir() + "/userdata/announcers/announcers.json"
	CURRENT_ANNOUNCER_DATA_PATH = AppData.get_exe_dir() + "/userdata/announcers/current_announcer.json"
	
	# 连接UI信号
	_connect_ui_signals()
	
	# 连接到解说员编辑器的信号
	_connect_to_editor_signals()
	
	# 加载解说员数据
	_load_announcers_data()
	
	# 加载当前解说员缓存
	_load_current_announcer_cache()
	
	# 根据缓存恢复选择状态
	_restore_selections_from_cache()
	
	# 更新UI
	_update_ui()

func _connect_to_editor_signals() -> void:
	"""连接到解说员编辑器的信号"""
	# 延迟连接，确保所有节点都已准备好
	call_deferred("_delayed_connect_to_editors")

func _delayed_connect_to_editors() -> void:
	"""延迟连接到编辑器信号"""
	var connected_count = 0
	
	# 方法1: 查找组中的编辑器节点
	var editor_nodes = get_tree().get_nodes_in_group("announcer_editors")
	for editor in editor_nodes:
		if editor.has_signal("announcer_data_updated"):
			if not editor.announcer_data_updated.is_connected(_on_announcer_data_updated):
				editor.announcer_data_updated.connect(_on_announcer_data_updated)
				print("Connected to announcer editor signal via group: " + editor.name)
				connected_count += 1
	
	# 方法2: 如果组中没有找到，尝试通过路径查找
	if connected_count == 0:
		var possible_paths = [
			"/root/Main/AnnouncerEditor",
			"/root/AnnouncerEditor", 
			"../AnnouncerEditor",
			"../../AnnouncerEditor"
		]
		
		for path in possible_paths:
			var editor = get_node_or_null(path)
			if editor and editor.has_signal("announcer_data_updated"):
				if not editor.announcer_data_updated.is_connected(_on_announcer_data_updated):
					editor.announcer_data_updated.connect(_on_announcer_data_updated)
					print("Connected to announcer editor signal via path: " + path)
					connected_count += 1
					break
	
	if connected_count == 0:
		print("Warning: Could not find announcer editor to connect signals")
	else:
		print("Successfully connected to " + str(connected_count) + " announcer editor(s)")

func _on_announcer_data_updated() -> void:
	"""处理解说员数据更新"""
	print("🔄 接收到解说员数据更新信号，开始重新加载...")
	
	# 重新加载解说员数据
	reload_announcers()
	
	# 重新加载当前解说员缓存
	_load_current_announcer_cache()
	
	# 根据缓存恢复选择状态
	_restore_selections_from_cache()
	
	# 更新UI显示
	_update_ui()
	
	print("✅ 解说员数据、缓存和选择状态刷新完成")

func _connect_ui_signals() -> void:
	"""连接UI信号"""
	if announcer_selection_1:
		announcer_selection_1.item_selected.connect(_on_announcer_selection_1_changed)
	
	if announcer_selection_2:
		announcer_selection_2.item_selected.connect(_on_announcer_selection_2_changed)
	
	if announcer_selection_3:
		announcer_selection_3.item_selected.connect(_on_announcer_selection_3_changed)
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

func _load_announcers_data() -> void:
	"""从JSON文件加载解说员数据"""
	print("Loading announcers data from: " + ANNOUNCER_DATA_PATH)
	
	if not FileAccess.file_exists(ANNOUNCER_DATA_PATH):
		print("Announcers data file not found: " + ANNOUNCER_DATA_PATH)
		all_announcers = []
		announcers_loaded.emit(all_announcers)
		return
	
	var file = FileAccess.open(ANNOUNCER_DATA_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			print("Error: Failed to parse announcers JSON")
			all_announcers = []
		elif data is Dictionary:
			# 单个解说员数据，转换为数组
			all_announcers = [data]
			print("Loaded single announcer: " + str(data.get("name", "Unknown")))
		elif data is Array:
			# 多个解说员数据
			all_announcers = data
			print("Loaded " + str(all_announcers.size()) + " announcers")
		else:
			print("Error: Invalid announcers data format")
			all_announcers = []
		
		# 填充解说员选择器
		_populate_announcer_selections()
		
		# 发送信号
		announcers_loaded.emit(all_announcers)
	else:
		print("Error: Could not open announcers data file")
		all_announcers = []
		announcers_loaded.emit(all_announcers)

func _populate_announcer_selections() -> void:
	"""填充解说员选择器OptionButton"""
	var selection_buttons = [announcer_selection_1, announcer_selection_2, announcer_selection_3]
	
	for button in selection_buttons:
		if button:
			button.clear()
			button.add_item("请选择解说员", -1)  # 添加默认选项
			
			for i in range(all_announcers.size()):
				var announcer = all_announcers[i]
				var announcer_name = str(announcer.get("name", "Unknown"))
				button.add_item(announcer_name, i)
	
	print("Populated announcer selections with " + str(all_announcers.size()) + " announcers")

func _on_announcer_selection_1_changed(index: int) -> void:
	"""处理第一个解说员选择器变化"""
	_handle_announcer_selection_change(0, index, announcer_selection_1)

func _on_announcer_selection_2_changed(index: int) -> void:
	"""处理第二个解说员选择器变化"""
	_handle_announcer_selection_change(1, index, announcer_selection_2)

func _on_announcer_selection_3_changed(index: int) -> void:
	"""处理第三个解说员选择器变化"""
	_handle_announcer_selection_change(2, index, announcer_selection_3)

func _handle_announcer_selection_change(slot_index: int, index: int, option_button: OptionButton) -> void:
	"""处理解说员选择变化的通用方法"""
	if not option_button:
		return
		
	var item_id = option_button.get_item_id(index)
	
	# 确保selected_announcers数组有足够的空间
	while selected_announcers.size() <= slot_index:
		selected_announcers.append({})
	
	if item_id == -1:  # 默认选项
		selected_announcers[slot_index] = {}
		return
	
	if item_id >= 0 and item_id < all_announcers.size():
		var selected_announcer = all_announcers[item_id]
		selected_announcers[slot_index] = selected_announcer
		print("Announcer selected at position " + str(slot_index + 1) + ": " + str(selected_announcer.get("name", "Unknown")))

func _on_confirm_pressed() -> void:
	"""处理确认按钮点击"""
	# 收集所有有效的解说员选择
	var confirmed_announcers: Array = []
	
	for announcer in selected_announcers:
		if not announcer.is_empty():
			confirmed_announcers.append(announcer)
	
	if confirmed_announcers.is_empty():
		print("No announcers selected")
		return
	
	# 将确认的解说员组合保存到current_announcer.json
	current_announcer_data = {
		"announcers": confirmed_announcers,
		"count": confirmed_announcers.size(),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 保存到文件
	_save_current_announcers()
	
	# 更新UI显示
	_update_current_announcer_display()
	
	# 发送解说员选择信号
	announcer_selected.emit(current_announcer_data)
	
	var announcer_names = []
	for announcer in confirmed_announcers:
		announcer_names.append(str(announcer.get("name", "Unknown")))
	
	print("Announcers confirmed: " + str(announcer_names))

func _save_current_announcers() -> void:
	"""保存当前解说员到current_announcer.json"""
	# 确保目录存在
	if not DirAccess.dir_exists_absolute(AppData.get_exe_dir() + "/userdata/announcers/"):
		DirAccess.make_dir_recursive_absolute(AppData.get_exe_dir() + "/userdata/announcers/")
	
	var file = FileAccess.open(CURRENT_ANNOUNCER_DATA_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(current_announcer_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Current announcers saved to: " + CURRENT_ANNOUNCER_DATA_PATH)
	else:
		print("Error: Could not save current announcers data")

func _update_ui() -> void:
	"""更新UI显示"""
	_update_current_announcer_display()

func _update_current_announcer_display() -> void:
	"""更新当前解说员信息显示"""
	if current_announcer_data.is_empty():
		if current_announcer_label:
			current_announcer_label.text = "未选择解说员"
		return
	
	var announcers_list = current_announcer_data.get("announcers", [])
	if announcers_list.is_empty():
		if current_announcer_label:
			current_announcer_label.text = "未选择解说员"
		return
	
	var announcer_names = []
	for announcer in announcers_list:
		announcer_names.append(str(announcer.get("name", "Unknown")))
	
	if current_announcer_label:
		current_announcer_label.text = "当前解说员: " + ", ".join(announcer_names)

# 公共API方法
func get_all_announcers() -> Array:
	"""获取所有解说员数据"""
	return all_announcers

func get_current_announcers() -> Dictionary:
	"""获取当前选择的解说员数据"""
	return current_announcer_data

func get_selected_announcers_list() -> Array:
	"""获取当前选择的解说员列表"""
	if current_announcer_data.has("announcers"):
		return current_announcer_data["announcers"]
	return []

func reload_announcers() -> void:
	"""重新加载解说员数据"""
	print("Reloading announcers data and cache...")
	_load_announcers_data()
	_load_current_announcer_cache()
	_update_ui()

# 公共方法：外部刷新接口
func refresh_announcer_data() -> void:
	"""外部调用的刷新接口"""
	reload_announcers()

# 公共方法：连接到特定编辑器
func connect_to_editor(editor_node: Node) -> void:
	"""连接到指定的编辑器节点"""
	if editor_node and editor_node.has_signal("announcer_data_updated"):
		if not editor_node.announcer_data_updated.is_connected(_on_announcer_data_updated):
			editor_node.announcer_data_updated.connect(_on_announcer_data_updated)
			print("Manually connected to announcer editor signal")

func _load_current_announcer_cache() -> void:
	"""从current_announcer.json加载当前解说员缓存"""
	print("Loading current announcer cache from: " + CURRENT_ANNOUNCER_DATA_PATH)
	
	if not FileAccess.file_exists(CURRENT_ANNOUNCER_DATA_PATH):
		print("Current announcer cache file not found, starting fresh")
		current_announcer_data = {}
		return
	
	var file = FileAccess.open(CURRENT_ANNOUNCER_DATA_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			print("Error: Failed to parse current announcer cache JSON")
			current_announcer_data = {}
		elif data is Dictionary:
			current_announcer_data = data
			print("Loaded current announcer cache with " + str(data.get("count", 0)) + " announcers")
		else:
			print("Error: Invalid current announcer cache format")
			current_announcer_data = {}
	else:
		print("Error: Could not open current announcer cache file")
		current_announcer_data = {}
	
	_restore_selections_from_cache()

func _restore_selections_from_cache() -> void:
	"""根据当前解说员缓存恢复UI选择状态"""
	if current_announcer_data.is_empty():
		return
	
	var cached_announcers = current_announcer_data.get("announcers", [])
	if cached_announcers.is_empty():
		return
	
	print("Restoring UI selections from cache...")
	
	# 清空当前选择
	selected_announcers = []
	
	# 恢复选择
	var selection_buttons = [announcer_selection_1, announcer_selection_2, announcer_selection_3]
	
	for i in range(min(cached_announcers.size(), selection_buttons.size())):
		var cached_announcer = cached_announcers[i]
		var cached_name = cached_announcer.get("name", "")
		
		# 在所有解说员中查找匹配的项
		for j in range(all_announcers.size()):
			var announcer = all_announcers[j]
			if announcer.get("name", "") == cached_name:
				# 找到匹配项，设置选择
				var button = selection_buttons[i]
				if button:
					# 设置OptionButton的选中项（+1是因为第0项是"请选择解说员"）
					button.select(j + 1)
					
					# 更新内部状态
					while selected_announcers.size() <= i:
						selected_announcers.append({})
					selected_announcers[i] = announcer
					
					print("Restored selection " + str(i + 1) + ": " + cached_name)
				break
	
	print("UI selections restored from cache")
