extends TextureRect

# 解说员名单显示管理
# 监听解说员选择确认并显示当前解说员

# 文件路径
var current_announcer_data_path: String

# UI节点引用
@onready var announcers_list_label: Label = get_node_or_null("AnnouncersList")

# 数据存储
var current_confirmed_announcers: Array = []

# 事件总线引用（_exit_tree 精确退订用，避免场景切换后订阅残留）
var _event_bus: EventBus = null
# 数据访问统一走 DataService（兼容 v1 信封与旧版裸格式）
var _data_service: DataService = null

func _ready() -> void:
	# 初始化路径变量
	current_announcer_data_path = AppData.get_user_dir() + "/userdata/announcers/current_announcer.json"

	# 订阅内核契约事件（铁律1/2/3：插件协作只走 EventBus，服务经 PluginContext 获取）
	var ctx := PluginContext.for_node(self)
	_event_bus = ctx.event_bus
	_data_service = ctx.data_service
	if _event_bus:
		_event_bus.subscribe(EventCatalog.ANNOUNCER_CHANGED, _on_announcer_confirmed, &"streaming_arena")
		_event_bus.subscribe(EventCatalog.DATA_RELOADED, _on_data_reloaded, &"streaming_arena")

	# 初始加载当前解说员数据
	_load_current_announcer_data()

	# 更新显示
	_update_announcers_display()

func _exit_tree() -> void:
	# 节点随场景销毁时精确退订本节点回调，杜绝订阅表残留死条目
	if _event_bus != null:
		_event_bus.unsubscribe(EventCatalog.ANNOUNCER_CHANGED, _on_announcer_confirmed)
		_event_bus.unsubscribe(EventCatalog.DATA_RELOADED, _on_data_reloaded)

func _on_data_reloaded(_payload: Dictionary) -> void:
	# 数据重载 / 当前解说被清空时，从 DataService 重读并刷新显示
	_load_current_announcer_data()
	_update_announcers_display()

func _on_announcer_confirmed(announcer_data: Dictionary) -> void:
	# 处理解说员确认信号
	print("🎯 接收到解说员确认信号: " + str(announcer_data))
	
	# 契约事件负载为单个解说实体（含 name）；旧格式为 {"announcers": [...]} 列表
	if announcer_data.has(DataKeys.ANNOUNCER_NAME):
		var name_str := str(announcer_data.get(DataKeys.ANNOUNCER_NAME, ""))
		current_confirmed_announcers = [] if name_str.is_empty() else [name_str]
		_update_announcers_display()
		return
	if announcer_data.has("announcers") and announcer_data["announcers"] is Array:
		# 新格式 {"announcers": [...], "count": 3, "timestamp": ...}
		var announcers_array = announcer_data["announcers"]
		current_confirmed_announcers = []
		
		for announcer in announcers_array:
			if announcer is Dictionary and announcer.has(DataKeys.ANNOUNCER_NAME):
				current_confirmed_announcers.append(announcer[DataKeys.ANNOUNCER_NAME])
		
		print("📋 从信号提取的解说员: " + str(current_confirmed_announcers))
		
		# 更新显示
		_update_announcers_display()
	else:
		# 如果信号数据格式不正确，尝试从文件加载
		print("⚠️ 信号数据格式不正确，尝试从文件加载..")
		_load_current_announcer_data()
		_update_announcers_display()

func _load_current_announcer_data() -> void:
	# 从 DataService 读取当前解说（兼容 v1 信封与旧版裸格式）
	if _data_service == null:
		current_confirmed_announcers = []
		return
	var announcer := _data_service.get_current_announcer()
	var name_str := str(announcer.get(DataKeys.ANNOUNCER_NAME, ""))
	current_confirmed_announcers = [] if name_str.is_empty() else [name_str]
	print("Loaded " + str(current_confirmed_announcers.size()) + " confirmed announcer(s): " + str(current_confirmed_announcers))

func _update_announcers_display() -> void:
	# 更新解说员名单显示
	if not announcers_list_label:
		print("Warning: AnnouncersList label not found")
		return
	
	print("Updating announcers display...")
	
	if current_confirmed_announcers.is_empty():
		announcers_list_label.text = "暂无解说员"
		return
	
	# 生成解说员名单文本
	var display_text = _generate_announcers_text()
	announcers_list_label.text = display_text
	
	print("Announcers display updated: " + str(current_confirmed_announcers.size()) + " announcer(s)")

func _generate_announcers_text() -> String:
	# 生成解说员名单显示文本
	var text_parts = []
	
	# current_confirmed_announcers 是字符串数组，直接使用
	for announcer_name in current_confirmed_announcers:
		if announcer_name and announcer_name != "":
			text_parts.append(announcer_name)
	
	# 格式：四个空格)(名字)(两个空格)|(两个空格)(名字)…
	return "    " + "  |  ".join(text_parts)

# 公共API方法
func refresh_announcers_display() -> void:
	# 外部调用的刷新接口
	_load_current_announcer_data()
	_update_announcers_display()

func get_current_announcers() -> Array:
	# 获取当前解说员数据
	return current_confirmed_announcers

func debug_announcers_data() -> void:
	# 调试解说员数据
	print("🔍 调试解说员数据")
	print("  文件路径: " + current_announcer_data_path)
	print("  文件存在: " + str(FileAccess.file_exists(current_announcer_data_path)))
	print("  解说员数量: " + str(current_confirmed_announcers.size()))
	
	if not current_confirmed_announcers.is_empty():
		print("  📋 解说员列表:")
		for i in range(current_confirmed_announcers.size()):
			var announcer_name = current_confirmed_announcers[i]
			print("    " + str(i + 1) + ". " + str(announcer_name))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
