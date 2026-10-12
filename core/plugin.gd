# plugin.gd
# 插件契约基类：一切皆插件（Everything is a Plugin）。
# 内置插件与第三方插件都通过本契约接入内核 —— 同一份清单、同一套生命周期。
#
# 由旧版 ModInterface 演进而来；ModInterface 仍作为兼容别名保留（见 mod_interface.gd）。

class_name Plugin
extends Node

# 插件生命周期状态机
enum PluginState {
	UNLOADED,   # 未加载
	LOADED,     # 已加载（能力尚未注册）
	ENABLED,    # 已启用（能力已注册，可被使用）
	DISABLED,   # 已禁用（能力已注销）
	RELOADING,  # 热重载中
	ERROR,      # 出错（可手动重试）
}

## 插件清单元数据（由 plugin.json 或 get_metadata() 提供）
class PluginMetadata:
	var id: String = ""
	var name: String = ""
	var version: String = "1.0.0"
	var author: String = ""
	var description: String = ""
	var api_version: String = "2.0.0"
	var dependencies: Array = []
	var load_priority: int = 0
	# 能力声明：{ "scenes": [...], "panels": [...], "data": ... }
	var provides: Dictionary = {}
	# 热重载监听路径（相对插件目录）
	var watch: Array = []

## 插件 -> 内核：插件自定义事件
signal plugin_event(plugin_id: String, event_name: String, event_data: Dictionary)

var state: int = PluginState.UNLOADED

# ── 元数据 ───────────────────────────────────────────────────────────────────

func get_metadata() -> PluginMetadata:
	var metadata := PluginMetadata.new()
	metadata.id = get_script().get_global_name()
	return metadata

func get_plugin_id() -> String:
	return get_metadata().id

# ── 生命周期（按需重写） ─────────────────────────────────────────────────────

## 加载：注册资源，勿做重活。返回 false 则中止加载。
func on_load() -> bool:
	return true

## 启用：注册能力、连接信号。
func on_enable() -> void:
	pass

## 禁用：断开信号、注销能力。
func on_disable() -> void:
	pass

## 热重载前：保存状态。
func on_before_reload() -> void:
	pass

## 热重载后：恢复状态。
func on_after_reload() -> void:
	pass

## 卸载：释放资源。
func on_unload() -> void:
	pass

# ── 内核访问入口 ─────────────────────────────────────────────────────────────

func get_kernel() -> Node:
	return get_node_or_null("/root/Kernel")

func get_event_bus() -> EventBus:
	var kernel := get_kernel()
	if kernel == null:
		return null
	return kernel.event_bus as EventBus

func get_data_service() -> DataService:
	var kernel := get_kernel()
	if kernel == null:
		return null
	return kernel.data_service as DataService

## 向内核发布一个插件事件。
func emit_plugin_event(event_name: String, data: Dictionary = {}) -> void:
	plugin_event.emit(get_plugin_id(), event_name, data)