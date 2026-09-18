class_name AnimatedNumberLabel
extends Label
## Presentation-only integer ticker. The authoritative value always lives elsewhere.

var displayed_value: float = 0.0
var target_value: int = 0
var _format: String = "%d"
var _number_tween: Tween
var _initialized: bool = false


func set_number(value: int, format_text: String = "%d", animate: bool = true) -> void:
	if _initialized and target_value == value and _format == format_text:
		return
	_format = format_text
	target_value = value
	if not _initialized or not animate or not is_inside_tree():
		_initialized = true
		displayed_value = value
		_apply_value(displayed_value)
		return
	if _number_tween != null:
		_number_tween.kill()
	var distance := absf(float(value) - displayed_value)
	var duration := clampf(0.18 + distance * 0.002, 0.18, 0.6)
	_number_tween = create_tween()
	_number_tween.tween_method(
		_apply_value, displayed_value, float(value), duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_infinity() -> void:
	_initialized = true
	if _number_tween != null:
		_number_tween.kill()
	text = "∞"


func _apply_value(value: float) -> void:
	displayed_value = value
	text = _format % int(round(value))
