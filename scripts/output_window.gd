extends Window

@export var viewport_path: NodePath = NodePath("/root/Main/OutputViewport")
@export var auto_hide_on_start: bool = true
@export var debug_mode: bool = false

var texture_rect: TextureRect = null
var viewport_texture: ViewportTexture = null

func _ready():
	texture_rect = get_node_or_null("TextureRect")
	if not texture_rect:
		texture_rect = TextureRect.new()
		texture_rect.name = "TextureRect"
		texture_rect.layout_mode = 3
		texture_rect.anchors_preset = 15
		texture_rect.anchor_right = 1.0
		texture_rect.anchor_bottom = 1.0
		texture_rect.grow_horizontal = 2
		texture_rect.grow_vertical = 2
		texture_rect.stretch_mode = 3
		add_child(texture_rect)
	
	setup_viewport_texture()
	
	if auto_hide_on_start and not debug_mode:
		hide_off_screen()
	else:
		show_on_screen()
	
	print("OutputWindow ready, debug mode: " + str(debug_mode))

func setup_viewport_texture():
	var viewport_node = get_node_or_null(viewport_path)
	if viewport_node is SubViewport:
		viewport_texture = ViewportTexture.new()
		viewport_texture.viewport_path = viewport_path
		texture_rect.texture = viewport_texture
		print("ViewportTexture set to: " + str(viewport_path))
	else:
		print("Warning: Cannot find SubViewport at path: " + str(viewport_path))

func hide_off_screen():
	var screen_size = DisplayServer.screen_get_size()
	var offset = 100
	position = Vector2(-screen_size.x - offset, -screen_size.y - offset)
	print("OutputWindow hidden at: " + str(position))

func show_on_screen():
	var screen_size = DisplayServer.screen_get_size()
	position = Vector2(
		(screen_size.x - size.x) / 2,
		(screen_size.y - size.y) / 2
	)
	print("OutputWindow shown at: " + str(position))

func set_target_viewport(new_viewport_path: NodePath):
	viewport_path = new_viewport_path
	setup_viewport_texture()

func capture_screenshot() -> Image:
	if viewport_texture:
		return viewport_texture.get_image()
	return null

func get_current_frame() -> Texture2D:
	return viewport_texture
