# control_panel.gd —— 控制面板基底（根节点 Window）。
# 职责：
#   1. 启动 / 自身重建时，全量装载 registry 中 slot="control_panel" 的二级面板；
#   2. 提供 mount_panel / unmount_panel（幂等），供二级面板插件主动挂载 / 卸载。
# 二级面板插件约定：
#   - plugin.json 的 provides.panels 声明 slot="control_panel"；
#   - on_enable / on_after_reload 时查找组 "control_panel_base" 并调用 mount_panel；
#   - on_disable / on_unload 时调用 unmount_panel。

extends Window

const PANEL_SLOT := "control_panel"

@onready var slots: VBoxContainer = $Margin/PanelSlots

func _ready() -> void:
	add_to_group("control_panel_base")
	# deferred：等待外部 add_child 完成布局后再装载二级面板。
	_mount_all.call_deferred()

## 装载一个二级面板（幂等：同 id 先卸载旧的再装载）。
func mount_panel(panel_id: String, packed: PackedScene, display_name: String = "") -> bool:
	if packed == null:
		push_warning("[control_panel_base] mount_panel 收到空场景: %s" % panel_id)
		return false
	unmount_panel(panel_id)
	var inst := packed.instantiate()
	inst.name = panel_id
	inst.set_meta("panel_id", panel_id)
	if inst is Control and not display_name.is_empty():
		inst.tooltip_text = display_name
	slots.add_child(inst)
	print("[control_panel_base] 已装载二级面板: %s" % panel_id)
	return true

## 卸载指定 id 的二级面板（幂等）。
func unmount_panel(panel_id: String) -> void:
	for child in slots.get_children():
		if str(child.get_meta("panel_id", child.name)) == panel_id:
			child.queue_free()

## 全量装载当前注册在 PANEL_SLOT 下的所有面板（启动 / 基底自身重建时的兜底）。
func _mount_all() -> void:
	var kernel := get_node_or_null("/root/Kernel")
	if kernel == null or kernel.plugin_registry == null:
		print("[control_panel_base] 内核不可用，跳过二级面板装载")
		return
	for entry in kernel.plugin_registry.get_panels_by_slot(PANEL_SLOT):
		var packed = entry.get("packed")
		if packed == null:
			var res_path := str(entry.get("res_path", ""))
			if not res_path.is_empty():
				packed = load(res_path)
		mount_panel(str(entry.get("id", "")), packed, str(entry.get("name", "")))
