extends Control

# 轮播页：单方选手信息。实例化 StreamPlayerCard 作为展示主体。
# 卡片节点会在 _ready 中重命名为含 red/blue 的名字，
# 这样 main.gd 的上台选手路由（按节点名 red/blue 分流）会自动把对应方选手数据投递到此卡片。

@export var side: String = "Red"
@export var title: String = "红方当前选手"

var _card: Control
var _title_label: Label

func _ready():
	_title_label = get_node_or_null("TitleLabel")
	_card = get_node_or_null("PlayerCard")

	if _title_label:
		_title_label.text = title
		var accent = Color(1, 0.3, 0.3) if side == "Red" else Color(0.223, 0.571, 0.771)
		_title_label.add_theme_color_override("font_color", accent)

	if _card:
		# 重命名使 main.gd 按红/蓝方路由上台选手到此卡片（卡片实现 Display(dict)）
		_card.name = side + "PlayerCard"
		if _card.has_method("DisplayWithMode"):
			_card.DisplayWithMode(side)
