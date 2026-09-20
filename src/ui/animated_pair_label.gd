class_name AnimatedPairLabel
extends Label
## Presentation-only ticker for compact readouts containing two integer values.

signal animation_finished

var target_first: int = 0
var target_second: int = 0
var displayed_first: float = 0.0
var displayed_second: float = 0.0
var _format: String = "%d / %d"
var _initialized: bool = false
var _number_tween: Tween


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


func set_numbers(first: int, second: int, format_text: String, animate: bool = true) -> void:
	if (
		_initialized
		and target_first == first
		and target_second == second
		and _format == format_text
	):
		return
	target_first = first
	target_second = second
	_format = format_text
	if _number_tween != null and _number_tween.is_valid():
		_number_tween.kill()
	if not _initialized or not animate or not is_inside_tree() or MotionPolicy.is_reduced():
		_initialized = true
		_apply_values(float(first), float(second))
		animation_finished.emit()
		return
	var from_first := displayed_first
	var from_second := displayed_second
	var distance := maxf(absf(float(first) - from_first), absf(float(second) - from_second))
	var duration := clampf(0.18 + distance * 0.002, 0.18, 0.58)
	_number_tween = create_tween()
	(
		_number_tween
		. tween_method(
			func(weight: float) -> void:
				_apply_values(
					lerpf(from_first, float(target_first), weight),
					lerpf(from_second, float(target_second), weight)
				),
			0.0,
			1.0,
			duration
		)
		. set_trans(Tween.TRANS_QUART)
		. set_ease(Tween.EASE_OUT)
	)
	_number_tween.tween_callback(
		func() -> void:
			_apply_values(float(target_first), float(target_second))
			animation_finished.emit()
	)


func set_literal(value: String) -> void:
	if _number_tween != null and _number_tween.is_valid():
		_number_tween.kill()
	_initialized = false
	text = value


func has_active_motion() -> bool:
	return _number_tween != null and _number_tween.is_valid() and _number_tween.is_running()


func _on_motion_preference_changed(reduced: bool) -> void:
	if not reduced or not has_active_motion():
		return
	_number_tween.kill()
	_number_tween = null
	_apply_values(float(target_first), float(target_second))
	animation_finished.emit()


func _apply_values(first: float, second: float) -> void:
	displayed_first = first
	displayed_second = second
	text = _format % [int(round(first)), int(round(second))]
