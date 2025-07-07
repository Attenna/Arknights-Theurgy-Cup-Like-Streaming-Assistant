# scene_manager_control_v2.gd
# 附加到你的 SceneManager 节点上

extends Control # 或者 Node，取决于你的 SceneManager 节点类型

# 定义一个自定义信号，用于通知其他节点场景切换请求
# 信号将携带一个字符串参数，表示目标场景的唯一标识符
signal transition_requested(target_scene_id: String)

# 导出变量，用于在编辑器中设置按钮的路径
# 请将这些路径替换为你的实际按钮节点路径
@export var to_main_vision_button_path: NodePath = "ToMainVisionButton"
@export var to_streaming_arena_button_path: NodePath = "ToStreamingArenaButton"
@export var to_waiting_scene_button_path: NodePath = "ToWaitingSceneButton"

@onready var to_main_vision_button: Button = get_node(to_main_vision_button_path)
@onready var to_streaming_arena_button: Button = get_node(to_streaming_arena_button_path)
@onready var to_waiting_scene_button: Button = get_node(to_waiting_scene_button_path)

func _ready():
	# 连接按钮的 'pressed' 信号到相应的处理函数
	if to_main_vision_button:
		to_main_vision_button.pressed.connect(_on_to_main_vision_button_pressed)
	else:
		print("Error: 'ToMainVisionButton' node not found.")

	if to_streaming_arena_button:
		to_streaming_arena_button.pressed.connect(_on_to_streaming_arena_button_pressed)
	else:
		print("Error: 'ToStreamingArenaButton' node not found.")

	if to_waiting_scene_button:
		to_waiting_scene_button.pressed.connect(_on_to_waiting_scene_button_pressed)
	else:
		print("Error: 'ToWaitingSceneButton' node not found.")

func _on_to_main_vision_button_pressed():
	"""
	当 'ToMainVisionButton' 被按下时调用。
	发出 'transition_requested' 信号，并指定目标场景ID为 "MainVision"。
	"""
	print("ToMainVisionButton pressed. Emitting 'transition_requested' signal: MainVision")
	transition_requested.emit("MainVision")

func _on_to_streaming_arena_button_pressed():
	"""
	当 'ToStreamingArenaButton' 被按下时调用。
	发出 'transition_requested' 信号，并指定目标场景ID为 "StreamingArena"。
	"""
	print("ToStreamingArenaButton pressed. Emitting 'transition_requested' signal: StreamingArena")
	transition_requested.emit("StreamingArena")

func _on_to_waiting_scene_button_pressed():
	"""
	当 'ToWaitingSceneButton' 被按下时调用。
	发出 'transition_requested' 信号，并指定目标场景ID为 "WaitingScene"。
	"""
	print("ToWaitingSceneButton pressed. Emitting 'transition_requested' signal: WaitingScene")
	transition_requested.emit("WaitingScene")
