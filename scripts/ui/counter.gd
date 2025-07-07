extends Node2D

# UI 节点引用
@onready var time_display: Label = get_node("TimeDisplay")
@onready var star1: TextureRect = get_node("star1")
@onready var star2: TextureRect = get_node("star2")
@onready var star3: TextureRect = get_node("star3")

# 计时器状态
var countdown_active: bool = false
var time_left: float = 180.0
const INITIAL_TIME: float = 180.0

# 闪烁状态
var remaining_connections: int = 3
var blinking_star: TextureRect = null
var blink_active: bool = false
var blink_timer: float = 0.0
const BLINK_DURATION: float = 1.0  # 一个完整的呼吸周期（秒）

# --- Godot 生命周期方法 ---

func _ready() -> void:
	# 初始化显示
	_update_time_display()
	star_reset() # 确保初始状态正确
	
	# 连接到 now_player 节点的信号
	_connect_to_now_player_signals()

func _process(delta: float) -> void:
	# 处理倒计时
	if countdown_active:
		time_left = max(0, time_left - delta)
		_update_time_display()
		if time_left == 0:
			countdown_active = false
			# 倒计时自然结束，等同于连麦结束
			_on_player_mic_status_changed("", false) 
			print("Countdown finished naturally.")
			
	# 处理闪烁动画
	if blink_active and blinking_star:
		blink_timer += delta
		# 使用三角函数（sin）来计算透明度，实现平滑的呼吸效果
		var alpha = (sin(blink_timer * (2 * PI / BLINK_DURATION)) + 1) / 2.0
		blinking_star.modulate.a = alpha

# --- 信号连接 ---

func _connect_to_now_player_signals() -> void:
	call_deferred("_delayed_connect")

func _delayed_connect() -> void:
	var now_player_nodes = get_tree().get_nodes_in_group("now_player_control")
	if now_player_nodes.is_empty():
		var root = get_tree().root
		var found_node = _find_node_with_script(root, "now_player.gd")
		if found_node:
			now_player_nodes.append(found_node)

	if not now_player_nodes.is_empty():
		var now_player = now_player_nodes[0]
		if now_player.has_signal("player_mic_status_changed"):
			now_player.player_mic_status_changed.connect(_on_player_mic_status_changed)
		if now_player.has_signal("player_mic_count_changed"):
			now_player.player_mic_count_changed.connect(_on_player_mic_count_changed)
	else:
		print("Counter Warning: Could not find 'now_player.gd' node.")

# --- 信号处理器 ---

func _on_player_mic_status_changed(_player_id: String, p_is_connected: bool) -> void:
	if p_is_connected:
		# 开始连麦
		start_countdown()
		
		# 根据剩余次数决定哪颗星闪烁
		match remaining_connections:
			3:
				blinking_star = star3
			2:
				blinking_star = star2
			1:
				blinking_star = star1
			_:
				blinking_star = null
		
		start_blinking()
	else:
		# 结束连麦
		stop_countdown()
		
		# 隐藏刚刚闪烁过的星星
		if blinking_star:
			blinking_star.visible = false
		
		stop_blinking()

		# 根据剩余次数决定倒计时Label的显示
		if remaining_connections > 0:
			time_left = 0 # 复位
		else:
			time_left = 0 # 归零
		_update_time_display()


func _on_player_mic_count_changed(_player_id: String, count: int) -> void:
	remaining_connections = clamp(count, 0, 3)
	print("Counter: Remaining connections updated to %d" % remaining_connections)
	
	# 如果收到的次数是3，说明是重置信号
	if remaining_connections == 3:
		star_reset()
		reset_countdown()

# --- 内部控制方法 ---

func start_countdown() -> void:
	if not countdown_active:
		time_left = INITIAL_TIME
		countdown_active = true
		print("Countdown started.")

func stop_countdown() -> void:
	if countdown_active:
		countdown_active = false
		print("Countdown stopped.")

func reset_countdown() -> void:
	countdown_active = false
	time_left = INITIAL_TIME
	_update_time_display()
	print("Countdown reset.")

func start_blinking() -> void:
	if blinking_star:
		blink_active = true
		blink_timer = 0.0
		print("Blinking started for: %s" % blinking_star.name)

func stop_blinking() -> void:
	blink_active = false
	if blinking_star:
		blinking_star.modulate.a = 1.0 # 恢复透明度
	blinking_star = null # 清除闪烁目标
	print("Blinking stopped.")

func star_reset() -> void:
	stop_blinking()
	star1.visible = true
	star2.visible = true
	star3.visible = true
	star1.modulate.a = 1.0
	star2.modulate.a = 1.0
	star3.modulate.a = 1.0
	remaining_connections = 3
	print("Stars have been reset.")

# --- 辅助函数 ---

func _find_node_with_script(node: Node, script_name: String) -> Node:
	if node.get_script() and node.get_script().resource_path.ends_with(script_name):
		return node
	for child in node.get_children():
		var found = _find_node_with_script(child, script_name)
		if found:
			return found
	return null

func _update_time_display() -> void:
	var minutes = floor(time_left / 60)
	var seconds = int(fmod(time_left, 60))
	var milliseconds = int(fmod(time_left, 1) * 100) # 计算百分之一秒
	time_display.text = "%02d:%02d.%02d" % [minutes, seconds, milliseconds]

