# main.gd
# 引导壳（Bootstrap Shell）。
# 职责：设置窗口、把 MainContentRoot 交给内核 SceneDirector、挂载控制面板。
# 它不再认识任何具体场景 —— 场景的注册与切换全部由内核 SceneDirector 负责。

extends Node

# MainContentRoot 节点路径：所有动态场景的挂载父节点。
@export var main_content_root_path: NodePath = "MainContentRoot"

# 控制面板场景路径（由内置插件 builtin_control_panel 以 panels 能力提供）。
@export var control_panel_scene_path: String = "res://src/scenes/ui/control_panel.tscn"

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
	# 所有直播场景（内置与第三方）均由插件系统注册，本壳不再认识任何具体场景。
	director.set_host(main_content_root)

	_load_control_panel()

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