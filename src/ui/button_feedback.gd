class_name ButtonFeedback
extends Node
## Consistent, bounded casino-button motion. Never changes gameplay state.

var _button: Button
var _motion: Tween


static func attach(button: Button) -> ButtonFeedback:
	var existing := button.get_node_or_null("ButtonFeedback") as ButtonFeedback
	if existing != null:
		return existing
	var feedback := ButtonFeedback.new()
	feedback.name = "ButtonFeedback"
	button.add_child(feedback)
	feedback._bind(button)
	return feedback


func _bind(button: Button) -> void:
	_button = button
	_button.pivot_offset = _button.size * 0.5
	_button.mouse_entered.connect(_hover_in)
	_button.mouse_exited.connect(_hover_out)
	_button.focus_entered.connect(_hover_in)
	_button.focus_exited.connect(_hover_out)
	_button.button_down.connect(_press)
	_button.button_up.connect(_release)
	_button.resized.connect(func() -> void: _button.pivot_offset = _button.size * 0.5)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	_on_motion_preference_changed(MotionPolicy.is_reduced())


func _hover_in() -> void:
	if not _button.disabled:
		_animate_to(Vector2(1.025, 1.025), 0.09, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _hover_out() -> void:
	if not _button.has_focus():
		_animate_to(Vector2.ONE, 0.13, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _press() -> void:
	if not _button.disabled:
		_animate_to(Vector2(0.94, 0.94), 0.06, Tween.TRANS_QUAD, Tween.EASE_IN)


func _release() -> void:
	if MotionPolicy.is_reduced():
		_reset_scale()
		return
	if _button.disabled:
		_animate_to(Vector2.ONE, 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
		return
	_animate_to(Vector2(1.02, 1.02), 0.08, Tween.TRANS_BACK, Tween.EASE_OUT)
	_motion.chain().tween_property(
		_button, "scale", Vector2.ONE, MotionPolicy.finite_duration(0.08)
	).set_trans(Tween.TRANS_QUAD)


func _animate_to(target: Vector2, duration: float, transition: Tween.TransitionType, ease: Tween.EaseType) -> void:
	if MotionPolicy.is_reduced():
		_reset_scale()
		return
	if _motion != null:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(
		_button, "scale", target, MotionPolicy.finite_duration(duration)
	).set_trans(transition).set_ease(ease)


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_reset_scale()


func _reset_scale() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	if _button != null:
		_button.scale = Vector2.ONE
