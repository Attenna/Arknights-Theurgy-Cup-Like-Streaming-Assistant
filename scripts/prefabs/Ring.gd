extends Node2D

# 节点旋转速度（度/秒）
@export var node_rotation_speed: float = 90.0

# 纹理固定角度（度），可以在编辑器调整
@export var texture_fixed_angle: float = 0.0

# 获取子节点和材质
@onready var ring_sprite: Sprite2D = $RingSprite
@onready var ring_material: ShaderMaterial = ring_sprite.material

func _process(delta: float) -> void:
	# 仅旋转节点本身
	ring_sprite.rotation += deg_to_rad(node_rotation_speed) * delta
	
	# 将固定角度传递给Shader（纹理不旋转）
	if ring_material:
		ring_material.set_shader_parameter("color_texture_sample_degrees", texture_fixed_angle)
