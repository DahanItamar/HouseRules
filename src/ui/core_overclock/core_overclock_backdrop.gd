class_name CoreOverclockBackdrop
extends Control
## The painted night sea, kept alive: the whole plate drifts on a slow parallax,
## squall bars drag across the sky above the chart, spray lifts off the water at
## its foot, spindrift hangs in the moonlight, and the vignette closes in as the
## climb goes on.
##
## The squall is a handful of wobbling bars rather than a screen shader, so it
## costs nothing. Presentation only, and completely static under reduced motion.

const MOTE_COUNT: int = 30
const MOTE_SEED: int = 20260920
const EMBER_COUNT: int = 18
const SQUALL_BARS: int = 5
## How far the plate drifts either way, in canvas pixels.
const PARALLAX: float = 5.0
const VIGNETTE_BANDS: int = 14

## 0 with the run at rest, up to 1 at the far end of the climb.
var climb: float = 0.0
var climbing: bool = false
var _phase: float = 0.0
var _motes: Array[Vector3] = []
var _embers: Array[Vector3] = []


func _init() -> void:
	name = "CoreOverclockBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MOTE_SEED
	for _index: int in range(MOTE_COUNT):
		# x, y and a per-mote size and speed multiplier.
		_motes.append(
			Vector3(
				rng.randf_range(0.0, 960.0), rng.randf_range(0.0, 540.0), rng.randf_range(0.4, 1.5)
			)
		)
	for _index: int in range(EMBER_COUNT):
		# offset across the foot of the chart, a phase and a speed multiplier.
		_embers.append(
			Vector3(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(0.5, 1.6))
		)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	queue_redraw()


func set_climb(climb_value: float, is_climbing: bool) -> void:
	var next := clampf(climb_value, 0.0, 1.0)
	if is_equal_approx(next, climb) and is_climbing == climbing:
		return
	climb = next
	climbing = is_climbing
	queue_redraw()


func _process(delta: float) -> void:
	if not MotionPolicy.allows_continuous_motion():
		return
	_phase += delta * (1.0 + climb * 1.6)
	queue_redraw()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_phase = 0.0
	queue_redraw()


func _draw() -> void:
	var drift := Vector2(sin(_phase * 0.2), sin(_phase * 0.15) * 0.5) * PARALLAX
	draw_texture_rect(
		CoreOverclockTheme.BACKDROP,
		Rect2(Vector2(-PARALLAX, -PARALLAX) + drift, size + Vector2(PARALLAX, PARALLAX) * 2.0),
		false
	)
	_draw_squall()
	_draw_embers()
	_draw_spindrift()
	_draw_vignette()


## Weather dragging across the sky above the chart, heavier the further the run
## has climbed. Cabinet screens are allowed this glow; the floor and the HUD are
## not.
func _draw_squall() -> void:
	if MotionPolicy.is_reduced() or climb <= 0.0:
		return
	var chart := CoreOverclockTheme.FLIGHT_AREA
	for index: int in range(SQUALL_BARS):
		var place := float(index) / float(SQUALL_BARS)
		var y := chart.position.y - 6.0 - place * 48.0
		var slide := sin(_phase * (2.4 + place) + float(index)) * (4.0 + climb * 7.0)
		var alpha := (0.05 + climb * 0.07) * (1.0 - place)
		draw_rect(
			Rect2(chart.position.x + slide, y, chart.size.x, 3.0),
			Color(CoreOverclockTheme.FLAME, alpha)
		)


## Sparks lifting off the water at the foot of the chart and dying as they rise.
func _draw_embers() -> void:
	if not climbing and climb <= 0.0:
		return
	var chart := CoreOverclockTheme.FLIGHT_AREA
	for index: int in range(_embers.size()):
		var spark := _embers[index]
		var life := fposmod(_phase * (0.35 + climb * 0.5) * spark.z + spark.y, 1.0)
		var origin := Vector2(chart.position.x + chart.size.x * spark.x, chart.end.y - 6.0)
		var at := (
			origin + Vector2(sin((life + spark.y) * 6.0) * 14.0, -life * (130.0 + climb * 120.0))
		)
		var alpha := (1.0 - life) * (0.25 + climb * 0.6)
		draw_circle(at, 1.0 + spark.z, Color(CoreOverclockTheme.EMBER, alpha))


## Spindrift hanging in the moonlight over the whole canvas.
func _draw_spindrift() -> void:
	var lift := _phase * 9.0
	for index: int in range(_motes.size()):
		var mote := _motes[index]
		var y := fposmod(mote.y - lift * mote.z, size.y)
		var x := mote.x + sin((_phase + float(index)) * 0.4) * 7.0
		var alpha := 0.06 + 0.10 * mote.z
		draw_circle(Vector2(x, y), 0.8 + mote.z, Color(CoreOverclockTheme.CREAM, alpha))


## A banded vignette that tightens and warms the further the run has climbed.
func _draw_vignette() -> void:
	var tint := CoreOverclockTheme.NIGHT.lerp(CoreOverclockTheme.RUST_DEEP, climb * 0.6)
	for index: int in range(VIGNETTE_BANDS):
		var inset := float(index) * 7.0
		var alpha := (0.05 + climb * 0.035) * (1.0 - float(index) / float(VIGNETTE_BANDS))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-inset), Color(tint, alpha), false, 8.0)
