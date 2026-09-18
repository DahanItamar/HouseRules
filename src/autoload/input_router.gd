extends Node

signal active_device_changed(device: Device)
signal gamepad_connection_changed(connected: bool)

enum Device { KEYBOARD, GAMEPAD }
var active_device: Device = Device.KEYBOARD
var active_gamepad_device: int = -1
var is_gamepad_disconnected: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
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
	var keys: Dictionary = {
		"interact": "INPUT_ENTER",
		"back": "INPUT_ESCAPE",
		"secondary": "INPUT_X",
		"tertiary": "INPUT_Y",
		"move_horizontal": "INPUT_AD",
		"move_vertical": "INPUT_WS",
		"move": "INPUT_WASD",
	}
	var buttons: Dictionary = {
		"interact": "INPUT_A",
		"back": "INPUT_B",
		"secondary": "INPUT_X",
		"tertiary": "INPUT_Y",
		"move_horizontal": "INPUT_STICK_HORIZONTAL",
		"move_vertical": "INPUT_STICK_VERTICAL",
		"move": "INPUT_STICK_DPAD",
	}
	var key: String = (
		buttons.get(action, "INPUT_DPAD")
		if active_device == Device.GAMEPAD
		else keys.get(action, "INPUT_WASD")
	)
	return tr(key)


func _input(event: InputEvent) -> void:
	var next: Device = active_device
	if event is InputEventKey and event.pressed:
		next = Device.KEYBOARD
	elif event is InputEventJoypadButton and event.pressed:
		next = Device.GAMEPAD
		active_gamepad_device = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		next = Device.GAMEPAD
		active_gamepad_device = event.device
	if next != active_device:
		active_device = next
		active_device_changed.emit(next)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected and is_gamepad_disconnected:
		active_gamepad_device = device
		is_gamepad_disconnected = false
		gamepad_connection_changed.emit(true)
	elif (
		not connected
		and active_device == Device.GAMEPAD
		and device == active_gamepad_device
		and not is_gamepad_disconnected
	):
		is_gamepad_disconnected = true
		gamepad_connection_changed.emit(false)


func move_snap_cursor(cursor: SnapCursor, event: InputEvent) -> bool:
	var direction := Vector2i.ZERO
	if event.is_action_pressed("move_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("move_right"):
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("move_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("move_down"):
		direction = Vector2i.DOWN
	var moved: bool = cursor.move(direction)
	if moved:
		AudioService.play(&"move")
	return moved


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
