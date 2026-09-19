extends GutTest

var _original_platform: PlatformServices
var _original_test_mode: bool
var _floor: FloorController


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	SaveService.platform = LocalPlatform.new("user://tests/session_%s" % Time.get_ticks_usec())
	SaveService.new_game(1234)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)
	SceneRouter.register_floor(_floor)


func after_each() -> void:
	SceneRouter.return_to_floor()
	await get_tree().process_frame
	SceneRouter.floor = null
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	SaveService.new_game(1234)


func _approach_slot() -> CabinetDefinition:
	var definition: CabinetDefinition = load("res://data/cabinets/slot_classic.tres")
	_floor.avatar_position = _floor.cabinet_positions[definition.id]
	_floor.refresh_proximity()
	return definition


func test_ac001_constant_speed_in_eight_directions() -> void:
	var origin := Vector2(480, 300)
	var distance := -1.0
	for direction in [
		Vector2.UP,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1)
	]:
		_floor.avatar_position = origin
		_floor.move_avatar(direction, 0.1)
		var moved := _floor.avatar_position.distance_to(origin)
		assert_gt(moved, 0.0)
		if distance < 0:
			distance = moved
		assert_almost_eq(moved, distance, 0.001)


func test_floor_avatar_animates_from_real_movement_and_keeps_facing() -> void:
	var avatar: Node2D = _floor._avatar_visual
	var starting_phase: float = avatar.get("walk_phase")
	_floor.avatar_position = Vector2(480, 300)
	_floor.move_avatar(Vector2.RIGHT, 0.05)
	assert_gt(float(avatar.get("walk_phase")), starting_phase)
	assert_gt((avatar.get("facing") as Vector2).x, 0.9)
	_floor.move_avatar(Vector2.ZERO, 0.05)
	assert_gt((avatar.get("facing") as Vector2).x, 0.9)
	var eight_directions: Array[Vector2] = [
		Vector2.UP,
		Vector2(1, -1),
		Vector2.RIGHT,
		Vector2(1, 1),
		Vector2.DOWN,
		Vector2(-1, 1),
		Vector2.LEFT,
		Vector2(-1, -1),
	]
	for expected_index: int in range(eight_directions.size()):
		avatar.call("set_motion", eight_directions[expected_index] * 5.0)
		assert_eq(
			int(avatar.get("facing_index")),
			expected_index,
			"Every cardinal and diagonal movement has a dedicated facing"
		)


func test_floor_avatar_uses_four_real_leg_phases_at_a_walking_pace() -> void:
	var avatar: FloorAvatar = _floor._avatar_visual
	var regions: Dictionary = {}
	avatar.set_motion(Vector2.RIGHT * 4.0)
	for _phase: int in range(4):
		regions[avatar._atlas.region] = true
		avatar.set_motion(Vector2.RIGHT * 16.0)
	assert_eq(regions.size(), 4, "Walk cycle uses four distinct contact and passing poses")
	assert_false(avatar._sprite.flip_h, "Generated directional frames do not fake steps by mirroring")
	assert_eq(
		avatar._atlas.region.position.x,
		6 * FloorAvatar.GUEST_CELL_SIZE.x,
		"Right movement uses the east atlas column"
	)
	assert_lte(FloorController.SPEED, 120.0, "Floor traversal stays at a natural walking pace")


func test_floor_join_dialog_is_contextual_and_can_be_dismissed() -> void:
	var definition := _approach_slot()
	assert_string_contains(_floor._prompt.text, tr(definition.name_key))
	assert_string_contains(_floor._prompt.text, "JOIN")
	assert_string_contains(_floor._prompt.text, "CLOSE")
	await wait_seconds(0.18)
	assert_eq(_floor._prompt.position, _floor._join_dialog_position(definition.id))
	assert_eq(_floor._prompt.size, FloorController.JOIN_DIALOG_SIZE)
	assert_lt(
		_floor._prompt.position.y + _floor._prompt.size.y,
		FloorController.CASHIER_POSITION.y - 45.0,
		"The contextual join card does not cover the cashier identity"
	)
	var back := InputEventAction.new()
	back.action = "back"
	back.pressed = true
	_floor._unhandled_input(back)
	assert_eq(_floor._dismissed_game, definition.id)
	assert_false(_floor._prompt_target_visible, "Close removes all contextual dialog chrome")
	assert_false(_floor.interact(), "A dismissed dialog cannot trigger a hidden join action")
	assert_eq(_floor._dismissed_game, definition.id)
	assert_null(SceneRouter.session)
	await wait_seconds(0.14)
	assert_false(_floor._prompt.visible, "The dismissed join dialog finishes its exit fade")
	_floor.avatar_position += Vector2(0, FloorController.INTERACTION_RADIUS + 20.0)
	_floor.refresh_proximity()
	assert_eq(_floor._dismissed_game, &"", "Leaving the machine resets the dismissed card")
	_floor.avatar_position = _floor.cabinet_positions[definition.id]
	_floor.refresh_proximity()
	assert_true(_floor._prompt.visible, "Approaching again restores the contextual join dialog")
	assert_string_contains(_floor._prompt.text, "JOIN")
	assert_true(_floor.interact(), "Re-entering the ring restores the join action")


func test_floor_movement_help_yields_after_the_player_moves() -> void:
	_floor.avatar_position = Vector2(480, 360)
	_floor.refresh_proximity()
	assert_true(_floor._prompt.visible)
	assert_string_contains(_floor._prompt.text, InputRouter.glyph("move"))
	_floor.move_avatar(Vector2.RIGHT, 0.05)
	assert_true(_floor._has_moved)
	assert_false(_floor._prompt_target_visible)
	assert_true(_floor._prompt.visible, "Full-motion prompt keeps its pixels for the exit fade")
	assert_true(_floor._prompt_tween.is_running())
	await wait_seconds(0.14)
	assert_false(_floor._prompt.visible, "Persistent tutorial chrome clears after first movement")
	_floor.avatar_position = _floor.cabinet_positions[&"blackjack"]
	_floor.refresh_proximity()
	assert_true(_floor._prompt.visible, "Contextual machine join card still appears")
	assert_string_contains(_floor._prompt.text, "JOIN")


func test_floor_machine_rings_are_the_real_activation_zones() -> void:
	for id: StringName in _floor.cabinet_positions:
		var center: Vector2 = _floor.cabinet_positions[id]
		assert_lte(_floor._machine_proximity_score(center, center), 1.0)
		assert_gt(
			_floor._machine_proximity_score(
				center + Vector2(FloorController.MACHINE_ZONE_RADIUS * 1.6, 0), center
			),
			1.0,
			"The visible ring and the activation boundary share the same footprint"
		)


func test_floor_machines_have_distinct_staggered_attract_loops() -> void:
	assert_eq(_floor._machine_attracts.size(), _floor.cabinet_positions.size())
	var slot: MachineAttract = _floor._machine_attracts[&"slot_classic"]
	var blackjack: MachineAttract = _floor._machine_attracts[&"blackjack"]
	var vault: MachineAttract = _floor._machine_attracts[&"minefield_vault"]
	assert_eq(slot.kind, MachineAttract.Kind.SLOT)
	assert_eq(blackjack.kind, MachineAttract.Kind.BLACKJACK)
	assert_eq(vault.kind, MachineAttract.Kind.VAULT)
	assert_eq(slot.z_index, 0, "Cabinet attract art stays behind the player")
	assert_eq(blackjack.z_index, 0, "Table attract art stays behind the player")
	assert_eq(vault.z_index, 0, "Vault attract art stays behind the player")
	assert_ne(slot.phase_offset, blackjack.phase_offset)
	assert_ne(blackjack.phase_offset, vault.phase_offset)
	assert_ne(slot._period(), blackjack._period())
	assert_ne(blackjack._period(), vault._period())
	var phase_before := slot.visual_phase()
	slot._process(0.2)
	assert_ne(slot.visual_phase(), phase_before, "Full-motion machine faces stay visibly alive")


func test_nearby_machine_heightens_only_its_attract_loop() -> void:
	_floor.avatar_position = _floor.cabinet_positions[&"blackjack"]
	_floor.refresh_proximity()
	for id: StringName in _floor._machine_attracts:
		var attract: MachineAttract = _floor._machine_attracts[id]
		assert_eq(attract.is_near, id == &"blackjack")
		assert_eq(attract.emphasis(), 1.45 if id == &"blackjack" else 1.0)


func test_cashier_opens_a_real_focusable_menu() -> void:
	Economy.debt = 50
	_floor.avatar_position = _floor.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	assert_true(_floor._cashier_panel.visible)
	assert_true(_floor._cashier_scrim.visible)
	assert_not_null(_floor._cashier_panel.get_node("TakeMarker"))
	assert_not_null(_floor._cashier_panel.get_node("RepayDebt"))
	assert_not_null(_floor._cashier_panel.get_node("CloseCashier"))
	await get_tree().process_frame
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		_floor._cashier_repay,
		"The enabled repayment confirmation receives controller focus"
	)


func test_cashier_wasd_actions_move_focus_inside_modal() -> void:
	Economy.debt = 50
	_floor.avatar_position = _floor.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	await wait_process_frames(1)
	_floor._cashier_marker.grab_focus()
	var move_right := InputEventAction.new()
	move_right.action = &"move_right"
	move_right.pressed = true
	_floor._unhandled_input(move_right)
	assert_eq(get_viewport().gui_get_focus_owner(), _floor._cashier_repay)


func test_cashier_repayment_picker_clamps_previews_and_confirms_selected_amount() -> void:
	Wallet.set_test_mode(false)
	Wallet.reset(37)
	Economy.debt = 25
	_floor.avatar_position = _floor.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	assert_eq(_floor._cashier_repay_amount, 10)
	assert_string_contains(_floor._cashier_preview.text, "CHIPS 27")
	assert_string_contains(_floor._cashier_preview.text, "DEBT 15")
	_floor._adjust_cashier_repayment(-10)
	assert_eq(_floor._cashier_repay_amount, 1, "Repayment never falls below one chip")
	_floor._adjust_cashier_repayment(1)
	assert_eq(_floor._cashier_repay_amount, 2, "Every whole-chip amount is reachable")
	_floor._confirm_cashier_repayment()
	assert_eq(Wallet.balance, 35, "Confirm pays only the displayed amount")
	assert_eq(Economy.debt, 23)
	_floor._maximize_cashier_repayment()
	assert_eq(_floor._cashier_repay_amount, 23, "Pay all is bounded by debt and available chips")
	_floor._confirm_cashier_repayment()
	assert_eq(Wallet.balance, 12)
	assert_eq(Economy.debt, 0)
	assert_true(_floor._cashier_repay.disabled)
	await wait_seconds(0.65)
	assert_string_contains(_floor._cashier_preview.text, "DEBT 0")


func test_cashier_marker_behavior_and_safe_focus_are_preserved() -> void:
	Wallet.set_test_mode(false)
	Wallet.reset(10)
	Economy.debt = 0
	_floor.avatar_position = _floor.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), _floor._cashier_marker)
	_floor._cashier_marker.pressed.emit()
	assert_eq(Wallet.balance, 110)
	assert_eq(Economy.debt, Economy.MARKER_STIPEND)


func test_insolvent_player_gets_a_safe_area_cashier_route_until_arrival() -> void:
	Wallet.reset(Economy.SOLVENCY_FLOOR - 1)
	_floor.avatar_position = Vector2(300, 300)
	_floor.refresh_proximity()
	var waypoint: CashierWaypoint = _floor._cashier_waypoint
	assert_true(waypoint.visible)
	assert_eq((waypoint.get_node("Caption") as Label).text, tr("CASHIER_WAYPOINT"))
	assert_gte(waypoint.position.x, CashierWaypoint.SAFE_MARGIN)
	assert_gte(waypoint.position.y, CashierWaypoint.SAFE_MARGIN)
	assert_lte(
		waypoint.position.x + waypoint.size.x,
		960.0 - CashierWaypoint.SAFE_MARGIN,
		"Cashier route remains inside the 960-wide controller-safe viewport"
	)
	assert_lte(
		waypoint.position.y + waypoint.size.y,
		540.0 - CashierWaypoint.SAFE_MARGIN,
		"Cashier route remains inside the 540-high controller-safe viewport"
	)
	assert_lt(absf(waypoint.route_angle()), 0.8, "Arrow points right toward the cashier")
	waypoint.update_route(Vector2(300, 300), Vector2(4000, -500), true)
	assert_true(waypoint.visible, "An offscreen cashier target keeps its edge route visible")
	assert_lte(waypoint.position.x + waypoint.size.x, 960.0 - CashierWaypoint.SAFE_MARGIN)
	assert_gte(waypoint.position.y, CashierWaypoint.SAFE_MARGIN)

	_floor.avatar_position = FloorController.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_false(waypoint._active)
	assert_true(waypoint.visible, "Waypoint keeps its plaque for the bounded exit fade")
	await wait_seconds(0.14)
	assert_false(waypoint.visible, "The route yields to the nearby cashier interaction prompt")
	assert_string_contains(_floor._prompt.text, InputRouter.glyph("interact"))


func test_cashier_route_clears_as_soon_as_the_bankroll_recovers() -> void:
	Wallet.reset(Economy.SOLVENCY_FLOOR - 1)
	_floor.refresh_proximity()
	assert_true(_floor._cashier_waypoint.visible)
	Wallet.reset(Economy.SOLVENCY_FLOOR)
	await wait_seconds(0.14)
	assert_false(_floor._cashier_waypoint.visible)


func test_cashier_route_never_leaks_over_a_cabinet_or_main_menu() -> void:
	Wallet.reset(Economy.SOLVENCY_FLOOR - 1)
	_floor.refresh_proximity()
	assert_true(_floor._cashier_waypoint.visible)
	_floor.set_prompt_visible(false)
	await wait_seconds(0.14)
	assert_false(_floor._cashier_waypoint.visible)
	_floor.set_prompt_visible(true)
	assert_true(_floor._cashier_waypoint.visible)
	_floor.hide()
	assert_false(_floor._directions_layer.visible)


func test_floor_collision_blocks_furniture_and_prevents_tunneling() -> void:
	for blocked_point: Vector2 in [
		Vector2(100, 170),
		Vector2(330, 140),
		Vector2(500, 140),
		Vector2(680, 140),
		Vector2(860, 170),
		Vector2(120, 400),
		Vector2(820, 400),
		Vector2(480, 490),
	]:
		assert_false(_floor._is_walkable(blocked_point), "%s is solid furniture" % blocked_point)
	for approach: Vector2 in _floor.cabinet_positions.values():
		assert_true(_floor._is_walkable(approach), "%s cabinet approach is reachable" % approach)
	assert_true(_floor._is_walkable(FloorController.CASHIER_POSITION))
	for approach: Vector2 in FloorController.WING_POSITIONS.values():
		assert_true(_floor._is_walkable(approach), "%s wing approach is reachable" % approach)

	_floor.avatar_position = Vector2(504, 280)
	_floor.move_avatar(Vector2.UP, 0.5)
	assert_true(_floor._is_walkable(_floor.avatar_position))
	assert_gte(_floor.avatar_position.y, 230.0, "A large frame cannot tunnel through machines")


func test_floor_collision_slides_along_furniture_edges() -> void:
	_floor.avatar_position = Vector2(504, 236)
	var origin := _floor.avatar_position
	for _step: int in range(10):
		_floor.move_avatar(Vector2(1, -1), 0.016)
	assert_true(_floor._is_walkable(_floor.avatar_position))
	assert_gt(_floor.avatar_position.x, origin.x, "Diagonal input keeps its tangential motion")


func test_ac002_through_ac008_floor_context_result_transaction_and_return() -> void:
	var definition := _approach_slot()
	assert_same(_floor.nearby_definition, definition)
	assert_true(_floor._prompt.visible)
	assert_string_contains(_floor._prompt.text, tr(definition.name_key))
	var return_position := _floor.avatar_position
	assert_true(_floor.interact())
	assert_not_null(SceneRouter.session)
	var session := SceneRouter.session
	assert_eq(session.context.balance, Wallet.balance)
	assert_same(session.context.definition, definition)
	assert_same(session.context.rng, RNGService.stream(definition.id))
	watch_signals(session.cabinet)
	watch_signals(Wallet)
	assert_true(session.cabinet.start_round(10))
	assert_false(session.cabinet.start_round(10), "Repeated input cannot double-stake")
	assert_eq(Wallet.balance, 200, "Cabinet does not directly modify wallet")
	session.cabinet.resolve_pending()
	assert_signal_emit_count(session.cabinet, "round_resolved", 1)
	var result: RoundResult = get_signal_parameters(session.cabinet, "round_resolved")[0]
	assert_eq(Wallet.balance, 200 - result.stake + result.payout)
	assert_false(session.apply_result(result), "Same round cannot settle twice")
	assert_signal_emit_count(Wallet, "balance_changed", 1)
	var settled_balance := Wallet.balance
	SceneRouter.return_to_floor()
	assert_null(SceneRouter.session)
	assert_eq(_floor.avatar_position, return_position)
	Wallet.reset(0)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, settled_balance, "AC-015 leaving persists state")


func test_ac004_unaffordable_cabinet_refuses_entry() -> void:
	var definition := _approach_slot()
	Wallet.reset(definition.min_bet - 1)
	_floor.refresh_proximity()
	assert_eq(
		_floor._prompt.text, tr("FLOOR_UNAVAILABLE") % [tr(definition.name_key), definition.min_bet]
	)
	assert_false(_floor.interact())
	assert_null(SceneRouter.session)


func test_ac009_abandon_forfeits_once_and_saves() -> void:
	_approach_slot()
	assert_true(_floor.interact())
	var cabinet := SceneRouter.session.cabinet
	watch_signals(cabinet)
	assert_true(cabinet.start_round(10))
	SceneRouter.return_to_floor()
	assert_eq(Wallet.balance, 190)
	assert_signal_emit_count(cabinet, "round_resolved", 1)
	var result: RoundResult = get_signal_parameters(cabinet, "round_resolved")[0]
	assert_eq(result.outcome, RoundResult.Outcome.ABANDONED)
	assert_eq(result.payout, 0)
	cabinet.resolve_pending()
	assert_eq(Wallet.balance, 190)
	Wallet.reset(0)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, 190)


func test_back_during_live_round_requires_confirmation_and_cancel_preserves_round() -> void:
	_approach_slot()
	assert_true(_floor.interact())
	var cabinet := SceneRouter.session.cabinet
	watch_signals(cabinet)
	assert_true(cabinet.start_round(10))
	var back := InputEventAction.new()
	back.action = &"back"
	back.pressed = true
	cabinet._unhandled_input(back)
	assert_true(cabinet.exit_confirmation.is_open)
	assert_string_contains(cabinet.exit_confirmation._message.text, "10")
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		cabinet.exit_confirmation._cancel_button,
		"The safe keep-playing action receives controller focus"
	)
	assert_signal_not_emitted(cabinet, "exit_requested")
	cabinet.exit_confirmation.cancel()
	assert_false(cabinet.exit_confirmation.is_open)
	assert_true(cabinet.is_round_active)
	assert_eq(Wallet.balance, 200)
	assert_signal_not_emitted(cabinet, "round_resolved")


func test_confirming_live_round_exit_forfeits_once_and_returns_to_floor() -> void:
	_approach_slot()
	assert_true(_floor.interact())
	var cabinet := SceneRouter.session.cabinet
	watch_signals(cabinet)
	assert_true(cabinet.start_round(10))
	var back := InputEventAction.new()
	back.action = &"back"
	back.pressed = true
	cabinet._unhandled_input(back)
	cabinet.exit_confirmation._leave_button.grab_focus()
	var accept := InputEventAction.new()
	accept.action = &"interact"
	accept.pressed = true
	assert_true(cabinet.exit_confirmation.handle_input(accept))
	assert_null(SceneRouter.session)
	assert_eq(Wallet.balance, 190)
	assert_signal_emit_count(cabinet, "round_resolved", 1)
	var result: RoundResult = get_signal_parameters(cabinet, "round_resolved")[0]
	assert_eq(result.outcome, RoundResult.Outcome.ABANDONED)
	assert_eq(result.payout, 0)
	cabinet.resolve_pending()
	assert_eq(Wallet.balance, 190)


func test_ac015_return_to_menu_saves() -> void:
	Wallet.reset(433)
	SceneRouter.return_to_menu()
	Wallet.reset(0)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, 433)


func test_ac024_contract_reward_is_independent_of_round_outcome() -> void:
	_approach_slot()
	assert_true(_floor.interact())
	Economy.active_contracts.assign([{"id": &"slot_rounds", "progress": 24}])
	watch_signals(Economy)
	var loss := RoundResult.create(
		10,
		0,
		RoundResult.Outcome.LOSS,
		{
			"symbols":
			[
				SlotMachineMath.Symbol.CHERRY,
				SlotMachineMath.Symbol.LEMON,
				SlotMachineMath.Symbol.BELL
			]
		}
	)
	assert_true(SceneRouter.session.apply_result(loss))
	assert_eq(Wallet.balance, 490, "Loss settles before the flat 300-chip contract reward")
	assert_eq(SceneRouter.session.context.balance, 490)
	assert_eq(Economy.contract_completions, 1)
	assert_eq(Economy.active_contracts.size(), Economy.CONTRACT_SLOTS)
	assert_signal_emitted_with_parameters(
		Economy, "contract_completed", ["CONTRACT_SLOT_ROUNDS", 300]
	)


func test_ac051_locked_wings_show_lifetime_wagered_thresholds() -> void:
	for id: StringName in FloorController.WING_POSITIONS:
		_floor.avatar_position = FloorController.WING_POSITIONS[id]
		_floor.refresh_proximity()
		assert_eq(_floor.nearby_wing, id)
		assert_string_contains(_floor._prompt.text, tr("WING_" + String(id).to_upper()))
		assert_string_contains(_floor._prompt.text, str(FloorController.WING_THRESHOLDS[id]))
		assert_false(_floor.interact(), "v1 transition points remain locked")
		assert_null(SceneRouter.session)


func test_back_input_exits_cabinet_without_also_leaving_floor() -> void:
	_approach_slot()
	assert_true(_floor.interact())
	watch_signals(SceneRouter)
	var event := InputEventAction.new()
	event.action = &"back"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	assert_null(SceneRouter.session)
	assert_signal_not_emitted(SceneRouter, "menu_requested")
