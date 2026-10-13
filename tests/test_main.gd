# tests/test_main.gd
# 轻量测试 runner 入口（ADR-0003 方案 B，issue #5）：以真实启动加载本场景执行全部测试。
#   godot --headless --path . res://tests/test_main.tscn
# 任一用例失败以退出码 1 结束；CI 以退出码 + [FAIL] 输出判定门禁。
# 说明：不用 -s 脚本入口 —— -s 模式下 autoload（EventCatalog 等）的编译期解析不可靠，
# 真实启动（完整 autoload + 内核装配）行为确定且更接近运行时。

extends Node

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_data_schema.gd",
	"res://tests/test_data_contract.gd",
	"res://tests/test_event_catalog.gd",
	"res://tests/test_event_bus.gd",
]

func _ready() -> void:
	print("[run_tests] 共 %d 个测试文件" % TEST_SCRIPTS.size())
	var all_pass := true
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			all_pass = false
			print("[FAIL] 测试脚本加载失败: " + path)
			continue
		var case: TestCase = script.new()
		all_pass = case.run() and all_pass
	print("----------")
	if all_pass:
		print("[run_tests] 全部通过")
		get_tree().quit(0)
	else:
		print("[run_tests] 存在失败用例（见上方 [FAIL] 项）")
		get_tree().quit(1)
