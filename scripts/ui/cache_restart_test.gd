extends Node

"""
解说员缓存重启测试脚本
测试解说员数据更新时的完整重启流程
"""

var test_announcer_editor: Node
var test_now_announcer: Node

func _ready() -> void:
	print("=== 开始解说员缓存重启测试 ===")
	call_deferred("_start_test")

func _start_test() -> void:
	"""开始测试"""
	# 查找测试目标
	test_announcer_editor = _find_announcer_editor()
	test_now_announcer = _find_now_announcer()
	
	if not test_announcer_editor or not test_now_announcer:
		print("❌ 测试失败：无法找到测试目标节点")
		return
	
	print("✅ 找到测试目标节点")
	print("   编辑器: " + test_announcer_editor.name)
	print("   选择器: " + test_now_announcer.name)
	
	# 连接测试信号
	if test_announcer_editor.has_signal("announcer_data_updated"):
		test_announcer_editor.announcer_data_updated.connect(_on_test_data_updated)
		print("✅ 连接到数据更新信号")
	
	# 显示当前状态
	_show_current_state()
	
	# 模拟数据更新
	print("\n🔄 模拟解说员数据更新...")
	test_announcer_editor.announcer_data_updated.emit()
	
	# 延迟显示更新后状态
	await get_tree().create_timer(1.0).timeout
	_show_updated_state()

func _on_test_data_updated() -> void:
	"""响应数据更新信号"""
	print("📡 接收到数据更新信号")

func _show_current_state() -> void:
	"""显示当前状态"""
	print("\n📊 当前状态:")
	if test_now_announcer.has_method("get_all_announcers"):
		var all_announcers = test_now_announcer.get_all_announcers()
		print("   所有解说员数量: " + str(all_announcers.size()))
	
	if test_now_announcer.has_method("get_current_announcers"):
		var current_data = test_now_announcer.get_current_announcers()
		if current_data.has("announcers"):
			print("   当前选择的解说员数量: " + str(current_data["announcers"].size()))
		else:
			print("   当前选择的解说员数量: 0")

func _show_updated_state() -> void:
	"""显示更新后状态"""
	print("\n📊 更新后状态:")
	_show_current_state()
	print("\n✅ 缓存重启测试完成")

func _find_announcer_editor() -> Node:
	"""查找解说员编辑器"""
	var editors = get_tree().get_nodes_in_group("announcer_editors")
	if editors.size() > 0:
		return editors[0]
	return null

func _find_now_announcer() -> Node:
	"""查找解说员选择器"""
	return _search_for_script(get_tree().root, "now_announcer.gd")

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
