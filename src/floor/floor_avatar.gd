class_name FloorAvatar
extends Node2D
## Resolution-independent casino guest animated from real movement distance.

const GUEST_TEXTURE := preload("res://assets/production/characters/casino_guest_eight_direction.png")
const GUEST_CELL_SIZE := Vector2(336, 376)
const GUEST_SCALE: float = 0.170
const WALK_CYCLE_DISTANCE: float = 58.0
const MIRRORED_POSE: Array[int] = [0, 7, 6, 5, 4, 3, 2, 1]
var facing := Vector2.DOWN
var walk_phase: float = 0.0
var walk_frame: int = 0
var idle_time: float = 0.0
var is_walking: bool = false
var _sprite: Sprite2D
var _atlas: AtlasTexture
var facing_index: int = 0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "HiggsfieldCasinoGuest"
	_atlas = AtlasTexture.new()
	_atlas.atlas = GUEST_TEXTURE
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.scale = Vector2.ONE * GUEST_SCALE
	_sprite.position = Vector2(0, -19)
	add_child(_sprite)
	_update_facing_texture()
	set_process(true)
	queue_redraw()


func set_motion(displacement: Vector2) -> void:
	is_walking = displacement.length_squared() > 0.01
	if is_walking:
		facing = displacement.normalized()
		walk_phase = fmod(
			walk_phase + displacement.length() / WALK_CYCLE_DISTANCE * TAU,
			TAU
		)
		walk_frame = int(walk_phase >= PI)
		idle_time = 0.0
		_update_facing_texture()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_walking:
		idle_time += delta
		queue_redraw()
	var stride := sin(walk_phase) if is_walking else 0.0
	var breathe := sin(idle_time * 2.6) * 0.008 if not is_walking else 0.0
	_sprite.rotation = stride * 0.006
	_sprite.scale = Vector2(GUEST_SCALE, GUEST_SCALE * (1.0 + breathe))
	_sprite.position = Vector2(stride * 0.25, -19.0 - absf(stride) * 0.45)
	is_walking = false


func _update_facing_texture() -> void:
	var clockwise_from_north := atan2(facing.x, -facing.y)
	facing_index = posmod(int(round(clockwise_from_north / (PI / 4.0))), 8)
	var pose_index := facing_index
	_sprite.flip_h = walk_frame == 1
	if walk_frame == 1:
		pose_index = MIRRORED_POSE[facing_index]
	var cell := Vector2i(pose_index % 4, pose_index / 4)
	_atlas.region = Rect2(Vector2(cell) * GUEST_CELL_SIZE, GUEST_CELL_SIZE)


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
