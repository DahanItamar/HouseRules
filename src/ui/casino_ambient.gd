class_name CasinoAmbient
extends Control
## Machine-specific attract lighting and short event feedback.

enum Mode { SLOT, BLACKJACK, VAULT, LOBBY }

var elapsed: float = 0.0
var accent := Color("c8a34b")
var mode: Mode = Mode.SLOT
var event_energy: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	elapsed += delta
	event_energy = maxf(0.0, event_energy - delta * 1.4)
	queue_redraw()


func trigger_event(strength: float = 1.0) -> void:
	event_energy = clampf(strength, 0.0, 1.0)
	queue_redraw()
	if MotionPolicy.is_reduced():
		var feedback := create_tween()
		feedback.tween_property(
			self, "event_energy", 0.0, MotionPolicy.finite_duration(0.20)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		feedback.tween_callback(queue_redraw)


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		elapsed = 0.0
		event_energy = 0.0
	queue_redraw()


func _draw() -> void:
	if mode == Mode.VAULT:
		var scan_x := fmod(elapsed * 86.0, size.x + 180.0) - 90.0
		draw_rect(Rect2(scan_x, 8, 90, size.y - 16), Color(accent, 0.035 + event_energy * 0.08))
		for corner: Vector2 in [Vector2(28, 24), Vector2(size.x - 28, 24)]:
			draw_arc(corner, 10.0 + event_energy * 4.0, 0, TAU, 24, Color(accent, 0.28), 2.0)
		return
	if mode == Mode.BLACKJACK:
		var sweep := (sin(elapsed * 0.75) + 1.0) * 0.5
		draw_arc(Vector2(size.x * 0.5, size.y + 270), 420.0, PI * 1.12, PI * 1.88, 72, Color(accent, 0.10 + sweep * 0.08 + event_energy * 0.22), 3.0)
		return
	var count := 18 if mode == Mode.SLOT else 14
	for index: int in range(count):
		var phase := elapsed * 2.2 + index * 0.65
		var alpha := 0.15 + (sin(phase) + 1.0) * 0.14 + event_energy * 0.35
		var point := Vector2(36 + index * (size.x - 72.0) / maxf(count - 1, 1), 36)
		draw_circle(point, 3.0 if index % 3 else 4.0, Color(accent, alpha))
