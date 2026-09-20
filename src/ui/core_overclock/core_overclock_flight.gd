class_name CoreOverclockFlight
extends Node2D
## The parrot of Corsair's Reach, and the line she draws behind her.
##
## This is the cabinet's multiplier made visible. The bird climbs an exponential
## curve from the bottom-left corner of the chart, and the glowing trail is
## simply where she has already been: the line is drawn live, point by point, to
## wherever the run has reached. She is the only thing on the curve -- there is
## no ship and no water, because a single object climbing a line is what a crash
## game is, and anything else on the canvas competes with the number.
##
## Nothing here reads or decides anything about the round. The cabinet hands it
## one number -- how far along the run is, 0 to 1 -- and everything else is
## geometry.
##
## `SHAPE` is how hard the curve bends: flat at the start so the first seconds
## are readable, steepening without bound so a long run feels like it is getting
## away from you.

const SHAPE: float = 2.35
## Points along the drawn curve. Enough to read as a curve, few enough to cost
## nothing.
const SEGMENTS: int = 96
## How thick the trail is drawn, in canvas px.
const TRAIL_HEIGHT: float = 16.0
## How wide the bird is drawn, in canvas px.
const BIRD_SPAN: float = 68.0
## A full wing beat, in seconds. A bird that beats faster than the eye can
## separate reads as a vibrating sprite, not as flight.
const FLAP_SECONDS: float = 0.46
## How far she rises and falls inside one beat, in canvas px. Without this the
## wings move but the bird slides, which is what gives a flap cycle away.
const BOB_PIXELS: float = 5.0

## The box the flight is drawn inside: x runs left to right with the run, y from
## the floor of the chart at the bottom to the top of its climb.
var area: Rect2 = Rect2(0, 0, 960, 540)
## 0 at the start of a run, 1 when the bird has reached the top of `area`.
var progress: float = 0.0
## Nothing is drawn until a run starts.
var running: bool = false

var _bird: Sprite2D
var _trail: Texture2D
var _flap: float = 0.0


func _init() -> void:
	name = "CorsairFlight"


func _ready() -> void:
	_trail = CoreOverclockTheme.TRAIL
	_bird = Sprite2D.new()
	_bird.name = "Parrot"
	_bird.texture = CoreOverclockTheme.PARROT_FLIGHT
	_bird.region_enabled = true
	_bird.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bird.scale = Vector2.ONE * (BIRD_SPAN / CoreOverclockTheme.PARROT_CELL)
	_bird.visible = false
	add_child(_bird)
	set_process(true)
	_lay_out()


func _process(delta: float) -> void:
	if not running:
		return
	if MotionPolicy.allows_continuous_motion():
		_flap += delta
	_lay_out()


## `reach` is how far along the run the flight has come, 0 to 1.
func set_reach(reach: float, is_running: bool) -> void:
	progress = clampf(reach, 0.0, 1.0)
	running = is_running
	_flap = 0.0 if not is_running else _flap
	_lay_out()
	queue_redraw()


## The height of the climb at `t` across the drawn span, 0 at the left edge and
## 1 at the head of the run.
func height_at(t: float) -> float:
	var span := clampf(t, 0.0, 1.0)
	return (exp(SHAPE * span) - 1.0) / (exp(SHAPE) - 1.0)


## Where the curve is on the canvas at `t` along the drawn span.
func crest_point(t: float) -> Vector2:
	var reach := maxf(progress, 0.0001)
	var x := area.position.x + area.size.x * reach * clampf(t, 0.0, 1.0)
	var lift := height_at(clampf(t, 0.0, 1.0)) * height_at(reach)
	var y := area.end.y - area.size.y * lift
	return Vector2(x, y)


## The slope of the curve under the bird, so she banks with her own climb.
func crest_angle() -> float:
	var back := crest_point(0.94)
	var head := crest_point(1.0)
	var run := head - back
	if run.length() <= 0.001:
		return 0.0
	return run.angle()


## Which wing position of the flap cycle is showing.
func flap_frame() -> int:
	var cells := int(CoreOverclockTheme.PARROT_GRID.x * CoreOverclockTheme.PARROT_GRID.y)
	if not MotionPolicy.allows_continuous_motion():
		# Reduced motion holds her on the level-winged frame instead of beating.
		return 1
	return posmod(int(_flap / FLAP_SECONDS * float(cells)), cells)


func _lay_out() -> void:
	if _bird == null:
		return
	_bird.visible = running
	if not running:
		return
	_bird.region_rect = CoreOverclockTheme.sheet_region(
		flap_frame(), CoreOverclockTheme.PARROT_GRID, CoreOverclockTheme.PARROT_CELL
	)
	# She rises on the downstroke and settles on the upstroke, so the beat moves
	# her instead of only animating her.
	var beat := sin(_flap / FLAP_SECONDS * TAU)
	var bob := 0.0 if not MotionPolicy.allows_continuous_motion() else beat * BOB_PIXELS
	_bird.position = crest_point(1.0) + Vector2(0.0, -bob)
	# She banks with the curve, but only part way: a bird climbing steeply still
	# holds her head up, and a sprite turned the full 70 degrees reads as falling.
	_bird.rotation = crest_angle() * 0.45


func _draw() -> void:
	if progress <= 0.0 or _trail == null:
		return
	var curve := PackedVector2Array()
	for step: int in range(SEGMENTS + 1):
		curve.append(crest_point(float(step) / float(SEGMENTS)))
	_draw_trail(curve)


## Lays the glowing beam along the curve, one quad per segment, so the light
## follows the climb instead of sitting on a straight line.
func _draw_trail(curve: PackedVector2Array) -> void:
	var across := 1.0 / float(curve.size() - 1)
	for index: int in range(curve.size() - 1):
		var here := curve[index]
		var next := curve[index + 1]
		var normal := (next - here).orthogonal().normalized() * TRAIL_HEIGHT * 0.5
		# The trail fades out behind her, so the eye is pulled to the head.
		var near := CoreOverclockTheme.TRAIL_TINT
		var far := Color(near, near.a * (0.15 + 0.85 * float(index) * across))
		draw_primitive(
			PackedVector2Array([here + normal, next + normal, next - normal, here - normal]),
			PackedColorArray([far, near, near, far]),
			PackedVector2Array(
				[
					Vector2(index * across, 0.0),
					Vector2((index + 1) * across, 0.0),
					Vector2((index + 1) * across, 1.0),
					Vector2(index * across, 1.0),
				]
			),
			_trail
		)
