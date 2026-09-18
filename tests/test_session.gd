extends GutTest

var _original_platform: PlatformServices
var _floor: FloorController


func before_each() -> void:
	_original_platform = SaveService.platform
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


func test_floor_avatar_uses_alternating_leg_poses_at_a_walking_pace() -> void:
	var avatar: FloorAvatar = _floor._avatar_visual
	avatar.set_motion(Vector2.RIGHT * 5.0)
	var first_region: Rect2 = avatar._atlas.region
	assert_false(avatar._sprite.flip_h)
	avatar.set_motion(Vector2.RIGHT * 25.0)
	assert_true(avatar._sprite.flip_h, "Second step mirrors the opposite leg pose")
	assert_ne(avatar._atlas.region, first_region, "Side walk alternates two actual leg silhouettes")
	assert_lte(FloorController.SPEED, 120.0, "Floor traversal stays at a natural walking pace")


func test_floor_machine_pads_have_explicit_unique_labels() -> void:
	assert_eq(_floor._machine_pad_title(&"slot_classic"), "FLOOR_PAD_SLOT")
	assert_eq(_floor._machine_pad_title(&"blackjack"), "FLOOR_PAD_BLACKJACK")
	assert_eq(_floor._machine_pad_title(&"minefield_vault"), "FLOOR_PAD_VAULT")
	assert_eq(_floor._machine_icon(&"slot_classic"), "777")
	assert_eq(_floor._machine_icon(&"blackjack"), "21")
	assert_eq(_floor._machine_icon(&"minefield_vault"), "V")


func test_cashier_opens_a_real_focusable_menu() -> void:
	_floor.avatar_position = _floor.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	assert_true(_floor._cashier_panel.visible)
	assert_not_null(_floor._cashier_panel.get_node("TakeMarker"))
	assert_not_null(_floor._cashier_panel.get_node("RepayDebt"))
	assert_not_null(_floor._cashier_panel.get_node("CloseCashier"))


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
