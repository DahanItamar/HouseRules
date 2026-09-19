extends GutTest

var _original_platform: PlatformServices
var _original_test_mode: bool
var _floor: FloorController


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	SaveService.platform = LocalPlatform.new(
		"user://tests/cashier_modal_handoff_%s" % Time.get_ticks_usec()
	)
	SaveService.new_game(20260919)
	Wallet.set_test_mode(false)
	Wallet.reset(80)
	Economy.debt = 40
	MotionPolicy.set_reduced_motion_for_tests(false)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)
	_floor.avatar_position = FloorController.CASHIER_POSITION
	_floor.refresh_proximity()


func after_each() -> void:
	MotionPolicy.clear_test_override()
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	SaveService.new_game(20260919)


func test_reduced_motion_settles_active_cashier_open_to_exact_visible_rest() -> void:
	assert_true(_floor.open_marker_desk())
	assert_true(_floor._cashier_open)
	assert_true(_floor._cashier_panel.visible)
	assert_true(_floor._cashier_tween.is_running())
	assert_ne(_floor._cashier_panel.scale, Vector2.ONE)

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_true(_floor._cashier_open)
	assert_true(_floor._cashier_panel.visible)
	assert_true(_floor._cashier_scrim.visible)
	assert_eq(_floor._cashier_panel.modulate, Color.WHITE)
	assert_eq(_floor._cashier_panel.scale, Vector2.ONE)
	assert_eq(_floor._cashier_scrim.modulate, Color.WHITE)
	assert_false(_floor._cashier_is_closing)
	assert_true(
		_floor._cashier_tween == null or not _floor._cashier_tween.is_running(),
		"The outer modal cannot keep travelling after the accessibility handoff"
	)


func test_reduced_motion_finishes_active_cashier_close_at_exact_hidden_rest() -> void:
	assert_true(_floor.open_marker_desk())
	await get_tree().process_frame
	_floor._close_cashier()
	assert_true(_floor._cashier_is_closing)
	assert_true(_floor._cashier_panel.visible)
	assert_true(_floor._cashier_tween.is_running())

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_false(_floor._cashier_open)
	assert_false(_floor._cashier_panel.visible)
	assert_false(_floor._cashier_scrim.visible)
	assert_eq(_floor._cashier_panel.modulate, Color.WHITE)
	assert_eq(_floor._cashier_panel.scale, Vector2.ONE)
	assert_eq(_floor._cashier_scrim.modulate, Color.WHITE)
	assert_false(_floor._cashier_is_closing)
	assert_true(
		_floor._cashier_tween == null or not _floor._cashier_tween.is_running(),
		"The close tween is consumed instead of freezing a half-dismissed modal"
	)


func test_reduced_motion_clears_active_cashier_transfer_at_canonical_feedback_rest() -> void:
	assert_true(_floor.open_marker_desk())
	_floor._cashier_repay_amount = 10
	_floor._confirm_cashier_repayment()
	assert_true(_floor._cashier_transaction_tween.is_running())
	assert_gt(_floor._cashier_transfer_layer.get_child_count(), 0)
	assert_eq(_floor._cashier_summary_flash.color, Color("58d68d2e"))
	assert_eq(_floor._cashier_preview.get_theme_color("font_color"), Color("8ce9b2"))

	MotionPolicy.set_reduced_motion_for_tests(true)
	await get_tree().process_frame

	assert_true(
		_floor._cashier_transaction_tween == null
		or not _floor._cashier_transaction_tween.is_running(),
		"No chip-transfer or feedback tween survives the live preference change"
	)
	assert_eq(_floor._cashier_transfer_layer.get_child_count(), 0)
	assert_eq(_floor._cashier_summary_flash.color, Color("58d68d00"))
	assert_eq(_floor._cashier_preview.get_theme_color("font_color"), Color("b8ad9c"))
	assert_eq(_floor._cashier_balance.text, tr("CASHIER_CHIPS") % 70)
	assert_eq(_floor._cashier_debt.text, tr("CASHIER_DEBT") % 30)


func test_reduced_motion_settles_active_exit_confirmation_reveal() -> void:
	var confirmation := CabinetExitConfirmation.new()
	add_child_autofree(confirmation)
	confirmation.present(25)
	assert_true(confirmation.is_open)
	assert_true(confirmation.visible)
	assert_true(confirmation._transition.is_running())
	assert_ne(confirmation._dialog.position, Vector2(250, 146))

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_true(confirmation.is_open)
	assert_true(confirmation.visible)
	assert_eq(confirmation._blocker.modulate, Color.WHITE)
	assert_eq(confirmation._blocker.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(confirmation._dialog.modulate, Color.WHITE)
	assert_eq(confirmation._dialog.position, Vector2(250, 146))
	assert_eq(confirmation._dialog.scale, Vector2.ONE)
	assert_true(
		confirmation._transition == null or not confirmation._transition.is_running(),
		"The reveal tween cannot continue after reduced motion takes ownership"
	)


func test_reduced_motion_finishes_active_exit_confirmation_dismiss() -> void:
	var confirmation := CabinetExitConfirmation.new()
	add_child_autofree(confirmation)
	confirmation.present(25)
	await wait_seconds(0.20)
	confirmation.cancel()
	assert_false(confirmation.is_open)
	assert_true(confirmation.visible)
	assert_true(confirmation._transition.is_running())
	assert_eq(confirmation._blocker.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_false(confirmation.is_open)
	assert_false(confirmation.visible)
	assert_eq(confirmation._blocker.modulate, Color.WHITE)
	assert_eq(confirmation._blocker.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(confirmation._dialog.modulate, Color.WHITE)
	assert_eq(confirmation._dialog.position, Vector2(250, 146))
	assert_eq(confirmation._dialog.scale, Vector2.ONE)
	assert_true(
		confirmation._transition == null or not confirmation._transition.is_running(),
		"The dismiss tween cannot remain alive behind a hidden confirmation"
	)
