# 解说员系统连接示例
# 如果自动连接不工作，可以在主场景脚本中手动连接

extends Node

@onready var announcer_editor = $AnnouncerEditor  # 解说员编辑器节点
@onready var now_announcer = $NowAnnouncer      # 解说员选择器节点

func _ready():
	# 手动连接解说员编辑器和选择器
	if announcer_editor and now_announcer:
		now_announcer.connect_to_editor(announcer_editor)
		print("Manually connected announcer editor and selector")
