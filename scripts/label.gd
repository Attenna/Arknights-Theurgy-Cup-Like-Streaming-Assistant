extends Label

# 总倒计时时长：10分钟 = 600秒
var total_time: float = 600.0
var remain_time: float = 600.0

func _ready() -> void:
    update_display()

func _process(delta: float) -> void:
    if remain_time > 0:
        remain_time -= delta
        if remain_time < 0:
            remain_time = 0
        update_display()

func update_display() -> void:
    var total_sec: int = int(floor(remain_time))
    var mins: int = total_sec / 60
    var secs: int = total_sec % 60
    text = "%02d %02d" % [mins, secs]
    
    # 更新shader的fill_progress参数（从上到下填充）
    var fill_progress: float = 1.0 - (remain_time / total_time)
    if material is ShaderMaterial:
        material.set_shader_parameter("fill_progress", fill_progress)

# 重置倒计时
func reset_timer():
    remain_time = total_time
    update_display()