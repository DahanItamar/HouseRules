extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
const VAULT_REVEAL_FX := preload("res://src/ui/vault_reveal_fx.gd")


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


func test_reduced_vault_effect_keeps_static_acknowledgement_without_smoke() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var host := Node2D.new()
	add_child_autofree(host)
	var safe_effect = VAULT_REVEAL_FX.spawn(host, Vector2.ZERO, VAULT_REVEAL_FX.Kind.SAFE)
	var mine_effect = VAULT_REVEAL_FX.spawn(host, Vector2.ZERO, VAULT_REVEAL_FX.Kind.MINE)
	assert_eq(safe_effect.shard_particles.amount, 1)
	assert_eq(safe_effect.shard_particles.initial_velocity_max, 0.0)
	assert_eq(mine_effect.debris_particles.amount, 1)
	assert_eq(mine_effect.debris_particles.initial_velocity_max, 0.0)
	assert_null(mine_effect.smoke_particles, "Reduced motion omits drifting smoke")


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
	for attract: MachineAttract in floor._machine_attracts.values():
		assert_true(attract.reduced_motion)
		assert_false(attract.is_processing(), "Machine attract loops hold a stable reduced frame")
		var stable_phase := attract.visual_phase()
		attract._process(0.4)
		assert_eq(attract.elapsed, 0.0)
		assert_eq(attract.visual_phase(), stable_phase)
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


func test_reduced_button_feedback_keeps_controls_still() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var button := Button.new()
	button.size = Vector2(180, 54)
	add_child_autofree(button)
	var feedback := ButtonFeedback.attach(button)
	feedback._hover_in()
	feedback._press()
	feedback._release()
	assert_eq(button.scale, Vector2.ONE, "Focus and press feedback never scale the control")
	assert_null(feedback._motion)


func test_reduced_ambient_and_lighting_are_static_but_keep_event_feedback() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var ambient := CasinoAmbient.new()
	ambient.size = Vector2(960, 110)
	add_child_autofree(ambient)
	var lighting := CasinoLighting.new()
	lighting.size = Vector2(960, 540)
	add_child_autofree(lighting)
	assert_false(ambient.is_processing())
	assert_false(lighting.is_processing())
	assert_eq(ambient.elapsed, 0.0)
	assert_eq(lighting.elapsed, 0.0)
	ambient.trigger_event(1.0)
	assert_eq(ambient.event_energy, 1.0, "Outcome feedback remains immediately perceivable")
	await wait_seconds(0.18)
	assert_almost_eq(ambient.event_energy, 0.0, 0.01, "Finite feedback settles")


func test_reduced_symbol_disables_idle_shader_motion_without_changing_spin_state() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var symbol := SlotSymbol.new()
	symbol.size = Vector2(120, 120)
	add_child_autofree(symbol)
	symbol.symbol_index = 4
	assert_false(symbol.is_processing())
	assert_eq(float(symbol._symbol_material.get_shader_parameter("continuous_motion")), 0.0)
	symbol.set_spin_strength(0.75)
	assert_eq(symbol.spin_strength, 0.75)
	assert_eq(symbol.symbol_index, 4, "Motion policy never changes the evaluated outcome")


func test_reduced_value_changes_reach_exact_final_state_without_ticking() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var ticker := AnimatedNumberLabel.new()
	add_child_autofree(ticker)
	ticker.set_number(10, "%d", false)
	ticker.set_number(910)
	assert_eq(ticker.text, "910")
	assert_eq(int(ticker.displayed_value), 910)
	assert_null(ticker._number_tween)
	var meter := VaultCashoutMeter.new()
	add_child_autofree(meter)
	meter.set_values(420, 2.5, 0.75, true)
	assert_eq(int(meter.displayed_amount), 420)
	assert_almost_eq(meter.displayed_multiplier, 2.5, 0.001)
	assert_almost_eq(meter.displayed_progress, 0.75, 0.001)
	assert_false(meter.has_active_motion())


func test_reduced_avatar_keeps_directional_walk_frames_without_body_bob() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var avatar := FloorAvatar.new()
	add_child_autofree(avatar)
	avatar.set_motion(Vector2(12, 0))
	avatar._process(0.01)
	assert_true(avatar.is_walking)
	assert_gt(avatar.walk_frame, -1, "Directional gait frames still communicate movement")
	assert_eq(avatar._sprite.rotation, 0.0)
	assert_eq(avatar._sprite.position, Vector2(0, -23))
	assert_eq(avatar._sprite.scale, Vector2.ONE * FloorAvatar.GUEST_SCALE)


func test_reduced_win_feedback_is_compact_and_self_clearing() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var celebration := WinCelebration.new()
	add_child_autofree(celebration)
	celebration.burst(Vector2(200, 160), 20)
	assert_eq(celebration.get_child_count(), 3, "Feedback is bounded to a compact acknowledgement")
	for child: Control in celebration.get_children():
		assert_lte(child.position.distance_to(Vector2(173, 133)), 44.0)
	await wait_seconds(0.20)
	assert_eq(celebration.get_child_count(), 0, "Finite feedback cannot become persistent motion")


func test_reduced_slot_keeps_bounded_reel_feedback_and_exact_outcome() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var state := {"completed": false}
	panel.begin_slot_spin([1, 2, 3], func() -> void: state.completed = true)
	assert_lte(panel._slot_stop_times.max(), 1.0, "Essential reel feedback is shortened")
	panel._process(0.2)
	assert_eq(panel._slot_offsets, [0.0, 0.0, 0.0], "Reduced reels avoid rapid strip travel")
	panel._process(0.9)
	assert_true(bool(state.completed))
	assert_false(panel._slot_spinning)
	assert_eq(panel._slot_spin_targets, [1, 2, 3])
	var burst_count := 0
	for child: Node in panel._art_root.get_children():
		if child is ImpactBurst:
			burst_count += 1
	assert_eq(burst_count, 0, "Reduced reels settle without stop-particle travel")
	panel.set_help_open(true)
	var modal := panel._help_overlay.get_child(1) as Control
	assert_eq(modal.scale, Vector2.ONE, "Help opens without a zoom effect")


func test_reduced_overlays_use_immediate_static_end_states() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var disconnect := DisconnectPauseOverlay.new()
	add_child_autofree(disconnect)
	disconnect.set_gamepad_connected(false)
	assert_true(disconnect.visible)
	assert_eq(disconnect._message.position.y, 245.0)
	assert_eq(disconnect._message.scale, Vector2.ONE)
	assert_false(disconnect.is_processing())
	disconnect.set_gamepad_connected(true)
	assert_false(disconnect.visible)

	var confirmation := CabinetExitConfirmation.new()
	add_child_autofree(confirmation)
	confirmation.present(25)
	assert_eq(confirmation._dialog.position, Vector2(250, 146))
	assert_eq(confirmation._dialog.scale, Vector2.ONE)
	confirmation.cancel()
	assert_false(confirmation.visible)
