# csv_codec.gd
# 轻量 CSV 解析 / 编码工具（插件内部，无 class_name）。
# 支持：UTF-8 BOM、逗号 / 分号 / 制表符自动识别、双引号包裹、
# 引号内逗号与换行、"" 转义、CRLF / LF，以及全空行剔除。

extends RefCounted

## 解析 CSV 文本，返回二维数组（行 → 单元格字符串）。
static func parse(text: String) -> Array:
	if text.is_empty():
		return []
	if text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var delimiter := detect_delimiter(text)
	var rows: Array = []
	var row: Array = []
	var field := ""
	var in_quotes := false
	var i := 0
	var length := text.length()
	while i < length:
		var ch := text[i]
		if in_quotes:
			if ch == "\"":
				if i + 1 < length and text[i + 1] == "\"":
					field += "\""
					i += 2
				else:
					in_quotes = false
					i += 1
			else:
				field += ch
				i += 1
		elif ch == "\"":
			in_quotes = true
			i += 1
		elif ch == delimiter:
			row.append(field)
			field = ""
			i += 1
		elif ch == "\r" or ch == "\n":
			if ch == "\r" and i + 1 < length and text[i + 1] == "\n":
				i += 1
			row.append(field)
			field = ""
			rows.append(row)
			row = []
			i += 1
		else:
			field += ch
			i += 1
	if not field.is_empty() or not row.is_empty():
		row.append(field)
		rows.append(row)
	var result: Array = []
	for parsed_row in rows:
		var has_value := false
		for cell in parsed_row:
			if not str(cell).strip_edges().is_empty():
				has_value = true
				break
		if has_value:
			result.append(parsed_row)
	return result

## 根据表头行自动识别分隔符（逗号 / 分号 / 制表符），无法判断时用逗号。
static func detect_delimiter(text: String) -> String:
	var counts := {",": 0, ";": 0, "\t": 0}
	var in_quotes := false
	var length := text.length()
	var i := 0
	while i < length:
		var ch := text[i]
		if ch == "\"":
			in_quotes = not in_quotes
		elif not in_quotes:
			if ch == "\r" or ch == "\n":
				break
			if counts.has(ch):
				counts[ch] += 1
		i += 1
	var best := ","
	var best_count := 0
	for delimiter in counts:
		if int(counts[delimiter]) > best_count:
			best_count = int(counts[delimiter])
			best = delimiter
	return best

## 编码二维数组为逗号分隔 CSV（末尾换行）。
static func encode(rows: Array) -> String:
	var lines: Array[String] = []
	for row in rows:
		var cells: PackedStringArray = []
		for cell in row:
			cells.append(escape_cell(str(cell)))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"

## 单元格转义：含逗号 / 引号 / 换行时用双引号包裹，内部引号翻倍。
static func escape_cell(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
		return "\"" + value.replace("\"", "\"\"") + "\""
	return value
