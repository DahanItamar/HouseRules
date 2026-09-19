class_name DisconnectPauseOverlay
extends CanvasLayer

var _paused_for_disconnect: bool = false
var _shade: ColorRect
var _message: Label
var _motion: Tween
var _idle_time: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.color = Color("0b0a12e8")
	_shade.size = Vector2(960, 540)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_message = Label.new()
	_message.position = Vector2(180, 245)
	_message.size = Vector2(600, 50)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", Typography.PROMINENT)
	_message.add_theme_color_override("font_color", Color("ffd23f"))
	_message.text = tr("GAMEPAD_RECONNECT")
	add_child(_message)
	InputRouter.gamepad_connection_changed.connect(set_gamepad_connected)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	hide()
	set_process(false)


func _process(delta: float) -> void:
	if not visible or not MotionPolicy.allows_continuous_motion():
		return
	_idle_time = fmod(_idle_time + delta, 3.0)
	var pulse := (sin(_idle_time * TAU / 1.5) + 1.0) * 0.5
	_message.modulate.a = 0.78 + pulse * 0.22
	_message.scale = Vector2.ONE * (1.0 + pulse * 0.012)


func set_gamepad_connected(connected: bool) -> void:
	if connected:
		if _paused_for_disconnect:
			get_tree().paused = false
			_paused_for_disconnect = false
		_play_hide()
		return
	show()
	_play_reveal()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_for_disconnect = true


func _play_reveal() -> void:
	if _motion != null:
		_motion.kill()
	_reset_visual_state()
	set_process(MotionPolicy.allows_continuous_motion())
	if MotionPolicy.is_reduced():
		return
	_shade.modulate.a = 0.0
	_message.modulate.a = 0.0
	_message.position.y = 253.0
	_message.pivot_offset = _message.size * 0.5
	_message.scale = Vector2(0.98, 0.98)
	_motion = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion.tween_property(_shade, "modulate:a", 1.0, 0.16)
	_motion.tween_property(_message, "modulate:a", 1.0, 0.18)
	_motion.tween_property(_message, "position:y", 245.0, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_message, "scale", Vector2.ONE, 0.18).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func _play_hide() -> void:
	if not visible:
		return
	if _motion != null:
		_motion.kill()
	set_process(false)
	if MotionPolicy.is_reduced():
		hide()
		_reset_visual_state()
		return
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion.tween_property(_shade, "modulate:a", 0.0, 0.12)
	_motion.tween_property(_message, "modulate:a", 0.0, 0.12)
	_motion.tween_property(_message, "position:y", 237.0, 0.12).set_trans(Tween.TRANS_QUAD)
	_motion.finished.connect(
		func() -> void:
			hide()
			_reset_visual_state()
	)


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced and _motion != null:
		_motion.kill()
	_reset_visual_state()
	set_process(visible and not reduced)


func _reset_visual_state() -> void:
	if _shade == null or _message == null:
		return
	_idle_time = 0.0
	_shade.modulate = Color.WHITE
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_message.modulate = Color.WHITE
	_message.position.y = 245.0
	_message.scale = Vector2.ONE
