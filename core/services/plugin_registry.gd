# plugin_registry.gd
# 能力索引：记录每个插件声明提供的能力（场景 / 面板 / 数据）。
# 供内核与 UI（导航面板、控制面板）按能力查询，内核无需认识具体插件。

class_name PluginRegistry
extends Node

# plugin_id -> { "plugin_id", "name", "path", "provides": Dictionary }
var _plugins: Dictionary = {}

func register_plugin(plugin_id: String, provides: Dictionary, meta: Dictionary = {}) -> void:
	_plugins[plugin_id] = {
		"plugin_id": plugin_id,
		"name": meta.get("name", plugin_id),
		"path": meta.get("path", ""),
		"provides": provides,
	}

func unregister_plugin(plugin_id: String) -> void:
	_plugins.erase(plugin_id)

func has_plugin(plugin_id: String) -> bool:
	return _plugins.has(plugin_id)

func get_plugin(plugin_id: String) -> Dictionary:
	return _plugins.get(plugin_id, {})

func get_plugin_ids() -> Array:
	return _plugins.keys()

## 按 slot 返回面板能力，并按 order 升序排序。
func get_panels_by_slot(slot: String) -> Array:
	var result: Array = []
	for plugin_id in _plugins.keys():
		var provides: Dictionary = _plugins[plugin_id].provides
		for panel in provides.get("panels", []):
			if str(panel.get("slot", "")) == slot:
				result.append(panel)
	result.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return result

func get_all_panels() -> Array:
	var result: Array = []
	for plugin_id in _plugins.keys():
		var provides: Dictionary = _plugins[plugin_id].provides
		result.append_array(provides.get("panels", []))
	return result