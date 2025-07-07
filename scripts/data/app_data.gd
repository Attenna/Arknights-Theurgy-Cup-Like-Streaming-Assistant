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

# 提供一个方法方便访问exe目录
func get_exe_dir() -> String:
    return exe_dir