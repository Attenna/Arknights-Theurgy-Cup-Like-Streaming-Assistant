extends Node2D

const FONT_PATH := "res://assets/fonts/AlimamaDongFangDaKai-Regular.ttf"
const SCROLL_SPEED := 80.0  # 像素/秒

@onready var credits_content: VBoxContainer = $CreditsLayer/CreditsContent

var sections := [
	{
		"title": "后勤部：（排名不分先后）",
		"names": [
			"winp", "蝶々ココア", "空白xyz", "月下独舞", "七凉旧梦", "FolwiSh",
			"George_78643", "海马赖人", "老师见状-", "舟遥遥", "何呵12138",
			"ReapEr收歌机", "泠穗", "被卷王痛击", "莫急ovo", "柒璐LUNA", "Weedy",
			"莫格街的黑猫", "认真想过的名字", "撒胡", "！传说中的不知道"
		]
	},
	{
		"title": "正式比赛选手：（排名不分先后）",
		"names": [
			"撒胡", "想喝橙汁的莫急", "何呵 12138", "二阶堂絮雨", "句号", "星野爱音",
			"真是强强又度度啊", "认真想好的名字", "欲与昔 Almond 爱", "除却＃1807",
			"空白 xyz", "泠穗", "黎澈", "yeyubk", "名字就不要了吧", "Rh2S", "cod",
			"欠妥", "刘谦", "江上舟遥遥", "午夜梦游 Zzz", "散光美竹兰", "柒璐 LUNA", "QAQ"
		]
	},
	{
		"title": "娱乐赛选手：（排名不分先后）",
		"names": [
			"搞么子", "Circle.", "抓小三", "星曦"
		]
	},
]

func _ready() -> void:
	build_credits()
	await get_tree().process_frame
	start_scroll()

func build_credits() -> void:
	var font: Font = load(FONT_PATH)
	# 深蓝色，接近黑色
	var dark_blue := Color(0.04, 0.07, 0.18, 1)
	credits_content.add_theme_font_override("font", font)

	for section in sections:
		var title_label := Label.new()
		title_label.text = section.title
		title_label.add_theme_font_override("font", font)
		title_label.add_theme_font_size_override("font_size", 96)
		title_label.add_theme_color_override("font_color", dark_blue)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		credits_content.add_child(title_label)

		for name in section.names:
			var name_label := Label.new()
			name_label.text = name
			name_label.add_theme_font_override("font", font)
			name_label.add_theme_font_size_override("font_size", 80)
			name_label.add_theme_color_override("font_color", dark_blue)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			credits_content.add_child(name_label)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 50)
		credits_content.add_child(spacer)

# 从屏幕底部向上滚动，直到整块完全移出顶部后停止
func start_scroll() -> void:
	var viewport_height := get_viewport_rect().size.y
	var content_height := credits_content.size.y
	credits_content.position.y = viewport_height

	var distance := viewport_height + content_height
	var duration := distance / SCROLL_SPEED

	var tween := create_tween()
	tween.tween_property(credits_content, "position:y", -content_height, duration)
