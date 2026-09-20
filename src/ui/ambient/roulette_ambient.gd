extends AmbientLayer
## Ruby Roulette: the salon's sconces and table lamps breathe on the backdrop,
## and every ~9 s the chandelier's light slides once across the wheel bowl.
##
## The breathing pools sit on the backdrop under the croupier. The sweep is a
## separate node placed directly above the wheel (and under the board, plates
## and controls); it is additive, masked to the bowl ellipse and capped, so the
## ball and pockets stay fully readable while it passes.

const SCONCE := Color("ffcf8c")
const SWEEP_TINT := Color("ffe9c4")
const SWEEP_SECONDS: float = 2.6
const SWEEP_INTERVAL: float = 9.4
const SWEEP_PHASE: float = 1.5
## The bowl as RouletteTablePanel draws it (a test keeps the two in step; the
## layer does not reference the panel so ambience never depends on table code).
const WHEEL_CENTER := Vector2(137, 245)
const WHEEL_RADIUS: float = 130.0
const WHEEL_SQUASH: float = 0.56

var wheel_sweep: AmbientSweep


func _ready() -> void:
	add_pool(Vector2(82, 46), 40.0, 1.0, SCONCE, 0.075, 4.3, 0.22)
	add_pool(Vector2(515, 76), 32.0, 1.0, SCONCE, 0.07, 5.6, 0.61)
	add_pool(Vector2(768, 94), 30.0, 1.0, SCONCE, 0.07, 3.9, 0.35)
	add_pool(Vector2(915, 82), 30.0, 1.0, SCONCE, 0.07, 6.2, 0.83)
	add_pool(Vector2(70, 152), 26.0, 0.8, SCONCE, 0.075, 4.8, 0.47)
	add_pool(Vector2(928, 150), 26.0, 0.8, SCONCE, 0.075, 5.1, 0.04)
	super._ready()


func wheel_ellipse() -> Rect2:
	var half := Vector2(WHEEL_RADIUS, WHEEL_RADIUS * WHEEL_SQUASH)
	return Rect2(WHEEL_CENTER - half, half * 2.0)


## Called once the layer is in the art root: puts the sweep right above the wheel.
func place_overlays(art: Node) -> void:
	var wheel := art.get_node_or_null("RouletteWheel")
	if wheel == null or wheel_sweep != null:
		return
	wheel_sweep = AmbientSweep.new()
	wheel_sweep.name = "WheelLightSweep"
	wheel_sweep.configure(
		wheel_ellipse(), null, SWEEP_TINT, {"band": 0.16, "slant": 0.7, "ellipse": wheel_ellipse()}
	)
	art.add_child(wheel_sweep)
	art.move_child(wheel_sweep, wheel.get_index() + 1)
	_advance()


func sweep_strength(at_time: float = elapsed) -> float:
	if reduced_motion:
		return 0.0
	var local := fposmod(at_time - SWEEP_PHASE, SWEEP_INTERVAL)
	if local >= SWEEP_SECONDS:
		return 0.0
	return SWEEP_ALPHA_CAP * 0.7 * sin(PI * local / SWEEP_SECONDS)


func sample_alpha_peaks(at_time: float) -> Dictionary:
	var peaks := super.sample_alpha_peaks(at_time)
	peaks["sweep"] = sweep_strength(at_time)
	return peaks


func moving_effect_bounds() -> Array[Rect2]:
	return [wheel_ellipse()]


func _advance() -> void:
	if wheel_sweep == null:
		return
	var local := fposmod(elapsed - SWEEP_PHASE, SWEEP_INTERVAL)
	wheel_sweep.show_progress(lerpf(-0.2, 1.2, local / SWEEP_SECONDS), sweep_strength())


func _draw_light(canvas: Node2D) -> void:
	draw_pools(canvas)
