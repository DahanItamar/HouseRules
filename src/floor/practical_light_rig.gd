class_name PracticalLightRig
extends Node2D
## Presentation-only authored activity for the floor's real light fixtures.
##
## The loop is mathematical rather than random, so captures and tests can sample the
## same frame exactly. Reduced motion holds the canonical authored rest frame.

const LOOP_SECONDS := 12.0
const REST_ELAPSED := 0.0
const WARM := Color("e6b95f")
const FIXTURES: Array[Dictionary] = [
	{"lamp": Vector2(253, 34), "pool": Vector2(270, 136), "phase": 0.00, "energy": 1.00},
	{"lamp": Vector2(413, 34), "pool": Vector2(420, 140), "phase": 0.19, "energy": 0.88},
	{"lamp": Vector2(568, 34), "pool": Vector2(560, 140), "phase": 0.43, "energy": 0.92},
	{"lamp": Vector2(729, 34), "pool": Vector2(710, 136), "phase": 0.68, "energy": 1.00},
	{"lamp": Vector2(360, 452), "pool": Vector2(392, 394), "phase": 0.31, "energy": 0.78},
	{"lamp": Vector2(584, 452), "pool": Vector2(552, 394), "phase": 0.82, "energy": 0.78},
]

var elapsed: float = REST_ELAPSED
var reduced_motion: bool = false


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(apply_motion_preference)
	apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	elapsed = fmod(elapsed + maxf(delta, 0.0), LOOP_SECONDS)
	queue_redraw()


func apply_motion_preference(reduced: bool) -> void:
	reduced_motion = reduced
	set_process(not reduced)
	if reduced:
		elapsed = REST_ELAPSED
	queue_redraw()


func fixture_intensity(index: int, at_time: float = elapsed) -> float:
	assert(index >= 0 and index < FIXTURES.size())
	var fixture: Dictionary = FIXTURES[index]
	var phase: float = float(fixture["phase"])
	var energy: float = float(fixture["energy"])
	var loop_phase := fposmod(at_time, LOOP_SECONDS) / LOOP_SECONDS
	# Two slow harmonics feel electrical without resembling a random flicker.
	var breath := sin((loop_phase + phase) * TAU)
	var filament := sin((loop_phase * 2.0 + phase * 0.73) * TAU)
	return clampf((0.78 + breath * 0.12 + filament * 0.04) * energy, 0.48, 0.96)


func reflection_offset(at_time: float = elapsed) -> float:
	# A small, bounded reflection drift across the polished central carpet medallion.
	return sin(fposmod(at_time, LOOP_SECONDS) / LOOP_SECONDS * TAU) * 18.0


func _draw() -> void:
	for index: int in range(FIXTURES.size()):
		var fixture: Dictionary = FIXTURES[index]
		var lamp: Vector2 = fixture["lamp"]
		var pool: Vector2 = fixture["pool"]
		var intensity := fixture_intensity(index)
		# Re-light only the authored practical, then let its pool fall onto the floor.
		draw_circle(lamp, 8.0, Color(WARM, 0.025 + intensity * 0.045))
		draw_circle(lamp, 3.0, Color("fff1bd", 0.12 + intensity * 0.12))
		draw_colored_polygon(
			PackedVector2Array([
				lamp + Vector2(-3, 7), lamp + Vector2(3, 7),
				pool + Vector2(35, 12), pool + Vector2(-35, 12),
			]),
			Color(WARM, 0.006 + intensity * 0.010)
		)
		draw_set_transform(pool, 0.0, Vector2(1.85, 0.42))
		draw_circle(Vector2.ZERO, 24.0, Color(WARM, 0.010 + intensity * 0.018))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var sweep_x := 480.0 + reflection_offset()
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(sweep_x - 22, 315), Vector2(sweep_x - 12, 315),
			Vector2(sweep_x + 30, 415), Vector2(sweep_x + 6, 415),
		]),
		Color(WARM, 0.014)
	)
