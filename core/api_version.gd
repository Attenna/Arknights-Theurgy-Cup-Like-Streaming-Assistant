# core/api_version.gd
# 内核 API 契约版本（详见 framework/docs/api-version.md）。
#
# 插件在 plugin.json 的 api_version 中声明兼容范围；PluginManager 在加载前校验，
# 不兼容即阻塞（硬错误，不是警告）。
#
# 版本：三段 semver（major.minor.patch）。
# 范围：空白分隔的比较式（如 ">=2.0.0 <3.0.0"）；裸版本 "2.0.0" 等价于
#       ">=2.0.0 <3.0.0"（同 major，且不低于声明版本）。

class_name ApiVersion
extends RefCounted

## 当前内核 API 契约版本。破坏性变更升 major；向后兼容新增升 minor；修正升 patch。
const CURRENT := "2.0.0"

## 解析 "major.minor.patch"；非法返回空字典。
static func parse(text: String) -> Dictionary:
	var value := text.strip_edges()
	if value.begins_with("v"):
		value = value.substr(1)
	var parts := value.split(".", true)
	if parts.size() != 3:
		return {}
	var numbers: Array[int] = []
	for part in parts:
		if not part.is_valid_int():
			return {}
		var number := int(part)
		if number < 0:
			return {}
		numbers.append(number)
	return {"major": numbers[0], "minor": numbers[1], "patch": numbers[2]}

## 比较两个已解析版本：a < b 返回 -1，相等 0，a > b 返回 1。
static func compare(a: Dictionary, b: Dictionary) -> int:
	for key in ["major", "minor", "patch"]:
		var left := int(a.get(key, 0))
		var right := int(b.get(key, 0))
		if left != right:
			return 1 if left > right else -1
	return 0

## 插件声明范围是否兼容当前内核版本。
## 空声明、非法范围、不满足任一比较式均返回 false（调用方据此阻塞加载）。
static func is_compatible(declared: String, core_version: String = CURRENT) -> bool:
	var core := parse(core_version)
	if core.is_empty():
		return false
	var text := declared.strip_edges()
	if text.is_empty():
		return false
	if text.find(">") < 0 and text.find("<") < 0 and text.find("=") < 0:
		var exact := parse(text)
		if exact.is_empty():
			return false
		return int(core["major"]) == int(exact["major"]) and compare(core, exact) >= 0
	for token in text.split(" ", false):
		var op := _operator(token)
		if op.is_empty():
			return false
		var version := parse(token.substr(op.length()))
		if version.is_empty():
			return false
		var result := compare(core, version)
		match op:
			">=":
				if result < 0:
					return false
			">":
				if result <= 0:
					return false
			"<=":
				if result > 0:
					return false
			"<":
				if result >= 0:
					return false
			"=":
				if result != 0:
					return false
	return true

static func _operator(token: String) -> String:
	for op in [">=", "<=", ">", "<", "="]:
		if token.begins_with(op):
			return op
	return ""
