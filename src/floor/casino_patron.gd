class_name CasinoPatron
extends Node2D
## Presentation-only casino-floor patron with a quiet, phase-staggered idle gesture.
##
## Patrons deliberately have no collision or domain references. They live inside the
## floor art's already-blocked furniture silhouettes and only add ambient motion.

const GUEST_TEXTURE := preload("res://assets/production/characters/casino_guest_walk_32.png")
const GUEST_CELL_SIZE := Vector2(221.75, 221.75)
const PROFILE_TINTS: Array[Color] = [
	Color("ffd9dc"),
	Color("d7f5df"),
	Color("d9e5ff"),
]
const PROFILE_ACCENTS: Array[Color] = [
	Color("d4495f"),
	Color("36a879"),
	Color("5f86d9"),
]

var profile_index: int = 0
var phase_offset: float = 0.0
var gesture_interval: float = 3.0
var gesture_strength: float = 0.0
var elapsed: float = 0.0
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _rest_position := Vector2(0, -19)


func configure(profile: int, phase: float) -> void:
	profile_index = posmod(profile, PROFILE_TINTS.size())
	phase_offset = maxf(0.0, phase)
	# Each guest has a distinct cadence, all within the requested 2–5 second range.
	gesture_interval = 2.6 + float(profile_index) * 0.85
	if is_node_ready():
		_apply_profile()


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "PatronPortrait"
	_atlas = AtlasTexture.new()
	_atlas.atlas = GUEST_TEXTURE
	# Profiles face different directions and use relaxed contact/passing poses.
	var columns: Array[int] = [5, 3, 4]
	var frames: Array[int] = [0, 2, 1]
	_atlas.region = Rect2(
		Vector2(columns[profile_index], frames[profile_index]) * GUEST_CELL_SIZE,
		GUEST_CELL_SIZE
	)
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.scale = Vector2.ONE * 0.285
	_sprite.position = _rest_position
	add_child(_sprite)
	_apply_profile()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	var cycle_time := fmod(elapsed + phase_offset, gesture_interval)
	# A brief ease-shaped gesture followed by a long, calm resting beat.
	var gesture_duration := 0.72
	gesture_strength = sin(cycle_time / gesture_duration * PI) if cycle_time < gesture_duration else 0.0
	var breath := sin((elapsed + phase_offset) * 1.35) * 0.006
	match profile_index:
		0: # raises a drink / greets a passing guest
			_sprite.position = _rest_position + Vector2(0, -gesture_strength * 2.2)
			_sprite.rotation = gesture_strength * 0.018
		1: # glances toward the nearby table
			_sprite.position = _rest_position + Vector2(gesture_strength * 1.8, 0)
			_sprite.rotation = -gesture_strength * 0.025
		_: # small approving nod
			_sprite.position = _rest_position + Vector2(0, gesture_strength * 1.5)
			_sprite.rotation = sin(cycle_time / gesture_duration * TAU) * 0.012 if cycle_time < gesture_duration else 0.0
	_sprite.scale = Vector2(0.285 * (1.0 - breath), 0.285 * (1.0 + breath))
	queue_redraw()


func _apply_profile() -> void:
	if _sprite == null:
		return
	_sprite.modulate = PROFILE_TINTS[profile_index]


func _draw() -> void:
	_draw_ellipse(Vector2(0, 8), Vector2(12.0, 4.0), Color("08060775"))
	var accent := PROFILE_ACCENTS[profile_index]
	# Small floor-side props distinguish the silhouettes without adding obstruction.
	match profile_index:
		0:
			draw_line(Vector2(12, -4), Vector2(12, -12 - gesture_strength * 3.0), accent, 2.0, true)
			draw_circle(Vector2(12, -13 - gesture_strength * 3.0), 2.5, Color("f2d58dcc"))
		1:
			draw_arc(Vector2(-11, -5), 5.0, PI, TAU, 12, accent, 2.0, true)
			draw_circle(Vector2(-11, -5), 1.8, Color("f2c84b"))
		_:
			draw_circle(Vector2(12, 4), 4.0 + gesture_strength, Color(accent, 0.8))
			draw_circle(Vector2(12, 4), 1.4, Color("f2c84b"))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
