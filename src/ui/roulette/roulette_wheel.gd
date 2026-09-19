class_name RouletteWheel
extends Node2D
## Painted single-zero wheel: a static mahogany bowl, a rotating rotor and a
## numbered pocket ring drawn in code in exact European order, plus an ivory
## ball. The pocket is decided by RouletteMath before spin_to() is called; the
## animation only steers the ball into that pocket and never picks one.

signal ball_landed(pocket: int)

const BOWL := preload("res://assets/production/roulette/roulette_wheel_bowl.png")
const ROTOR := preload("res://assets/production/roulette/roulette_wheel_rotor.png")
## Radii as fractions of the painted bowl radius (the source is 1000 px). The
## bowl art paints its own pocket ring between 0.50 and 0.66 with the frets at
## 0.58, so the drawn ring sits exactly on it instead of floating inside it.
const BOWL_SOURCE_RADIUS: float = 1000.0
const RING_INNER: float = 0.500
const RING_OUTER: float = 0.660
const POCKET_REST: float = 0.580
## The ball runs the painted wood track just inside the brass rim.
const TRACK: float = 0.780
const SPIN_SECONDS: float = 4.6
const IDLE_SPEED: float = 0.22
const SPIN_SPEED: float = 1.9
const BALL_TURNS: float = 5.0
const REDUCED_CUE_SECONDS: float = 0.45

var radius: float = 120.0
## Vertical foreshortening of the painted bowl (1.0 = seen from straight above).
var squash: float = 1.0
var wheel_order: PackedInt32Array
var math: RouletteMath
var rotor_angle: float = 0.0
var ball_pocket: int = 0
var spinning: bool = false
var _ring: Node2D
var _rotor_sprite: Sprite2D
var _rotor_holder: Node2D
var _ball: Node2D
var _elapsed: float = 0.0
var _beta_start: float = 0.0
var _beta_target: float = 0.0
var _ball_radius_fraction: float = POCKET_REST
var _ball_beta: float = 0.0
var _cue_left: float = 0.0


## `squash` tilts the bowl into perspective. It is applied to the painted
## sprites and folded into every computed position, so the ball stays round and
## the pocket numbers stay upright instead of being squashed with the node.
func setup(table_math: RouletteMath, display_radius: float, wheel_squash: float = 1.0) -> void:
	math = table_math
	wheel_order = math.paytable.wheel_order
	radius = display_radius
	squash = clampf(wheel_squash, 0.1, 1.0)
	var bowl := Sprite2D.new()
	bowl.name = "WheelBowl"
	bowl.texture = BOWL
	bowl.scale = Vector2(1.0, squash) * radius / BOWL_SOURCE_RADIUS
	bowl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(bowl)
	_ring = Node2D.new()
	_ring.name = "PocketRing"
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	# The holder squashes an upright rotating sprite, so the rotor turns as an
	# ellipse rather than a spinning oval.
	_rotor_holder = Node2D.new()
	_rotor_holder.name = "RotorHolder"
	_rotor_holder.scale = Vector2(1.0, squash)
	add_child(_rotor_holder)
	_rotor_sprite = Sprite2D.new()
	_rotor_sprite.name = "WheelRotor"
	_rotor_sprite.texture = ROTOR
	_rotor_sprite.scale = Vector2.ONE * radius / BOWL_SOURCE_RADIUS
	_rotor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rotor_holder.add_child(_rotor_sprite)
	_ball = Node2D.new()
	_ball.name = "Ball"
	_ball.draw.connect(_draw_ball)
	add_child(_ball)
	_ball_beta = pocket_angle(ball_pocket)
	_place_ball()
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


## Angle of a pocket's centre in the rotor's frame (clockwise from the top).
func pocket_angle(pocket: int) -> float:
	var index := wheel_order.find(pocket)
	return TAU * float(maxi(index, 0)) / float(wheel_order.size())


## Starts the ball toward `pocket`. Reduced motion lands it at once and shows
## one bounded brass cue around the pocket instead of the travel.
func spin_to(pocket: int) -> void:
	ball_pocket = pocket
	_beta_target = pocket_angle(pocket)
	if MotionPolicy.is_reduced():
		_land()
		_cue_left = REDUCED_CUE_SECONDS
		set_process(true)
		return
	_elapsed = 0.0
	# The ball runs against the rotor: several turns, ending exactly on target.
	var current := fposmod(_ball_beta, TAU)
	var turns := BALL_TURNS * TAU + fposmod(current - _beta_target, TAU)
	_beta_start = _beta_target + turns
	spinning = true
	set_process(true)


## Snaps any travel to its final state (reduced-motion switch or teardown).
func settle() -> void:
	if spinning:
		_land()
	_cue_left = 0.0
	_ring.queue_redraw()


func _on_motion_preference_changed(_reduced: bool) -> void:
	settle()
	set_process(true)


func is_animating() -> bool:
	return spinning or _cue_left > 0.0


func _ready() -> void:
	set_process(not MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if _cue_left > 0.0:
		_cue_left = maxf(0.0, _cue_left - delta)
		_ring.queue_redraw()
	if MotionPolicy.is_reduced():
		if _cue_left <= 0.0:
			set_process(false)
		return
	var speed := IDLE_SPEED
	if spinning:
		_elapsed += delta
		var progress := clampf(_elapsed / SPIN_SECONDS, 0.0, 1.0)
		speed = lerpf(SPIN_SPEED, IDLE_SPEED * 1.6, progress)
		_advance_ball(progress)
		if progress >= 1.0:
			_land()
	rotor_angle = fposmod(rotor_angle + speed * delta, TAU)
	_rotor_sprite.rotation = rotor_angle
	_ring.queue_redraw()
	_place_ball()


## Relative angle eases out onto the target; the ball drops from the track to
## the pocket ring over the last third with two decaying hops.
func _advance_ball(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_ball_beta = lerpf(_beta_start, _beta_target, eased)
	var drop := clampf((progress - 0.58) / 0.3, 0.0, 1.0)
	var hop := sin(drop * PI * 3.0) * (1.0 - drop) * 0.06
	_ball_radius_fraction = lerpf(TRACK, POCKET_REST, drop * drop * (3.0 - 2.0 * drop)) + hop


func _land() -> void:
	var was_spinning := spinning
	spinning = false
	_ball_beta = _beta_target
	_ball_radius_fraction = POCKET_REST
	_place_ball()
	if was_spinning or MotionPolicy.is_reduced():
		ball_landed.emit(ball_pocket)


func _place_ball() -> void:
	if _ball == null:
		return
	_ball.position = _at(rotor_angle + _ball_beta, _ball_radius_fraction)
	_ball.queue_redraw()


## A point on the wheel: `fraction` of the radius at `angle`, foreshortened.
func _at(angle: float, fraction: float) -> Vector2:
	var reach := radius * fraction
	return Vector2(sin(angle) * reach, -cos(angle) * reach * squash)


## Screen-space centre of a pocket (used by tests and the cue).
func pocket_position(pocket: int) -> Vector2:
	return _at(rotor_angle + pocket_angle(pocket), POCKET_REST)


func _draw_ring() -> void:
	var count := wheel_order.size()
	var step := TAU / float(count)
	for index: int in range(count):
		var number := wheel_order[index]
		var start := rotor_angle + step * (float(index) - 0.5)
		var points := PackedVector2Array()
		for sample: int in range(5):
			points.append(_at(start + step * float(sample) / 4.0, RING_OUTER))
		for sample: int in range(4, -1, -1):
			points.append(_at(start + step * float(sample) / 4.0, RING_INNER))
		_ring.draw_colored_polygon(points, RouletteStyle.pocket_color(number, math))
		_ring.draw_line(
			_at(start, RING_INNER), _at(start, RING_OUTER), RouletteStyle.BRASS, 1.0, true
		)
	# Brass frets bound the painted ring; the numbers stay upright so they read
	# at a glance instead of tipping over with the perspective.
	_draw_ellipse(RING_OUTER, RouletteStyle.BRASS, 1.6)
	_draw_ellipse(RING_INNER, Color(RouletteStyle.BRASS, 0.55), 1.0)
	for index: int in range(count):
		var mid := rotor_angle + step * float(index)
		var label_at := _at(mid, (RING_INNER + RING_OUTER) * 0.5)
		RouletteStyle.draw_centered(
			_ring, str(wheel_order[index]), label_at, 9, RouletteStyle.IVORY
		)
	if _cue_left > 0.0:
		var alpha := clampf(_cue_left / REDUCED_CUE_SECONDS, 0.0, 1.0)
		var ink := Color(RouletteStyle.BRASS_BRIGHT, alpha)
		var cue := pocket_position(ball_pocket)
		var wide := radius * 0.075
		_ring.draw_arc(cue, wide, 0.0, TAU, 24, ink, 2.0, true)


## An ellipse at `fraction` of the radius, drawn as the foreshortened circle.
func _draw_ellipse(fraction: float, ink: Color, width: float) -> void:
	var points := PackedVector2Array()
	for step: int in range(97):
		points.append(_at(TAU * float(step) / 96.0, fraction))
	_ring.draw_polyline(points, ink, width, true)


func _draw_ball() -> void:
	var ball_size := maxf(3.5, radius * 0.036)
	_ball.draw_circle(Vector2(0.8, 1.2), ball_size, Color(0, 0, 0, 0.45))
	_ball.draw_circle(Vector2.ZERO, ball_size, Color("f4efe4"))
	_ball.draw_circle(Vector2(-ball_size * 0.35, -ball_size * 0.35), ball_size * 0.38, Color.WHITE)
