extends Node

signal transition_requested(target_scene_id: String)

func request_transition(scene_id: String):
	emit_signal("transition_requested", scene_id)
	print("SceneManager: Transition requested for scene: ", scene_id)
