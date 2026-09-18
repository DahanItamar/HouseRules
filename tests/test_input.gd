extends GutTest

const BUTTON_ACTIONS := {
	&"move_left": JOY_BUTTON_DPAD_LEFT,
	&"move_right": JOY_BUTTON_DPAD_RIGHT,
	&"move_up": JOY_BUTTON_DPAD_UP,
	&"move_down": JOY_BUTTON_DPAD_DOWN,
	&"interact": JOY_BUTTON_A,
	&"back": JOY_BUTTON_B,
	&"secondary": JOY_BUTTON_X,
	&"tertiary": JOY_BUTTON_Y,
	&"help": JOY_BUTTON_START,
}
const AXIS_ACTIONS := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}
var _original_device: InputRouter.Device


func before_each() -> void:
	_original_device = InputRouter.active_device


func after_each() -> void:
	get_tree().paused = false
	InputRouter.active_device = _original_device
	InputRouter.active_gamepad_device = -1
	InputRouter.is_gamepad_disconnected = false
	InputRouter.active_device_changed.emit(_original_device)


func test_ac037_every_gameplay_action_has_a_gamepad_button() -> void:
	for action: StringName in BUTTON_ACTIONS:
		assert_true(InputMap.has_action(action), "%s action exists" % action)
		assert_true(
			_has_button(action, BUTTON_ACTIONS[action]),
			"%s has its documented gamepad button" % action
		)


func test_ac037_movement_supports_the_left_stick_and_dpad() -> void:
	for action: StringName in AXIS_ACTIONS:
		var expected: Array = AXIS_ACTIONS[action]
		assert_true(
			_has_axis(action, expected[0], expected[1]),
			"%s has its documented left-stick direction" % action
		)


func test_ac038_device_change_swaps_glyphs_and_live_floor_prompt() -> void:
	InputRouter.active_device = InputRouter.Device.KEYBOARD
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.avatar_position = Vector2(480, 400)
	floor.refresh_proximity()
	assert_string_contains(floor._prompt.text, tr("INPUT_WASD"))
	assert_string_contains(floor._prompt.text, tr("INPUT_ESCAPE"))

	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	InputRouter._input(button)
	assert_eq(InputRouter.active_device, InputRouter.Device.GAMEPAD)
	assert_string_contains(floor._prompt.text, tr("INPUT_STICK_DPAD"))
	assert_string_contains(floor._prompt.text, tr("INPUT_B"))

	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	InputRouter._input(key)
	assert_eq(InputRouter.active_device, InputRouter.Device.KEYBOARD)
	assert_string_contains(floor._prompt.text, tr("INPUT_WASD"))


func test_ac037_active_gamepad_disconnect_pauses_until_reconnect() -> void:
	var overlay := DisconnectPauseOverlay.new()
	add_child_autofree(overlay)
	var button := InputEventJoypadButton.new()
	button.device = 7
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	InputRouter._input(button)

	InputRouter._on_joy_connection_changed(7, false)
	assert_true(InputRouter.is_gamepad_disconnected)
	assert_true(overlay.visible)
	assert_true(get_tree().paused)

	InputRouter._on_joy_connection_changed(9, true)
	assert_false(InputRouter.is_gamepad_disconnected)
	assert_eq(InputRouter.active_gamepad_device, 9)
	assert_false(overlay.visible)
	assert_false(get_tree().paused)


func test_ac039_dpad_and_left_stick_move_a_wrapping_snap_cursor() -> void:
	var cursor := SnapCursor.new(5, 5)
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_LEFT
	dpad.pressed = true
	assert_true(InputRouter.move_snap_cursor(cursor, dpad))
	assert_eq(cursor.index, 4, "Left wraps inside the current row")

	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	assert_true(InputRouter.move_snap_cursor(cursor, stick))
	assert_eq(cursor.index, 9, "Down preserves the selected column")

	cursor.index = 24
	assert_true(InputRouter.move_snap_cursor(cursor, stick))
	assert_eq(cursor.index, 4, "Vertical movement wraps inside the grid")


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


func _has_axis(action: StringName, axis: JoyAxis, direction: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventJoypadMotion
			and event.axis == axis
			and is_equal_approx(event.axis_value, direction)
		):
			return true
	return false
