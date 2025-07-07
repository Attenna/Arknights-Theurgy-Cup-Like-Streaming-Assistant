extends Node2D

var user_data_path: String = AppData.get_exe_dir()

var CURRENT_ANNOUNCERS_PATH = user_data_path + "/userdata/announcers/current_announcer.json"

# 解说员图标控件
var announcer_icons: Array = []
var announcer_name_labels: Array = []

# 动画相关
const ANIMATION_DURATION: float = 0.6
const SCALE_START: float = 0.8
const ALPHA_START: float = 0.0
const MOVE_DISTANCE: float = 50.0

func _ready() -> void:
	# 初始化UI引用
	setup_ui_references()
	
	# 加载解说员数据并显示
	load_and_display_announcers()

func setup_ui_references() -> void:
	"""设置UI节点引用"""
	# 获取三个解说员图标控件
	announcer_icons = [
		get_node_or_null("Icon1"),
		get_node_or_null("Icon2"),
		get_node_or_null("Icon3")
	]
	
	# 获取三个解说员名字标签
	announcer_name_labels = []
	for i in range(3):
		var icon_node = announcer_icons[i]
		if icon_node:
			# 获取场景中的固定 NameLabel 节点
			var name_label = icon_node.get_node_or_null("NameLabel")
			announcer_name_labels.append(name_label)
			
			if not name_label:
				print("AnnouncerInfo Warning: NameLabel not found in Icon" + str(i + 1))
			
			# 设置初始状态（用于动画）
			icon_node.modulate.a = ALPHA_START
			icon_node.scale = Vector2(SCALE_START, SCALE_START)
		else:
			announcer_name_labels.append(null)
			print("AnnouncerInfo Warning: Icon" + str(i + 1) + " node not found")

func load_and_display_announcers() -> void:
	"""加载并显示解说员信息"""
	print("AnnouncerInfo: Loading current announcers...")
	
	# 检查文件是否存在
	if not FileAccess.file_exists(CURRENT_ANNOUNCERS_PATH):
		print("AnnouncerInfo: current_announcers.json not found. Using default empty data.")
		display_announcers([])
		return
	
	# 读取文件
	var file = FileAccess.open(CURRENT_ANNOUNCERS_PATH, FileAccess.READ)
	if not file:
		print("AnnouncerInfo Error: Could not open current_announcers.json for reading.")
		display_announcers([])
		return
	
	var content = file.get_as_text()
	file.close()
	
	# 解析JSON
	var json_data = JSON.parse_string(content)
	if json_data == null:
		print("AnnouncerInfo Error: Failed to parse current_announcer.json. Invalid JSON format.")
		display_announcers([])
		return
	
	if not json_data is Dictionary:
		print("AnnouncerInfo Error: current_announcer.json content is not a valid JSON object.")
		display_announcers([])
		return
	
	# 提取 announcers 数组
	var announcers_data = json_data.get("announcers", [])
	if not announcers_data is Array:
		print("AnnouncerInfo Error: 'announcers' field is not a valid array.")
		display_announcers([])
		return
	
	print("AnnouncerInfo: Successfully loaded " + str(announcers_data.size()) + " announcers.")
	display_announcers(announcers_data)

func display_announcers(announcers_data: Array) -> void:
	"""显示解说员信息并播放动画"""
	# 更新解说员信息
	for i in range(3):
		var icon_node = announcer_icons[i]
		var name_label = announcer_name_labels[i]
		
		if not icon_node or not name_label:
			continue
		
		# 获取解说员数据
		var announcer_data = null
		if i < announcers_data.size():
			announcer_data = announcers_data[i]
		
		# 更新UI内容
		update_announcer_ui(icon_node, name_label, announcer_data)
	
	# 播放入场动画
	play_entrance_animation()

func update_announcer_ui(icon_node: Control, name_label: Label, announcer_data) -> void:
	"""更新单个解说员的UI"""
	if announcer_data and announcer_data is Dictionary:
		# 显示解说员名字
		var announcer_name = announcer_data.get("name", "未知解说")
		name_label.text = announcer_name
		
		# 加载并设置头像（使用 icon_path 字段）
		var avatar_path = announcer_data.get("icon_path", "")
		load_announcer_avatar(icon_node, avatar_path)
		
		# 显示该解说员
		icon_node.visible = true
	else:
		# 隐藏该解说员位置
		name_label.text = ""
		icon_node.visible = false

func load_announcer_avatar(icon_node: Control, avatar_path: String) -> void:
	"""加载解说员头像"""
	var icon_texture = icon_node.get_node_or_null("Icon")
	var _frame_texture = icon_node.get_node_or_null("Frame")  # 预留用于框架纹理
	
	if not icon_texture:
		print("AnnouncerInfo Warning: Icon TextureRect not found in " + icon_node.name)
		return
	
	# 清空当前头像
	icon_texture.texture = null
	
	if avatar_path.is_empty():
		# 使用默认头像
		var default_avatar = load("res://assets/textures/default_avatar.png")
		if default_avatar:
			icon_texture.texture = default_avatar
		return
	
	# 加载自定义头像
	var texture = _load_texture_from_path(avatar_path)
	if texture:
		icon_texture.texture = texture
	else:
		# 加载失败，使用默认头像
		var default_avatar = load("res://assets/textures/default_avatar.png")
		if default_avatar:
			icon_texture.texture = default_avatar

func _load_texture_from_path(path: String) -> Texture2D:
	"""从路径加载纹理（支持多种格式）"""
	if path.is_empty():
		return null
	
	if not FileAccess.file_exists(path):
		print("AnnouncerInfo Warning: Avatar file not found: " + path)
		return null
	
	if path.begins_with("res://"):
		return load(path)
	else:
		var image = Image.new()
		var error = image.load(path)
		if error == OK:
			return ImageTexture.create_from_image(image)
		else:
			print("AnnouncerInfo Warning: Failed to load image from: " + path)
	
	return null

func play_entrance_animation() -> void:
	"""播放入场动画"""
	print("AnnouncerInfo: Playing entrance animation...")
	
	# 为每个可见的解说员图标播放动画，间隔0.2秒
	for i in range(3):
		var icon_node = announcer_icons[i]
		if icon_node and icon_node.visible:
			# 延迟启动动画
			var delay = i * 0.2
			get_tree().create_timer(delay).timeout.connect(func(): animate_announcer_entrance(icon_node))

func animate_announcer_entrance(icon_node: Control) -> void:
	"""单个解说员的入场动画"""
	if not is_instance_valid(icon_node):
		return
	
	# 设置初始位置（向上偏移）
	var original_position = icon_node.position
	var start_position = original_position + Vector2(0, -MOVE_DISTANCE)
	icon_node.position = start_position
	
	# 创建动画
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 透明度动画（快速淡入）
	tween.tween_method(
		func(alpha): icon_node.modulate.a = alpha,
		ALPHA_START,
		1.0,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# 缩放动画（弹性效果）
	tween.tween_method(
		func(scale_value): icon_node.scale = Vector2(scale_value, scale_value),
		SCALE_START,
		1.0,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 位置动画（从上方滑入）
	tween.tween_method(
		func(pos): icon_node.position = pos,
		start_position,
		original_position,
		ANIMATION_DURATION
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func refresh_announcers() -> void:
	"""刷新解说员信息（可供外部调用）"""
	print("AnnouncerInfo: Refreshing announcer data...")
	load_and_display_announcers()
