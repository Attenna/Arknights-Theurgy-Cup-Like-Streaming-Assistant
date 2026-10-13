# plugin.gd
# 场景管理面板插件（scene_manager_panel）—— 二级插件示例。
# 依赖 control_panel_base：把自己提供的面板挂载到基底的控制面板上。
# 挂载约定：
#   - on_enable / on_after_reload → 在组 "control_panel_base" 中查找基底并 mount_panel；
#     基底尚未创建时（启动早期）静默跳过，基底 _ready 的全量装载会兜底；
#   - on_disable / on_unload → unmount_panel。

extends Plugin

const PANEL_ID := "scene_manager_panel"
const BASE_GROUP := "control_panel_base"
const PANEL_SLOT := "control_panel"

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = PANEL_ID
	metadata.name = "场景管理面板"
	metadata.description = "二级面板：在控制面板基底上列出全部直播场景供切换"
	return metadata

func on_enable() -> void:
	_mount()
	print("[scene_manager_panel] 已启用")

func on_disable() -> void:
	_unmount()

func on_after_reload() -> void:
	_mount()

func on_unload() -> void:
	_unmount()

func _mount() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var base: Node = tree.get_first_node_in_group(BASE_GROUP)
	if base == null or not base.has_method("mount_panel"):
		# 基底面板尚未创建（main 壳未 ready）——由基底 _ready 全量装载兜底。
		return
	var kernel := get_node_or_null("/root/Kernel")
	if kernel == null or kernel.plugin_registry == null:
		return
	for entry in kernel.plugin_registry.get_panels_by_slot(PANEL_SLOT):
		if str(entry.get("id", "")) != PANEL_ID:
			continue
		var packed = entry.get("packed")
		if packed != null:
			base.mount_panel(PANEL_ID, packed, str(entry.get("name", "场景管理")))
		return

func _unmount() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var base: Node = tree.get_first_node_in_group(BASE_GROUP)
	if base != null and base.has_method("unmount_panel"):
		base.unmount_panel(PANEL_ID)
