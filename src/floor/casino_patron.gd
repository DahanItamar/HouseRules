class_name CasinoPatron
extends Node2D
## Presentation-only casino-floor patron animated from authored atlas poses.
##
## Patrons have no collision or domain references. They live inside the floor art's
## already-blocked furniture zones and cycle through production character poses.

const WalkAtlas := preload("res://src/floor/character_walk_atlas.gd")
const GUEST_TEXTURE: Texture2D = preload(
	"res://assets/production/characters/casino_guest_walk_integer.png"
)
const PROFILE_COLUMNS: Array[int] = [5, 3, 4]
const PROFILE_REST_FRAMES: Array[int] = [0, 2, 1]
const GESTURE_POSES: Array[Array] = [[0, 1, 2, 1], [2, 3, 0, 3], [1, 2, 3, 2]]

var profile_index: int = 0
var phase_offset: float = 0.0
var gesture_interval: float = 3.0
var gesture_strength: float = 0.0
var elapsed: float = 0.0
var gesture_frame: int = 0
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _sprite_rest_position := Vector2(0, -19)


func configure(profile: int, phase: float) -> void:
	profile_index = posmod(profile, PROFILE_COLUMNS.size())
	phase_offset = maxf(0.0, phase)
	# Each guest has a distinct cadence, all within the requested 2-5 second range.
	gesture_interval = 2.6 + float(profile_index) * 0.85
	if is_node_ready():
		_apply_profile()
		_set_gesture_frame(PROFILE_REST_FRAMES[profile_index])


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
	# A short deliberate gesture followed by a long calm rest keeps the floor readable.
	var gesture_duration := 0.78
	gesture_strength = (
		sin(cycle_time / gesture_duration * PI) if cycle_time < gesture_duration else 0.0
	)
	if cycle_time < gesture_duration:
		var progress := clampf(cycle_time / gesture_duration, 0.0, 0.999)
		var pose_index := mini(int(floor(progress * 4.0)), 3)
		_set_gesture_frame(int(GESTURE_POSES[profile_index][pose_index]))
	else:
		_set_gesture_frame(PROFILE_REST_FRAMES[profile_index])
	_apply_sprite_pose(cycle_time)
	queue_redraw()


func authored_pose_region() -> Rect2:
	return _atlas.region if _atlas != null else Rect2()


func _build_authored_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "PatronPortrait"
	_atlas = AtlasTexture.new()
	_atlas.atlas = GUEST_TEXTURE
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE * 0.285
	_sprite.position = _sprite_rest_position
	add_child(_sprite)
	_set_gesture_frame(PROFILE_REST_FRAMES[profile_index])


func _set_gesture_frame(frame: int) -> void:
	gesture_frame = posmod(frame, WalkAtlas.ROWS)
	if _atlas == null:
		return
	_atlas.region = Rect2(
		Vector2(Vector2i(PROFILE_COLUMNS[profile_index], gesture_frame) * WalkAtlas.CELL_SIZE),
		Vector2(WalkAtlas.CELL_SIZE)
	)


func _apply_sprite_pose(cycle_time: float) -> void:
	var breath := sin((elapsed + phase_offset) * 1.35) * 0.006
	_sprite.scale = Vector2(0.285 * (1.0 - breath), 0.285 * (1.0 + breath))
	match profile_index:
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
	_set_gesture_frame(PROFILE_REST_FRAMES[profile_index])
	if _sprite != null:
		_sprite.position = _sprite_rest_position
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE * 0.285
	queue_redraw()


func _apply_profile() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color("ffd9dc") if profile_index == 0 else Color.WHITE


func _draw() -> void:
	_draw_ellipse(Vector2(0, 8), Vector2(12.0, 4.0), Color("08060775"))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
