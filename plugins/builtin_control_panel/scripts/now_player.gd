extends VBoxContainer

# 信号定义
signal player_mic_status_changed(player_id: String, is_connected: bool)
signal player_mic_count_changed(player_id: String, count: int)
signal player_selected(player_data: Dictionary)
signal players_loaded(players: Array)

# 文件路径
var players_data_path: String
var current_player_data_path: String

# 数据存储
var all_players: Array = []
var current_player_data: Dictionary = {}
var player_mic_status: Dictionary = {} # player_id -> bool (是否连麦)
var player_mic_counts: Dictionary = {} # player_id -> int (剩余连麦次数)

# UI节点引用（假设您有这些UI元素，根据实际情况调整）
@onready var player_selection: OptionButton = get_node_or_null("PlayerSelection")
@onready var player_confirm: Button = get_node_or_null("PlayerConfirm")
@onready var current_player_label: Label = get_node_or_null("CurrentPlayerLabel")
@onready var mic_count_label: Label = get_node_or_null("Label")
@onready var timer_start: Button = get_node_or_null("TimerStart")
@onready var timer_stop: Button = get_node_or_null("TimerStop")
@onready var counter_reset: Button = get_node_or_null("CounterReset")
@onready var score_input: LineEdit = get_node_or_null("Score")
@onready var money_taken_input: LineEdit = get_node_or_null("MoneyTaken")
@onready var score_confirm: Button = get_node_or_null("ScoreConfirm")

# 信号
signal team_data_changed # 当队伍数据（如余额）发生变化时发送

func _ready() -> void:
	# 初始化路径变量
	players_data_path = AppData.get_user_dir() + "/userdata/players/players.json"
	current_player_data_path = AppData.get_user_dir() + "/userdata/players/current_player.json"
	
	# 调试信息：输出文件路径
	print("=== NowPlayer 调试信息 ===")
	print("📂 players.json 读取路径: " + players_data_path)
	print("📂 current_player.json 写入路径: " + current_player_data_path)
	print("========================")
	
	# 添加到组中，便于其他节点找到
	add_to_group("now_player")
	
	# 连接UI信号
	_connect_ui_signals()
	
	# 连接到选手编辑器的信号
	_connect_to_editor_signals()
	
	# 加载选手数据
	_load_players_data()
	
	# 加载当前选手缓存
	_load_current_player_cache()
	
	# 根据缓存恢复选择状�?	_restore_selection_from_cache()
	
	# 更新UI
	_update_ui()

func _connect_ui_signals() -> void:
	"""连接UI信号"""
	if player_selection:
		player_selection.item_selected.connect(_on_player_selection_changed)
	
	if player_confirm:
		player_confirm.pressed.connect(_on_player_confirm_pressed)
	
	if timer_start:
		timer_start.pressed.connect(_on_timer_start_pressed)
	
	if timer_stop:
		timer_stop.pressed.connect(_on_timer_stop_pressed)
	
	if counter_reset:
		counter_reset.pressed.connect(_on_counter_reset_pressed)
	
	if score_confirm:
		score_confirm.pressed.connect(_on_score_confirm_pressed)

func _load_players_data() -> void:
	"""从JSON文件加载选手数据"""
	print("🔄 开始加载选手数据...")
	print("📖 尝试读取 players.json 路径: " + players_data_path)
	
	# 检查文件是否存在
	if not FileAccess.file_exists(players_data_path):
		print("❌ players.json 文件不存在: " + players_data_path)
		all_players = []
		players_loaded.emit(all_players)
		return
	else:
		print("✅ players.json 文件存在")
	
	var file = FileAccess.open(players_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		print("📄 players.json 文件大小: " + str(content.length()) + " 字符")
		
		var data = JSON.parse_string(content)
		if data == null:
			print("❌ players.json JSON解析失败")
			all_players = []
		elif data is Dictionary:
			# 单个选手数据，转换为数组
			all_players = [data]
			print("✅ 加载单个选手: " + str(data.get("name", "Unknown")))
		elif data is Array:
			# 多个选手数据
			all_players = data
			print("✅ 加载了 " + str(all_players.size()) + " 个选手")
			# 输出所有选手姓名
			var player_names = []
			for player in all_players:
				player_names.append(player.get("name", "Unknown"))
			print("👥 选手列表: " + str(player_names))
		else:
			print("❌ players.json 数据格式无效")
			all_players = []
		
		# 初始化连麦状态和计数
		_initialize_player_states()
		
		# 填充选手选择器
		_populate_player_selection()
		
		# 发送信号
		players_loaded.emit(all_players)
	else:
		print("Error: Could not open players data file")
		all_players = []
		players_loaded.emit(all_players)

func _initialize_player_states() -> void:
	"""初始化所有选手的连麦状态和计数"""
	for player in all_players:
		var player_id = str(player.get("id", ""))
		if not player_id.is_empty():
			player_mic_status[player_id] = false  # 默认未连麦
			player_mic_counts[player_id] = 3      # 默认剩余连麦次数为3

func _populate_player_selection() -> void:
	"""填充选手选择器OptionButton"""
	if not player_selection:
		return
	
	player_selection.clear()
	player_selection.add_item("请选择选手", -1)  # 添加默认选项
																														  
	for i in range(all_players.size()):
		var player = all_players[i]
		var player_name = str(player.get("name", "Unknown"))
		var is_captain = player.get("captain", 0) == 1
		
		var display_text = player_name
		if is_captain:
			display_text += " (队长)"
		
		player_selection.add_item(display_text, i)
	
	print("Populated player selection with " + str(all_players.size()) + " players")

func _on_player_selection_changed(index: int) -> void:
	"""处理选手选择器变化"""
	var item_id = player_selection.get_item_id(index)
	
	if item_id == -1:  # 默认选项
		current_player_data = {}
		_update_current_player_display()
		return
	
	if item_id >= 0 and item_id < all_players.size():
		var selected_player = all_players[item_id]
		print("Player selected in dropdown: " + str(selected_player.get("name", "Unknown")))
		# 注意：这里只是预选，需要点击确认按钮才会正式选择

func _on_player_confirm_pressed() -> void:
	"""处理选手确认按钮点击"""
	if not player_selection:
		return
	
	var selected_index = player_selection.selected
	var item_id = player_selection.get_item_id(selected_index)
	
	if item_id == -1:  # 默认选项
		print("No player selected")
		return
	
	if item_id >= 0 and item_id < all_players.size():
		# 找到完整的选手数据
		var selected_player = all_players[item_id]
		current_player_data = selected_player
		
		# 保存到current_player.json
		_save_current_player()
		
		# 更新UI显示
		_update_current_player_display()
		
		# 发送选手选择信号
		player_selected.emit(current_player_data)
		
		print("Player confirmed: " + str(current_player_data.get("name", "Unknown")))

func _save_current_player() -> void:
	"""保存当前选手到current_player.json"""
	print("💾 开始保存当前选手数据...")
	print("📝 尝试写入 current_player.json 路径: " + current_player_data_path)
	
	# 确保目录存在
	if not DirAccess.dir_exists_absolute(AppData.get_user_dir() + "/userdata/players/"):
		print("📁 创建目录: " + AppData.get_user_dir() + "/userdata/players/")
		DirAccess.make_dir_recursive_absolute(AppData.get_user_dir() + "/userdata/players/")
	
	var file = FileAccess.open(current_player_data_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(current_player_data, "\t")
		file.store_string(json_string)
		file.close()
		print("✅ current_player.json 写入成功: " + current_player_data_path)
		print("📄 写入的选手数据: " + str(current_player_data.get("name", "Unknown")))
	else:
		print("❌ 无法写入 current_player.json 文件: " + current_player_data_path)

func _update_ui() -> void:
	"""更新UI显示"""
	_update_current_player_display()

func _update_current_player_display() -> void:
	"""更新当前选手信息显示"""
	if current_player_data.is_empty():
		if current_player_label:
			current_player_label.text = "未选择选手"
		if mic_count_label:
			mic_count_label.text = "剩余连麦次数: 3"
		
		# 禁用控件
		if timer_start:
			timer_start.disabled = true
		if timer_stop:
			timer_stop.disabled = true
		if counter_reset:
			counter_reset.disabled = true
		if score_confirm:
			score_confirm.disabled = true
		return
	
	var player_name = str(current_player_data.get("name", "Unknown"))
	var player_id = str(current_player_data.get("id", ""))
	var mic_connected = player_mic_status.get(player_id, false)
	var mic_count = player_mic_counts.get(player_id, 0)
	
	if current_player_label:
		current_player_label.text = "当前选手: " + player_name
	
	if mic_count_label:
		mic_count_label.text = "剩余连麦次数: " + str(mic_count)
	
	# 更新按钮状态
	if timer_start:
		timer_start.disabled = mic_connected or mic_count <= 0  # 正在连麦或没有剩余次数时禁用
	
	if timer_stop:
		timer_stop.disabled = not mic_connected
	
	if counter_reset:
		counter_reset.disabled = false
	
	if score_confirm:
		score_confirm.disabled = false

func _on_timer_start_pressed() -> void:
	"""处理开始计时按钮点击"""
	if current_player_data.is_empty():
		print("No player selected")
		return
	
	var player_id = str(current_player_data.get("id", ""))
	if player_id.is_empty():
		print("Invalid player ID")
		return
	
	# 检查剩余连麦次数
	var remaining_count = player_mic_counts.get(player_id, 0)
	if remaining_count <= 0:
		print("No remaining mic chances for player: " + str(current_player_data.get("name", "Unknown")))
		return
	
	# 更新连麦状态和减少剩余次数
	player_mic_status[player_id] = true
	player_mic_counts[player_id] = remaining_count - 1
	
	# 发送信号
	player_mic_status_changed.emit(player_id, true)
	player_mic_count_changed.emit(player_id, player_mic_counts[player_id])
	
	# 更新UI
	_update_current_player_display()
	
	print("Player " + str(current_player_data.get("name", "Unknown")) + " started timer (remaining: " + str(player_mic_counts[player_id]) + ")")

func _on_timer_stop_pressed() -> void:
	"""处理停止计时按钮点击"""
	if current_player_data.is_empty():
		print("No player selected")
		return
	
	var player_id = str(current_player_data.get("id", ""))
	if player_id.is_empty():
		print("Invalid player ID")
		return
	
	# 更新连麦状态
	player_mic_status[player_id] = false
	
	# 发送信号
	player_mic_status_changed.emit(player_id, false)
	
	# 更新UI
	_update_current_player_display()
	
	print("Player " + str(current_player_data.get("name", "Unknown")) + " stopped timer")

func _on_counter_reset_pressed() -> void:
	"""重置连麦计数器"""
	if current_player_data.is_empty():
		print("No player selected")
		return
	
	var player_id = str(current_player_data.get("id", ""))
	if player_id.is_empty():
		print("Invalid player ID")
		return
	
	# 重置剩余连麦次数为3
	player_mic_counts[player_id] = 3
	
	# 发送信号
	player_mic_count_changed.emit(player_id, 3)
	
	# 更新UI
	_update_current_player_display()
	
	print("Reset remaining mic count to 3 for player: " + str(current_player_data.get("name", "Unknown")))

func _on_score_confirm_pressed() -> void:
	"""处理分数和取钱确认按钮点击"""
	if current_player_data.is_empty():
		print("No player selected")
		return

	var player_id = current_player_data.get("id", "")
	var team_id = current_player_data.get("team_id", "")
	if player_id.is_empty() or team_id.is_empty():
		print("Error: Player or Team ID is missing.")
		return

	# --- 读取和验证输入 ---
	var score_text = score_input.text.strip_edges()
	var money_text = money_taken_input.text.strip_edges()

	var total_score = 0
	var total_money_taken = 0

	if not score_text.is_empty():
		if score_text.is_valid_float():
			total_score = float(score_text)
		else:
			print("Invalid score format")
			return
	
	if not money_text.is_empty():
		if money_text.is_valid_int():
			total_money_taken = int(money_text)
		else:
			print("Invalid money format")
			return

	# --- 更新选手的stats数据（覆写方式） ---
	var players = _load_all_players_from_file()
	var player_found = false
	for i in range(players.size()):
		if players[i].get("id") == player_id:
			# 确保 stats 字段存在
			if not players[i].has("stats"):
				players[i]["stats"] = {}
			
			# 覆写 stats 中的数据
			players[i]["stats"]["score"] = total_score
			players[i]["stats"]["money_taken"] = total_money_taken
			player_found = true
			break
	
	if not player_found:
		print("Error: Could not find player in players.json")
		return
	
	_save_all_players_to_file(players)
	print("Player stats updated for " + player_id + " - Score: " + str(total_score) + ", Money: " + str(total_money_taken))

	# --- 计算并更新队伍数据 ---
	_update_team_totals_from_players(team_id, players)

	# --- 清空输入框并发出信号 ---
	score_input.clear()
	money_taken_input.clear()
	emit_signal("team_data_changed")
	print("Score and money confirmed. Player stats updated, team totals recalculated.")

func _update_team_totals_from_players(team_id: String, players_data: Array):
	"""根据队伍内所有选手的stats计算队伍总分和余额"""
	# 计算队伍总分和总取款
	var team_total_score = 0
	var team_total_money_taken = 0
	
	for player in players_data:
		if player.get("team_id") == team_id:
			var player_stats = player.get("stats", {})
			
			# 优先使用 stats 中的数据，如果没有则使用根级别的数据（向后兼容）
			var player_score = player_stats.get("score", player.get("score", 0))
			var player_money = player_stats.get("money_taken", player.get("money_taken", 0))
			
			team_total_score += player_score
			team_total_money_taken += player_money
	
	# 更新队伍数据
	var teams = _load_all_teams_from_file()
	var team_found = false
	for i in range(teams.size()):
		if teams[i].get("id") == team_id:
			# 设置队伍总分
			teams[i]["score"] = team_total_score
			
			# 计算队伍余额：初始余额（默认200) - 总取款
			var initial_balance = 200  # 可以考虑从配置文件读取
			teams[i]["balance"] = initial_balance - team_total_money_taken
			
			team_found = true
			print("Team " + team_id + " totals updated - Score: " + str(team_total_score) + ", Balance: " + str(teams[i]["balance"]))
			break
	
	if team_found:
		_save_all_teams_to_file(teams)
		print("Team data saved to teams.json")
	else:
		print("Warning: Could not find team " + team_id + " in teams.json")


func _load_all_players_from_file() -> Array:
	var players = []
	if not FileAccess.file_exists(players_data_path):
		return players
	var file = FileAccess.open(players_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data is Array:
			players = data
	return players

func _save_all_players_to_file(players_data: Array):
	var file = FileAccess.open(players_data_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(players_data, "\t"))
		file.close()

func _load_all_teams_from_file() -> Array:
	var teams = []
	# 注意：这里需要teams.json 的正确路径
	var teams_data_path = AppData.get_user_dir() + "/userdata/teams/teams.json"
	if not FileAccess.file_exists(teams_data_path):
		return teams
	var file = FileAccess.open(teams_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data is Array:
			teams = data
	return teams

func _save_all_teams_to_file(teams_data: Array):
	var teams_data_path = AppData.get_user_dir() + "/userdata/teams/teams.json"
	var file = FileAccess.open(teams_data_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(teams_data, "\t"))
		file.close()


# 公共API方法
func get_all_players() -> Array:
	"""获取所有选手数据"""
	return all_players

func get_current_player() -> Dictionary:
	"""获取当前选择的选手数据"""
	return current_player_data

func get_player_mic_status(player_id: String) -> bool:
	"""获取指定选手的连麦状态"""
	return player_mic_status.get(player_id, false)

func get_player_mic_count(player_id: String) -> int:
	"""获取指定选手的剩余连麦次数"""
	return player_mic_counts.get(player_id, 0)

func reload_players() -> void:
	"""重新加载选手数据"""
	print("Reloading players data and cache...")
	_load_players_data()
	_load_current_player_cache()
	_update_ui()

func _connect_to_editor_signals() -> void:
	"""连接到选手编辑器的信号"""
	# 延迟连接，确保所有节点都已准备好
	call_deferred("_delayed_connect_to_editors")

func _delayed_connect_to_editors() -> void:
	"""延迟连接到编辑器信号"""
	var connected_count = 0
	
	# 方法1: 查找组中的编辑器节点
	var editor_nodes = get_tree().get_nodes_in_group("player_editors")
	for editor in editor_nodes:
		if editor.has_signal("player_data_updated"):
			if not editor.player_data_updated.is_connected(_on_player_data_updated):
				editor.player_data_updated.connect(_on_player_data_updated)
				print("Connected to player editor signal via group: " + editor.name)
				connected_count += 1
	
	# 方法2: 如果组中没有找到，尝试通过路径查找
	if connected_count == 0:
		var possible_paths = [
			"/root/Main/PlayerEditor",
			"/root/PlayerEditor", 
			"../PlayerEditor",
			"../../PlayerEditor"
		]
		
		for path in possible_paths:
			var editor = get_node_or_null(path)
			if editor and editor.has_signal("player_data_updated"):
				if not editor.player_data_updated.is_connected(_on_player_data_updated):
					editor.player_data_updated.connect(_on_player_data_updated)
					print("Connected to player editor signal via path: " + path)
					connected_count += 1
					break
	
	if connected_count == 0:
		print("Warning: Could not find player editor to connect signals")
	else:
		print("Successfully connected to " + str(connected_count) + " player editor(s)")

func _on_player_data_updated() -> void:
	"""处理选手数据更新"""
	print("🔄 接收到选手数据更新信号，开始重新加载...")
	
	# 重新加载选手数据
	reload_players()
	
	# 重新加载当前选手缓存
	_load_current_player_cache()
	
	# 根据缓存恢复选择状态
	_restore_selection_from_cache()
	
	# 更新UI显示
	_update_ui()
	
	print("所有选手数据、缓存和选择状态刷新完成")

func _load_current_player_cache() -> void:
	"""从current_player.json加载当前选手缓存"""
	print("Loading current player cache from: " + current_player_data_path)
	
	if not FileAccess.file_exists(current_player_data_path):
		print("Current player cache file not found, starting fresh")
		current_player_data = {}
		return
	
	var file = FileAccess.open(current_player_data_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			print("Error: Failed to parse current player cache JSON")
			current_player_data = {}
		elif data is Dictionary:
			current_player_data = data
			print("Loaded current player cache: " + str(data.get("id", "Unknown")))
		else:
			print("Error: Invalid current player cache format")
			current_player_data = {}
	else:
		print("Error: Could not open current player cache file")
		current_player_data = {}

func _restore_selection_from_cache() -> void:
	"""根据当前选手缓存恢复UI选择状态"""
	if current_player_data.is_empty():
		return
	
	var cached_player_id = current_player_data.get("id", "")
	if cached_player_id.is_empty():
		return
	
	print("Restoring player selection from cache: " + cached_player_id)
	
	# 在所有选手中查找匹配的ID
	for i in range(all_players.size()):
		var player = all_players[i]
		if player.get("id", "") == cached_player_id:
			# 找到匹配项，设置选择
			if player_selection:
				# 设置OptionButton的选中项（+1是因为第0项可能是"请选择选手"）
				player_selection.select(i + 1)
				print("Restored player selection: " + cached_player_id)
			break
	
	print("Player selection restored from cache")
