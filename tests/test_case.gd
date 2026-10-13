# tests/test_case.gd
# 轻量测试框架（ADR-0003 方案 B）：极简断言基类。
# 具体测试脚本 extends 本类并实现 run()，返回全部断言是否通过。

class_name TestCase
extends RefCounted

var _failures: Array[String] = []
var _count := 0

## 测试入口，由具体测试脚本实现；返回是否全部通过。
func run() -> bool:
	return true

## 断言条件成立。
func ok(cond: bool, label: String) -> void:
	_count += 1
	if not cond:
		_failures.append(label)
		print("  [FAIL] " + label)

## 断言两值相等。
func eq(actual: Variant, expected: Variant, label: String) -> void:
	_count += 1
	if actual != expected:
		var msg := "%s（期望 %s，实际 %s）" % [label, expected, actual]
		_failures.append(msg)
		print("  [FAIL] " + msg)

## 汇总并打印本用例结果；返回是否全部通过。
func summary(case_name: String) -> bool:
	if _failures.is_empty():
		print("[PASS] %s（%d 项断言）" % [case_name, _count])
		return true
	print("[FAIL] %s：%d/%d 项失败" % [case_name, _failures.size(), _count])
	return false
