# tests/test_docs_links.gd
# 文档链接契约测试（issue #36）：仓库内 Markdown 的相对链接与锚点必须有效。
# 只校验仓库内链接；http(s) / mailto / tel 一律跳过（CI 不访问外网）。
# 锚点按 GitHub 标题 slug 规则计算：小写、去标点、空白转连字符、保留 - 与 _。

extends TestCase

const ROOT_DOCS: Array[String] = [
	"res://README.md",
	"res://STRUCTURE.md",
	"res://AGENTS.md",
]
const DOCS_DIR := "res://framework/docs"

var _checked := 0

func run() -> bool:
	var files := _collect_docs()
	ok(files.size() >= 4, "收集到文档（%d 个）" % files.size())
	for path in files:
		_check_file(path)
	ok(_checked > 0, "至少校验到一条仓库内链接（%d 条）" % _checked)
	return summary("test_docs_links")

func _collect_docs() -> Array[String]:
	var result: Array[String] = []
	for path in ROOT_DOCS:
		if FileAccess.file_exists(path):
			result.append(path)
		else:
			ok(false, "根文档存在: " + path)
	_walk(DOCS_DIR, result)
	return result

func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		ok(false, "文档目录可读: " + dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var path := dir_path.path_join(entry)
			if dir.current_is_dir():
				_walk(path, out)
			elif entry.ends_with(".md"):
				out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _check_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		ok(false, "文档可读: " + path)
		return
	for link in _extract_links(text):
		_check_link(path, link)

## 提取行内链接目标；跳过围栏代码块内的内容。
func _extract_links(text: String) -> Array[String]:
	var kept := PackedStringArray()
	var in_fence := false
	for line in text.split("\n"):
		if line.strip_edges().begins_with("```"):
			in_fence = not in_fence
			continue
		if not in_fence:
			kept.append(line)
	var re := RegEx.new()
	if re.compile("\\]\\(([^)\\s]+)(?:\\s+\"[^\"]*\")?\\)") != OK:
		ok(false, "链接正则编译失败")
		return []
	var result: Array[String] = []
	for m in re.search_all("\n".join(kept)):
		result.append(m.get_string(1))
	return result

func _check_link(from_path: String, raw: String) -> void:
	var target := raw.strip_edges()
	if target.begins_with("<") and target.ends_with(">"):
		target = target.substr(1, target.length() - 2)
	var lower := target.to_lower()
	if lower.begins_with("http://") or lower.begins_with("https://") \
			or lower.begins_with("mailto:") or lower.begins_with("tel:"):
		return
	_checked += 1

	var hash_pos := target.find("#")
	var path_part := target.substr(0, hash_pos) if hash_pos >= 0 else target
	var fragment := target.substr(hash_pos + 1) if hash_pos >= 0 else ""
	path_part = _percent_decode(path_part)

	var resolved := from_path
	if not path_part.is_empty():
		resolved = from_path.get_base_dir().path_join(path_part).simplify_path()

	if path_part.ends_with("/"):
		var dir_probe := resolved.trim_suffix("/")
		ok(DirAccess.open(dir_probe) != null,
				"%s -> 目录存在: %s" % [from_path, target])
		return

	var exists := FileAccess.file_exists(resolved) or DirAccess.open(resolved) != null
	ok(exists, "%s -> 目标存在: %s" % [from_path, target])
	if not exists or fragment.is_empty() or not resolved.ends_with(".md"):
		return
	var slugs := _heading_slugs(FileAccess.get_file_as_string(resolved))
	ok(slugs.has(fragment), "%s -> 锚点存在: %s" % [from_path, target])

## 收集 Markdown 标题的 GitHub 风格锚点；跳过围栏代码块。
func _heading_slugs(md: String) -> Array[String]:
	var result: Array[String] = []
	var re := RegEx.new()
	if re.compile("^#{1,6}[ \t]+(.+?)[ \t]*$") != OK:
		ok(false, "标题正则编译失败")
		return result
	var in_fence := false
	for line in md.split("\n"):
		if line.strip_edges().begins_with("```"):
			in_fence = not in_fence
			continue
		if in_fence:
			continue
		var m := re.search(line)
		if m != null:
			result.append(_slug(m.get_string(1)))
	return result

## GitHub 标题 slug：小写、去标点、空白转连字符。
func _slug(title: String) -> String:
	var text := title.strip_edges()
	while text.ends_with("#"):
		text = text.substr(0, text.length() - 1).strip_edges()
	var drop := RegEx.new()
	if drop.compile("[^\\p{L}\\p{N}\\s_-]") != OK:
		ok(false, "slug 正则编译失败")
		return text.to_lower()
	text = drop.sub(text, "", true).to_lower()
	var spaces := RegEx.new()
	if spaces.compile("\\s+") == OK:
		text = spaces.sub(text, "-", true)
	return text

## 解码 %XX（例如中文路径被 URL 编码的情况）。
func _percent_decode(text: String) -> String:
	if not text.contains("%"):
		return text
	var bytes := PackedByteArray()
	var i := 0
	while i < text.length():
		if text[i] == "%" and i + 2 < text.length():
			bytes.append(("0x" + text.substr(i + 1, 2)).hex_to_int())
			i += 3
		else:
			bytes.append_array(text[i].to_utf8_buffer())
			i += 1
	return bytes.get_string_from_utf8()
