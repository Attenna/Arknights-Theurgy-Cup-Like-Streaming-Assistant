extends Node

"""
左侧ID栏测试脚本
测试左侧ID栏的选手信息显示功能
"""

var test_left_id_bar: Node
var test_now_player: Node

func _ready() -> void:
	print("=== 开始左侧ID栏测试 ===")
	call_deferred("_start_test")

func _start_test() -> void:
	"""开始测试"""
	# 查找测试目标
	test_left_id_bar = _find_left_id_bar()
	test_now_player = _find_now_player()
	
	if not test_left_id_bar:
		print("❌ 测试失败：无法找到左侧ID栏节点")
		return
	
	print("✅ 找到左侧ID栏节点: " + test_left_id_bar.name)
	
	if test_now_player:
		print("✅ 找到选手选择节点: " + test_now_player.name)
	else:
		print("⚠️ 未找到选手选择节点，将进行手动测试")
	
	# 显示当前状态
	_show_current_state()
	
	# 显示支持的格式信息
	_test_format_info()
	
	# 测试手动更新
	print("\n🔄 测试手动更新选手数据...")
	_test_manual_update()
	
	# 等待1秒后测试刷新
	await get_tree().create_timer(1.0).timeout
	print("\n🔄 测试刷新功能...")
	_test_refresh()
	
	# 等待1秒后测试清空
	await get_tree().create_timer(1.0).timeout
	print("\n🔄 测试清空功能...")
	_test_clear()

func _show_current_state() -> void:
	"""显示当前状态"""
	print("\n📊 当前左侧ID栏状态:")
	if test_left_id_bar.has_method("get_current_player_data"):
		var current_data = test_left_id_bar.get_current_player_data()
		if current_data.is_empty():
			print("   当前选手数据: 空")
		else:
			print("   当前选手数据: " + str(current_data.get("id", "Unknown")))
			print("   队伍: " + str(current_data.get("team_id", "Unknown")))
			print("   开局干员: " + str(current_data.get("starting_operator_choice", "Unknown")))
			print("   开局分队: " + str(current_data.get("starting_squad_choice", "Unknown")))

func _test_manual_update() -> void:
	"""测试手动更新"""
	var test_player_data = {
		"id": "测试选手",
		"team_id": "测试队伍",
		"icon_path": "res://shared/assets/textures/default_avatar.png",
		"starting_operator_choice": "阿米娅",
		"starting_squad_choice": "先锋分队",
		"starting_relic_choice": "测试藏品"
	}
	
	print("📋 测试数据: " + str(test_player_data))
	
	if test_left_id_bar.has_method("update_player_data"):
		test_left_id_bar.update_player_data(test_player_data)
		print("手动更新测试选手数据完成")
		
		# 测试图像格式支持
		_test_image_format_support()
	else:
		print("左侧ID栏没有 update_player_data 方法")

func _test_image_format_support() -> void:
	"""测试不同图像格式的支持"""
	print("\n🖼️ 测试图像格式支持...")
	
	var test_formats = [
		{
			"format": "PNG",
			"path": "user://test_images/test.png",
			"description": "标准PNG格式"
		},
		{
			"format": "JPG",
			"path": "user://test_images/test.jpg",
			"description": "JPEG格式"
		},
		{
			"format": "WebP",
			"path": "user://test_images/test.webp",
			"description": "WebP格式（现代压缩）"
		},
		{
			"format": "BMP",
			"path": "user://test_images/test.bmp",
			"description": "位图格式"
		},
		{
			"format": "TGA",
			"path": "user://test_images/test.tga",
			"description": "Targa格式"
		},
		{
			"format": "SVG",
			"path": "user://test_images/test.svg",
			"description": "矢量图格式"
		}
	]
	
	for format_test in test_formats:
		print("  测试 " + format_test.format + " (" + format_test.description + ")")
		print("    路径: " + format_test.path)
		
		# 检查文件是否存在
		if FileAccess.file_exists(format_test.path):
			print("    ✓ 文件存在")
			
			# 测试图像加载
			if test_left_id_bar.has_method("_validate_image_file"):
				var is_valid = test_left_id_bar._validate_image_file(format_test.path)
				print("    验证结果: " + ("✓ 通过" if is_valid else "✗ 失败"))
			
			# 测试纹理加载
			if test_left_id_bar.has_method("_load_texture_from_path"):
				var texture = test_left_id_bar._load_texture_from_path(format_test.path)
				if texture:
					print("    ✓ 纹理加载成功")
				else:
					print("    ✗ 纹理加载失败")
		else:
			print("    ℹ️ 测试文件不存在，跳过")
	
	print("图像格式支持测试完成")

func _test_refresh() -> void:
	"""测试刷新功能"""
	if test_left_id_bar.has_method("refresh_display"):
		test_left_id_bar.refresh_display()
		print("刷新功能测试完成")
	else:
		print("左侧ID栏没有 refresh_display 方法")

func _test_clear() -> void:
	"""测试清空功能"""
	var empty_data = {}
	if test_left_id_bar.has_method("update_player_data"):
		test_left_id_bar.update_player_data(empty_data)
		print("清空功能测试完成")
	else:
		print("左侧ID栏没有 update_player_data 方法")

func _test_format_info() -> void:
	"""显示支持的图像格式信息"""
	print("\n📋 支持的图像格式:")
	
	var supported_formats = [
		{
			"extension": "PNG",
			"description": "便携式网络图形 - 无损压缩，支持透明度",
			"recommended": true
		},
		{
			"extension": "JPG/JPEG", 
			"description": "联合图像专家组 - 有损压缩，文件小",
			"recommended": true
		},
		{
			"extension": "WebP",
			"description": "现代网络图像格式 - 高压缩比，质量好",
			"recommended": true
		},
		{
			"extension": "BMP",
			"description": "位图格式 - 无压缩，文件大",
			"recommended": false
		},
		{
			"extension": "TGA",
			"description": "Targa格式 - 支持alpha通道",
			"recommended": false
		},
		{
			"extension": "SVG",
			"description": "可缩放矢量图形 - 矢量格式",
			"recommended": false
		},
		{
			"extension": "HDR",
			"description": "高动态范围图像",
			"recommended": false
		},
		{
			"extension": "EXR",
			"description": "OpenEXR格式 - 专业级HDR",
			"recommended": false
		}
	]
	
	for format_info in supported_formats:
		var status = "✓ 推荐" if format_info.recommended else "⚠️ 支持"
		print("  " + status + " " + format_info.extension)
		print("    " + format_info.description)

func _find_left_id_bar() -> Node:
	"""查找左侧ID栏节点"""
	return _search_for_script(get_tree().root, "left_id_bar.gd")

func _find_now_player() -> Node:
	"""查找选手选择节点"""
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
