# plugin.gd
# 第三方插件范本入口脚本（example_mod）。
# 契约基类为 Plugin；生命周期回调按需重写即可。

extends Plugin

func get_metadata() -> Plugin.PluginMetadata:
	var metadata := Plugin.PluginMetadata.new()
	metadata.id = "example_mod"
	metadata.name = "示例插件"
	metadata.version = "1.0.0"
	metadata.author = "Framework Author"
	metadata.description = "演示插件的清单 / 契约 / 直播场景 / 热重载"
	metadata.provides = {
		"scenes": [
			{
				"id": "example_live_scene",
				"name": "示例直播场景",
				"type": "live",
				"scene": "scenes/live_scene.tscn",
				"description": "演示插件直播场景",
			}
		]
	}
	return metadata

func on_load() -> bool:
	print("[ExampleMod] 加载中...")
	return true

func on_enable() -> void:
	print("[ExampleMod] 已启用")

func on_before_reload() -> void:
	print("[ExampleMod] 即将热重载，保存状态")

func on_after_reload() -> void:
	print("[ExampleMod] 热重载完成，恢复状态")

func on_unload() -> void:
	print("[ExampleMod] 已卸载")