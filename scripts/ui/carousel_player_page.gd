extends Node2D

# 轮播选手页：单方选手信息（红/蓝方通用同一份 scene，通过 side 属性区分）。
#
# 节点结构是"扁平 + 离散"：所有 UI 元素都是 Page 的直接子节点，
# 程序员可以单独选中/移动任意一个，不需要改父容器布局。
#
# 路由协议：本脚本的 _ready() 会把所有"显示型"子节点的名称加上
#   "Red" / "Blue" 前缀（依赖 main.gd 的 _node_is_red_blue() 分流规则）。
#   .tscn 中的节点名是"语义名"（如 PlayerUsername），不写前缀；
#   这样编辑器里看到的就是程序员写的名字，方便二次排版。
#
# 增删显示字段的方法：
#   1. 在 .tscn 中拖入 PlayerFieldLabel / PlayerImageField（§6.10 零散控件），
#      设置 Field/Kind/StaticLabel 等 [Export] 参数。
#   2. 设 position 到目标位置即可，无需改本脚本或 main.gd。

@export var side: String = "Red"
@export var title: String = "红方当前选手"

# 不参与红蓝路由的"元数据"节点：标题与背景。
const _META_NAMES: Array[StringName] = [&"TitleLabel", &"Background"]

func _ready() -> void:
	# 1) 标题文字 + 红蓝主题色
	var title_label := get_node_or_null("TitleLabel")
	if title_label is Label:
		title_label.text = title
		var accent := Color(1, 0.3, 0.3) if side == "Red" else Color(0.223, 0.571, 0.771)
		title_label.add_theme_color_override("font_color", accent)

	# 2) 给所有"显示型"子节点加 side 前缀，让 main.gd 按红蓝方路由数据
	for child in get_children():
		if child == title_label:
			continue
		if child.name in _META_NAMES:
			continue
		var nm := str(child.name)
		if not nm.begins_with("Red") and not nm.begins_with("Blue"):
			child.name = StringName(side + nm)
