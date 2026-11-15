# tests/test_api_version.gd
# API 契约版本测试（阶段 2）：版本解析、范围匹配、非法输入拒绝。

extends TestCase

func run() -> bool:
	_test_parse()
	_test_bare_version()
	_test_explicit_range()
	_test_invalid()
	return summary("test_api_version")

func _test_parse() -> void:
	eq(ApiVersion.parse("2.0.0"), {"major": 2, "minor": 0, "patch": 0}, "解析 2.0.0")
	eq(ApiVersion.parse("v12.3.4"), {"major": 12, "minor": 3, "patch": 4}, "解析 v12.3.4")
	eq(ApiVersion.parse("2.1"), {}, "拒绝两段版本")
	eq(ApiVersion.parse("2.x.0"), {}, "拒绝非数字段")

func _test_bare_version() -> void:
	ok(ApiVersion.is_compatible("2.0.0", "2.0.0"), "裸版本：同版本兼容")
	ok(ApiVersion.is_compatible("2.0.0", "2.5.1"), "裸版本：同 major 更高 minor 兼容")
	ok(not ApiVersion.is_compatible("2.1.0", "2.0.0"), "裸版本：核心低于声明不兼容")
	ok(not ApiVersion.is_compatible("3.0.0", "2.0.0"), "裸版本：major 不同不兼容")

func _test_explicit_range() -> void:
	ok(ApiVersion.is_compatible(">=2.0.0 <3.0.0", "2.0.0"), "范围：下界包含")
	ok(ApiVersion.is_compatible(">=2.0.0 <3.0.0", "2.9.9"), "范围：上界内")
	ok(not ApiVersion.is_compatible(">=2.0.0 <3.0.0", "3.0.0"), "范围：上界排除")
	ok(not ApiVersion.is_compatible(">=2.0.0 <3.0.0", "1.9.9"), "范围：低于下界排除")

func _test_invalid() -> void:
	ok(not ApiVersion.is_compatible("", "2.0.0"), "空声明不兼容")
	ok(not ApiVersion.is_compatible("2.0.0", ""), "空内核版本不兼容")
	ok(not ApiVersion.is_compatible("~2.0.0", "2.0.0"), "不支持的范围语法不兼容")
	ok(not ApiVersion.is_compatible(">=2.0.0 nope", "2.0.0"), "范围含非法项不兼容")
