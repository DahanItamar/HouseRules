extends Node

signal active_device_changed(device: Device)

enum Device { KEYBOARD, GAMEPAD }
var active_device: Device = Device.KEYBOARD


func _ready() -> void:
	_bind("move_left", KEY_A, JOY_BUTTON_DPAD_LEFT)
	_bind("move_right", KEY_D, JOY_BUTTON_DPAD_RIGHT)
	_bind("move_up", KEY_W, JOY_BUTTON_DPAD_UP)
	_bind("move_down", KEY_S, JOY_BUTTON_DPAD_DOWN)
	_bind("interact", KEY_ENTER, JOY_BUTTON_A)
	_bind("back", KEY_ESCAPE, JOY_BUTTON_B)
	_bind("secondary", KEY_X, JOY_BUTTON_X)
	_bind("tertiary", KEY_Y, JOY_BUTTON_Y)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


func glyph(action: String) -> String:
	var keys: Dictionary = {"interact": "Enter", "back": "Esc", "secondary": "X", "tertiary": "Y"}
	var buttons: Dictionary = {"interact": "A", "back": "B", "secondary": "X", "tertiary": "Y"}
	return (
		buttons.get(action, "D-pad")
		if active_device == Device.GAMEPAD
		else keys.get(action, "WASD")
	)


func _input(event: InputEvent) -> void:
	var next: Device = active_device
	if event is InputEventKey and event.pressed:
		next = Device.KEYBOARD
	elif event is InputEventJoypadButton and event.pressed:
		next = Device.GAMEPAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		next = Device.GAMEPAD
	if next != active_device:
		active_device = next
		active_device_changed.emit(next)


func _bind(action: String, key: Key, button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = button
	InputMap.action_add_event(action, pad_event)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
