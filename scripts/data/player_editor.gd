# player_editor.gd
extends Control

# 信号定义
signal player_data_updated()  # 选手数据更新信号

# UI Node Paths
@export var id_input_path: NodePath = "IDInput"
@export var team_input_path: NodePath = "TeamInput"
@export var select_icon_button_path: NodePath = "SelectIconButton"
@export var icon_path_label_path: NodePath = "IconPathLabel"
@export var team_leader_checkbox_path: NodePath = "TeamLeader"
@export var squad_choice_path: NodePath = "SquadChoice"
@export var relic_choice_path: NodePath = "RelicChoice"
@export var operator_selection_path: NodePath = "OperatorSelection"
@export var save_button_path: NodePath = "SaveButton"
@export var search_input_path: NodePath = "Search"
@export var star_selection_path: NodePath = "StarSelection"
@export var slogan_edit_path: NodePath = "SloganEdit"

# File Paths
var players_data_path: String
var player_icons_dir: String
var last_player_icon_path_file: String
var last_file_dialog_path_file: String
var relics_data_path: String
var squads_data_path: String
var operators_base_dir: String
var stars_to_choose_path: String

# UI Node References
@onready var id_input: LineEdit = get_node_or_null(id_input_path)
@onready var team_input: LineEdit = get_node_or_null(team_input_path)
@onready var select_icon_button: Button = get_node_or_null(select_icon_button_path)
@onready var icon_path_label: Label = get_node_or_null(icon_path_label_path)
@onready var team_leader_checkbox: CheckButton = get_node_or_null(team_leader_checkbox_path)
@onready var squad_choice: OptionButton = get_node_or_null(squad_choice_path)
@onready var relic_choice: OptionButton = get_node_or_null(relic_choice_path)
@onready var operator_selection: OptionButton = get_node_or_null(operator_selection_path)
@onready var save_button: Button = get_node_or_null(save_button_path)

# 新增的UI节点引用
@onready var search_input: LineEdit = get_node_or_null(search_input_path)
@onready var star_selection: OptionButton = get_node_or_null(star_selection_path)
@onready var slogan_edit: TextEdit = get_node_or_null(slogan_edit_path)

var file_dialog: FileDialog = null
var cached_icon_path: String = ""
var available_stars: Array = []
var all_operators_by_star: Dictionary = {}

func _ready():
	# 初始化路径变量
	players_data_path = AppData.get_exe_dir() + "/userdata/players/players.json"
	player_icons_dir = AppData.get_exe_dir() + "/userdata/players/player_icons/"
	last_player_icon_path_file = AppData.get_exe_dir() + "/userdata/players/last_player_icon_path.json"
	last_file_dialog_path_file = AppData.get_exe_dir() + "/data/last_file_dialog_path.json"
	relics_data_path = AppData.get_exe_dir() + "/data/relics.json"
	squads_data_path = AppData.get_exe_dir() + "/data/squads.json"
	operators_base_dir = AppData.get_exe_dir() + "/data/operators/"
	stars_to_choose_path = AppData.get_exe_dir() + "/data/operators/star_namelist.json"
	
	# 添加到选手编辑器组
	add_to_group("player_editors")
	print("选手编辑器已加入 player_editors 组")
	
	# 检查所有必需的UI节点是否存在
	var all_nodes_found = true
	if not id_input: print("Error: ID输入框未找到，路径: " + str(id_input_path)); all_nodes_found = false
	if not team_input: print("Error: 队伍输入框未找到，路径: " + str(team_input_path)); all_nodes_found = false
	if not select_icon_button: print("Error: 选择头像按钮未找到，路径: " + str(select_icon_button_path)); all_nodes_found = false
	if not icon_path_label: print("Error: 头像路径标签未找到，路径: " + str(icon_path_label_path)); all_nodes_found = false
	if not save_button: print("Error: 保存按钮未找到，路径: " + str(save_button_path)); all_nodes_found = false

	if not all_nodes_found:
		print("请检查PlayerEditor 脚本中的节点路径配置")
		return

	# 连接信号
	select_icon_button.pressed.connect(_on_select_icon_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	
	# 如果有搜索功能，连接相关信号
	if search_input:
		search_input.text_changed.connect(_on_search_text_changed)
	if squad_choice:
		squad_choice.item_selected.connect(_on_squad_choice_item_selected)
	if star_selection:
		star_selection.item_selected.connect(_on_star_selection_item_selected)

	# 初始化文件选择对话框
	file_dialog = FileDialog.new()
	file_dialog.title = "选择选手头像"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.png,*.jpg,*.jpeg ; 图片文件"]
	file_dialog.size = Vector2i(900, 800)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	add_child(file_dialog)

	# 确保用户数据目录存在
	_ensure_user_data_directories()
	
	# 迁移旧的数据结构
	_migrate_player_data_structure()
	
	# 加载配置数据
	_load_relics_data()
	_load_squads_data()
	_load_operators_data()
	
	# 初始化星级选择
	_initialize_star_selection()
	
	# 加载上次选择的头像路径
	_load_last_player_icon_path()
	
	# 初始化干员筛选
	_filter_operators()

func _ensure_user_data_directories():
	print("确保用户数据目录存在...")
	# 确保选手数据目录存在
	if not DirAccess.dir_exists_absolute(AppData.get_exe_dir() + "/userdata/players/"):
		var error = DirAccess.make_dir_recursive_absolute(AppData.get_exe_dir() + "/userdata/players/")
		if error != OK: print("创建选手数据目录失败: " + str(error))
		else: print("创建了选手数据目录")

	# 确保选手头像目录存在
	if not DirAccess.dir_exists_absolute(player_icons_dir):
		var error = DirAccess.make_dir_recursive_absolute(player_icons_dir)
		if error != OK: print("创建选手头像目录失败: " + str(error))
		else: print("创建了选手头像目录: " + player_icons_dir)

	# 确保游戏数据目录存在
	if not DirAccess.dir_exists_absolute(AppData.get_exe_dir() + "/data/"):
		var error = DirAccess.make_dir_recursive_absolute(AppData.get_exe_dir() + "/data/")
		if error != OK: print("创建游戏数据目录失败: " + str(error))
		else: print("创建了游戏数据目录")

	# 确保干员数据目录存在
	if not DirAccess.dir_exists_absolute(operators_base_dir):
		var error = DirAccess.make_dir_recursive_absolute(operators_base_dir)
		if error != OK: print("创建干员数据目录失败: " + str(error))
		else: print("创建了干员数据目录: " + operators_base_dir)

func _load_relics_data():
	print("加载圣遗物数据: " + relics_data_path)
	if not FileAccess.file_exists(relics_data_path):
		print("圣遗物数据文件不存在，创建默认文件")
		var new_file = FileAccess.open(relics_data_path, FileAccess.WRITE)
		if new_file:
			new_file.store_string(JSON.stringify(["美愿时代的留恋", "死仇时代的怨愤", "炽热时代的激情"], "\t"))
			new_file.close()
		return

	var file = FileAccess.open(relics_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data is Array and relic_choice:
			relic_choice.clear()
			for relic_name in data:
				relic_choice.add_item(str(relic_name))
			if relic_choice.get_item_count() > 0:
				relic_choice.select(0)

func _load_squads_data():
	print("加载分队数据: " + squads_data_path)
	if not FileAccess.file_exists(squads_data_path):
		print("分队数据文件不存在，创建默认文件")
		var new_file = FileAccess.open(squads_data_path, FileAccess.WRITE)
		if new_file:
			new_file.store_string(JSON.stringify(["指挥分队", "蓝图测绘分队", "因地制宜分队"], "\t"))
			new_file.close()
		return

	var file = FileAccess.open(squads_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data is Array and squad_choice:
			squad_choice.clear()
			for squad_name in data:
				squad_choice.add_item(str(squad_name))
			if squad_choice.get_item_count() > 0:
				squad_choice.select(0)

func _load_operators_data():
	print("加载干员数据: " + operators_base_dir)
	# 加载可用星级
	if not FileAccess.file_exists(stars_to_choose_path):
		print("星级配置文件不存在，创建默认文件")
		var new_file = FileAccess.open(stars_to_choose_path, FileAccess.WRITE)
		if new_file:
			new_file.store_string(JSON.stringify([5, 6], "\t"))
			new_file.close()
		available_stars = [5, 6]
	else:
		var stars_file = FileAccess.open(stars_to_choose_path, FileAccess.READ)
		if stars_file:
			var content = stars_file.get_as_text()
			stars_file.close()
			var data = JSON.parse_string(content)
			if data is Array:
				available_stars = data

	# 加载每个星级的干员名称
	all_operators_by_star.clear()
	for star in available_stars:
		var operator_list_path = operators_base_dir + str(star) + "_star_name_list.json"
		if not FileAccess.file_exists(operator_list_path):
			print("干员名单文件不存在，创建默认文件: " + operator_list_path)
			var new_file = FileAccess.open(operator_list_path, FileAccess.WRITE)
			if new_file:
				# 创建一些示例干员名称
				var example_operators = []
				if star == 6:
					example_operators = ["陈", "银灰", "艾雅法拉", "史尔特尔", "能天使", "推进之王", "山", "夕", "w", "瑕光"]
				elif star == 5:
					example_operators = ["蓝毒", "白金", "临光", "夜魔", "德克萨斯", "幽灵鲨", "雷蛇", "普罗旺斯", "凛冬", "初雪"]
				new_file.store_string(JSON.stringify(example_operators, "\t"))
				new_file.close()
				all_operators_by_star[star] = example_operators
		else:
			var op_file = FileAccess.open(operator_list_path, FileAccess.READ)
			if op_file:
				var content = op_file.get_as_text()
				op_file.close()
				var data = JSON.parse_string(content)
				if data is Array:
					all_operators_by_star[star] = data
		
		# 创建对应的精选名单文件（如果不存在）
		_create_star_name_list_file(star)

func _initialize_star_selection():
	if not star_selection:
		return
	star_selection.clear()
	star_selection.add_item("所有星级", 0)
	for star in available_stars:
		star_selection.add_item(str(star) + "星", star)
	star_selection.select(0)

func _on_squad_choice_item_selected(index: int):
	if squad_choice:
		var selected_squad = squad_choice.get_item_text(index)
		print("用户选择了分队: " + selected_squad)
	
	print("分队选择变化，重新过滤干员..")
	_filter_operators()

func _on_star_selection_item_selected(index: int):
	if star_selection:
		var selected_star_text = star_selection.get_item_text(index)
		var selected_star_id = star_selection.get_item_id(index)
		print("用户选择了星级: " + selected_star_text + " (ID: " + str(selected_star_id) + ")")
	else:
		print("星级选择触发，但无法获取选择信息")
	
	print("开始刷新干员选择列表...")
	_filter_operators()

func _on_search_text_changed(new_text: String):
	print("搜索文本变化: '" + new_text + "'")
	print("开始根据搜索文本过滤干员..")
	_filter_operators()

func _filter_operators():
	if not operator_selection:
		print("警告: operator_selection 节点未找到")
		return
	
	print("开始过滤干员列表..")
	
	# 清空并重新初始化选择器
	operator_selection.clear()
	operator_selection.add_item("选择干员", 0)

	var search_text = ""
	if search_input:
		search_text = search_input.text.strip_edges().to_lower()

	var selected_star = -1 # -1 表示所有星级
	if star_selection and star_selection.selected > 0:
		selected_star = star_selection.get_item_id(star_selection.selected)
		print("选择的星级: " + str(selected_star))
	else:
		print("选择的是所有星级")

	var raw_operator_names: Array = []
	
	# 收集干员名单
	if selected_star != -1:
		# 特定星级 - 使用对应的(星级)_star_name_list.json 文件收缩选择范围
		print("获取 " + str(selected_star) + " 星干员..")
		raw_operator_names = _get_operators_for_star(selected_star)
		print("获取了" + str(raw_operator_names.size()) + " 个" + str(selected_star) + " 星干员")
	else:
		# 所有星级
		print("获取所有星级干员..")
		for star in available_stars:
			var star_operators = _get_operators_for_star(star)
			raw_operator_names += star_operators
			print("从" + str(star) + " 星获取了 " + str(star_operators.size()) + " 个干员")

	# 过滤干员名单
	var filtered_operators: Array = []
	for op_name in raw_operator_names:
		if search_text == "" or str(op_name).to_lower().contains(search_text):
			filtered_operators.append(op_name)

	# 去重并排序
	var unique_operators = {}
	for op in filtered_operators:
		unique_operators[op] = true
	filtered_operators = unique_operators.keys()
	filtered_operators.sort()

	# 添加到选择器
	for operator_name in filtered_operators:
		operator_selection.add_item(str(operator_name))

	# 确保选择默认项
	if operator_selection.get_item_count() > 0:
		operator_selection.select(0)
	
	print("已加载" + str(filtered_operators.size()) + " 个干员到选择列表")

func _get_operators_for_star(star: int) -> Array:
	# 获取指定星级的干员列表，优先使用 (星级)_star_name_list.json 文件
	var operators: Array = []
	
	# 构建 (星级)_star_name_list.json 文件路径
	var star_name_list_path = operators_base_dir + str(star) + "_star_name_list.json"
	
	print("尝试从文件加载" + str(star) + " 星干员: " + star_name_list_path)
	
	if FileAccess.file_exists(star_name_list_path):
		# 使用星级名单文件
		print("找到星级名单文件: " + star_name_list_path)
		var file = FileAccess.open(star_name_list_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var data = JSON.parse_string(content)
			if data is Array:
				operators = data
				print("从" + str(star) + "_star_name_list.json 成功加载了" + str(operators.size()) + " 个干员")
			else:
				print("警告: " + star_name_list_path + " 格式错误，不是数组")
		else:
			print("错误: 无法打开文件 " + star_name_list_path)
	else:
		# 回退到使用缓存的完整名单
		print("未找到" + str(star) + "_star_name_list.json，尝试使用缓存数据")
		if all_operators_by_star.has(star):
			operators = all_operators_by_star[star]
			print("从缓存加载了 " + str(operators.size()) + " 个" + str(star) + " 星干员")
		else:
			print("警告: 未找到" + str(star) + " 星干员数据（缓存和文件都没有）")
	
	print("最终返回" + str(operators.size()) + " 个" + str(star) + " 星干员")
	return operators

func _load_last_player_icon_path():
	if not FileAccess.file_exists(last_player_icon_path_file):
		return
	var file = FileAccess.open(last_player_icon_path_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data is Dictionary and data.has("last_icon_path") and icon_path_label:
			icon_path_label.text = data["last_icon_path"]

func _save_last_player_icon_path(path: String):
	var data = {"last_icon_path": path}
	var file = FileAccess.open(last_player_icon_path_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("保存了上次选择的头像路径: " + path)

func _load_last_file_dialog_path() -> String:
	if not FileAccess.file_exists(last_file_dialog_path_file):
		return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var file = FileAccess.open(last_file_dialog_path_file, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data is Dictionary and data.has("last_dialog_path"):
			return data["last_dialog_path"]
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

func _save_last_file_dialog_path(path: String):
	var data = {"last_dialog_path": path}
	var file = FileAccess.open(last_file_dialog_path_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _on_select_icon_button_pressed():
	file_dialog.current_dir = _load_last_file_dialog_path()
	file_dialog.popup_centered()

func _on_file_dialog_file_selected(path: String):
	_save_last_file_dialog_path(path.get_base_dir())
	cached_icon_path = path
	if icon_path_label:
		icon_path_label.text = "已选择: " + path.get_file()

func _on_save_button_pressed():
	# --- 数据验证 ---
	var player_name = ""
	if id_input:
		player_name = id_input.text.strip_edges()
	if player_name.is_empty():
		_show_message_dialog("验证错误", "选手姓名不能为空")
		return

	var team_id = ""
	if team_input:
		team_id = team_input.text.strip_edges()
	if team_id.is_empty():
		_show_message_dialog("验证错误", "队伍ID不能为空")
		return

	# --- 处理头像文件 ---
	var final_icon_path = ""
	if not cached_icon_path.is_empty():
		# 复制选择的头像文件到选手头像目录
		var dest_path = player_icons_dir.path_join(player_name + "." + cached_icon_path.get_extension())
		var err = DirAccess.copy_absolute(cached_icon_path, dest_path)
		if err == OK:
			final_icon_path = dest_path
			cached_icon_path = ""
			if icon_path_label:
				icon_path_label.text = final_icon_path
			_save_last_player_icon_path(final_icon_path)
		else:
			_show_message_dialog("错误", "无法复制头像文件。错误代码: " + str(err))
			return
	elif icon_path_label and not icon_path_label.text.strip_edges().is_empty() and not icon_path_label.text.begins_with("已选择:"):
		final_icon_path = icon_path_label.text
	else:
		_show_message_dialog("验证错误", "请为选手选择头像")
		return

	# --- 准备选手数据 ---
	var new_player_data = {
		"id": player_name,
		"name": player_name,
		"team_id": team_id,
		"icon_path": final_icon_path,
		"captain": 0, # 0表示不是队长, 1表示是队长
		"stats": {} # 统计数据，包含分数和取钱记录
	}

	# 添加队长状态
	if team_leader_checkbox:
		new_player_data["captain"] = 1 if team_leader_checkbox.button_pressed else 0

	# 添加游戏相关数据
	if squad_choice and squad_choice.selected >= 0:
		new_player_data["starting_squad_choice"] = squad_choice.get_item_text(squad_choice.selected)
	if relic_choice and relic_choice.selected >= 0:
		new_player_data["starting_relic_choice"] = relic_choice.get_item_text(relic_choice.selected)
	if operator_selection and operator_selection.selected > 0: # 跳过"选择干员"占位符
		new_player_data["starting_operator_choice"] = operator_selection.get_item_text(operator_selection.selected)

	# 添加选手感言
	if slogan_edit:
		var slogan_text = slogan_edit.text.strip_edges()
		new_player_data["stats"]["slogan"] = slogan_text

	# --- 读取、更新并写入 players.json ---
	var players = []
	if FileAccess.file_exists(players_data_path):
		var read_file = FileAccess.open(players_data_path, FileAccess.READ)
		if read_file:
			var content = read_file.get_as_text()
			read_file.close()
			if not content.is_empty():
				var parse_result = JSON.parse_string(content)
				if parse_result is Array:
					players = parse_result

	var found_index = -1
	for i in range(players.size()):
		if players[i].has("name") and players[i]["name"] == player_name:
			found_index = i
			break

	if found_index != -1:
		# 覆盖现有选手，保留统计数据
		var existing_player = players[found_index]
		var existing_stats = existing_player.get("stats", {})
		
		# 保留现有的统计数据，但更新slogan
		new_player_data["stats"] = existing_stats
		if slogan_edit:
			new_player_data["stats"]["slogan"] = slogan_edit.text.strip_edges()
		
		# 迁移旧的根级别数据到 stats（如果存在且 stats 中没有）
		if existing_player.has("score") and not existing_stats.has("score"):
			new_player_data["stats"]["score"] = existing_player["score"]
		if existing_player.has("money_taken") and not existing_stats.has("money_taken"):
			new_player_data["stats"]["money_taken"] = existing_player["money_taken"]
		
		# 不再保留根级别的 score 和 money_taken，统一使用 stats
		players[found_index] = new_player_data
		print("更新现有选手: " + player_name + "（已迁移数据到stats）")
	else:
		# 添加新选手
		players.append(new_player_data)
		print("添加新选手: " + player_name)

	# 写回文件
	var file = FileAccess.open(players_data_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(players, "\t"))
		file.close()
		
		# --- 更新对应的队伍数据---
		_update_team_members_and_captain(new_player_data)
		
		_show_message_dialog("成功", "选手数据保存成功")
		emit_signal("player_data_updated")
		
		# 清空表单
		_clear_form()
	else:
		_show_message_dialog("错误", "无法写入 players.json 文件")

func _update_team_members_and_captain(player_data: Dictionary):
	# 更新选手所属队伍的成员和队长信息
	var team_id = player_data.get("team_id", "")
	if team_id.is_empty():
		print("警告: 选手没有队伍ID，无法更新队伍数据")
		return
	
	var teams_data_path = AppData.get_exe_dir() + "/userdata/teams/teams.json"
	
	# 读取所有队伍数据
	var teams = []
	if FileAccess.file_exists(teams_data_path):
		var teams_file = FileAccess.open(teams_data_path, FileAccess.READ)
		if teams_file:
			var content = teams_file.get_as_text()
			teams_file.close()
			if not content.is_empty():
				var parse_result = JSON.parse_string(content)
				if parse_result is Array:
					teams = parse_result
	
	# 找到对应的队伍
	var team_found = false
	for i in range(teams.size()):
		if teams[i].get("id") == team_id:
			# 重新计算该队伍的所有成员和队长
			var all_players = _load_all_players_from_team(team_id)
			var members = []
			var captain_name = null
			
			for player in all_players:
				members.append(player.get("name"))
				if player.get("captain", 0) == 1:
					captain_name = player.get("name")
			
			teams[i]["members"] = members
			teams[i]["captain"] = captain_name
			team_found = true
			print("更新了队伍'" + team_id + "' 的成员和队长信息")
			break
	
	if not team_found:
		print("警告: 在队伍文件中找不到队伍'" + team_id + "'，无法更新队伍数据")
		return
	
	# 写回队伍数据
	var teams_write_file = FileAccess.open(teams_data_path, FileAccess.WRITE)
	if teams_write_file:
		teams_write_file.store_string(JSON.stringify(teams, "\t"))
		teams_write_file.close()
		print("队伍数据更新成功")
	else:
		print("错误: 无法写入更新的队伍数据到 teams.json")

func _load_all_players_from_team(team_id: String) -> Array:
	# 加载指定队伍的所有选手
	var team_players = []
	var all_players = []
	
	if FileAccess.file_exists(players_data_path):
		var players_file = FileAccess.open(players_data_path, FileAccess.READ)
		if players_file:
			var content = players_file.get_as_text()
			players_file.close()
			if not content.is_empty():
				var parse_result = JSON.parse_string(content)
				if parse_result is Array:
					all_players = parse_result
	
	# 筛选出属于指定队伍的选手
	for player in all_players:
		if player.get("team_id") == team_id:
			team_players.append(player)
	
	return team_players

func _clear_form():
	# 清空表单内容
	print("清空表单...")
	
	if id_input:
		id_input.text = ""
	if team_input:
		team_input.text = ""
	if icon_path_label:
		icon_path_label.text = "未选择头像"
	if search_input:
		search_input.text = ""
	if team_leader_checkbox:
		team_leader_checkbox.button_pressed = false
	if slogan_edit:
		slogan_edit.text = ""
	
	# 重置选择器到默认状态
	if squad_choice and squad_choice.get_item_count() > 0:
		squad_choice.select(0)
	if relic_choice and relic_choice.get_item_count() > 0:
		relic_choice.select(0)
	if star_selection and star_selection.get_item_count() > 0:
		star_selection.select(0)
	if operator_selection:
		operator_selection.clear()
		operator_selection.add_item("选择干员", 0)
		operator_selection.select(0)
	
	# 清空缓存的图标路径
	cached_icon_path = ""
	
	# 重新过滤干员列表
	_filter_operators()
	
	print("表单清空完成")

func _migrate_player_data_structure():
	print("开始检查并迁移选手数据结构...")
	if not FileAccess.file_exists(players_data_path):
		print("选手数据文件不存在, 无需迁移")
		return

	var file = FileAccess.open(players_data_path, FileAccess.READ)
	if not file:
		print("无法打开选手数据文件进行迁移")
		return

	var content = file.get_as_text()
	file.close()
	if content.is_empty():
		print("选手数据文件为空, 无需迁移")
		return

	var parse_result = JSON.parse_string(content)
	if not parse_result is Array:
		print("选手数据格式不正确, 无法迁移")
		return

	var players = parse_result
	var migration_needed = false

	for player in players:
		if not player is Dictionary:
			continue

		var stats = player.get("stats", {})
		var player_migrated = false

		# 检�?'score'
		if player.has("score") and not stats.has("score"):
			stats["score"] = player["score"]
			player.erase("score")
			player_migrated = true

		# 检�?'money_taken'
		if player.has("money_taken") and not stats.has("money_taken"):
			stats["money_taken"] = player["money_taken"]
			player.erase("money_taken")
			player_migrated = true
		
		# 检�?'slogan'
		if player.has("slogan") and not stats.has("slogan"):
			stats["slogan"] = player["slogan"]
			player.erase("slogan")
			player_migrated = true

		if player_migrated:
			player["stats"] = stats
			migration_needed = true
			print("为选手 '" + player.get("name", "未知") + "' 迁移了数据")

	if migration_needed:
		print("数据结构已更新, 正在写回文件...")
		var write_file = FileAccess.open(players_data_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(JSON.stringify(players, "\t"))
			write_file.close()
			print("选手数据迁移成功")
		else:
			print("错误: 无法写回迁移后的选手数据")
	else:
		print("所有选手数据结构都是最新的, 无需迁移")

func _show_message_dialog(title: String, message: String):
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func _create_star_name_list_file(star: int):
	# 创建指定星级的精选名单文件, 如果不存在的话
	var star_selected_list_path = operators_base_dir + str(star) + "_star_selected.json"
	
	if not FileAccess.file_exists(star_selected_list_path):
		print("创建星级精选名单文件: " + star_selected_list_path)
		var new_file = FileAccess.open(star_selected_list_path, FileAccess.WRITE)
		if new_file:
			# 创建精选的干员列表（从完整列表中选择一部分）
			var selected_operators = []
			
			if all_operators_by_star.has(star):
				var all_ops = all_operators_by_star[star]
				if star == 6:
					# 6星精选：选择前几个经典角色
					selected_operators = ["陈", "银灰", "艾雅法拉", "史尔特尔", "山"]
					# 确保选择的干员在完整列表中存在
					selected_operators = selected_operators.filter(func(op): return op in all_ops)
					# 如果过滤后为空，使用前几个
					if selected_operators.is_empty() and all_ops.size() > 0:
						selected_operators = all_ops.slice(0, min(5, all_ops.size()))
				elif star == 5:
					# 5星精选：选择前几个经典角色
					selected_operators = ["蓝毒", "白金", "临光", "德克萨斯"]
					# 确保选择的干员在完整列表中存在
					selected_operators = selected_operators.filter(func(op): return op in all_ops)
					# 如果过滤后为空，使用前几个
					if selected_operators.is_empty() and all_ops.size() > 0:
						selected_operators = all_ops.slice(0, min(4, all_ops.size()))
				else:
					# 其他星级：选择前几个
					if all_ops.size() > 0:
						selected_operators = all_ops.slice(0, min(3, all_ops.size()))
			
			# 如果还是为空，提供默认值
			if selected_operators.is_empty():
				if star == 6:
					selected_operators = ["陈", "银灰", "艾雅法拉"]
				elif star == 5:
					selected_operators = ["蓝毒", "白金", "临光"]
				else:
					selected_operators = ["示例干员" + str(star)]
			
			new_file.store_string(JSON.stringify(selected_operators, "\t"))
			new_file.close()
			print("已创建" + str(star) + " 星精选名单文件, 包含 " + str(selected_operators.size()) + " 个干员")
		else:
			print("错误: 无法创建文件 " + star_selected_list_path)
	else:
		print(str(star) + " 星精选名单文件已存在: " + star_selected_list_path)
