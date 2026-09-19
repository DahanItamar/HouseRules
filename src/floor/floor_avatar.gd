class_name FloorAvatar
extends Node2D
## Resolution-independent casino guest animated from real movement distance.

const WalkAtlas := preload("res://src/floor/character_walk_atlas.gd")
const GUEST_TEXTURE: Texture2D = preload(
	"res://assets/production/characters/casino_guest_walk_integer.png"
)
# Compatibility-facing size remains a Vector2; atlas math itself uses the
# integer-only CharacterWalkAtlas.CELL_SIZE.
const GUEST_CELL_SIZE := Vector2(240, 240)
const GUEST_SCALE: float = 0.34
const WALK_CYCLE_DISTANCE: float = 64.0
var facing := Vector2.DOWN
var walk_phase: float = 0.0
var walk_frame: int = 0
var idle_time: float = 0.0
var is_walking: bool = false
var _sprite: Sprite2D
var _atlas: AtlasTexture
var facing_index: int = 0
var _walk_hold: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "HiggsfieldCasinoGuest"
	_atlas = AtlasTexture.new()
	_atlas.atlas = GUEST_TEXTURE
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE * GUEST_SCALE
	_sprite.position = Vector2(0, -19)
	add_child(_sprite)
	_update_facing_texture()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	set_process(true)
	queue_redraw()


func set_motion(displacement: Vector2) -> void:
	var moved := displacement.length_squared() > 0.01
	if moved:
		is_walking = true
		_walk_hold = 0.09
		facing = displacement.normalized()
		walk_phase = fmod(
			walk_phase + displacement.length() / WALK_CYCLE_DISTANCE * TAU,
			TAU
		)
		walk_frame = int(floor(walk_phase / (TAU / 4.0))) % 4
		idle_time = 0.0
		_update_facing_texture()
	queue_redraw()


func _process(delta: float) -> void:
	_walk_hold = maxf(0.0, _walk_hold - delta)
	is_walking = _walk_hold > 0.0
	if not is_walking and MotionPolicy.allows_continuous_motion():
		idle_time += delta
		queue_redraw()
	var reduced := MotionPolicy.is_reduced()
	var breathe := sin(idle_time * 2.6) * 0.008 if not is_walking and not reduced else 0.0
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(GUEST_SCALE, GUEST_SCALE * (1.0 + breathe))
	# The rendered gait comes from the photographed leg phases. Keeping the
	# anchor integer-stable prevents the old procedural sway from looking like
	# the character is sliding over the carpet.
	_sprite.position = Vector2(0, -23)


func _apply_motion_preference(reduced: bool) -> void:
	if reduced and _sprite != null:
		idle_time = 0.0
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE * GUEST_SCALE
		_sprite.position = Vector2(0, -23)
	queue_redraw()


func _update_facing_texture() -> void:
	facing_index = WalkAtlas.direction_index(facing)
	_sprite.flip_h = WalkAtlas.is_mirrored(facing_index)
	_atlas.region = WalkAtlas.region(facing_index, walk_frame)


func _draw() -> void:
	if _sprite != null:
		_draw_ellipse(Vector2(0, 8), Vector2(13.0, 4.5), Color("0806078f"))
		return
	var stride: float = sin(walk_phase) if is_walking else 0.0
	var bob: float = abs(sin(walk_phase)) * -1.4 if is_walking else sin(idle_time * 2.6) * 0.45
	var side: float = signf(facing.x) if absf(facing.x) > 0.2 else 1.0
	var profile: float = clampf(absf(facing.x), 0.0, 1.0)
	draw_set_transform(Vector2(0, bob))
	_draw_ellipse(Vector2(0, 8), Vector2(15.5, 5.5), Color("0806078f"))
	var left_foot := Vector2(-4.0 + stride * 3.2, 7.0)
	var right_foot := Vector2(4.0 - stride * 3.2, 7.0)
	draw_line(Vector2(-3, -1), left_foot, Color("17161a"), 5.0, true)
	draw_line(Vector2(3, -1), right_foot, Color("17161a"), 5.0, true)
	draw_line(left_foot, left_foot + Vector2(side * 3, 0), Color("080708"), 3.0, true)
	draw_line(right_foot, right_foot + Vector2(side * 3, 0), Color("080708"), 3.0, true)
	var arm_swing := stride * 3.0
	draw_line(Vector2(-7, -14), Vector2(-10, -3 + arm_swing), Color("681526"), 5.0, true)
	draw_line(Vector2(7, -14), Vector2(10, -3 - arm_swing), Color("681526"), 5.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-8, -16), Vector2(-10, -2), Vector2(-5, 2),
			Vector2(0, 0), Vector2(5, 2), Vector2(10, -2), Vector2(8, -16)
		]),
		Color("711827")
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-3, -16), Vector2(0, -8), Vector2(3, -16)]),
		Color("f1e8d8")
	)
	draw_line(Vector2(0, -15), Vector2(0, -1), Color("c8a34b"), 1.5, true)
	draw_circle(Vector2(0, -8), 1.4, Color("f2c84b"))
	draw_circle(Vector2(0, -22), 7.0, Color("e2b58f"))
	draw_arc(Vector2(0, -23), 6.6, PI, TAU, 18, Color("24171a"), 4.0, true)
	draw_circle(Vector2(side * (3.0 + profile), -21.0), 1.2, Color("e2b58f"))
	var eye_x := side * lerpf(1.5, 3.0, profile)
	draw_circle(Vector2(eye_x, -23), 0.8, Color("17161a"))
	draw_line(Vector2(-5, -16), Vector2(5, -16), Color("c8a34b"), 1.5, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
