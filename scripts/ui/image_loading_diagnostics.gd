extends Node
# 图像加载故障排除脚本

func _ready() -> void:
	print("🔍 开始图像加载故障排除...")
	call_deferred("diagnose_image_loading")

func diagnose_image_loading() -> void:
	"""诊断图像加载问题"""
	var separator = "=================================================="
	print("\n" + separator)
	print("🛠️ 图像加载诊断")
	print(separator)
	
	# 检查常见的图像路径
	var test_paths = [
		"user://userdata/players/player_icons/123_123.png",
		"user://userdata/players/current_player.json",
		"user://data/operators/5/头像_陈.png",
		"user://data/squads/近卫.png",
		"user://userdata/teams/001_Rhodes Island.jpg"
	]
	
	for path in test_paths:
		print("\n🔍 检查路径: " + path)
		diagnose_single_file(path)
	
	# 检查目录结构
	print("\n📁 检查目录结构...")
	check_directory_structure()
	
	# 提供解决方案
	print("\n💡 解决方案建议...")
	provide_solutions()

func diagnose_single_file(path: String) -> void:
	"""诊断单个文件"""
	if path.ends_with(".json"):
		# JSON文件诊断
		if FileAccess.file_exists(path):
			print("  ✓ 文件存在")
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				print("  ✓ 文件可读，大小: " + str(content.length()) + " 字节")
				
				var data = JSON.parse_string(content)
				if data != null:
					print("  ✓ JSON格式有效")
					if data is Dictionary:
						print("  📋 JSON内容: " + str(data))
				else:
					print("  ✗ JSON格式无效")
			else:
				print("  ✗ 无法打开文件")
		else:
			print("  ✗ 文件不存在")
	else:
		# 图像文件诊断
		if FileAccess.file_exists(path):
			print("  ✓ 文件存在")
			
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var size = file.get_length()
				file.close()
				print("  📏 文件大小: " + str(size) + " 字节")
				
				if size == 0:
					print("  ⚠️ 文件为空")
				elif size < 10:
					print("  ⚠️ 文件过小，可能损坏")
				else:
					print("  ✓ 文件大小正常")
			else:
				print("  ✗ 无法打开文件")
			
			# 尝试加载图像
			var image = Image.new()
			var error = image.load(path)
			if error == OK:
				print("  ✓ 图像加载成功")
				print("  📐 图像尺寸: " + str(image.get_width()) + "x" + str(image.get_height()))
				print("  🎨 图像格式: " + str(image.get_format()))
			else:
				print("  ✗ 图像加载失败，错误代码: " + str(error))
				print("  📝 错误描述: " + get_error_name(error))
		else:
			print("  ✗ 文件不存在")

func check_directory_structure() -> void:
	"""检查目录结构"""
	var directories = [
		"user://userdata",
		"user://userdata/players",
		"user://userdata/players/player_icons",
		"user://userdata/teams",
		"user://data",
		"user://data/operators",
		"user://data/squads"
	]
	
	for dir_path in directories:
		if DirAccess.dir_exists_absolute(dir_path):
			print("  ✓ " + dir_path + " - 存在")
			
			# 列出目录内容
			var dir = DirAccess.open(dir_path)
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				var file_count = 0
				
				while file_name != "":
					file_count += 1
					if file_count <= 3:  # 只显示前3个文件
						print("    📄 " + file_name)
					file_name = dir.get_next()
				
				if file_count > 3:
					print("    ... 还有 " + str(file_count - 3) + " 个文件")
				elif file_count == 0:
					print("    🗂️ 目录为空")
				
				dir.list_dir_end()
		else:
			print("  ✗ " + dir_path + " - 不存在")

func provide_solutions() -> void:
	"""提供解决方案"""
	print("1. 🔧 检查文件路径是否正确")
	print("   - 确保路径中的文件名和扩展名正确")
	print("   - 检查中文字符是否正确编码")
	
	print("\n2. 📁 检查文件是否存在")
	print("   - 确保图像文件已正确保存到指定位置")
	print("   - 检查文件权限是否正确")
	
	print("\n3. 🖼️ 检查图像文件格式")
	print("   - 支持的格式: PNG, JPG, JPEG, BMP, TGA, WEBP")
	print("   - 检查文件是否损坏")
	
	print("\n4. 🔄 重新创建或复制文件")
	print("   - 如果文件损坏，尝试重新创建")
	print("   - 确保从可靠来源复制文件")
	
	print("\n5. 🐛 调试模式")
	print("   - 在 _update_player_info() 中添加更多调试信息")
	print("   - 检查 current_player_data 的内容")

func get_error_name(error_code: int) -> String:
	"""获取错误代码的名称"""
	match error_code:
		OK:
			return "OK"
		ERR_FILE_NOT_FOUND:
			return "ERR_FILE_NOT_FOUND"
		ERR_FILE_BAD_DRIVE:
			return "ERR_FILE_BAD_DRIVE"
		ERR_FILE_BAD_PATH:
			return "ERR_FILE_BAD_PATH"
		ERR_FILE_NO_PERMISSION:
			return "ERR_FILE_NO_PERMISSION"
		ERR_FILE_ALREADY_IN_USE:
			return "ERR_FILE_ALREADY_IN_USE"
		ERR_FILE_CANT_OPEN:
			return "ERR_FILE_CANT_OPEN"
		ERR_FILE_CANT_WRITE:
			return "ERR_FILE_CANT_WRITE"
		ERR_FILE_CANT_READ:
			return "ERR_FILE_CANT_READ"
		ERR_FILE_UNRECOGNIZED:
			return "ERR_FILE_UNRECOGNIZED"
		ERR_FILE_CORRUPT:
			return "ERR_FILE_CORRUPT"
		_:
			return "UNKNOWN_ERROR (" + str(error_code) + ")"
