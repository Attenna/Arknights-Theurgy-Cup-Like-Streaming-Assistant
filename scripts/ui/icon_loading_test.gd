extends Node
# 图标加载功能测试脚本

const LEFT_ID_BAR_PATH = "scripts/ui/left_id_bar.gd"

func _ready() -> void:
	print("🧪 图标加载功能测试开始...")
	call_deferred("run_tests")

func run_tests() -> void:
	"""运行所有图标加载测试"""
	test_operator_icon_paths()
	test_squad_icon_paths() 
	test_team_icon_paths()
	test_texture_loading()
	print("✅ 图标加载功能测试完成")

func test_operator_icon_paths() -> void:
	"""测试干员图标路径生成"""
	print("\n📋 测试干员图标路径生成...")
	
	# 模拟干员图标路径生成
	var test_operators = ["陈", "史尔特尔", "山", "W", "银灰"]
	var test_stars = [5, 6, 6, 6, 6]  # 对应的星级
	
	for i in range(test_operators.size()):
		var op_name = test_operators[i]
		var expected_star = test_stars[i]
		var expected_path = "user://data/operators/" + str(expected_star) + "/头像_" + op_name + ".png"
		print("  干员: " + op_name + " -> 期望路径: " + expected_path)

func test_squad_icon_paths() -> void:
	"""测试分队图标路径生成"""
	print("\n📋 测试分队图标路径生成...")
	
	var test_squads = ["近卫", "狙击", "术师", "医疗", "重装", "辅助", "特种", "先锋"]
	
	for squad in test_squads:
		var expected_path = "user://data/squads/" + squad + ".png"
		print("  分队: " + squad + " -> 路径: " + expected_path)

func test_team_icon_paths() -> void:
	"""测试战队图标路径生成"""
	print("\n📋 测试战队图标路径生成...")
	
	var test_teams = [
		"001_Rhodes Island",
		"002_Lungmen",
		"003_Kazimierz",
		"004_Victoria"
	]
	
	for team in test_teams:
		var expected_path = "user://userdata/teams/" + team + ".jpg"
		print("  战队: " + team + " -> 路径: " + expected_path)

func test_texture_loading() -> void:
	"""测试纹理加载逻辑"""
	print("\n📋 测试纹理加载逻辑...")
	
	# 测试路径类型检测
	var test_paths = [
		"user://data/test.png",
		"res://textures/test.png", 
		"/absolute/path/test.png",
		""
	]
	
	for path in test_paths:
		print("  路径: " + path)
		if path.is_empty():
			print("    -> 空路径，应返回 null")
		elif path.begins_with("user://"):
			print("    -> user:// 路径，需要 FileAccess 加载")
		elif path.begins_with("res://"):
			print("    -> res:// 路径，可直接 load()")
		else:
			print("    -> 其他路径，尝试 load()")

func simulate_left_id_bar_test() -> void:
	"""模拟 left_id_bar.gd 的图标加载测试"""
	print("\n🎯 模拟左侧ID栏图标加载测试...")
	
	# 模拟选手数据
	var player_data = {
		"id": "测试选手",
		"team_id": "001_Rhodes Island",
		"icon_path": "user://userdata/players/test_player.png",
		"starting_operator_choice": "陈",
		"starting_squad_choice": "近卫"
	}
	
	print("  模拟选手数据:")
	for key in player_data:
		print("    " + key + ": " + str(player_data[key]))
	
	# 模拟图标路径生成
	print("\n  模拟图标路径生成:")
	print("    选手头像: " + player_data.icon_path)
	print("    干员头像: user://data/operators/5/头像_" + player_data.starting_operator_choice + ".png")
	print("    分队图标: user://data/squads/" + player_data.starting_squad_choice + ".png") 
	print("    战队图标: user://userdata/teams/" + player_data.team_id + ".jpg")

# 调用模拟测试
func _on_timer_timeout() -> void:
	simulate_left_id_bar_test()

# 创建定时器以延迟执行测试
func create_test_timer() -> void:
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	timer.start()
