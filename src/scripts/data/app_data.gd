extends Node

# 游戏可执行文件所在的目录路径
var exe_dir: String

func _ready():
    # 获取当前可执行文件的路径
    var exe_path = OS.get_executable_path()
    # 提取目录部分
    exe_dir = exe_path.get_base_dir()
    
    # 打印调试信息（发布时可移除）
    print("Executable path: ", exe_path)
    print("Executable directory: ", exe_dir)

    # 首次运行时播种示例数据到用户目录
    seed_userdata_if_missing()

# 提供一个方法方便访问exe目录
func get_exe_dir() -> String:
    return exe_dir

# 提供用户数据目录（user://）
func get_user_dir() -> String:
    return OS.get_user_data_dir()

# 首次运行时把仓库自带的示例数据播种到用户数据目录
func seed_userdata_if_missing() -> void:
    if DirAccess.dir_exists_absolute("user://userdata"):
        return
    if not DirAccess.dir_exists_absolute("res://userdata"):
        return
    _copy_dir_recursive("res://userdata", "user://userdata")

# 递归复制目录（用于播种示例数据）
func _copy_dir_recursive(src_dir: String, dst_dir: String) -> void:
    var err := DirAccess.make_dir_recursive_absolute(dst_dir)
    if err != OK and err != ERR_ALREADY_EXISTS:
        push_warning("创建用户目录失败: %s (错误码 %d)" % [dst_dir, err])
        return
    var dir := DirAccess.open(src_dir)
    if dir == null:
        push_warning("无法打开源目录: %s" % src_dir)
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if entry.begins_with("."):
            entry = dir.get_next()
            continue
        var src_path := src_dir.path_join(entry)
        var dst_path := dst_dir.path_join(entry)
        if dir.current_is_dir():
            _copy_dir_recursive(src_path, dst_path)
        else:
            # 跳过 0 字节占位文件：避免播种出无法解析的空 JSON
            if FileAccess.get_file_as_bytes(src_path).size() == 0:
                entry = dir.get_next()
                continue
            var content := FileAccess.get_file_as_bytes(src_path)
            var out := FileAccess.open(dst_path, FileAccess.WRITE)
            if out == null:
                push_warning("无法写入文件: %s" % dst_path)
            else:
                out.store_buffer(content)
                out.close()
        entry = dir.get_next()
    dir.list_dir_end()