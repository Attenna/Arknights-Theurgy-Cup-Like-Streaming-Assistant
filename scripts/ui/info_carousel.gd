extends Control

# 信息轮播容器：实例化三个子场景（红方选手 / 蓝方选手 / 赛事排名），
# 按固定间隔自动切换，带淡入淡出。选手数据由 main.gd 自动路由到对应卡片，
# 排名数据由排名页自行向服务器拉取。

@export var interval: float = 6.0

const RED_PLAYER_PAGE = preload("res://scene/ui/carousel_player_page.tscn")
const BLUE_PLAYER_PAGE = preload("res://scene/ui/carousel_player_page.tscn")
const RANK_PAGE = preload("res://scene/ui/carousel_rank_page.tscn")

var _pages: Array = []
var _current: int = 0
var _timer: Timer

func _ready():
	_add_page(RED_PLAYER_PAGE, {"side": "Red", "title": "红方当前选手"})
	_add_page(BLUE_PLAYER_PAGE, {"side": "Blue", "title": "蓝方当前选手"})
	_add_page(RANK_PAGE, {})

	for i in range(_pages.size()):
		_pages[i].visible = (i == 0)
		_pages[i].modulate.a = 1.0 if i == 0 else 0.0

	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.autostart = true
	_timer.timeout.connect(_next)
	add_child(_timer)

func _add_page(scene: PackedScene, props: Dictionary):
	var page = scene.instantiate()
	for k in props:
		page.set(k, props[k])
	$PagesContainer.add_child(page)
	_pages.append(page)

func _next():
	if _pages.size() <= 1:
		return
	var old_idx = _current
	_current = (_current + 1) % _pages.size()
	var old_page = _pages[old_idx]
	var new_page = _pages[_current]

	new_page.visible = true
	new_page.modulate.a = 0.0

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(old_page, "modulate:a", 0.0, 0.4)
	tw.tween_property(new_page, "modulate:a", 1.0, 0.4)
	tw.chain().tween_callback(_hide_old.bind(old_page))

func _hide_old(old_page: Node):
	if is_instance_valid(old_page):
		old_page.visible = false
