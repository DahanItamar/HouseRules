extends GutTest


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_project_defaults_to_full_motion() -> void:
	MotionPolicy.clear_test_override()
	assert_false(bool(ProjectSettings.get_setting(MotionPolicy.SETTING_PATH)))
	assert_false(MotionPolicy.is_reduced())
	assert_true(MotionPolicy.allows_continuous_motion())
	assert_true(MotionPolicy.allows_camera_emphasis())


func test_reduced_override_disables_persistent_and_camera_motion() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_true(MotionPolicy.is_reduced())
	assert_false(MotionPolicy.allows_continuous_motion())
	assert_false(MotionPolicy.allows_camera_emphasis())
	assert_almost_eq(MotionPolicy.finite_duration(1.0), 0.6, 0.001)


func test_reduced_card_reveal_reaches_final_state_and_keeps_finite_feedback() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var card := PlayingCard.new()
	card.size = Vector2(88, 124)
	add_child_autofree(card)
	card.configure(10, 1, true)
	card.reveal()
	assert_false(card.face_down, "Logical state updates immediately")
	assert_gt(card._sheen_remaining, 0.0, "Finite state feedback remains visible")
	await wait_seconds(0.22)
	assert_false(card._visual_face_down)
	assert_almost_eq(card.scale.x, 1.0, 0.01)


func test_reduced_vault_reveal_completes_callbacks_in_headless() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var tile := VaultTile.new()
	tile.size = Vector2(48, 48)
	add_child_autofree(tile)
	watch_signals(tile)
	tile.reveal(VaultTile.Face.SAFE)
	await wait_seconds(0.28)
	assert_eq(tile.face, VaultTile.Face.SAFE)
	assert_false(tile.is_flipping)
	assert_eq(tile.scale, Vector2.ONE)
	assert_signal_emitted(tile, "reveal_effect_requested")
	assert_signal_emitted(tile, "reveal_completed")


func test_reduced_floor_stops_dust_patrons_and_camera_emphasis() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	assert_false(floor._dust.emitting)
	var patron: Node2D = floor._patrons[0]
	patron.call("_process", 0.4)
	assert_eq(float(patron.get("elapsed")), 0.0)
	assert_eq(float(patron.get("gesture_strength")), 0.0)
	floor.avatar_position = floor.cabinet_positions[&"slot_classic"]
	floor.refresh_proximity()
	assert_eq(floor._floor_camera.position, FloorController.CAMERA_CENTER)
	assert_eq(floor._floor_camera.zoom, Vector2.ONE)


func test_reduced_spin_button_has_static_but_responsive_visual_state() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var spin := SlotSpinButton.new()
	spin.size = Vector2(140, 110)
	add_child_autofree(spin)
	spin._process(0.5)
	assert_eq(spin.idle_time, 0.0, "Ambient breathing is disabled")
	assert_eq(spin.focus_mode, Control.FOCUS_ALL, "Immediate focus feedback remains available")
