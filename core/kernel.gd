# kernel.gd
# 内核入口（autoload 名：Kernel）。
# 职责：创建并连接核心服务、初始化插件管理器，然后把一切交给插件系统。
# 内核本身不含任何业务场景 —— 一切皆插件（Everything is a Plugin）。

extends Node

const CORE_VERSION := "2.0.0"

# 核心服务（均作为内核子节点存在，通过 Kernel.<service> 访问）
var event_bus: EventBus
var data_service: DataService
var scene_director: SceneDirector
var plugin_registry: PluginRegistry
var file_watcher: FileWatcher
var plugin_manager: PluginManager

func _ready() -> void:
	_create_services()
	_create_plugin_manager()
	print("[Kernel] 内核就绪（core %s）" % CORE_VERSION)

func _create_services() -> void:
	event_bus = EventBus.new()
	event_bus.name = "EventBus"
	add_child(event_bus)

	data_service = DataService.new()
	data_service.name = "DataService"
	add_child(data_service)

	scene_director = SceneDirector.new()
	scene_director.name = "SceneDirector"
	add_child(scene_director)

	plugin_registry = PluginRegistry.new()
	plugin_registry.name = "PluginRegistry"
	add_child(plugin_registry)

	file_watcher = FileWatcher.new()
	file_watcher.name = "FileWatcher"
	add_child(file_watcher)

	# 服务互连：数据与场景服务通过事件总线广播状态变化。
	data_service.event_bus = event_bus
	scene_director.event_bus = event_bus

func _create_plugin_manager() -> void:
	plugin_manager = PluginManager.new()
	plugin_manager.name = "PluginManager"
	add_child(plugin_manager)
	plugin_manager.setup(self)

## 全局快捷键：F5 重载全部插件（热重载手动触发）。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		if plugin_manager:
			plugin_manager.reload_all()
			get_viewport().set_input_as_handled()