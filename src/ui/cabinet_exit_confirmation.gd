class_name CabinetExitConfirmation
extends CanvasLayer
## Controller-first confirmation shown before abandoning a live wager.

signal leave_confirmed
signal cancelled

var is_open: bool = false
var _message: Label
var _leave_button: Button
var _cancel_button: Button
var _previous_focus: Control
var _blocker: ColorRect
var _dialog: Panel
var _transition: Tween


func _ready() -> void:
	layer = 110
	visible = false
	_blocker = ColorRect.new()
	_blocker.name = "ExitConfirmationBlocker"
	_blocker.size = Vector2(960, 540)
	_blocker.color = Color("080708d9")
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

	_dialog = Panel.new()
	_dialog.name = "ExitConfirmationDialog"
	_dialog.position = Vector2(250, 146)
	_dialog.size = Vector2(460, 248)
	_dialog.add_theme_stylebox_override(
		"panel", _panel_style(Color("17161af7"), Color("c8a34b"), 10, 2)
	)
	add_child(_dialog)

	var title := _label(_dialog, Vector2(32, 24), Vector2(396, 38), 28, Color("f1e8d8"))
	title.name = "ExitConfirmationTitle"
	title.text = tr("EXIT_CONFIRM_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_message = _label(_dialog, Vector2(42, 78), Vector2(376, 58), 20, Color("d8cdbc"))
	_message.name = "ExitConfirmationMessage"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_cancel_button = _button(
		_dialog, "ExitCancel", tr("EXIT_CONFIRM_CANCEL"), Vector2(32, 164), Vector2(188, 56), false
	)
	_leave_button = _button(
		_dialog, "ExitConfirm", tr("EXIT_CONFIRM_LEAVE"), Vector2(240, 164), Vector2(188, 56), true
	)
	_cancel_button.pressed.connect(cancel)
	_leave_button.pressed.connect(confirm_leave)
	_cancel_button.focus_neighbor_right = _leave_button.get_path()
	_leave_button.focus_neighbor_left = _cancel_button.get_path()


func present(stake: int) -> void:
	if is_open:
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_message.text = tr("EXIT_CONFIRM_MESSAGE") % stake
	is_open = true
	visible = true
	_play_reveal()
	_cancel_button.grab_focus()


func cancel() -> void:
	if not is_open:
		return
	is_open = false
	_play_dismiss()
	if is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()
	cancelled.emit()


func confirm_leave() -> void:
	if not is_open:
		return
	is_open = false
	_play_dismiss()
	leave_confirmed.emit()


func dismiss() -> void:
	is_open = false
	if _transition != null:
		_transition.kill()
	visible = false
	_reset_visual_state()


func _play_reveal() -> void:
	if _transition != null:
		_transition.kill()
	_reset_visual_state()
	if MotionPolicy.is_reduced():
		return
	_blocker.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	_dialog.position = Vector2(250, 154)
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.98, 0.98)
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_blocker, "modulate:a", 1.0, 0.12)
	_transition.tween_property(_dialog, "modulate:a", 1.0, 0.16)
	_transition.tween_property(_dialog, "position:y", 146.0, 0.18).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_dialog, "scale", Vector2.ONE, 0.18)
	_transition.finished.connect(func() -> void: _transition = null)


func _play_dismiss() -> void:
	if _transition != null:
		_transition.kill()
	if MotionPolicy.is_reduced():
		visible = false
		_reset_visual_state()
		return
	_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition.tween_property(_blocker, "modulate:a", 0.0, 0.12)
	_transition.tween_property(_dialog, "modulate:a", 0.0, 0.12)
	_transition.tween_property(_dialog, "position:y", 154.0, 0.12)
	_transition.tween_property(_dialog, "scale", Vector2(0.98, 0.98), 0.12)
	_transition.finished.connect(
		func() -> void:
			visible = false
			_reset_visual_state()
			_transition = null
	)


func _reset_visual_state() -> void:
	if _blocker == null or _dialog == null:
		return
	_blocker.modulate = Color.WHITE
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.modulate = Color.WHITE
	_dialog.position = Vector2(250, 146)
	_dialog.scale = Vector2.ONE


func handle_input(event: InputEvent) -> bool:
	if not is_open:
		return false
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	if event.is_action_pressed("back"):
		cancel()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused == _leave_button:
			_cancel_button.grab_focus()
		else:
			_leave_button.grab_focus()
	elif event.is_action_pressed("interact"):
		if get_viewport().gui_get_focus_owner() == _leave_button:
			confirm_leave()
		else:
			cancel()
	return true


func _label(
	parent: Control, at: Vector2, dimensions: Vector2, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font", Typography.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(
	parent: Control,
	node_name: String,
	text_value: String,
	at: Vector2,
	dimensions: Vector2,
	destructive: bool
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", Typography.CONTROL)
	button.add_theme_color_override("font_color", Color("f1e8d8"))
	var fill := Color("5a111c") if destructive else Color("252126")
	button.add_theme_stylebox_override("normal", _panel_style(fill, Color("6e5225"), 7, 1))
	button.add_theme_stylebox_override(
		"hover", _panel_style(fill.lightened(0.08), Color("c8a34b"), 7, 2)
	)
	button.add_theme_stylebox_override(
		"pressed", _panel_style(fill.darkened(0.14), Color("c8a34b"), 7, 2)
	)
	button.add_theme_stylebox_override("focus", _panel_style(fill, Color("48c5d5"), 7, 2))
	parent.add_child(button)
	ButtonFeedback.attach(button)
	return button


func _panel_style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color("05040570")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style
