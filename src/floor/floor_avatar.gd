class_name FloorAvatar
extends Node2D
## The player on the casino floor: a full-body walk atlas, phase-locked to the
## distance actually walked.
##
## CharacterWalkAtlas describes the active atlas (path, phases per cycle, idle
## frame, cycle distance). The frame comes from the distance walked, so the feet
## advance with the floor instead of on a timer, and a blocked walk (zero
## displacement after collision) does not animate in place. The frames carry
## their own body motion, so no procedural bob is added.

const WalkAtlas := preload("res://src/floor/character_walk_atlas.gd")
# Compatibility-facing size remains a Vector2; atlas math itself uses the
# integer-only CharacterWalkAtlas.CELL_SIZE.
const GUEST_CELL_SIZE := Vector2(240, 240)
const GUEST_SCALE: float = 0.29
## Feet sit on the node origin, which is also the avatar's depth-sort point.
## The atlas figure's lowest sole is 110 px below its 240 px cell centre.
const FOOT_OFFSET := Vector2(0, -110.0 * GUEST_SCALE)
## Screen distance of one full cycle (two steps) walking sideways at avatar
## scale 1, in virtual px.
const WALK_CYCLE_DISTANCE: float = WalkAtlas.CYCLE_DISTANCE
## A new facing only wins once travel leaves the current column's 45° wedge by
## this margin (radians), so sliding along a wall cannot flicker the facing.
const FACING_HYSTERESIS: float = 0.14
## Seconds per 45° when the body turns, so a reversal sweeps through the
## in-between facings instead of popping.
const TURN_STEP_TIME: float = 0.045
## The walk pose is held this long after the last movement, so one hitching
## frame or a momentary block never drops the walker into his standing pose.
const WALK_HOLD_TIME: float = 0.18
## Standing still this long resets the gait to the standing frame, so stepping
## off never pops mid-stride. A single slow frame is far under it, so the phase
## survives a hitch and the soles stay locked to the floor.
const STANDING_RESET_TIME: float = 0.3

var facing := Vector2.DOWN
## Cycle phase in radians (0..TAU) and the atlas row it selects.
var walk_phase: float = 0.0
var walk_frame: int = WalkAtlas.IDLE_ROW
## Full cycles walked; its fractional part is the phase.
var walk_cycles: float = 0.0
var idle_time: float = 0.0
var is_walking: bool = false
## Facing the walker is heading for (from real movement, with hysteresis).
var facing_index: int = 4
## Facing currently drawn; turns toward facing_index one column at a time.
var display_index: int = 4
## Room whose depth scale the avatar follows (see follow_room_scale()).
var room_layout: FloorRoomLayout
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _walk_hold: float = 0.0
var _turn_timer: float = 0.0
var _standing_time: float = INF


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "HiggsfieldCasinoGuest"
	_atlas = AtlasTexture.new()
	_atlas.atlas = load(WalkAtlas.ATLAS_PATH) as Texture2D
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE * GUEST_SCALE
	_sprite.position = FOOT_OFFSET
	add_child(_sprite)
	facing_index = WalkAtlas.direction_index(facing)
	display_index = facing_index
	_update_region()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	set_process(true)
	queue_redraw()


## `displacement` is the avatar's actual movement this frame in parent space
## (after collision), so a blocked walk leaves the frame unchanged.
func set_motion(displacement: Vector2) -> void:
	if displacement.length_squared() <= 0.01:
		return
	_apply_depth_scale()
	if _standing_time >= STANDING_RESET_TIME:
		# Step off from the standing frame so starting never pops a stride.
		walk_cycles = float(WalkAtlas.IDLE_ROW) / WalkAtlas.ROWS
	_standing_time = 0.0
	var local_distance := displacement.length() / maxf(absf(scale.x), 0.001)
	walk_cycles += local_distance / WalkAtlas.cycle_distance(displacement)
	var phase := fposmod(walk_cycles, 1.0)
	walk_phase = phase * TAU
	walk_frame = int(floor(phase * WalkAtlas.ROWS)) % WalkAtlas.ROWS
	facing = displacement.normalized()
	_update_facing(facing)
	is_walking = true
	_walk_hold = WALK_HOLD_TIME
	idle_time = 0.0
	_update_region()


## Scales the avatar with the room's depth: the painted adults of each room are
## larger or smaller at different screen heights, and the player matches them
## wherever he stands. Re-evaluated whenever the feet move.
func follow_room_scale(room: FloorRoomLayout) -> void:
	room_layout = room
	_apply_depth_scale()


func _apply_depth_scale() -> void:
	if room_layout != null:
		scale = Vector2.ONE * room_layout.avatar_scale_at(position.y)


func _process(delta: float) -> void:
	_apply_depth_scale()
	_walk_hold = maxf(0.0, _walk_hold - delta)
	is_walking = _walk_hold > 0.0
	if not is_walking:
		walk_frame = WalkAtlas.IDLE_ROW
		_standing_time += delta
		if MotionPolicy.allows_continuous_motion():
			idle_time += delta
	_advance_turn(delta)
	var breathe := 0.0
	if not is_walking and not MotionPolicy.is_reduced():
		breathe = sin(idle_time * 2.6) * 0.008
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(GUEST_SCALE, GUEST_SCALE * (1.0 + breathe))
	_sprite.position = FOOT_OFFSET
	_update_region()


func _apply_motion_preference(reduced: bool) -> void:
	if reduced and _sprite != null:
		idle_time = 0.0
		display_index = facing_index
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE * GUEST_SCALE
		_sprite.position = FOOT_OFFSET
		_update_region()
	queue_redraw()


## Picks the target facing with hysteresis around the 45° wedge boundaries.
## Stepping off, reduced motion and a one-wedge change show the new facing at
## once; a sharper turn while walking sweeps through the facings in between.
func _update_facing(direction: Vector2) -> void:
	var was_walking := is_walking
	var candidate := WalkAtlas.direction_index(direction)
	if candidate == facing_index:
		return
	var current := WalkAtlas.direction_vector(facing_index)
	if absf(current.angle_to(direction)) <= PI / 8.0 + FACING_HYSTERESIS:
		return
	facing_index = candidate
	var wedges := absi(posmod(facing_index - display_index + 4, 8) - 4)
	if not was_walking or wedges <= 1 or MotionPolicy.is_reduced():
		display_index = facing_index
		_turn_timer = 0.0


## Sweeps the drawn facing toward the target, one 45° column per step.
func _advance_turn(delta: float) -> void:
	if display_index == facing_index:
		_turn_timer = 0.0
		return
	if MotionPolicy.is_reduced():
		display_index = facing_index
		return
	_turn_timer += delta
	while _turn_timer >= TURN_STEP_TIME and display_index != facing_index:
		_turn_timer -= TURN_STEP_TIME
		var offset := posmod(facing_index - display_index + 4, 8) - 4
		display_index = posmod(display_index + (1 if offset > 0 else -1), 8)


func _update_region() -> void:
	if _sprite == null:
		return
	_sprite.flip_h = WalkAtlas.is_mirrored(display_index)
	var row := walk_frame if is_walking else WalkAtlas.IDLE_ROW
	_atlas.region = WalkAtlas.region(display_index, row)


func _draw() -> void:
	# Soft contact shadow under the feet.
	_draw_ellipse(Vector2(0, 0), Vector2(10.0, 3.5), Color("0806078f"))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
