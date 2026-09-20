class_name ButtonFeedback
extends Node
## Consistent, bounded casino-button motion shared by every interactive control.
## Never changes gameplay state.
##
##   hover / focus  lift to HOVER_SCALE (the style's brighter brass edge does the rest)
##   press          a quick PRESS_SCALE squash, then a release past rest and settle
##   reduced motion no scaling at all; state changes are instant

const HOVER_SCALE := Vector2(1.03, 1.03)
const PRESS_SCALE := Vector2(0.97, 0.97)

var _button: Button
var _motion: Tween
var _focus_time: float = 0.0


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
	_button.focus_entered.connect(_begin_focus_idle)
	_button.focus_exited.connect(_end_focus_idle)
	_button.button_down.connect(_press)
	_button.button_up.connect(_release)
	_button.resized.connect(func() -> void: _button.pivot_offset = _button.size * 0.5)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	_on_motion_preference_changed(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if _button == null or not _button.has_focus() or MotionPolicy.is_reduced():
		return
	_focus_time = fmod(_focus_time + delta, 2.4)
	var breath := (sin(_focus_time * TAU / 2.4) + 1.0) * 0.5
	# Only the current keyboard/controller decision breathes. The 8% warm tint
	# reads as an active affordance without competing with semantic button color.
	_button.self_modulate = Color.WHITE.lerp(Color("fff4dd"), breath * 0.08)


func _hover_in() -> void:
	if not _button.disabled:
		_animate_to(HOVER_SCALE, 0.09, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _hover_out() -> void:
	if not _button.has_focus():
		_animate_to(Vector2.ONE, 0.13, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _press() -> void:
	if not _button.disabled:
		_animate_to(PRESS_SCALE, 0.06, Tween.TRANS_QUAD, Tween.EASE_IN)


func _release() -> void:
	if MotionPolicy.is_reduced():
		_reset_scale()
		return
	if _button.disabled:
		_animate_to(Vector2.ONE, 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT)
		return
	_animate_to(Vector2(1.02, 1.02), 0.08, Tween.TRANS_BACK, Tween.EASE_OUT)
	var rest := HOVER_SCALE if _button.has_focus() or _hovered() else Vector2.ONE
	(
		_motion
		. chain()
		. tween_property(_button, "scale", rest, MotionPolicy.finite_duration(0.08))
		. set_trans(Tween.TRANS_QUAD)
	)


func _hovered() -> bool:
	if not _button.is_inside_tree():
		return false
	return _button.get_global_rect().has_point(_button.get_global_mouse_position())


func _begin_focus_idle() -> void:
	_focus_time = 0.0
	set_process(not MotionPolicy.is_reduced())


func _end_focus_idle() -> void:
	_focus_time = 0.0
	set_process(false)
	if _button != null:
		_button.self_modulate = Color.WHITE


func _animate_to(
	target: Vector2, duration: float, transition: Tween.TransitionType, ease: Tween.EaseType
) -> void:
	if MotionPolicy.is_reduced():
		_reset_scale()
		return
	if _motion != null:
		_motion.kill()
	_motion = create_tween()
	(
		_motion
		. tween_property(_button, "scale", target, MotionPolicy.finite_duration(duration))
		. set_trans(transition)
		. set_ease(ease)
	)


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_reset_scale()
		_end_focus_idle()
	else:
		set_process(_button != null and _button.has_focus())


func _reset_scale() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	if _button != null:
		_button.scale = Vector2.ONE
		_button.self_modulate = Color.WHITE
