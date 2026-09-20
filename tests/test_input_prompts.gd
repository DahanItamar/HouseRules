extends GutTest
## Input prompts: device and pad-family detection, glyph resolution from the
## InputMap, bet-stepping bindings, and live prompt components.

var _device: InputRouter.Device
var _family: InputRouter.GamepadFamily


func before_each() -> void:
	_device = InputRouter.active_device
	_family = InputRouter.gamepad_family


func after_each() -> void:
	InputRouter.force_prompt_family(_device, _family)
	InputRouter.force_prompt_family(-1, -1)
	InputRouter.active_device_changed.emit(InputRouter.active_device)


func test_pad_family_is_detected_from_the_controller_name() -> void:
	var cases := {
		"Sony Interactive Entertainment Wireless Controller": InputRouter.GamepadFamily.PLAYSTATION,
		"DualSense Wireless Controller": InputRouter.GamepadFamily.PLAYSTATION,
		"PS4 Controller": InputRouter.GamepadFamily.PLAYSTATION,
		"DualShock 4": InputRouter.GamepadFamily.PLAYSTATION,
		"Nintendo Switch Pro Controller": InputRouter.GamepadFamily.NINTENDO,
		"Joy-Con (L/R)": InputRouter.GamepadFamily.NINTENDO,
		"Xbox Series X Controller": InputRouter.GamepadFamily.XBOX,
		"XInput Gamepad (GLFW)": InputRouter.GamepadFamily.XBOX,
		"Generic USB Joystick": InputRouter.GamepadFamily.XBOX,
	}
	for joy_name: String in cases:
		assert_eq(InputRouter.family_for_name(joy_name), cases[joy_name], joy_name)


func test_family_change_emits_once_and_switches_glyphs() -> void:
	InputRouter.force_prompt_family(InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.XBOX)
	watch_signals(InputRouter)
	InputRouter.force_prompt_family(
		InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.PLAYSTATION
	)
	assert_signal_emit_count(InputRouter, "gamepad_family_changed", 1)
	InputRouter.force_prompt_family(
		InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.PLAYSTATION
	)
	assert_signal_emit_count(InputRouter, "gamepad_family_changed", 1, "No change, no signal")
	assert_eq(InputRouter.glyph_spec(&"interact").symbol, &"cross")


func test_keyboard_glyphs_come_from_the_input_map_binding() -> void:
	var keyboard := InputRouter.Device.KEYBOARD
	assert_eq(InputRouter.glyph_spec(&"interact", keyboard).label, tr("INPUT_ENTER"))
	assert_eq(InputRouter.glyph_spec(&"back", keyboard).label, tr("INPUT_ESCAPE"))
	assert_eq(InputRouter.glyph_spec(&"secondary", keyboard).label, "X")
	assert_eq(InputRouter.glyph_spec(&"tertiary", keyboard).label, "Y")
	assert_eq(InputRouter.glyph_spec(&"bet_down", keyboard).label, "Q")
	assert_eq(InputRouter.glyph_spec(&"bet_up", keyboard).label, "E")
	assert_eq(InputRouter.glyph_spec(&"bet_max", keyboard).label, "R")
	assert_eq(InputRouter.glyph_spec(&"help", keyboard).label, "F1")
	var move := InputRouter.glyph_spec(&"move", keyboard)
	assert_eq(move.kind, InputRouter.GlyphKind.KEY_CLUSTER)
	assert_eq(move.labels, ["W", "A", "S", "D"])
	assert_eq(InputRouter.glyph_spec(&"move_horizontal", keyboard).labels, ["A", "D"])
	# A rebind is read back from the InputMap, not from a hard-coded table.
	InputMap.add_action(&"prompt_probe")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	InputMap.action_add_event(&"prompt_probe", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"prompt_probe", pad)
	assert_eq(InputRouter.glyph_spec(&"prompt_probe", keyboard).label, "T")
	var xbox := InputRouter.glyph_spec(
		&"prompt_probe", InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.XBOX
	)
	assert_eq(xbox.label, "Y")
	assert_eq(xbox.color, InputRouter.XBOX_FACE_COLORS[JOY_BUTTON_Y])
	InputMap.erase_action(&"prompt_probe")


func test_gamepad_glyphs_follow_each_family() -> void:
	var pad := InputRouter.Device.GAMEPAD
	var xbox := InputRouter.GamepadFamily.XBOX
	var sony := InputRouter.GamepadFamily.PLAYSTATION
	var nintendo := InputRouter.GamepadFamily.NINTENDO
	var face := InputRouter.glyph_spec(&"interact", pad, xbox)
	assert_eq(face.kind, InputRouter.GlyphKind.FACE)
	assert_eq(face.label, "A")
	assert_eq(face.color, InputRouter.XBOX_FACE_COLORS[JOY_BUTTON_A], "Xbox A is green")
	assert_eq(
		InputRouter.glyph_spec(&"back", pad, xbox).color, InputRouter.XBOX_FACE_COLORS[JOY_BUTTON_B]
	)
	var symbols := {
		&"interact": &"cross", &"back": &"circle", &"secondary": &"square", &"tertiary": &"triangle"
	}
	for action: StringName in symbols:
		assert_eq(InputRouter.glyph_spec(action, pad, sony).symbol, symbols[action], String(action))
	assert_eq(
		InputRouter.glyph_spec(&"interact", pad, nintendo).label, "B", "Nintendo bottom button"
	)
	var shoulders := {
		xbox: ["LB", "RB", "RT"], sony: ["L1", "R1", "R2"], nintendo: ["L", "R", "ZR"]
	}
	for family: int in shoulders:
		var expected: Array = shoulders[family]
		assert_eq(
			InputRouter.glyph_spec(&"bet_down", pad, family).kind, InputRouter.GlyphKind.SHOULDER
		)
		assert_eq(InputRouter.glyph_spec(&"bet_down", pad, family).label, expected[0])
		assert_eq(InputRouter.glyph_spec(&"bet_up", pad, family).label, expected[1])
		assert_eq(
			InputRouter.glyph_spec(&"bet_max", pad, family).kind, InputRouter.GlyphKind.TRIGGER
		)
		assert_eq(InputRouter.glyph_spec(&"bet_max", pad, family).label, expected[2])
		var menu := InputRouter.glyph_spec(&"help", pad, family)
		assert_eq(menu.kind, InputRouter.GlyphKind.MENU)
		assert_eq(menu.family, family)
	assert_eq(
		InputRouter.glyph_spec(&"move_horizontal", pad, xbox).kind, InputRouter.GlyphKind.DPAD
	)
	assert_eq(InputRouter.glyph_spec(&"move", pad, xbox).kind, InputRouter.GlyphKind.STICK)


func test_bet_actions_are_bound_and_conflict_free() -> void:
	var expected := {
		&"bet_down": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],
		&"bet_up": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action: StringName in expected:
		assert_true(InputMap.has_action(action))
		assert_true(_has_key(action, expected[action][0]), "%s key" % action)
		assert_true(_has_button(action, expected[action][1]), "%s button" % action)
	assert_true(_has_key(&"bet_max", KEY_R))
	var trigger := false
	for event: InputEvent in InputMap.action_get_events(&"bet_max"):
		var motion := event as InputEventJoypadMotion
		trigger = trigger or (motion != null and motion.axis == JOY_AXIS_TRIGGER_RIGHT)
	assert_true(trigger, "bet_max rides the right trigger")
	# No other gameplay action shares these keys or buttons.
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or action in [&"bet_down", &"bet_up", &"bet_max"]:
			continue
		for key: Key in [KEY_Q, KEY_E, KEY_R]:
			assert_false(_has_key(action, key), "%s does not also use %s" % [action, key])
		for button: JoyButton in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			assert_false(_has_button(action, button), "%s does not also use a shoulder" % action)


func test_mouse_input_counts_as_keyboard() -> void:
	InputRouter.force_prompt_family(InputRouter.Device.GAMEPAD, -1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	InputRouter._input(click)
	assert_eq(InputRouter.active_device, InputRouter.Device.KEYBOARD)
	InputRouter.force_prompt_family(InputRouter.Device.GAMEPAD, -1)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(24, 0)
	InputRouter._input(motion)
	assert_eq(InputRouter.active_device, InputRouter.Device.KEYBOARD)


func test_input_hint_text_updates_on_device_change() -> void:
	InputRouter.force_prompt_family(InputRouter.Device.KEYBOARD, InputRouter.GamepadFamily.XBOX)
	var hint := InputHint.new()
	hint.action = &"interact"
	hint.label = tr("ACTION_DEAL")
	add_child_autofree(hint)
	assert_eq(hint.plain_text(), "[%s] %s" % [tr("INPUT_ENTER"), tr("ACTION_DEAL")])
	var keyboard_width := hint.size.x
	InputRouter.force_prompt_family(InputRouter.Device.GAMEPAD, -1)
	assert_eq(hint.plain_text(), "[%s] %s" % [tr("INPUT_A"), tr("ACTION_DEAL")])
	assert_eq(hint.glyph_spec().kind, InputRouter.GlyphKind.FACE)
	assert_ne(hint.size.x, keyboard_width, "The hint re-measures for the new glyph")


func test_prompt_label_draws_tokens_and_keeps_a_plain_fallback() -> void:
	InputRouter.force_prompt_family(InputRouter.Device.KEYBOARD, InputRouter.GamepadFamily.XBOX)
	var label := InputPromptLabel.new()
	label.add_theme_color_override("font_color", Color("f1e8d8"))
	add_child_autofree(label)
	label.template = "[{interact}] JOIN    [{back}] CLOSE"
	assert_true(label.has_glyphs())
	assert_eq(label.glyph_actions(), [&"interact", &"back"] as Array[StringName])
	assert_eq(label.text, "[%s] JOIN    [%s] CLOSE" % [tr("INPUT_ENTER"), tr("INPUT_ESCAPE")])
	assert_eq(label.get_theme_color("font_color").a, 0.0, "Glyph art replaces the native text")
	assert_eq(label.ink(), Color("f1e8d8"))
	InputRouter.force_prompt_family(InputRouter.Device.GAMEPAD, -1)
	assert_eq(label.text, "[A] JOIN    [B] CLOSE", "The fallback follows the live device")
	label.template = "Plain copy"
	assert_false(label.has_glyphs())
	assert_eq(label.get_theme_color("font_color"), Color("f1e8d8"), "Plain copy draws natively")
	label.template = "{unknown_action} stays literal"
	assert_false(label.has_glyphs())


func test_prompt_button_keeps_its_label_and_names_its_input() -> void:
	InputRouter.force_prompt_family(
		InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.PLAYSTATION
	)
	var button := PromptButton.new()
	button.text = tr("ACTION_DEAL")
	button.action = &"interact"
	button.size = Vector2(168, 56)
	add_child_autofree(button)
	assert_eq(button.text, tr("ACTION_DEAL"))
	assert_eq(button.glyph_spec().symbol, &"cross")
	assert_eq(button.get_theme_color("font_color").a, 0.0, "The button draws its own label")
	assert_string_contains(button.plain_text(), tr("ACTION_DEAL"))


func test_glyphs_measure_to_their_labels() -> void:
	var narrow := InputGlyph.measure({"kind": InputRouter.GlyphKind.KEYCAP, "label": "Q"}, 20.0)
	var wide := InputGlyph.measure(
		{"kind": InputRouter.GlyphKind.KEYCAP, "label": tr("INPUT_ENTER")}, 20.0
	)
	assert_almost_eq(
		narrow, 20.0 * GlyphKit.KEYCAP_ASPECT, 0.5, "A single-letter keycap keeps the painted cap"
	)
	assert_gt(wide, narrow, "Wide keys grow with their legend")
	var face := {"kind": InputRouter.GlyphKind.FACE, "label": "A", "color": Color.GREEN}
	assert_eq(InputGlyph.measure(face, 18.0), 18.0)


func _has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and (key.physical_keycode == keycode or key.keycode == keycode):
			return true
	return false


func _has_button(action: StringName, button_index: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if button != null and button.button_index == button_index:
			return true
	return false
