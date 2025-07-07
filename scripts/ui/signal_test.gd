extends Node

"""
信号连接测试脚本
用于验证 announcer_editor 和 now_announcer 之间的信号通信
"""

var announcer_editor: Node
var now_announcer: Node

func _ready() -> void:
	print("=== 信号连接测试开始 ===")
	
	# 延迟测试，确保所有节点都加载完成
	call_deferred("_test_signal_connection")

func _test_signal_connection() -> void:
	"""测试信号连接"""
	print("1. 查找announcer_editors组中的节点...")
	var editor_nodes = get_tree().get_nodes_in_group("announcer_editors")
	print("   找到 " + str(editor_nodes.size()) + " 个编辑器节点")
	
	for i in range(editor_nodes.size()):
		var editor = editor_nodes[i]
		print("   编辑器 " + str(i) + ": " + editor.name + " (" + str(editor.get_script()) + ")")
		if editor.has_signal("announcer_data_updated"):
			print("   - 具有 announcer_data_updated 信号")
		else:
			print("   - 缺少 announcer_data_updated 信号")
	
	print("2. 查找 now_announcer 节点...")
	# 尝试在不同路径中查找
	var possible_paths = [
		"/root/Main/NowAnnouncer",
		"/root/NowAnnouncer",
		"../NowAnnouncer",
		"../../NowAnnouncer"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node:
			print("   在路径 " + path + " 找到节点: " + node.name)
			now_announcer = node
			break
	
	if not now_announcer:
		print("   未找到 now_announcer 节点")
	else:
		print("   now_announcer 节点: " + now_announcer.name)
	
	print("3. 测试手动连接...")
	if editor_nodes.size() > 0 and now_announcer:
		announcer_editor = editor_nodes[0]
		print("   尝试连接 " + announcer_editor.name + " 到 " + now_announcer.name)
		
		if announcer_editor.has_signal("announcer_data_updated"):
			# 检查是否已连接
			if announcer_editor.announcer_data_updated.is_connected(_on_test_signal_received):
				print("   信号已连接")
			else:
				announcer_editor.announcer_data_updated.connect(_on_test_signal_received)
				print("   信号连接成功")
			
			# 手动触发信号进行测试
			print("   手动触发信号...")
			announcer_editor.announcer_data_updated.emit()
		else:
			print("   编辑器没有 announcer_data_updated 信号")
	
	print("=== 信号连接测试完成 ===")

func _on_test_signal_received() -> void:
	"""接收到测试信号"""
	print("✓ 成功接收到 announcer_data_updated 信号")
	
	if now_announcer and now_announcer.has_method("reload_announcers"):
		print("  调用 now_announcer.reload_announcers()")
		now_announcer.reload_announcers()
	else:
		print("  now_announcer 没有 reload_announcers 方法")
