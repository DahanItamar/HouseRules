extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_help_reveal_stages_bounded_content_then_restores_exact_final_state() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	panel.set_help_open(true)
	assert_eq(panel._help_modal.position, Vector2(170, 70))
	assert_eq(panel._help_modal.scale, Vector2(0.98, 0.98))
	assert_eq(panel._help_shade.modulate.a, 0.0)
	for item: Control in panel._help_reveal_items:
		assert_eq(item.modulate.a, 0.0, "%s begins staged and transparent" % item.name)
		assert_eq(
			item.position,
			(panel._help_rest_positions[item] as Vector2) + Vector2(0, 6),
			"%s uses only bounded vertical displacement" % item.name
		)
	await wait_seconds(0.25)
	assert_eq(panel._help_modal.position, Vector2(170, 64))
	assert_eq(panel._help_modal.scale, Vector2.ONE)
	assert_eq(panel._help_modal.modulate, Color.WHITE)
	assert_eq(panel._help_shade.modulate, Color.WHITE)
	for item: Control in panel._help_reveal_items:
		assert_eq(item.position, panel._help_rest_positions[item])
		assert_eq(item.modulate, Color.WHITE)


func test_help_dismiss_uses_inverse_transform_and_cleans_up_visual_state() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	panel.set_help_open(true)
	await wait_seconds(0.25)
	panel.set_help_open(false)
	assert_true(panel._help_overlay.visible, "Dismiss remains visible for its short exit beat")
	assert_eq(panel._help_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await wait_seconds(0.16)
	assert_false(panel._help_overlay.visible)
	assert_eq(panel._help_modal.position, Vector2(170, 64))
	assert_eq(panel._help_modal.scale, Vector2.ONE)
	assert_eq(panel._help_modal.modulate, Color.WHITE)


func test_exit_confirmation_cancel_and_confirm_share_the_same_exit_motion() -> void:
	var cancel_confirmation := CabinetExitConfirmation.new()
	add_child_autofree(cancel_confirmation)
	cancel_confirmation.present(25)
	await wait_seconds(0.20)
	cancel_confirmation.cancel()
	assert_true(cancel_confirmation.visible)
	assert_eq(cancel_confirmation._blocker.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await wait_seconds(0.06)
	var cancel_position := cancel_confirmation._dialog.position.y
	var cancel_scale := cancel_confirmation._dialog.scale.x

	var confirm_confirmation := CabinetExitConfirmation.new()
	add_child_autofree(confirm_confirmation)
	confirm_confirmation.present(25)
	await wait_seconds(0.20)
	watch_signals(confirm_confirmation)
	confirm_confirmation.confirm_leave()
	assert_signal_emitted(confirm_confirmation, "leave_confirmed")
	assert_true(confirm_confirmation.visible)
	assert_eq(confirm_confirmation._blocker.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await wait_seconds(0.06)
	assert_almost_eq(confirm_confirmation._dialog.position.y, cancel_position, 0.5)
	assert_almost_eq(confirm_confirmation._dialog.scale.x, cancel_scale, 0.01)
	await wait_seconds(0.08)
	assert_false(cancel_confirmation.visible)
	assert_false(confirm_confirmation.visible)
	assert_eq(confirm_confirmation._dialog.position, Vector2(250, 146))
	assert_eq(confirm_confirmation._dialog.scale, Vector2.ONE)


func test_reduced_overlays_snap_to_exact_open_and_closed_states_without_tweens() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	panel.set_help_open(true)
	assert_null(panel._help_tween)
	assert_eq(panel._help_modal.position, Vector2(170, 64))
	assert_eq(panel._help_modal.scale, Vector2.ONE)
	for item: Control in panel._help_reveal_items:
		assert_eq(item.position, panel._help_rest_positions[item])
		assert_eq(item.modulate, Color.WHITE)
	panel.set_help_open(false)
	assert_false(panel._help_overlay.visible)

	var confirmation := CabinetExitConfirmation.new()
	add_child_autofree(confirmation)
	confirmation.present(25)
	assert_null(confirmation._transition)
	assert_eq(confirmation._dialog.position, Vector2(250, 146))
	assert_eq(confirmation._dialog.scale, Vector2.ONE)
	confirmation.confirm_leave()
	assert_false(confirmation.visible)
	assert_null(confirmation._transition)
	assert_eq(confirmation._dialog.modulate, Color.WHITE)
