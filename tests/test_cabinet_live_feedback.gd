extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(500)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)


func test_slot_formula_change_uses_a_bounded_semantic_handoff() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var rest_position := panel._slot_result_formula.position
	game.selected_stake = 25
	panel.refresh()

	assert_eq(panel._slot_result_formula.text, tr("SLOT_IDLE_FORMULA") % 25)
	assert_eq(panel._slot_result_formula.position, rest_position + Vector2(0, 4))
	assert_almost_eq(panel._slot_result_formula.modulate.a, 0.56, 0.01)
	game.current_stake = 25
	game.is_round_active = true
	panel.refresh()
	assert_true(panel._slot_spin_label.disabled)
	game.is_round_active = false
	panel.refresh()
	assert_false(panel._slot_spin_label.disabled)
	assert_eq(panel._slot_spin_label.scale, Vector2(0.955, 0.955))
	assert_true(panel.has_live_state_feedback())
	await wait_seconds(0.24)
	assert_eq(panel._slot_result_formula.position, rest_position)
	assert_almost_eq(panel._slot_result_formula.modulate.a, 1.0, 0.01)
	assert_eq(panel._slot_spin_label.scale, Vector2.ONE)


func test_blackjack_action_copy_and_newly_enabled_action_animate_together() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var math: BlackjackMath = game.get("math")
	math.player.assign([10, 7])
	math.dealer.assign([9, 8])
	math.stake = 10
	math.active = true
	game.current_stake = 10
	game.is_round_active = true
	panel.refresh()

	assert_eq(panel._blackjack_primary.text, tr("ACTION_HIT"))
	assert_false(panel._blackjack_stand.disabled)
	assert_eq(panel._blackjack_stand.scale, Vector2(0.955, 0.955))
	assert_true(panel.has_live_state_feedback())
	await wait_seconds(0.27)
	assert_eq(panel._blackjack_stand.scale, Vector2.ONE)
	assert_eq(panel._blackjack_stand.modulate, Color.WHITE)


func test_vault_open_and_cashout_actions_acknowledge_live_round_state() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(VAULT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var math: MinefieldMath = game.get("math")
	math.stake = 10
	math.mines.assign([20, 21, 22])
	math.revealed.assign([0])
	math.safe_reveals = 1
	math.active = true
	game.current_stake = 10
	game.is_round_active = true
	panel.refresh()

	assert_eq(panel._vault_open.text, tr("ACTION_OPEN"))
	assert_false(panel._vault_cash_out.disabled)
	assert_eq(panel._vault_cash_out.scale, Vector2(0.955, 0.955))
	assert_eq(panel._status.text, panel._detail.text)
	assert_true(panel.has_live_state_feedback())


func test_reduced_motion_switch_snaps_all_feedback_to_exact_final_state() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = game.panel
	var rest_position := panel._slot_result_formula.position
	game.selected_stake = 25
	panel.refresh()
	assert_true(panel.has_live_state_feedback())

	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(panel.has_live_state_feedback())
	assert_eq(panel._slot_result_formula.position, rest_position)
	assert_almost_eq(panel._slot_result_formula.modulate.a, 1.0, 0.001)
	assert_eq(panel._slot_spin_label.scale, Vector2.ONE)
	assert_eq(panel._slot_spin_label.modulate, Color.WHITE)
