# plugin.gd —— 插件入口模板
#
# ══════════ 协作三铁律（违者必出 bug，细则见 framework/docs/架构演进路线.md）══════════
# 1. 插件不引用插件：禁 preload/load 其它插件脚本，禁跨插件 get_node（含 ../xxx）。
#    协作只走：EventBus 事件 / plugin.json provides 声明 / DataService 共享数据 /
#    控制面板 mount_panel 挂载约定（control_panel_base 组）。
# 2. 服务只从访问层获取：经基类 getter（get_event_bus / get_scene_director / …）
#    或 self.context 取内核服务，禁止硬编码内核 autoload 节点路径（ADR-0001）；
#    非 Plugin 派生脚本用 PluginContext.for_node(self)。
# 3. 事件名 / 数据字段名必须常量化：统一进 EventCatalog.gd / DataKeys.gd，
#    禁止裸字符串事件名；新事件先登记目录再使用。
# ═════════════════════════════════════════════════════════════════════════════
#
# 使用：复制整个 _template 目录到 mods/<你的插件名>/，plugin.json.example 改名
# plugin.json 并修改 id 等字段，删除本段注释即可。

extends Plugin

const PLUGIN_ID := "my_plugin"

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = PLUGIN_ID
	metadata.name = "我的插件"
	metadata.description = "从 _template 复制的示例插件"
	return metadata

func on_load() -> bool:
	return true

func on_enable() -> void:
	print("[%s] 已启用" % PLUGIN_ID)

func on_disable() -> void:
	pass

func on_before_reload() -> void:
	pass

func on_after_reload() -> void:
	pass

func on_unload() -> void:
	pass
