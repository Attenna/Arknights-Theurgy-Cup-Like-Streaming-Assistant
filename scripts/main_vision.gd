extends Node2D

signal countdown_finished

func _ready() -> void:
	var countdown_label := get_node_or_null("Label")
	if countdown_label != null and countdown_label.has_signal("countdown_finished"):
		if not countdown_label.countdown_finished.is_connected(_on_countdown_finished):
			countdown_label.countdown_finished.connect(_on_countdown_finished)

# 由控制面板的“开始倒计时”按钮触发，启动主视觉倒计时
func start_countdown() -> void:
	var countdown_label := get_node_or_null("Label")
	if countdown_label != null and countdown_label.has_method("start"):
		countdown_label.start()

func _on_countdown_finished() -> void:
	countdown_finished.emit()
