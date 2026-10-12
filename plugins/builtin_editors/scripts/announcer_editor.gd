# announcer_editor.gd
# 解说员编辑器 - 支持多个解说员追加录入

extends Control


# 信号定义
signal announcer_data_updated()  # 解说员数据更新信号

# UI节点引用
@onready var name_input: LineEdit = get_node_or_null("NameInput")
@onready var select_icon_button: Button = get_node_or_null("SelectIconButton")
@onready var icon_path_label: Label = get_node_or_null("IconPathLabel")
@onready var save_button: Button = get_node_or_null("SaveButton")

# 文件路径
var announcer_icons_dir: String
var announcers_data_path: String

# 变量
var file_dialog: FileDialog = null
var selected_icon_path: String = ""

func _ready():
	# 初始化路径变量
	announcer_icons_dir = AppData.get_user_dir() + "/userdata/announcers/announcer_icons/"
	announcers_data_path = AppData.get_user_dir() + "/userdata/announcers/announcers.json"
	
	# 添加到解说员编辑器组
	add_to_group("announcer_editors")
	print("✅ 解说员编辑器已加入 announcer_editors 组")
	
	# 检查UI节点
	if not _validate_ui_nodes():
		return
	
	# 连接信号
	_connect_signals()
	
	# 初始化文件对话框
	_setup_file_dialog()
	
	# 确保目录存在
	_ensure_directories()
	
	# 初始化UI
	_clear_form()

func _validate_ui_nodes() -> bool:
	"""验证UI节点是否存在"""
	var nodes_valid = true
	if not name_input: print("Error: NameInput not found"); nodes_valid = false
	if not select_icon_button: print("Error: SelectIconButton not found"); nodes_valid = false
	if not icon_path_label: print("Error: IconPathLabel not found"); nodes_valid = false
	if not save_button: print("Error: SaveButton not found"); nodes_valid = false
	return nodes_valid

func _connect_signals():
	"""连接UI信号"""
	select_icon_button.pressed.connect(_on_select_icon_pressed)
	save_button.pressed.connect(_on_save_pressed)

func _setup_file_dialog():
	"""设置文件对话框"""
	file_dialog = FileDialog.new()
	file_dialog.title = "选择解说员头像"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.png,*.jpg,*.jpeg ; 图片文件"]
	file_dialog.size = Vector2i(800, 600)
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

func _ensure_directories():
	"""确保必要的目录存在"""
	var base_userdata_dir = AppData.get_user_dir() + "/userdata/announcers/"
	if not DirAccess.dir_exists_absolute(base_userdata_dir):
		DirAccess.make_dir_recursive_absolute(base_userdata_dir)
	
	if not DirAccess.dir_exists_absolute(announcer_icons_dir):
		DirAccess.make_dir_recursive_absolute(announcer_icons_dir)

func _on_select_icon_pressed():
	"""处理选择头像按钮点击"""
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	"""处理文件选择"""
	selected_icon_path = path
	icon_path_label.text = "已选择: " + path.get_file()
	print("Icon selected: " + path)

func _on_save_pressed():
	"""处理保存按钮点击"""
	# 验证输入
	if not _validate_input():
		return
	
	# 复制头像文件
	var final_icon_path = _copy_icon_file()
	if final_icon_path.is_empty():
		return
	
	# 保存解说员数据
	_save_announcer_data(final_icon_path)

func _validate_input() -> bool:
	"""验证输入数据"""
	if name_input.text.strip_edges().is_empty():
		_show_message("验证错误", "解说员姓名不能为空")
		return false
	
	if selected_icon_path.is_empty():
		_show_message("验证错误", "请选择解说员头像")
		return false
	
	return true

func _copy_icon_file() -> String:
	"""复制头像文件到目标目录"""
	var announcer_name = name_input.text.strip_edges()
	var file_extension = selected_icon_path.get_extension()
	var new_file_name = announcer_name.replace(" ", "_").to_lower() + "." + file_extension
	var destination_path = announcer_icons_dir + new_file_name
	
	# 复制文件
	var source_file = FileAccess.open(selected_icon_path, FileAccess.READ)
	if not source_file:
		_show_message("错误", "无法打开源文件")
		return ""
	
	var dest_file = FileAccess.open(destination_path, FileAccess.WRITE)
	if not dest_file:
		source_file.close()
		_show_message("错误", "无法创建目标文件")
		return ""
	
	dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	source_file.close()
	dest_file.close()
	
	if FileAccess.file_exists(destination_path):
		print("Icon copied to: " + destination_path)
		return destination_path
	else:
		_show_message("错误", "文件复制失败")
		return ""

func _save_announcer_data(icon_path: String):
	"""保存解说员数据（追加模式）"""
	# 加载现有数据
	var announcers_list: Array = _load_existing_announcers()
	
	# 创建新解说员数据
	var announcer_data = {
		"id": _generate_announcer_id(),
		"name": name_input.text.strip_edges(),
		"icon_path": icon_path
	}
	
	# 检查是否已存在同名解说员
	for i in range(announcers_list.size()):
		var announcer = announcers_list[i]
		if announcer.get("name", "") == announcer_data["name"]:
			# 更新现有解说员
			announcers_list[i] = announcer_data
			if _write_announcers_file(announcers_list):
				_show_message("成功", "解说员 \"" + announcer_data["name"] + "\" 已更新")
				print("📡 发射解说员数据更新信号（更新现有）")
				announcer_data_updated.emit()  # 发送数据更新信号
				_clear_form()
			else:
				_show_message("错误", "更新失败")
			return
	
	# 添加新解说员
	announcers_list.append(announcer_data)
	
	# 保存到文件
	if _write_announcers_file(announcers_list):
		_show_message("成功", "解说员 \"" + announcer_data["name"] + "\" 已保存")
		print("📡 发射解说员数据更新信号（新增）")
		announcer_data_updated.emit()  # 发送数据更新信号
		_clear_form()
	else:
		_show_message("错误", "保存失败")

func _load_existing_announcers() -> Array:
	"""加载现有的解说员数据"""
	if not FileAccess.file_exists(announcers_data_path):
		return []
	
	var file = FileAccess.open(announcers_data_path, FileAccess.READ)
	if not file:
		return []
	
	var content = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(content)
	if data == null:
		print("Error parsing existing announcers JSON")
		return []
	
	if data is Array:
		return data
	elif data is Dictionary:
		return [data]  # 转换单个对象为数组
	else:
		return []

func _write_announcers_file(announcers_list: Array) -> bool:
	"""写入解说员文件"""
	var file = FileAccess.open(announcers_data_path, FileAccess.WRITE)
	if not file:
		print("Error: Could not open announcers file for writing")
		return false
	
	var json_string = JSON.stringify(announcers_list, "\t")
	file.store_string(json_string)
	file.close()
	
	print("Announcers data saved. Total count: " + str(announcers_list.size()))
	return true

func _generate_announcer_id() -> String:
	"""生成解说员ID"""
	return "announcer_" + str(Time.get_unix_time_from_system())

func _clear_form():
	"""清空表单"""
	name_input.text = ""
	selected_icon_path = ""
	icon_path_label.text = "未选择头像"

func _show_message(title: String, message: String):
	"""显示消息对话框"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
