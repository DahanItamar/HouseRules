class_name BlackjackBetStack
extends Control
## Presentation-only wager marker. The cabinet remains the source of truth for stake values.

const SOURCE_POSITION := Vector2(365, 464)
const TABLE_POSITION := Vector2(126, 354)

var wager: int = 0
var is_live: bool = false
var _placement_tween: Tween
var _pulse: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(92, 62)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if is_live and MotionPolicy.allows_continuous_motion():
		_pulse = fmod(_pulse + delta, 2.8)
		queue_redraw()


func place_wager(amount: int, animated: bool = true) -> void:
	var was_live := is_live
	wager = maxi(amount, 0)
	is_live = wager > 0
	visible = is_live
	if not is_live:
		return
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
	modulate = Color.WHITE
	position = SOURCE_POSITION if animated and not was_live else TABLE_POSITION
	rotation = -0.08 if animated and not was_live else 0.0
	scale = Vector2(0.82, 0.82) if animated and not was_live else Vector2.ONE
	queue_redraw()
	if MotionPolicy.is_reduced() or not animated or was_live:
		position = TABLE_POSITION
		rotation = 0.0
		scale = Vector2.ONE
		return
	_placement_tween = create_tween().set_parallel(true)
	_placement_tween.tween_property(self, "position", TABLE_POSITION, 0.26).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_placement_tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_QUAD)
	_placement_tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func clear_wager(animated: bool = true) -> void:
	if not is_live:
		visible = false
		return
	is_live = false
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
	if MotionPolicy.is_reduced() or not animated:
		visible = false
		wager = 0
		queue_redraw()
		return
	_placement_tween = create_tween().set_parallel(true)
	_placement_tween.tween_property(self, "position:y", position.y - 8.0, 0.14)
	_placement_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_placement_tween.finished.connect(
		func() -> void:
			visible = false
			wager = 0
			modulate = Color.WHITE
			queue_redraw()
	)


func _apply_motion_preference(reduced: bool) -> void:
	if reduced and _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
		position = TABLE_POSITION
		rotation = 0.0
		scale = Vector2.ONE
		modulate = Color.WHITE
	_pulse = 0.0
	queue_redraw()


func _draw() -> void:
	if not is_live:
		return
	var glow_alpha := 0.18
	if MotionPolicy.allows_continuous_motion():
		glow_alpha += sin((_pulse / 2.8) * TAU) * 0.05
	draw_circle(Vector2(46, 34), 31.0, Color(0.95, 0.74, 0.22, glow_alpha))
	for chip_data: Array in [
		[Vector2(35, 34), Color("f1e8d8")],
		[Vector2(46, 28), Color("5a111c")],
		[Vector2(57, 22), Color("17161a")],
	]:
		var center: Vector2 = chip_data[0]
		var fill: Color = chip_data[1]
		draw_circle(center, 17.0, Color("080708"))
		draw_circle(center, 15.5, fill)
		draw_arc(center, 11.5, 0.0, TAU, 32, Color("c8a34b"), 2.0, true)
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			var radial := Vector2.from_angle(angle)
			draw_line(center + radial * 12.0, center + radial * 16.0, Color("c8a34b"), 3.0)
	var amount_text := tr("CABINET_STAKE") % wager
	draw_string(
		Typography.UI_FONT,
		Vector2(0, 60),
		amount_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		92,
		14,
		Color("f5e6bd")
	)
