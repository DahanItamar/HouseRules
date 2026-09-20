class_name AnimatedNumberLabel
extends Label
## Presentation-only integer ticker. The authoritative value always lives elsewhere.

var displayed_value: float = 0.0
var target_value: int = 0
var _format: String = "%d"
var _number_tween: Tween
var _initialized: bool = false
var _showing_infinity: bool = false


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)


func set_number(value: int, format_text: String = "%d", animate: bool = true) -> void:
	if _initialized and not _showing_infinity and target_value == value and _format == format_text:
		return
	var was_showing_infinity := _showing_infinity
	_showing_infinity = false
	_format = format_text
	target_value = value
	if (
		was_showing_infinity
		or not _initialized
		or not animate
		or not is_inside_tree()
		or MotionPolicy.is_reduced()
	):
		_initialized = true
		displayed_value = value
		_apply_value(displayed_value)
		return
	if _number_tween != null:
		_number_tween.kill()
	var distance := absf(float(value) - displayed_value)
	var duration := clampf(0.18 + distance * 0.002, 0.18, 0.6)
	_number_tween = create_tween()
	(
		_number_tween
		. tween_method(_apply_value, displayed_value, float(value), duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func set_infinity() -> void:
	_initialized = true
	_showing_infinity = true
	if _number_tween != null:
		_number_tween.kill()
		_number_tween = null
	text = "∞"


func _apply_value(value: float) -> void:
	displayed_value = value
	text = _format % int(round(value))


func _apply_motion_preference(reduced: bool) -> void:
	if not reduced or _showing_infinity:
		return
	if _number_tween != null and _number_tween.is_valid() and _number_tween.is_running():
		_number_tween.kill()
		_number_tween = null
		_apply_value(float(target_value))
