class_name CreditChipIcon
extends Control
## Resolution-independent casino chip stack used by the global credit HUD.

var idle_time: float = 0.0
var transaction_time: float = 0.0
var transaction_direction: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(38, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	queue_redraw()


func _process(delta: float) -> void:
	if MotionPolicy.allows_continuous_motion():
		idle_time = fmod(idle_time + delta, 6.0)
	if transaction_time > 0.0:
		transaction_time = maxf(transaction_time - delta, 0.0)
	queue_redraw()
	if transaction_time <= 0.0 and not MotionPolicy.allows_continuous_motion():
		set_process(false)


func play_transaction(delta_chips: int) -> void:
	transaction_direction = signi(delta_chips)
	transaction_time = MotionPolicy.finite_duration(0.42)
	set_process(true)
	queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		idle_time = 0.0
		transaction_time = 0.0
		transaction_direction = 0
	set_process(not reduced or transaction_time > 0.0)
	queue_redraw()


func _draw() -> void:
	var breath := (
		(sin(idle_time * TAU / 3.2) + 1.0) * 0.5
		if MotionPolicy.allows_continuous_motion()
		else 0.0
	)
	var lift := breath * 0.6
	for chip_data: Array in [
		[Vector2(19, 24), Color("5a111c")],
		[Vector2(15, 18), Color("f1e8d8")],
		[Vector2(21, 12), Color("5a111c")],
	]:
		var center: Vector2 = chip_data[0] + Vector2(0.0, -lift)
		var fill: Color = chip_data[1]
		draw_circle(center, 9.0, Color("0c0b0d"))
		draw_circle(center, 8.0, fill)
		draw_arc(center, 6.0, 0.0, TAU, 24, Color("c8a34b"), 2.0)
		draw_line(center + Vector2(-8, 0), center + Vector2(-4, 0), Color("c8a34b"), 2.0)
		draw_line(center + Vector2(4, 0), center + Vector2(8, 0), Color("c8a34b"), 2.0)
	if MotionPolicy.allows_continuous_motion():
		var sheen_progress := fmod(idle_time, 3.2) / 3.2
		var sheen_center := Vector2(10.0 + sheen_progress * 20.0, 8.0 + sheen_progress * 18.0)
		draw_circle(sheen_center, 1.5, Color(1.0, 0.95, 0.72, sin(sheen_progress * PI) * 0.72))
	if transaction_time > 0.0:
		var progress := 1.0 - transaction_time / MotionPolicy.finite_duration(0.42)
		var accent := Color("68f0a4") if transaction_direction >= 0 else Color("f2c84b")
		accent.a = (1.0 - progress) * 0.85
		draw_arc(Vector2(19, 19), 13.0 + progress * 7.0, 0.0, TAU, 32, accent, 2.0)
