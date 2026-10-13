# plugin_context.gd
# 插件服务访问层（ADR-0001，issue #2）。
#
# 插件获取内核服务**只走本层**，禁止在插件代码中硬编码内核 autoload 节点路径（CI 禁令3）。
# 两种获取方式：
#   1. Plugin 派生插件：直接用基类注入的 `context`（PluginManager 实例化时注入）
#      或基类便捷 getter（get_event_bus / get_scene_director / …）；
#   2. 非 Plugin 派生脚本（面板 UI、场景根节点等）：
#      `PluginContext.for_node(self)` —— 经内核入组名查找，不含任何节点路径字符串。
#
# 内核在 `_ready()` 中 add_to_group(KERNEL_GROUP)；autoload 先于主场景与插件加载就绪。

class_name PluginContext
extends RefCounted

## 内核入组名（core/kernel.gd 中 add_to_group，禁散落硬编码）。
const KERNEL_GROUP := "kernel"

var kernel: Node = null
var event_bus: EventBus = null
var data_service: DataService = null
var scene_director: SceneDirector = null
var plugin_registry: PluginRegistry = null
var file_watcher: FileWatcher = null
# 用 Node 而非 PluginManager，避免与 plugin_manager.gd 形成 class_name 循环依赖。
var plugin_manager: Node = null
var core_version: String = ""

func _init(p_kernel: Node = null) -> void:
	kernel = p_kernel
	if kernel == null:
		return
	event_bus = kernel.get("event_bus") as EventBus
	data_service = kernel.get("data_service") as DataService
	scene_director = kernel.get("scene_director") as SceneDirector
	plugin_registry = kernel.get("plugin_registry") as PluginRegistry
	file_watcher = kernel.get("file_watcher") as FileWatcher
	plugin_manager = kernel.get("plugin_manager")
	core_version = str(kernel.get_script().get_script_constant_map().get("CORE_VERSION", ""))

## 非 Plugin 派生脚本的兜底入口：按内核入组名查找并构造上下文。
## 内核不存在（未启动 / 已退出）时各服务属性为 null，调用方按空安全处理。
static func for_node(node: Node) -> PluginContext:
	var found: Node = null
	if node != null:
		var tree := node.get_tree()
		if tree != null:
			found = tree.get_first_node_in_group(KERNEL_GROUP)
	return PluginContext.new(found)