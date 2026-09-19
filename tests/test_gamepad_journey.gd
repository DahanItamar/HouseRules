extends GutTest

const MAIN_SCENE := preload("res://src/ui/main.tscn")

var _original_platform: PlatformServices
var _original_test_mode: bool
var _original_device: InputRouter.Device


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	_original_device = InputRouter.active_device
	SaveService.platform = LocalPlatform.new(
		"user://tests/gamepad_journey_%s" % Time.get_ticks_usec()
	)
	SaveService.new_game(20260919)
	InputRouter.active_device = InputRouter.Device.KEYBOARD
	InputRouter.active_gamepad_device = -1


func after_each() -> void:
	_release_axis(JOY_AXIS_LEFT_X)
	_release_axis(JOY_AXIS_LEFT_Y)
	if SceneRouter.session != null:
		SceneRouter.return_to_floor()
	await get_tree().process_frame
	SceneRouter.floor = null
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	InputRouter.active_device = _original_device
	InputRouter.active_gamepad_device = -1
	InputRouter.is_gamepad_disconnected = false
	SaveService.new_game(20260919)


func test_controller_only_player_can_complete_menu_to_cabinet_to_floor_journey() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_true(main._menu.visible)
	assert_false(main._is_playing)

	await _press_button(JOY_BUTTON_A)
	assert_eq(InputRouter.active_device, InputRouter.Device.GAMEPAD)
	assert_true(main._is_playing, "A starts play from the main menu")
	var floor: FloorController = main._floor
	assert_not_null(floor)
	assert_null(floor.nearby_definition)

	# The floor polls the left stick. Move through the open lower aisle, then
	# approach the slot from below so collision and proximity both participate.
	await _move_floor_with_axis(floor, JOY_AXIS_LEFT_X, -1.0, 1.65)
	await _move_floor_with_axis(floor, JOY_AXIS_LEFT_Y, -1.0, 1.88)
	assert_not_null(floor.nearby_definition, "Left-stick movement reaches a join ring")
	assert_eq(floor.nearby_definition.id, &"slot_classic")
	assert_string_contains(floor._prompt.text, "[%s] JOIN" % tr("INPUT_A"))

	await _press_button(JOY_BUTTON_A)
	assert_not_null(SceneRouter.session, "A joins the nearby cabinet")
	var cabinet: MiniGame = SceneRouter.session.cabinet
	assert_eq(cabinet.context.definition.id, &"slot_classic")
	assert_false(cabinet.is_round_active)

	await _press_button(JOY_BUTTON_A)
	assert_true(cabinet.is_round_active, "A exercises the cabinet primary action")

	await _press_button(JOY_BUTTON_START)
	assert_true(cabinet.panel.help_open, "Menu opens contextual help")
	await _press_button(JOY_BUTTON_B)
	assert_false(cabinet.panel.help_open, "B closes contextual help")

	# Exiting a live wager is deliberately guarded. B opens the confirmation,
	# right-stick navigation selects Leave, and A confirms it.
	await _press_button(JOY_BUTTON_B)
	assert_true(cabinet.exit_confirmation.is_open)
	await _pulse_axis(JOY_AXIS_LEFT_X, 1.0)
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		cabinet.exit_confirmation._leave_button,
		"Stick navigation reaches the explicit leave action"
	)
	await _press_button(JOY_BUTTON_A)
	assert_null(SceneRouter.session, "A confirms exit back to the casino floor")
	assert_true(main._floor.visible)
	assert_true(main._floor.is_physics_processing())


func _press_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.device = 0
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.device = 0
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _pulse_axis(axis: JoyAxis, value: float) -> void:
	_hold_axis(axis, value)
	await get_tree().process_frame


func _move_floor_with_axis(
	floor: FloorController, axis: JoyAxis, value: float, duration: float
) -> void:
	_hold_axis(axis, value)
	await get_tree().process_frame
	# Real 60 Hz steps: one giant frame is clamped by the tunnelling guard.
	for _frame: int in range(ceili(duration * 60.0)):
		floor._physics_process(1.0 / 60.0)
	_release_axis(axis)
	await get_tree().process_frame
	_release_axis(axis)
	await get_tree().process_frame


func _hold_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _release_axis(axis: JoyAxis) -> void:
	_hold_axis(axis, 0.0)
