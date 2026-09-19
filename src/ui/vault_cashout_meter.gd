class_name VaultCashoutMeter
extends Control
## Presentation-only vault cash-out meter. Game rules remain the caller's responsibility.

signal animation_finished

const ANIMATION_MIN_SECONDS: float = 0.35
const ANIMATION_MAX_SECONDS: float = 0.55
const PANEL_COLOR := Color("17171b")
const PANEL_BORDER := Color("665a47")
const READY_COLOR := Color("45bd78")
const DISABLED_COLOR := Color("77736c")
const RAIL_COLOR := Color("302f33")
const TEXT_COLOR := Color("f2eadc")
const MUTED_TEXT_COLOR := Color("aaa49b")

var target_amount: int = 0
var target_multiplier: float = 1.0
var target_progress: float = 0.0
var displayed_amount: float = 0.0
var displayed_multiplier: float = 1.0
var displayed_progress: float = 0.0
var is_ready: bool = false
var animation_duration: float = ANIMATION_MIN_SECONDS
var _value_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(240, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_values(
	cashout_amount: int,
	multiplier: float,
	progress: float,
	animate: bool = true
) -> void:
	var next_amount := maxi(cashout_amount, 0)
	var next_multiplier := maxf(multiplier, 0.0)
	var next_progress := clampf(progress, 0.0, 1.0)
	if (
		target_amount == next_amount
		and is_equal_approx(target_multiplier, next_multiplier)
		and is_equal_approx(target_progress, next_progress)
	):
		return
	target_amount = next_amount
	target_multiplier = next_multiplier
	target_progress = next_progress
	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()
	if not animate or not is_inside_tree():
		_apply_values(float(target_amount), target_multiplier, target_progress)
		return
	if MotionPolicy.is_reduced():
		_apply_values(float(target_amount), target_multiplier, target_progress)
		animation_finished.emit()
		return

	var amount_distance := absf(float(target_amount) - displayed_amount)
	var multiplier_distance := absf(target_multiplier - displayed_multiplier)
	var progress_distance := absf(target_progress - displayed_progress)
	var motion_weight := maxf(
		minf(amount_distance / 200.0, 1.0),
		maxf(minf(multiplier_distance / 4.0, 1.0), progress_distance)
	)
	animation_duration = lerpf(ANIMATION_MIN_SECONDS, ANIMATION_MAX_SECONDS, motion_weight)
	var from_amount := displayed_amount
	var from_multiplier := displayed_multiplier
	var from_progress := displayed_progress
	_value_tween = create_tween()
	_value_tween.tween_method(
		func(weight: float) -> void:
			_apply_values(
				lerpf(from_amount, float(target_amount), weight),
				lerpf(from_multiplier, target_multiplier, weight),
				lerpf(from_progress, target_progress, weight)
			),
		0.0,
		1.0,
		animation_duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_value_tween.tween_callback(
		func() -> void:
			_apply_values(float(target_amount), target_multiplier, target_progress)
			animation_finished.emit()
	)


func set_ready(ready: bool) -> void:
	if is_ready == ready:
		return
	is_ready = ready
	queue_redraw()


func amount_text() -> String:
	return str(int(round(displayed_amount)))


func multiplier_text() -> String:
	return "%.2f×" % displayed_multiplier


func has_active_motion() -> bool:
	return _value_tween != null and _value_tween.is_valid() and _value_tween.is_running()


func _apply_values(amount: float, multiplier: float, progress: float) -> void:
	displayed_amount = amount
	displayed_multiplier = multiplier
	displayed_progress = progress
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_COLOR
	panel.border_color = READY_COLOR if is_ready else PANEL_BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	draw_style_box(panel, bounds)

	var accent := READY_COLOR if is_ready else DISABLED_COLOR
	var primary_text := TEXT_COLOR if is_ready else MUTED_TEXT_COLOR
	var label_font := Typography.UI_FONT
	var number_font := Typography.DISPLAY_FONT
	draw_string(
		label_font,
		Vector2(12, 21),
		tr("ACTION_CASH_OUT"),
		HORIZONTAL_ALIGNMENT_LEFT,
		84,
		Typography.BODY_MIN,
		primary_text
	)
	draw_string(
		number_font,
		Vector2(90, 25),
		amount_text(),
		HORIZONTAL_ALIGNMENT_RIGHT,
		62,
		Typography.CONTROL,
		primary_text
	)
	draw_string(
		number_font,
		Vector2(size.x - 82, 25),
		multiplier_text(),
		HORIZONTAL_ALIGNMENT_RIGHT,
		70,
		Typography.CONTROL,
		accent
	)

	var rail := Rect2(Vector2(12, size.y - 18), Vector2(maxf(size.x - 24, 0.0), 7))
	draw_rect(rail, RAIL_COLOR, true)
	if displayed_progress > 0.0:
		var fill := rail
		fill.size.x *= displayed_progress
		draw_rect(fill, accent, true)
	draw_line(
		Vector2(rail.end.x, rail.position.y - 2),
		Vector2(rail.end.x, rail.end.y + 2),
		PANEL_BORDER,
		2.0
	)
