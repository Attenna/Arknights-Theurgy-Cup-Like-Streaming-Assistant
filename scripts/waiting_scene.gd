extends Node2D

# 子场景引用
@onready var info_container: Control = get_node_or_null("InfoContainer")
var score_board_scene: PackedScene = preload("res://scene/ui/score_board.tscn")
var player_info_scene: PackedScene = preload("res://scene/ui/player_info.tscn")
var announcer_info_scene: PackedScene = preload("res://scene/ui/announcer_info.tscn")

# 轮播控制
var current_scene_index: int = 0
var scenes: Array[PackedScene] = []
var current_instance: Node = null
var switch_timer: Timer
var tween: Tween
var is_switching: bool = false

# 轮播间隔（秒）
const SWITCH_INTERVAL: float = 6.0
const FADE_DURATION: float = 0.5

func _ready() -> void:
	print("WaitingScene: 初始化候场轮播系统")
	
	# 设置场景数组（包含解说信息）
	scenes = [score_board_scene, player_info_scene, announcer_info_scene]
	
	# 创建并配置计时器
	switch_timer = Timer.new()
	switch_timer.wait_time = SWITCH_INTERVAL
	switch_timer.timeout.connect(_switch_to_next_scene)
	switch_timer.autostart = true
	add_child(switch_timer)
	
	# 显示第一个场景
	_show_scene(current_scene_index)

func _show_scene(index: int) -> void:
	"""显示指定索引的场景，带淡入淡出效果"""
	if not info_container:
		print("WaitingScene: InfoContainer 节点未找到")
		return
	
	if index < 0 or index >= scenes.size():
		print("WaitingScene: 场景索引超出范围: ", index)
		return
	
	if is_switching:
		print("WaitingScene: 正在切换中，跳过本次切换")
		return
	
	is_switching = true
	
	# 创建Tween如果不存在
	if not tween:
		tween = create_tween()
	else:
		tween.kill()
		tween = create_tween()
	
	# 如果有当前实例，先淡出
	if current_instance:
		print("WaitingScene: 开始淡出当前场景")
		tween.tween_property(current_instance, "modulate:a", 0.0, FADE_DURATION)
		await tween.finished
		
		# 移除当前实例
		current_instance.queue_free()
		current_instance = null
	
	# 实例化新场景
	var scene_to_load = scenes[index]
	if scene_to_load:
		current_instance = scene_to_load.instantiate()
		if current_instance:
			# 设置初始透明度为0
			current_instance.modulate.a = 0.0
			info_container.add_child(current_instance)
			print("WaitingScene: 已加载场景 ", index, " - ", scene_to_load.resource_path)
			
			# 淡入新场景
			print("WaitingScene: 开始淡入新场景")
			tween = create_tween()
			tween.tween_property(current_instance, "modulate:a", 1.0, FADE_DURATION)
			await tween.finished
		else:
			print("WaitingScene: 场景实例化失败: ", scene_to_load.resource_path)
	else:
		print("WaitingScene: 场景资源无效，索引: ", index)
	
	is_switching = false
	print("WaitingScene: 场景切换完成")

func _switch_to_next_scene() -> void:
	"""切换到下一个场景"""
	if is_switching:
		print("WaitingScene: 正在切换中，跳过本次自动切换")
		return
		
	current_scene_index = (current_scene_index + 1) % scenes.size()
	print("WaitingScene: 切换到场景 ", current_scene_index)
	_show_scene(current_scene_index)

func add_scene(scene: PackedScene) -> void:
	"""添加新的场景到轮播列表"""
	if scene:
		scenes.append(scene)
		print("WaitingScene: 添加新场景到轮播: ", scene.resource_path)

func remove_scene(scene: PackedScene) -> void:
	"""从轮播列表移除场景"""
	var index = scenes.find(scene)
	if index != -1:
		scenes.remove_at(index)
		print("WaitingScene: 从轮播移除场景: ", scene.resource_path)
		
		# 如果移除的是当前显示的场景，切换到下一个
		if current_scene_index >= scenes.size():
			current_scene_index = 0
		
		# 确保有场景可显示
		if scenes.size() > 0:
			_show_scene(current_scene_index)
		else:
			# 如果没有场景了，清空当前实例
			if current_instance:
				if tween:
					tween.kill()
					tween = create_tween()
				tween.tween_property(current_instance, "modulate:a", 0.0, FADE_DURATION)
				await tween.finished
				current_instance.queue_free()
				current_instance = null
			print("WaitingScene: 所有场景已移除")

func set_switch_interval(interval: float) -> void:
	"""设置轮播间隔时间"""
	if switch_timer:
		switch_timer.wait_time = interval
		print("WaitingScene: 轮播间隔设置为 ", interval, " 秒")

func pause_rotation() -> void:
	"""暂停轮播"""
	if switch_timer:
		switch_timer.paused = true
		print("WaitingScene: 轮播已暂停")

func resume_rotation() -> void:
	"""恢复轮播"""
	if switch_timer:
		switch_timer.paused = false
		print("WaitingScene: 轮播已恢复")

func force_switch_to_scene(index: int) -> void:
	"""强制切换到指定场景"""
	if index >= 0 and index < scenes.size():
		if is_switching:
			print("WaitingScene: 正在切换中，跳过强制切换")
			return
			
		current_scene_index = index
		_show_scene(current_scene_index)
		# 重置计时器
		if switch_timer:
			switch_timer.stop()
			switch_timer.start()
		print("WaitingScene: 强制切换到场景 ", index)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
