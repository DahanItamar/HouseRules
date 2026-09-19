class_name CasinoPatron
extends Node2D
## Presentation-only floor guests with identities separate from the player avatar.

const PATRON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/production/characters/patrons/patron_emerald_woman.png"),
	preload("res://assets/production/characters/patrons/patron_gold_woman.png"),
	preload("res://assets/production/characters/patrons/patron_ruby_woman.png"),
	preload("res://assets/production/characters/patrons/patron_navy_man.png"),
	preload("res://assets/production/characters/patrons/patron_ivory_man.png"),
	preload("res://assets/production/characters/patrons/patron_velvet_man.png"),
	preload("res://assets/production/characters/patrons/patron_blonde_seated.png"),
	preload("res://assets/production/characters/patrons/patron_brunette_seated.png"),
	preload("res://assets/production/characters/patrons/patron_auburn_champagne.png"),
	preload("res://assets/production/characters/patrons/patron_tux_seated.png"),
]
const PROFILE_HEIGHTS: Array[float] = [54.0, 66.0, 54.0, 56.0, 56.0, 56.0, 54.0, 52.0, 54.0, 46.0]

var profile_index: int = 0
var phase_offset: float = 0.0
var gesture_interval: float = 3.0
var gesture_strength: float = 0.0
var elapsed: float = 0.0
var gesture_frame: int = 0
var faces_left: bool = false
var _sprite: Sprite2D
var _sprite_scale: float = 1.0
var _sprite_rest_position := Vector2.ZERO


func configure(profile: int, phase: float, face_left: bool = false) -> void:
	profile_index = posmod(profile, PATRON_TEXTURES.size())
	phase_offset = maxf(0.0, phase)
	faces_left = face_left
	gesture_interval = 2.6 + float(profile_index % 3) * 0.85
	if is_node_ready():
		_apply_profile()


func _ready() -> void:
	_build_authored_sprite()
	_apply_profile()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not MotionPolicy.allows_continuous_motion():
		return
	elapsed += delta
	var cycle_time := fmod(elapsed + phase_offset, gesture_interval)
	var gesture_duration := 0.78
	gesture_strength = (
		sin(cycle_time / gesture_duration * PI) if cycle_time < gesture_duration else 0.0
	)
	gesture_frame = mini(int(floor(cycle_time / gesture_duration * 4.0)), 3)
	_apply_sprite_pose(cycle_time)
	queue_redraw()


func portrait_texture() -> Texture2D:
	return _sprite.texture if _sprite != null else null


func authored_pose_region() -> Rect2:
	if _sprite == null or _sprite.texture == null:
		return Rect2()
	return Rect2(Vector2.ZERO, _sprite.texture.get_size())


func _build_authored_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "PatronPortrait"
	_sprite.texture = PATRON_TEXTURES[profile_index]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.flip_h = faces_left
	_sprite_scale = PROFILE_HEIGHTS[profile_index] / _sprite.texture.get_height()
	_sprite.scale = Vector2.ONE * _sprite_scale
	_sprite_rest_position = Vector2(0, 8.0 - PROFILE_HEIGHTS[profile_index] * 0.5)
	_sprite.position = _sprite_rest_position
	add_child(_sprite)


func _apply_sprite_pose(cycle_time: float) -> void:
	var breath := sin((elapsed + phase_offset) * 1.35) * 0.006
	_sprite.scale = Vector2(
		_sprite_scale * (1.0 - breath), _sprite_scale * (1.0 + breath)
	)
	match profile_index % 3:
		0:
			_sprite.position = _sprite_rest_position + Vector2(0, -gesture_strength * 2.2)
			_sprite.rotation = gesture_strength * 0.018
		1:
			_sprite.position = _sprite_rest_position + Vector2(gesture_strength * 1.8, 0)
			_sprite.rotation = -gesture_strength * 0.025
		_:
			_sprite.position = _sprite_rest_position + Vector2(0, gesture_strength * 1.5)
			_sprite.rotation = (
				sin(cycle_time / 0.78 * TAU) * 0.012 if cycle_time < 0.78 else 0.0
			)


func _apply_motion_preference(reduced: bool) -> void:
	if not reduced or _sprite == null:
		return
	elapsed = 0.0
	gesture_strength = 0.0
	gesture_frame = 0
	_sprite.position = _sprite_rest_position
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE * _sprite_scale
	queue_redraw()


func _apply_profile() -> void:
	if _sprite == null:
		return
	_sprite.texture = PATRON_TEXTURES[profile_index]
	_sprite.flip_h = faces_left
	_sprite_scale = PROFILE_HEIGHTS[profile_index] / _sprite.texture.get_height()
	_sprite_rest_position = Vector2(0, 8.0 - PROFILE_HEIGHTS[profile_index] * 0.5)
	_sprite.position = _sprite_rest_position
	_sprite.scale = Vector2.ONE * _sprite_scale


func _draw() -> void:
	_draw_ellipse(Vector2(0, 8), Vector2(12.0, 4.0), Color("08060775"))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
