# event_bus.gd
# 全局事件总线：内核提供的唯一跨插件通信通道。
# 插件之间不应互相持有引用，而应通过事件总线发布 / 订阅，从而彻底解耦。

class_name EventBus
extends Node

## 通用事件：插件可发布任意命名事件，payload 为字典。
signal bus_event(event_name: String, payload: Dictionary)

## 常用领域事件（内置插件与第三方插件共享的约定事件）
signal player_changed(player_data: Dictionary)               # 当前选手变化
signal announcer_changed(announcer_data: Dictionary)         # 当前解说变化
signal scene_changed(from_scene: String, to_scene: String)   # 直播场景切换
signal data_reloaded(scope: String)                          # 数据重载（热重载）

## 发布一个通用事件。
func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	bus_event.emit(event_name, payload)