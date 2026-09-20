extends Node

signal active_device_changed(device: Device)
signal gamepad_connection_changed(connected: bool)
## Emitted when the pad's button family changes (Xbox, PlayStation, Nintendo).
signal gamepad_family_changed(family: GamepadFamily)

enum Device { KEYBOARD, GAMEPAD }
## Face-button families. XBOX also covers generic XInput and SDL pads.
enum GamepadFamily { XBOX, PLAYSTATION, NINTENDO }
## Glyph shapes an InputGlyph knows how to draw.
enum GlyphKind { KEYCAP, KEY_PAIR, KEY_CLUSTER, FACE, SHOULDER, TRIGGER, DPAD, STICK, MENU, VIEW }

const XBOX_FACE_COLORS: Dictionary = {
	JOY_BUTTON_A: Color("3fa84a"),
	JOY_BUTTON_B: Color("d2433b"),
	JOY_BUTTON_X: Color("2f6fcf"),
	JOY_BUTTON_Y: Color("e3b126"),
}
const PLAYSTATION_FACE_COLORS: Dictionary = {
	JOY_BUTTON_A: Color("86a9e8"),
	JOY_BUTTON_B: Color("e86a6e"),
	JOY_BUTTON_X: Color("dd92d0"),
	JOY_BUTTON_Y: Color("4cc6a4"),
}
const PLAYSTATION_FACE_SYMBOLS: Dictionary = {
	JOY_BUTTON_A: &"cross",
	JOY_BUTTON_B: &"circle",
	JOY_BUTTON_X: &"square",
	JOY_BUTTON_Y: &"triangle",
}
## Nintendo pads print B at the bottom and A on the right (SDL positional layout).
const NINTENDO_FACE_LABELS: Dictionary = {
	JOY_BUTTON_A: "B",
	JOY_BUTTON_B: "A",
	JOY_BUTTON_X: "Y",
	JOY_BUTTON_Y: "X",
}
const SHOULDER_LABELS: Dictionary = {
	GamepadFamily.XBOX: ["LB", "RB", "LT", "RT", "LS", "RS"],
	GamepadFamily.PLAYSTATION: ["L1", "R1", "L2", "R2", "L3", "R3"],
	GamepadFamily.NINTENDO: ["L", "R", "ZL", "ZR", "LS", "RS"],
}

var active_device: Device = Device.KEYBOARD
var active_gamepad_device: int = -1
var is_gamepad_disconnected: bool = false
var gamepad_family: GamepadFamily = GamepadFamily.XBOX
## Capture tools and tests pin the prompt family; a negative value means unpinned.
var _forced_family: int = -1


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
	_bind("help", KEY_F1, JOY_BUTTON_START)
	# Bet stepping: the shoulders walk the legal denominations and the right
	# trigger jumps to the table maximum. No cabinet binds Q, E, R or the shoulders.
	_bind("bet_down", KEY_Q, JOY_BUTTON_LEFT_SHOULDER)
	_bind("bet_up", KEY_E, JOY_BUTTON_RIGHT_SHOULDER)
	_bind_trigger("bet_max", KEY_R, JOY_AXIS_TRIGGER_RIGHT)
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
		"help": "INPUT_F1",
		"bet_down": "INPUT_Q",
		"bet_up": "INPUT_E",
		"bet_max": "INPUT_R",
	}
	var buttons: Dictionary = {
		"interact": "INPUT_A",
		"back": "INPUT_B",
		"secondary": "INPUT_X",
		"tertiary": "INPUT_Y",
		"move_horizontal": "INPUT_STICK_HORIZONTAL",
		"move_vertical": "INPUT_STICK_VERTICAL",
		"move": "INPUT_STICK_DPAD",
		"help": "INPUT_MENU",
		"bet_down": "INPUT_LB",
		"bet_up": "INPUT_RB",
		"bet_max": "INPUT_RT",
	}
	if active_device == Device.GAMEPAD and gamepad_family == GamepadFamily.PLAYSTATION:
		(
			buttons
			. merge(
				{
					"interact": "INPUT_PS_CROSS",
					"back": "INPUT_PS_CIRCLE",
					"secondary": "INPUT_PS_SQUARE",
					"tertiary": "INPUT_PS_TRIANGLE",
					"help": "INPUT_OPTIONS",
					"bet_down": "INPUT_L1",
					"bet_up": "INPUT_R1",
					"bet_max": "INPUT_R2",
				},
				true
			)
		)
	elif active_device == Device.GAMEPAD and gamepad_family == GamepadFamily.NINTENDO:
		(
			buttons
			. merge(
				{
					"interact": "INPUT_B",
					"back": "INPUT_A",
					"secondary": "INPUT_Y",
					"tertiary": "INPUT_X",
					"help": "INPUT_PLUS",
					"bet_down": "INPUT_L",
					"bet_up": "INPUT_R_SHOULDER",
					"bet_max": "INPUT_ZR",
				},
				true
			)
		)
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
	elif event is InputEventMouseButton and event.pressed:
		next = Device.KEYBOARD
	elif event is InputEventMouseMotion and event.relative.length() > 6.0:
		next = Device.KEYBOARD
	elif event is InputEventJoypadButton and event.pressed:
		next = Device.GAMEPAD
		active_gamepad_device = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		next = Device.GAMEPAD
		active_gamepad_device = event.device
	if next == Device.GAMEPAD:
		_refresh_gamepad_family()
	if next != active_device:
		active_device = next
		active_device_changed.emit(next)


## The pad family named by a controller's reported name.
static func family_for_name(joy_name: String) -> GamepadFamily:
	var lowered := joy_name.to_lower()
	for marker: String in ["sony", "playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5"]:
		if lowered.contains(marker):
			return GamepadFamily.PLAYSTATION
	if lowered.begins_with("ps ") or lowered.contains(" ps "):
		return GamepadFamily.PLAYSTATION
	for marker: String in ["nintendo", "switch", "joy-con", "joycon", "pro controller"]:
		if lowered.contains(marker):
			return GamepadFamily.NINTENDO
	return GamepadFamily.XBOX


## Pins the prompt device and family (capture tools and tests). A negative family
## releases the pin so the connected pad decides again.
func force_prompt_family(device: int, family: int = -1) -> void:
	_forced_family = family
	if family >= 0 and family != gamepad_family:
		gamepad_family = family as GamepadFamily
		gamepad_family_changed.emit(gamepad_family)
	if device >= 0 and device != active_device:
		active_device = device as Device
		active_device_changed.emit(active_device)


func _refresh_gamepad_family(device: int = -1) -> void:
	var pad := active_gamepad_device if device < 0 else device
	if _forced_family >= 0 or pad < 0:
		return
	var family := family_for_name(Input.get_joy_name(pad))
	if family != gamepad_family:
		gamepad_family = family
		gamepad_family_changed.emit(family)


## Describes how to draw the prompt for `action` on the active (or given) device.
## Keys and buttons come from the InputMap binding, so a rebind updates the glyph.
## Composite prompts: `move`, `move_horizontal`, `move_vertical`.
func glyph_spec(action: StringName, device: int = -1, family: int = -1) -> Dictionary:
	var use_device: Device = active_device if device < 0 else device as Device
	var use_family: GamepadFamily = gamepad_family if family < 0 else family as GamepadFamily
	if use_device == Device.KEYBOARD:
		return _keyboard_spec(action)
	return _gamepad_spec(action, use_family)


## True when `action` names a prompt this router can draw.
func has_prompt(action: StringName) -> bool:
	return action in [&"move", &"move_horizontal", &"move_vertical"] or InputMap.has_action(action)


func _keyboard_spec(action: StringName) -> Dictionary:
	match action:
		&"move":
			return {
				"kind": GlyphKind.KEY_CLUSTER,
				"labels":
				[
					_key_label_for(&"move_up"),
					_key_label_for(&"move_left"),
					_key_label_for(&"move_down"),
					_key_label_for(&"move_right"),
				],
			}
		&"move_horizontal":
			return {
				"kind": GlyphKind.KEY_PAIR,
				"labels": [_key_label_for(&"move_left"), _key_label_for(&"move_right")],
			}
		&"move_vertical":
			return {
				"kind": GlyphKind.KEY_PAIR,
				"labels": [_key_label_for(&"move_up"), _key_label_for(&"move_down")],
			}
	return {"kind": GlyphKind.KEYCAP, "label": _key_label_for(action)}


func _gamepad_spec(action: StringName, family: GamepadFamily) -> Dictionary:
	match action:
		&"move":
			return {"kind": GlyphKind.STICK, "direction": &"all", "label": ""}
		&"move_horizontal":
			return {"kind": GlyphKind.DPAD, "direction": &"horizontal"}
		&"move_vertical":
			return {"kind": GlyphKind.DPAD, "direction": &"vertical"}
	if not InputMap.has_action(action):
		return {"kind": GlyphKind.FACE, "label": "?", "color": Color("3a3438")}
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if button != null:
			return button_spec(button.button_index, family)
	for event: InputEvent in InputMap.action_get_events(action):
		var motion := event as InputEventJoypadMotion
		if motion == null:
			continue
		var labels: Array = SHOULDER_LABELS[family]
		if motion.axis == JOY_AXIS_TRIGGER_LEFT:
			return {"kind": GlyphKind.TRIGGER, "label": labels[2]}
		if motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			return {"kind": GlyphKind.TRIGGER, "label": labels[3]}
		return {"kind": GlyphKind.STICK, "direction": &"all", "label": ""}
	return {"kind": GlyphKind.FACE, "label": "?", "color": Color("3a3438")}


## The drawable glyph for one gamepad button in a family.
static func button_spec(index: int, family: GamepadFamily) -> Dictionary:
	var labels: Array = SHOULDER_LABELS[family]
	match index:
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			if family == GamepadFamily.PLAYSTATION:
				return {
					"kind": GlyphKind.FACE,
					"symbol": PLAYSTATION_FACE_SYMBOLS[index],
					"color": PLAYSTATION_FACE_COLORS[index],
				}
			if family == GamepadFamily.NINTENDO:
				return {
					"kind": GlyphKind.FACE,
					"label": NINTENDO_FACE_LABELS[index],
					"color": Color("201d21"),
					"outlined": true,
				}
			return {
				"kind": GlyphKind.FACE,
				"label": ["A", "B", "X", "Y"][index],
				"color": XBOX_FACE_COLORS[index],
			}
		JOY_BUTTON_LEFT_SHOULDER:
			return {"kind": GlyphKind.SHOULDER, "label": labels[0]}
		JOY_BUTTON_RIGHT_SHOULDER:
			return {"kind": GlyphKind.SHOULDER, "label": labels[1]}
		JOY_BUTTON_LEFT_STICK:
			return {"kind": GlyphKind.STICK, "direction": &"press", "label": labels[4]}
		JOY_BUTTON_RIGHT_STICK:
			return {"kind": GlyphKind.STICK, "direction": &"press", "label": labels[5]}
		JOY_BUTTON_DPAD_LEFT:
			return {"kind": GlyphKind.DPAD, "direction": &"left"}
		JOY_BUTTON_DPAD_RIGHT:
			return {"kind": GlyphKind.DPAD, "direction": &"right"}
		JOY_BUTTON_DPAD_UP:
			return {"kind": GlyphKind.DPAD, "direction": &"up"}
		JOY_BUTTON_DPAD_DOWN:
			return {"kind": GlyphKind.DPAD, "direction": &"down"}
		JOY_BUTTON_START:
			return {"kind": GlyphKind.MENU, "family": family}
		JOY_BUTTON_BACK:
			return {"kind": GlyphKind.VIEW, "family": family}
	return {"kind": GlyphKind.FACE, "label": str(index), "color": Color("3a3438")}


## The printed legend of the key bound to an action (e.g. "Enter", "Q", "F1").
func _key_label_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: Key = key.keycode
		if code == KEY_NONE and key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			# The printed legend follows the player's keyboard layout when the
			# display server can map it (not under --headless).
			if DisplayServer.get_name() != "headless":
				var mapped := DisplayServer.keyboard_get_keycode_from_physical(code)
				if mapped != KEY_NONE:
					code = mapped
		return key_label(code)
	return "?"


static func key_label(code: Key) -> String:
	match code:
		KEY_ENTER, KEY_KP_ENTER:
			return TranslationServer.translate("INPUT_ENTER")
		KEY_ESCAPE:
			return TranslationServer.translate("INPUT_ESCAPE")
		KEY_SPACE:
			return TranslationServer.translate("INPUT_SPACE")
		KEY_UP:
			return String.chr(0x2191)
		KEY_DOWN:
			return String.chr(0x2193)
		KEY_LEFT:
			return String.chr(0x2190)
		KEY_RIGHT:
			return String.chr(0x2192)
	return OS.get_keycode_string(code)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected and (active_gamepad_device < 0 or device == active_gamepad_device):
		_refresh_gamepad_family(device)
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


func _bind_trigger(action: String, key: Key, axis: JoyAxis) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.5)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = axis
	trigger.axis_value = 1.0
	InputMap.action_add_event(action, trigger)


func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
