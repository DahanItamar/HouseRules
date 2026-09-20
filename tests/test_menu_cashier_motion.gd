extends GutTest

const MAIN_SCENE := preload("res://src/ui/main.tscn")
const CASHIER_MOTION_DIRECTOR_SCRIPT := preload("res://src/ui/cashier_motion_director.gd")

var _original_platform: PlatformServices
var _original_test_mode: bool


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	SaveService.platform = LocalPlatform.new(
		"user://tests/menu_cashier_motion_%s" % Time.get_ticks_usec()
	)
	SaveService.new_game(20260919)
	Wallet.set_test_mode(false)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	SaveService.new_game(20260919)


func test_menu_reveal_stages_the_information_hierarchy_then_settles_exactly() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_eq(main._menu_badge.modulate.a, 0.0, "The badge fades in rather than popping")
	assert_eq(main._menu_badge.position.y, 72.0, "The badge drops the last few pixels")
	for row: Button in main._menu_rows:
		assert_eq(row.modulate.a, 0.0)
		assert_eq(row.position.x, 38.0, "Every row slides in from the left")
	for chrome: Control in main._menu_chrome:
		assert_eq(chrome.modulate.a, 0.0)
	await wait_seconds(0.46)
	assert_eq(main._menu_badge.modulate, Color.WHITE)
	assert_eq(main._menu_badge.position, Vector2(56, 64))
	for index: int in range(main._menu_rows.size()):
		var row: Button = main._menu_rows[index]
		assert_eq(row.modulate, Color.WHITE)
		assert_eq(row.position, Vector2(56, 300 + 56 * index), "Rows settle on their step")
	for chrome: Control in main._menu_chrome:
		assert_eq(chrome.modulate, Color.WHITE)


func test_reduced_menu_reveal_is_immediately_complete() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_eq(main._menu_background.modulate.a, 1.0)
	assert_eq(main._menu_badge.modulate, Color.WHITE)
	assert_eq(main._menu_badge.position, Vector2(56, 64))
	for index: int in range(main._menu_rows.size()):
		var row: Button = main._menu_rows[index]
		assert_eq(row.modulate, Color.WHITE, "Reduced motion shows the finished menu at once")
		assert_eq(row.position, Vector2(56, 300 + 56 * index))
	for chrome: Control in main._menu_chrome:
		assert_eq(chrome.modulate, Color.WHITE)


func test_cashier_content_reveal_is_bounded_and_restores_every_control() -> void:
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	var director := CASHIER_MOTION_DIRECTOR_SCRIPT.new()
	add_child_autofree(director)
	director.bind(floor)
	assert_gt(director.tracked_control_count(), 10)
	director.play_open()
	assert_true(director.has_active_motion())
	assert_eq(director._controls[0].modulate.a, 0.0)
	assert_eq(
		director._controls[0].position,
		(
			director._rest_positions[director._controls[0]]
			+ CASHIER_MOTION_DIRECTOR_SCRIPT.ENTRY_OFFSET
		)
	)
	await wait_seconds(0.58)
	assert_false(director.has_active_motion())
	for control: Control in director._controls:
		assert_eq(control.position, director._rest_positions[control])
		assert_eq(control.modulate, Color.WHITE)


func test_reduced_motion_cancels_cashier_travel_at_authoritative_final_state() -> void:
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	var director := CASHIER_MOTION_DIRECTOR_SCRIPT.new()
	add_child_autofree(director)
	director.bind(floor)
	director.play_open()
	assert_true(director.has_active_motion())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(director.has_active_motion())
	for control: Control in director._controls:
		assert_eq(control.position, director._rest_positions[control])
		assert_eq(control.modulate, Color.WHITE)


func test_main_shell_connects_cashier_visibility_to_the_content_director() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main._show_floor_now()
	var floor: FloorController = main._floor
	floor.set_physics_process(false)
	floor.avatar_position = FloorController.CASHIER_POSITION
	floor.refresh_proximity()
	assert_true(floor.interact())
	await get_tree().process_frame
	assert_true(main._cashier_motion_director.has_active_motion())
	assert_gt(main._cashier_motion_director.tracked_control_count(), 10)


func test_open_cashier_keeps_a_bounded_ambient_visual_alive_after_entry_settles() -> void:
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	var director := CASHIER_MOTION_DIRECTOR_SCRIPT.new()
	add_child_autofree(director)
	director.bind(floor)
	floor.avatar_position = FloorController.CASHIER_POSITION
	floor.refresh_proximity()
	assert_true(floor.interact())
	await wait_seconds(0.58)
	assert_false(director.has_active_motion(), "The finite content reveal has settled")
	assert_true(
		director.has_active_ambient_motion(),
		"The open cashier retains one quiet, presentation-only ambient loop"
	)
	var first_sample: Variant = director.ambient_visual_sample()
	await wait_seconds(0.27)
	var second_sample: Variant = director.ambient_visual_sample()
	assert_ne(
		second_sample,
		first_sample,
		"The ambient loop changes an observable visual after the entry choreography"
	)


func test_reduced_motion_stops_cashier_ambient_and_holds_its_exact_rest_sample() -> void:
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	var director := CASHIER_MOTION_DIRECTOR_SCRIPT.new()
	add_child_autofree(director)
	director.bind(floor)
	floor.avatar_position = FloorController.CASHIER_POSITION
	floor.refresh_proximity()
	assert_true(floor.interact())
	await wait_seconds(0.20)
	assert_true(director.has_active_ambient_motion())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(director.has_active_motion())
	assert_false(director.has_active_ambient_motion())
	var rest_sample: Variant = director.ambient_visual_sample()
	assert_eq(rest_sample, director.ambient_rest_sample())
	await wait_seconds(0.27)
	assert_eq(
		director.ambient_visual_sample(),
		rest_sample,
		"Reduced motion holds the cashier accent at a byte-stable visual state"
	)


func test_reduced_motion_settles_an_active_join_dialog_to_its_canonical_pose() -> void:
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	floor.avatar_position = floor.cabinet_positions[&"slot_classic"]
	floor.refresh_proximity()
	var expected_position := floor._join_dialog_position(&"slot_classic")
	assert_true(floor._prompt_tween.is_running())
	assert_ne(floor._prompt.position, expected_position)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_eq(floor._prompt.position, expected_position)
	assert_eq(floor._prompt.modulate, Color.WHITE)
	assert_true(floor._prompt.visible)
	assert_true(floor._prompt_tween == null or not floor._prompt_tween.is_running())


func test_reduced_motion_settles_active_hud_feedback_to_exact_rest_state() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main._show_floor_now()
	main._on_balance_changed(100, 90)
	assert_true(main._bank_feedback_tween.is_running())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_eq(main._bank_panel.scale, Vector2.ONE)
	assert_eq(main._hud.modulate, Color.WHITE)
	assert_true(main._bank_feedback_tween == null or not main._bank_feedback_tween.is_running())
