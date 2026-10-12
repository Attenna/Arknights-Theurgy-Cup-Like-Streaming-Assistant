# main.gd
# 引导壳（Bootstrap Shell）。
# 职责：设置窗口、把 MainContentRoot 交给内核 SceneDirector、挂载控制面板。
# 它不再认识任何具体场景 —— 场景的注册与切换全部由内核 SceneDirector 负责。

extends Node

# MainContentRoot 节点路径：所有动态场景的挂载父节点。
@export var main_content_root_path: NodePath = "MainContentRoot"

# 控制面板场景路径（P3 将改为由内置插件以 panels 能力注入）。
@export var control_panel_scene_path: String = "res://src/scenes/ui/control_panel.tscn"

# TODO(P3): 三个内置场景迁入 plugins/ 后，删除以下常量与 _register_builtin_scenes()。
const STREAMING_ARENA_SCENE = preload("res://src/scenes/streaming_arena.tscn")
const WAITING_SCENE = preload("res://src/scenes/waiting_scene.tscn")

var control_panel_instance: Window = null

@onready var main_content_root: Node = get_node(main_content_root_path)

func _ready() -> void:
	get_window().title = "Streaming Scene"

	if not main_content_root:
		print("Error: MainContentRoot node not found. Please check 'main_content_root_path' setting.")
		return

	var kernel := get_node_or_null("/root/Kernel")
	if kernel == null:
		print("Error: Kernel autoload not found. Scene system unavailable.")
		return

	var director := kernel.scene_director as SceneDirector
	if director == null:
		print("Error: SceneDirector unavailable.")
		return

	# 把挂载点交给内核；此后所有场景切换都通过 SceneDirector 完成。
	director.set_host(main_content_root)

	_register_builtin_scenes(director) # TODO(P3) 改为内置插件

	_load_control_panel()

# ── 过渡期场景注册 ────────────────────────────────────────────────────────────
# 说明：P3 阶段内置场景正陆续迁入 plugins/，迁移完成前暂由本文件注册；
# 它们与插件场景统一注册进 SceneDirector，从而走同一条切换路径。

func _register_builtin_scenes(director: SceneDirector) -> void:
	director.register_scene({
		"id": "StreamingArena", "name": "比赛场", "type": "live",
		"description": "比赛场直播场景", "plugin_id": "builtin", "scene": STREAMING_ARENA_SCENE,
	})
	director.register_scene({
		"id": "WaitingScene", "name": "候场页", "type": "live",
		"description": "候场页直播场景", "plugin_id": "builtin", "scene": WAITING_SCENE,
	})

# ── 控制面板 ─────────────────────────────────────────────────────────────────

func _load_control_panel() -> void:
	if control_panel_scene_path.is_empty():
		print("Warning: control_panel_scene_path is empty. Control panel will not be loaded.")
		return

	var control_panel_scene = load(control_panel_scene_path)
	if control_panel_scene == null:
		print("Error: Failed to load control_panel scene from path: " + control_panel_scene_path)
		return

	control_panel_instance = control_panel_scene.instantiate()
	add_child(control_panel_instance)

	if control_panel_instance is Window:
		control_panel_instance.title = "Control Panel"
		control_panel_instance.call_deferred("popup_centered")
		control_panel_instance.close_requested.connect(_on_control_panel_close_requested)

	print("Control panel loaded and added as child.")

	# 连接控制面板内所有请求场景切换的节点（内置导航面板 / 模组面板）。
	_connect_transition_sources(control_panel_instance)

func _connect_transition_sources(root: Node) -> void:
	"""递归连接任意暴露 'transition_requested' 信号的后代节点。"""
	var found := 0
	for node in _find_nodes_with_signal(root, "transition_requested"):
		if not node.transition_requested.is_connected(_on_transition_requested):
			node.transition_requested.connect(_on_transition_requested)
			found += 1
	if found > 0:
		print("Connected %d scene transition source(s)." % found)
	else:
		print("Warning: No node with a 'transition_requested' signal found in the control panel.")

func _find_nodes_with_signal(node: Node, signal_name: String) -> Array:
	var result: Array = []
	if node.has_signal(signal_name):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes_with_signal(child, signal_name))
	return result

func _on_transition_requested(target_scene_id: String) -> void:
	print("Received scene transition request for: %s" % target_scene_id)
	var kernel := get_node_or_null("/root/Kernel")
	if kernel == null:
		return
	var director := kernel.scene_director as SceneDirector
	if director:
		director.switch_to(target_scene_id)

func _on_control_panel_close_requested() -> void:
	"""控制面板请求关闭时直接退出程序。"""
	print("Control panel close requested. Quitting application directly.")
	get_tree().quit()