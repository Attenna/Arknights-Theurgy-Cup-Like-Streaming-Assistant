# file_watcher.gd
# 轮询式文件变更检测：Godot 运行时未暴露 OS 级文件监听 API，
# 因此采用"定时扫描 + mtime / 目录项比对"来发现变更，作为热重载的触发源。

class_name FileWatcher
extends Node

signal files_changed(paths: Array)

var poll_interval_ms: int = 500

var _enabled: bool = false
var _watch_paths: Array = []      # 待监听的文件 / 目录（res:// 或绝对路径）
var _snapshot: Dictionary = {}    # 文件绝对路径 -> 修改时间
var _timer: Timer = null

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = float(poll_interval_ms) / 1000.0
	_timer.autostart = false
	_timer.one_shot = false
	_timer.timeout.connect(_poll)
	add_child(_timer)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		# 开启时重建初始快照，避免把已有文件误判为"变更"。
		_snapshot = _take_snapshot()
		if _timer:
			_timer.start()
	else:
		if _timer:
			_timer.stop()

func is_enabled() -> bool:
	return _enabled

func set_poll_interval(ms: int) -> void:
	poll_interval_ms = max(50, ms)
	if _timer:
		_timer.wait_time = float(poll_interval_ms) / 1000.0

## 新增监听路径（文件或目录），并把其当前状态并入快照以免误报。
func watch_path(path: String) -> void:
	if path.is_empty() or _watch_paths.has(path):
		return
	_watch_paths.append(path)
	var fresh: Dictionary = {}
	_collect(path, fresh)
	for key in fresh.keys():
		_snapshot[key] = fresh[key]

func unwatch_path(path: String) -> void:
	_watch_paths.erase(path)
	var abs_path := _to_abs(path)
	for key in _snapshot.keys():
		if key == abs_path or key.begins_with(abs_path):
			_snapshot.erase(key)

func clear_watch_paths() -> void:
	_watch_paths.clear()
	_snapshot.clear()

func _poll() -> void:
	if not _enabled:
		return
	var changed := _detect_changes()
	if not changed.is_empty():
		files_changed.emit(changed)

# ── 内部实现 ─────────────────────────────────────────────────────────────────

func _detect_changes() -> Array:
	var current := _take_snapshot()
	var changed: Array = []
	for path in current.keys():
		if not _snapshot.has(path) or _snapshot[path] != current[path]:
			changed.append(path)
	for path in _snapshot.keys():
		if not current.has(path):
			changed.append(path) # 被删除的文件同样算作变更
	_snapshot = current
	return changed

func _take_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for path in _watch_paths:
		_collect(path, snap)
	return snap

## 递归收集路径下的文件及其修改时间（目录会被展开）。
func _collect(path: String, snap: Dictionary) -> void:
	var abs_path := _to_abs(path)
	if DirAccess.dir_exists_absolute(abs_path):
		var dir := DirAccess.open(abs_path)
		if dir == null:
			return
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not entry.begins_with("."):
				_collect(abs_path.path_join(entry), snap)
			entry = dir.get_next()
		dir.list_dir_end()
	elif FileAccess.file_exists(abs_path):
		snap[abs_path] = FileAccess.get_modified_time(abs_path)

func _to_abs(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path