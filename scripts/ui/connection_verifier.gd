extends Node

"""
简化的信号连接验证脚本
验证 now_announcer 是否能正确接收并处理 announcer_data_updated 信号
"""

func _ready() -> void:
	print("=== 验证信号连接 ===")
	call_deferred("_verify_connections")

func _verify_connections() -> void:
	"""验证连接状态"""
	# 1. 检查announcer_editors组
	var editors = get_tree().get_nodes_in_group("announcer_editors")
	print("找到 " + str(editors.size()) + " 个解说员编辑器")
	
	# 2. 查找now_announcer节点
	var now_announcer = _find_now_announcer()
	
	if now_announcer:
		print("找到 now_announcer 节点: " + now_announcer.name)
		
		# 3. 检查连接状态
		if editors.size() > 0:
			var editor = editors[0]
			print("检查编辑器: " + editor.name)
			
			if editor.has_signal("announcer_data_updated"):
				var connections = editor.announcer_data_updated.get_connections()
				print("announcer_data_updated 信号有 " + str(connections.size()) + " 个连接")
				
				for connection in connections:
					print("- 连接到: " + str(connection["target"].name) + "." + connection["method"])
				
				# 手动测试连接
				print("测试信号发射...")
				editor.announcer_data_updated.emit()
			else:
				print("编辑器缺少 announcer_data_updated 信号")
		else:
			print("没有找到解说员编辑器")
	else:
		print("没有找到 now_announcer 节点")

func _find_now_announcer() -> Node:
	"""查找 now_announcer 节点"""
	var search_paths = [
		"/root/Main/NowAnnouncer",
		"/root/NowAnnouncer", 
		"/root/Main/UI/NowAnnouncer",
		"/root/UI/NowAnnouncer"
	]
	
	for path in search_paths:
		var node = get_node_or_null(path)
		if node:
			return node
	
	# 如果路径查找失败，尝试在整个场景树中搜索
	return _search_in_tree(get_tree().root, "now_announcer")

func _search_in_tree(node: Node, script_name: String) -> Node:
	"""在场景树中递归搜索具有特定脚本的节点"""
	if node.get_script():
		var script_path = node.get_script().resource_path
		if script_path.ends_with(script_name + ".gd"):
			return node
	
	for child in node.get_children():
		var result = _search_in_tree(child, script_name)
		if result:
			return result
	
	return null
