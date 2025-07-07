extends Control

# UI节点引用
@onready var order_label: Label = get_node_or_null("Order")
@onready var team_name_label: Label = get_node_or_null("TeamName")
@onready var balance_label: Label = get_node_or_null("Balance")
@onready var score_label: Label = get_node_or_null("Score")
@onready var team_icon: TextureRect = get_node_or_null("TeamIcon")

func _ready() -> void:
	# 确保所有UI元素都正确连接
	if not order_label:
		print("ScoreBar Warning: Order label not found")
	if not team_name_label:
		print("ScoreBar Warning: TeamName label not found")
	if not balance_label:
		print("ScoreBar Warning: Balance label not found")
	if not score_label:
		print("ScoreBar Warning: Score label not found")
	if not team_icon:
		print("ScoreBar Warning: TeamIcon not found")

func setup_team_data(team_data: Dictionary) -> void:
	"""设置队伍数据到score_bar的UI元素"""
	
	# 设置排名
	if order_label:
		order_label.text = str(team_data.get("rank", "?"))
	
	# 设置队伍名称
	if team_name_label:
		team_name_label.text = str(team_data.get("name", "Unknown"))
	
	# 设置余额
	if balance_label:
		balance_label.text = str(team_data.get("balance", 0))
	
	# 设置分数
	if score_label:
		score_label.text = str(team_data.get("score", 0))
	
	# 设置队伍图标
	if team_icon:
		var icon_path = team_data.get("icon_path", "")
		if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
			var texture = _load_texture_from_path(icon_path)
			if texture:
				team_icon.texture = texture
			else:
				team_icon.texture = null
		else:
			team_icon.texture = null

func _load_texture_from_path(path: String) -> Texture2D:
	"""从路径加载纹理"""
	if path.is_empty():
		return null
	
	if not FileAccess.file_exists(path):
		return null
	
	if path.begins_with("res://"):
		return load(path)
	else:
		var image = Image.new()
		var error = image.load(path)
		if error == OK:
			return ImageTexture.create_from_image(image)
	
	return null
