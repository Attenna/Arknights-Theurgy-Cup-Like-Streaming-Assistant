extends VBoxContainer

# 文件路径
var teams_data_path: String
var players_data_path: String

# UI 节点引用
@onready var team_name_label: Label = $TeamName
@onready var team_id_label: Label = $TeamID
@onready var team_balance_label: Label = $TeamBalance
@onready var team_score_label: Label = $TeamScore

# 当前选中的玩家ID
var current_player_id: String = ""
var current_team_data: Dictionary = {}

# 信号：当队伍数据改变时发出
signal team_data_changed

func _ready() -> void:
	# 初始化路径变量
	teams_data_path = AppData.get_exe_dir() + "/userdata/teams/teams.json"
	players_data_path = AppData.get_exe_dir() + "/userdata/players/players.json"
	
	# 初始化显示
	update_team_display()
	
	# 连接到 NowPlayer 的信号来获取当前选中的玩家
	connect_to_now_player_signals()

func connect_to_now_player_signals():
	"""连接到 NowPlayer 节点的信号"""
	# 延迟连接，确保所有节点都已准备好
	call_deferred("_delayed_connect_to_now_player")

func _delayed_connect_to_now_player():
	"""延迟连接到 NowPlayer 信号"""
	# 查找 NowPlayer 节点
	var now_player_node = get_node_or_null("../NowPlayer")
	if now_player_node:
		# 连接玩家选择信号
		if now_player_node.has_signal("player_selected"):
			now_player_node.player_selected.connect(_on_player_selected)
			print("NowTeam: Connected to NowPlayer's player_selected signal.")
		else:
			print("NowTeam Warning: NowPlayer doesn't have player_selected signal.")
		
		# 连接队伍数据变更信号（分数保存后触发）
		if now_player_node.has_signal("team_data_changed"):
			now_player_node.team_data_changed.connect(_on_team_data_changed)
			print("NowTeam: Connected to NowPlayer's team_data_changed signal.")
		else:
			print("NowTeam Warning: NowPlayer doesn't have team_data_changed signal.")
		
		# 获取当前选中的玩家（如果有的话）
		if now_player_node.has_method("get_current_player"):
			var current_player = now_player_node.get_current_player()
			if not current_player.is_empty():
				_on_player_selected(current_player)
	else:
		print("NowTeam Warning: Could not find NowPlayer node.")

func _on_player_selected(player_data: Dictionary):
	"""当玩家被选择时更新队伍信息"""
	var player_id = player_data.get("id", "")
	current_player_id = player_id
	update_team_display()
	print("NowTeam: Player selected, updating team display for player: " + str(player_data.get("name", "Unknown")))

func _on_team_data_changed():
	"""当队伍数据改变时（如分数保存后）重新刷新显示"""
	update_team_display()
	print("NowTeam: Team data changed, refreshing display")

func update_team_display():
	"""更新队伍信息显示"""
	if current_player_id.is_empty():
		# 没有选中玩家时显示默认信息
		team_name_label.text = "队伍名称：未选择"
		team_id_label.text = "队伍ID：未选择"
		team_balance_label.text = "余额：--"
		team_score_label.text = "分数：--"
		current_team_data.clear()
		return
	
	# 根据玩家ID获取队伍信息
	var team_id = get_team_id_by_player(current_player_id)
	if team_id.is_empty():
		team_name_label.text = "队伍名称：未分配队伍"
		team_id_label.text = "队伍ID：未分配队伍"
		team_balance_label.text = "余额：--"
		team_score_label.text = "分数：--"
		current_team_data.clear()
		return
	
	# 获取队伍详细信息
	var team_data = get_team_data_by_id(team_id)
	if team_data.is_empty():
		team_name_label.text = "队伍名称：队伍不存在"
		team_id_label.text = "队伍ID：" + team_id
		team_balance_label.text = "余额：--"
		team_score_label.text = "分数：--"
		current_team_data.clear()
		return
	
	# 更新显示
	current_team_data = team_data
	team_name_label.text = "队伍名称：" + str(team_data.get("name", "未知"))
	team_id_label.text = "队伍ID：" + str(team_data.get("id", "未知"))
	team_balance_label.text = "余额：" + str(team_data.get("balance", 0))
	team_score_label.text = "分数：" + str(team_data.get("score", 0))
	
	print("NowTeam: Updated display for team: " + str(team_data.get("name", "未知")))

func get_team_id_by_player(player_id: String) -> String:
	"""根据玩家ID获取队伍ID"""
	if not FileAccess.file_exists(players_data_path):
		print("NowTeam Warning: players.json not found.")
		return ""
	
	var file = FileAccess.open(players_data_path, FileAccess.READ)
	if not file:
		print("NowTeam Error: Could not open players.json for reading.")
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var players_list = JSON.parse_string(content)
	if not players_list is Array:
		print("NowTeam Error: players.json is not a valid JSON array.")
		return ""
	
	# 查找匹配的玩家
	for player in players_list:
		if player.get("id") == player_id:
			return player.get("team_id", "")
	
	return ""

func get_team_data_by_id(team_id: String) -> Dictionary:
	"""根据队伍ID获取队伍详细信息"""
	if not FileAccess.file_exists(teams_data_path):
		print("NowTeam Warning: teams.json not found.")
		return {}
	
	var file = FileAccess.open(teams_data_path, FileAccess.READ)
	if not file:
		print("NowTeam Error: Could not open teams.json for reading.")
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var teams_list = JSON.parse_string(content)
	if not teams_list is Array:
		print("NowTeam Error: teams.json is not a valid JSON array.")
		return {}
	
	# 查找匹配的队伍
	for team in teams_list:
		if team.get("id") == team_id:
			return team
	
	return {}

func get_current_team_data() -> Dictionary:
	"""获取当前队伍数据（供其他脚本调用）"""
	return current_team_data

func get_current_team_id() -> String:
	"""获取当前队伍ID（供其他脚本调用）"""
	return current_team_data.get("id", "")

func get_current_player_id() -> String:
	"""获取当前玩家ID（供其他脚本调用）"""
	return current_player_id

func refresh_team_data():
	"""刷新队伍数据（供外部调用）"""
	update_team_display()
	emit_signal("team_data_changed")
