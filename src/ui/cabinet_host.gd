class_name CabinetHost
extends Control
## Presentation-only mini-game host contained inside a protected side lane.

var host_texture: Texture2D
var _portrait: TextureRect
var _elapsed: float = 0.0


func configure(texture: Texture2D, display_size: Vector2) -> void:
	host_texture = texture
	size = display_size
	if is_node_ready():
		_apply_texture()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = TextureRect.new()
	_portrait.name = "HostPortrait"
	_portrait.position = Vector2.ZERO
	_portrait.size = size
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_apply_texture()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if not MotionPolicy.allows_continuous_motion():
		return
	_elapsed += delta
	_portrait.position.y = roundf(sin(_elapsed * TAU / 4.2))


func portrait_texture() -> Texture2D:
	return host_texture


func visual_bounds() -> Rect2:
	return Rect2(position, size)


func _apply_texture() -> void:
	if _portrait != null:
		_portrait.texture = host_texture


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced and _portrait != null:
		_elapsed = 0.0
		_portrait.position = Vector2.ZERO
