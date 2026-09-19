extends GutTest

var _original_platform: PlatformServices
var _original_test_mode: bool
var _floor: FloorController


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	SaveService.platform = LocalPlatform.new(
		"user://tests/cashier_presentation_%s" % Time.get_ticks_usec()
	)
	SaveService.new_game(20260919)
	Wallet.set_test_mode(false)
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


func test_cashier_financial_values_tick_and_repayment_launches_chips() -> void:
	Wallet.reset(80)
	Economy.debt = 40
	assert_true(_floor.open_marker_desk())
	assert_true(_floor._cashier_balance is AnimatedNumberLabel)
	assert_true(_floor._cashier_debt is AnimatedNumberLabel)
	assert_true(_floor._cashier_amount is AnimatedNumberLabel)
	assert_true(_floor._cashier_preview.has_method("set_numbers"))
	_floor._cashier_repay_amount = 10
	_floor._confirm_cashier_repayment()
	assert_eq(Wallet.balance, 70, "The ticker never owns wallet truth")
	assert_eq(Economy.debt, 30, "The ticker never owns debt truth")
	assert_eq(_floor._cashier_balance.target_value, 70)
	assert_eq(_floor._cashier_debt.target_value, 30)
	assert_eq(_floor._cashier_preview.get("target_first"), 60)
	assert_eq(_floor._cashier_preview.get("target_second"), 20)
	assert_gt(
		_floor._cashier_transfer_layer.get_child_count(),
		0,
		"Repayment launches a bounded chip-transfer acknowledgement"
	)
	await wait_seconds(0.65)
	assert_eq(_floor._cashier_balance.text, tr("CASHIER_CHIPS") % 70)
	assert_eq(_floor._cashier_debt.text, tr("CASHIER_DEBT") % 30)
	assert_eq(_floor._cashier_transfer_layer.get_child_count(), 0)


func test_cashier_close_animates_then_releases_focus_and_hides() -> void:
	Economy.debt = 25
	assert_true(_floor.open_marker_desk())
	await get_tree().process_frame
	assert_true(_floor._cashier_panel.visible)
	assert_true(_floor._cashier_panel.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	_floor._close_cashier()
	assert_false(_floor._cashier_open)
	assert_true(_floor._cashier_panel.visible, "Full-motion close retains the panel for its exit beat")
	assert_true(_floor._cashier_is_closing)
	assert_false(_floor._prompt_target_visible)
	assert_true(
		_floor._prompt.visible,
		"Cashier instructions fade with the modal before the next contextual prompt appears"
	)
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(focused == null or not _floor._cashier_panel.is_ancestor_of(focused))
	await wait_seconds(0.18)
	assert_false(_floor._cashier_panel.visible)
	assert_false(_floor._cashier_scrim.visible)
	assert_false(_floor._cashier_is_closing)
	assert_eq(_floor._cashier_panel.scale, Vector2.ONE)


func test_reduced_cashier_feedback_keeps_final_state_without_chip_travel() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	Wallet.reset(10)
	Economy.debt = 0
	assert_true(_floor.open_marker_desk())
	_floor._take_cashier_marker()
	assert_eq(Wallet.balance, 110)
	assert_eq(Economy.debt, Economy.MARKER_STIPEND)
	assert_eq(_floor._cashier_balance.text, tr("CASHIER_CHIPS") % 110)
	assert_eq(_floor._cashier_debt.text, tr("CASHIER_DEBT") % Economy.MARKER_STIPEND)
	assert_eq(
		_floor._cashier_transfer_layer.get_child_count(),
		0,
		"Reduced motion keeps the success flash but removes chip travel"
	)
	_floor._close_cashier()
	assert_false(_floor._cashier_panel.visible)
	assert_false(_floor._cashier_is_closing)


func test_pair_ticker_snaps_to_authoritative_values_when_reduced_mid_animation() -> void:
	var ticker := AnimatedPairLabel.new()
	add_child_autofree(ticker)
	ticker.set_numbers(10, 20, "%d / %d", false)
	watch_signals(ticker)
	ticker.set_numbers(210, 420, "%d / %d")
	assert_true(ticker.has_active_motion())
	await wait_seconds(0.04)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(ticker.has_active_motion())
	assert_eq(ticker.text, "210 / 420")
	assert_eq(int(ticker.displayed_first), 210)
	assert_eq(int(ticker.displayed_second), 420)
	assert_signal_emit_count(ticker, "animation_finished", 1)
