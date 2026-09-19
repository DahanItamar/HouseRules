class_name CashierAmbient
extends Control
## Quiet, presentation-only life for the cashier after its entry choreography.

const CYCLE_DURATION := 4.8

var elapsed: float = 0.0
var active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if not active or not MotionPolicy.allows_continuous_motion():
		return
	elapsed = fmod(elapsed + delta, CYCLE_DURATION)
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	set_process(active and MotionPolicy.allows_continuous_motion())
	if not active:
		elapsed = 0.0
	queue_redraw()


func is_animating() -> bool:
	return active and is_processing() and MotionPolicy.allows_continuous_motion()


func visual_sample() -> Vector2:
	if not MotionPolicy.allows_continuous_motion():
		return rest_sample()
	var progress := elapsed / CYCLE_DURATION
	return Vector2(progress, sin(progress * TAU) * 0.45)


func rest_sample() -> Vector2:
	return Vector2.ZERO


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		elapsed = 0.0
	set_process(active and not reduced)
	queue_redraw()


func _draw() -> void:
	var progress := elapsed / CYCLE_DURATION if MotionPolicy.allows_continuous_motion() else 0.0
	var rail := Rect2(36, 259, 388, 2)
	draw_rect(rail, Color("6e52254f"))
	for index: int in range(9):
		var x := rail.position.x + rail.size.x * float(index) / 8.0
		draw_circle(Vector2(x, rail.position.y + 1), 1.5, Color("c8a34b80"))
	var sweep_x := rail.position.x + rail.size.x * progress
	draw_line(
		Vector2(maxf(rail.position.x, sweep_x - 32.0), rail.position.y + 1),
		Vector2(sweep_x, rail.position.y + 1),
		Color("f2c84bcc"),
		2.0
	)
	_draw_chip_tray(Vector2(43, 337), progress)
	_draw_chip_tray(Vector2(417, 337), 1.0 - progress)


func _draw_chip_tray(center: Vector2, phase: float) -> void:
	var lift := sin(phase * TAU) * 0.45 if MotionPolicy.allows_continuous_motion() else 0.0
	draw_line(center + Vector2(-15, 7), center + Vector2(15, 7), Color("6e5225a0"), 2.0)
	for index: int in range(3):
		var chip_center := center + Vector2((index - 1) * 8, -index * 2 - lift)
		draw_circle(chip_center, 5.0, Color("0c0b0d"))
		draw_circle(chip_center, 4.0, Color("5a111c") if index != 1 else Color("f1e8d8"))
		draw_arc(chip_center, 3.0, 0.0, TAU, 16, Color("c8a34b"), 1.0)


func _exit_tree() -> void:
	if MotionPolicy.motion_preference_changed.is_connected(_apply_motion_preference):
		MotionPolicy.motion_preference_changed.disconnect(_apply_motion_preference)
