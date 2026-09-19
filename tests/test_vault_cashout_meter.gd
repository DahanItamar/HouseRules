extends GutTest

const METER_SCRIPT := preload("res://src/ui/vault_cashout_meter.gd")


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_meter_sets_exact_values_without_motion() -> void:
	var meter := METER_SCRIPT.new()
	meter.size = Vector2(420, 76)
	add_child_autofree(meter)
	meter.set_values(375, 3.75, 0.6, false)
	assert_eq(meter.target_amount, 375)
	assert_eq(meter.amount_text(), "375")
	assert_eq(meter.multiplier_text(), "3.75×")
	assert_eq(meter.displayed_progress, 0.6)
	assert_false(meter.has_active_motion())


func test_meter_interpolates_and_finishes_on_exact_targets() -> void:
	var meter := METER_SCRIPT.new()
	meter.size = Vector2(420, 76)
	add_child_autofree(meter)
	meter.set_values(20, 1.2, 0.1, false)
	watch_signals(meter)
	meter.set_values(420, 5.25, 0.9)
	assert_true(meter.has_active_motion())
	assert_between(
		meter.animation_duration,
		METER_SCRIPT.ANIMATION_MIN_SECONDS,
		METER_SCRIPT.ANIMATION_MAX_SECONDS
	)
	await wait_seconds(0.18)
	assert_gt(meter.displayed_amount, 20.0)
	assert_lt(meter.displayed_amount, 420.0)
	assert_gt(meter.displayed_progress, 0.1)
	assert_lt(meter.displayed_progress, 0.9)
	await wait_seconds(0.40)
	assert_false(meter.has_active_motion())
	assert_eq(meter.amount_text(), "420")
	assert_eq(meter.multiplier_text(), "5.25×")
	assert_almost_eq(meter.displayed_progress, 0.9, 0.0001)
	assert_signal_emitted(meter, "animation_finished")


func test_meter_clamps_invalid_presentation_inputs() -> void:
	var meter := METER_SCRIPT.new()
	add_child_autofree(meter)
	meter.set_values(-50, -2.0, 1.8, false)
	assert_eq(meter.target_amount, 0)
	assert_eq(meter.target_multiplier, 0.0)
	assert_eq(meter.target_progress, 1.0)
	meter.set_values(10, 1.25, -0.4, false)
	assert_eq(meter.target_progress, 0.0)


func test_meter_exposes_distinct_ready_and_disabled_states() -> void:
	var meter := METER_SCRIPT.new()
	add_child_autofree(meter)
	assert_false(meter.is_ready)
	meter.set_ready(true)
	assert_true(meter.is_ready)
	meter.set_ready(false)
	assert_false(meter.is_ready)
	assert_eq(meter.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_ne(METER_SCRIPT.READY_COLOR, METER_SCRIPT.DISABLED_COLOR)


func test_ready_meter_keeps_a_bounded_idle_pulse_and_respects_reduced_motion() -> void:
	var meter := VaultCashoutMeter.new()
	add_child_autofree(meter)
	meter.set_ready(true)
	meter._process(0.25)
	assert_gt(meter.idle_time, 0.0, "Ready cash-out state remains visibly alive")
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_eq(meter.idle_time, 0.0)
	assert_false(meter.is_processing(), "Reduced motion freezes the persistent meter pulse")


func test_enabling_reduced_motion_snaps_an_active_value_tween_to_its_target() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)
	var meter := VaultCashoutMeter.new()
	add_child_autofree(meter)
	meter.set_values(10, 1.1, 0.1, false)
	watch_signals(meter)
	meter.set_values(410, 4.25, 0.9)
	assert_true(meter.has_active_motion())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(meter.has_active_motion())
	assert_eq(meter.amount_text(), "410")
	assert_almost_eq(meter.displayed_multiplier, 4.25, 0.001)
	assert_almost_eq(meter.displayed_progress, 0.9, 0.001)
	assert_signal_emit_count(meter, "animation_finished", 1)
