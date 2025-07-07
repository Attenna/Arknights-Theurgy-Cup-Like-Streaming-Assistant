extends Node

"""
选手管理系统信号测试脚本
测试选手编辑器与选择界面之间的信号通信
"""

var test_player_editor: Node
var test_now_player: Node

func _ready() -> void:
	print("=== 开始选手管理系统信号测试 ===")
	call_deferred("_start_test")

func _start_test() -> void:
	"""开始测试"""
	# 查找测试目标
	test_player_editor = _find_player_editor()
	test_now_player = _find_now_player()
	
	if not test_player_editor or not test_now_player:
		print("❌ 测试失败：无法找到测试目标节点")
		_show_available_nodes()
		return
	
	print("✅ 找到测试目标节点")
	print("   编辑器: " + test_player_editor.name)
	print("   选择器: " + test_now_player.name)
	
	# 连接测试信号
	if test_player_editor.has_signal("player_data_updated"):
		test_player_editor.player_data_updated.connect(_on_test_data_updated)
		print("✅ 连接到选手数据更新信号")
	
	# 显示当前状态
	_show_current_state()
	
	# 模拟数据更新
	print("\n🔄 模拟选手数据更新...")
	test_player_editor.player_data_updated.emit()
	
	# 延迟显示更新后状态
	await get_tree().create_timer(1.0).timeout
	_show_updated_state()

func _on_test_data_updated() -> void:
	"""响应数据更新信号"""
	print("📡 接收到选手数据更新信号")

func _show_current_state() -> void:
	"""显示当前状态"""
	print("\n📊 当前状态:")
	if test_now_player.has_method("get_all_players"):
		var all_players = test_now_player.get("all_players")
		if all_players:
			print("   所有选手数量: " + str(all_players.size()))
		else:
			print("   所有选手数量: 0")
	
	if test_now_player.has_method("get_current_player"):
		var current_data = test_now_player.get("current_player_data")
		if current_data and not current_data.is_empty():
			print("   当前选择的选手: " + str(current_data.get("id", "Unknown")))
		else:
			print("   当前选择的选手: 无")

func _show_updated_state() -> void:
	"""显示更新后状态"""
	print("\n📊 更新后状态:")
	_show_current_state()
	print("\n✅ 选手系统信号测试完成")

func _find_player_editor() -> Node:
	"""查找选手编辑器"""
	var editors = get_tree().get_nodes_in_group("player_editors")
	if editors.size() > 0:
		return editors[0]
	return null

func _find_now_player() -> Node:
	"""查找选手选择器"""
	return _search_for_script(get_tree().root, "now_player.gd")

func _search_for_script(node: Node, script_name: String) -> Node:
	"""递归搜索具有指定脚本的节点"""
	if node.get_script():
		var script_path = node.get_script().resource_path
		if script_path.ends_with(script_name):
			return node
	
	for child in node.get_children():
		var result = _search_for_script(child, script_name)
		if result:
			return result
	
	return null

func _show_available_nodes() -> void:
	"""显示可用节点信息"""
	print("\n🔍 可用节点信息:")
	
	var player_editors = get_tree().get_nodes_in_group("player_editors")
	print("   player_editors 组中的节点: " + str(player_editors.size()))
	for editor in player_editors:
		print("     - " + editor.name + " (" + str(editor.get_script()) + ")")
	
	var announcer_editors = get_tree().get_nodes_in_group("announcer_editors")
	print("   announcer_editors 组中的节点: " + str(announcer_editors.size()))
	for editor in announcer_editors:
		print("     - " + editor.name + " (" + str(editor.get_script()) + ")")
	
	print("   搜索 now_player.gd 脚本...")
	var now_player = _search_for_script(get_tree().root, "now_player.gd")
	if now_player:
		print("     找到: " + now_player.name)
	else:
		print("     未找到")
