extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")

const LEVER_REST_ROTATION: float = 0.0

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_balance = Wallet.balance
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.test_mode_enabled = false
	Wallet.reset(500)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func _begin(definition: CabinetDefinition) -> CabinetSession:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(definition)
	return session


func test_mechanical_lever_is_visible_on_slot_only() -> void:
	var slot := _begin(SLOT_DEFINITION)
	var lever: Node2D = slot.cabinet.panel._slot_lever
	assert_not_null(lever, "The classic slot exposes its physical pull lever")
	if lever == null:
		return
	assert_eq(lever.name, "SlotLever")
	assert_true(lever.is_visible_in_tree())
	assert_gt(lever.get_child_count(), 0, "The lever owns visible presentation geometry")
	assert_between(lever.position.x, 0.0, 960.0)
	assert_between(lever.position.y, 0.0, 540.0)
	assert_almost_eq(lever.rotation, LEVER_REST_ROTATION, 0.0001)

	for definition: CabinetDefinition in [BLACKJACK_DEFINITION, VAULT_DEFINITION]:
		var other := _begin(definition)
		assert_null(
			other.cabinet.panel._slot_lever,
			"%s does not inherit slot-only mechanical furniture" % definition.id
		)


func test_spin_pulls_lever_and_keeps_all_wager_input_gated() -> void:
	var session := _begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var lever: Node2D = panel._slot_lever
	assert_not_null(lever)
	if lever == null:
		return

	assert_true(game.request_spin())
	var pending_before: RoundResult = game.get("_pending")
	var symbols_before: Array = pending_before.detail.get("symbols", []).duplicate()
	assert_true(game.is_round_active)
	assert_true(panel._slot_spin_label.disabled, "Spin is gated for the entire active round")
	for button: Button in panel._stake_selector._buttons:
		assert_true(button.disabled, "Wager controls stay gated while the reels are active")
	assert_false(game.request_spin(), "The lever cannot start a second overlapping spin")
	assert_same(game.get("_pending"), pending_before)
	assert_eq(pending_before.detail.get("symbols", []), symbols_before)

	await wait_seconds(0.10)
	assert_gt(absf(lever.rotation), 0.05, "The mechanical lever visibly leaves its rest pose")
	assert_true(panel.has_active_motion())
	await wait_seconds(0.34)
	assert_almost_eq(
		lever.rotation,
		LEVER_REST_ROTATION,
		0.0001,
		"The lever returns exactly to rest while the longer reel motion continues"
	)
	assert_true(game.is_round_active)
	assert_true(panel._slot_spin_label.disabled)


func test_reduced_motion_snaps_lever_to_exact_rest_pose() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := _begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var lever: Node2D = panel._slot_lever
	assert_not_null(lever)
	if lever == null:
		return

	assert_true(game.request_spin())
	assert_eq(lever.rotation, LEVER_REST_ROTATION)
	assert_true(panel._motion_tween == null or not panel._motion_tween.is_running())
	assert_true(panel._slot_spin_label.disabled)
	assert_true(panel._slot_spinning, "Reduced motion preserves the semantic active-spin state")


func test_enabling_reduced_motion_settles_an_active_lever_pull() -> void:
	var session := _begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var lever: Node2D = panel._slot_lever
	assert_not_null(lever)
	if lever == null:
		return

	assert_true(game.request_spin())
	await wait_seconds(0.10)
	assert_gt(absf(lever.rotation), 0.05)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_eq(lever.rotation, LEVER_REST_ROTATION)
	assert_true(panel._motion_tween == null or not panel._motion_tween.is_running())
	assert_true(game.is_round_active, "Accessibility settlement never resolves domain play early")
	assert_true(panel._slot_spin_label.disabled)


func test_lever_motion_never_mutates_evaluated_domain_symbols() -> void:
	var session := _begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var symbols: Array[int] = [
		SlotMachineMath.Symbol.SEVEN,
		SlotMachineMath.Symbol.SEVEN,
		SlotMachineMath.Symbol.SEVEN,
	]
	var result := SlotMachineMath.new().evaluate(symbols, 10)
	var authoritative_symbols: Array = result.detail.get("symbols", []).duplicate()

	panel.begin_slot_spin(authoritative_symbols, func() -> void: pass)
	await wait_seconds(0.20)
	assert_eq(result.detail.get("symbols", []), authoritative_symbols)
	assert_eq(panel._slot_spin_targets, authoritative_symbols)
	assert_eq(
		result.payout,
		10 * SlotMachineMath.new().paytable.multipliers[SlotMachineMath.Symbol.SEVEN],
		"Presentation motion cannot change the evaluated payout"
	)


func test_reel_motion_accelerates_cruises_brakes_and_still_ends_exactly() -> void:
	var session := _begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var samples: Array[float] = []
	for progress: float in [0.0, 0.05, 0.10, 0.18, 0.45, 0.72, 0.90, 0.95, 1.0]:
		samples.append(panel._slot_motion_progress(progress))
	assert_eq(samples[0], 0.0)
	assert_eq(samples[samples.size() - 1], 1.0)
	for index: int in range(1, samples.size()):
		assert_gt(samples[index], samples[index - 1], "Reel travel stays monotonic")
	assert_lt(samples[1] - samples[0], samples[2] - samples[1], "The reel accelerates")
	assert_gt(samples[7] - samples[6], samples[8] - samples[7], "The reel brakes")
