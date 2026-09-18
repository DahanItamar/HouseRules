extends GutTest

const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_balance = Wallet.balance
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.test_mode_enabled = false
	Wallet.reset(200)
	MotionPolicy.clear_test_override()


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func test_blackjack_reveal_and_readable_beat_precede_single_settlement() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var game: MiniGame = session.cabinet
	var math: BlackjackMath = game.get("math")
	math.player.assign([10, 7])
	math.dealer.assign([9, 8])
	math.stake = 10
	math.active = true
	game.current_stake = 10
	game.is_round_active = true
	game.panel.refresh()
	await wait_seconds(0.62)
	assert_true(game.panel._blackjack_cards[1].face_down)
	watch_signals(game)
	watch_signals(session)

	var result := math._resolve(20, RoundResult.Outcome.WIN)
	game.call("_resolve", result)
	assert_true(game.is_result_pending)
	assert_false(game.panel._blackjack_cards[1].face_down, "Hole-card state flips before settlement")
	assert_false(game.request_stand(), "Gameplay input stays locked through the reveal timeline")
	assert_true(game.panel._blackjack_primary.disabled)
	assert_eq(game.panel._blackjack_dealer_total.target_value, 9, "Tally waits for the reveal beat")
	assert_null(game.panel._result, "Result UI stays hidden during the reveal timeline")
	assert_eq(Wallet.balance, 200, "Wallet remains untouched during presentation")
	assert_signal_not_emitted(game, "round_resolved")

	await wait_seconds(0.30)
	assert_eq(Wallet.balance, 200, "The readable beat follows the completed card flip")
	assert_signal_not_emitted(game, "round_resolved")
	await wait_seconds(0.28)
	assert_signal_emit_count(game, "round_resolved", 1)
	assert_signal_emit_count(session, "round_applied", 1)
	assert_eq(Wallet.balance, 210)
	assert_false(game.is_result_pending)
	assert_eq(game.panel._blackjack_dealer_total.target_value, 17)
	assert_same(game.panel._result, result)


func test_reduced_motion_vault_flip_still_finishes_before_single_settlement() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(VAULT_DEFINITION)
	var game: MiniGame = session.cabinet
	var math: MinefieldMath = game.get("math")
	math.stake = 10
	math.mines.assign([0, 4, 8])
	math.revealed.assign([0])
	math.active = false
	game.current_stake = 10
	game.is_round_active = true
	watch_signals(game)
	watch_signals(session)

	var result := RoundResult.create(
		10,
		0,
		RoundResult.Outcome.LOSS,
		{"safe_reveals": 0, "mines": math.mines.duplicate(), "revealed": [0]}
	)
	game.call("_finish", result)
	assert_true(game.is_result_pending)
	assert_true(game.panel._vault_tiles[0].is_flipping)
	assert_false(game.request_open())
	assert_false(game.request_cash_out())
	assert_true(game.panel._vault_open.disabled)
	assert_eq(Wallet.balance, 200)

	await wait_seconds(0.22)
	assert_false(game.panel._vault_tiles[0].is_flipping, "Reduced motion still reaches reveal completion")
	assert_signal_not_emitted(game, "round_resolved")
	await wait_seconds(0.18)
	assert_signal_emit_count(game, "round_resolved", 1)
	assert_signal_emit_count(session, "round_applied", 1)
	assert_eq(Wallet.balance, 190)
	game.call("_finish", result)
	assert_signal_emit_count(game, "round_resolved", 1)
	assert_eq(Wallet.balance, 190, "Resolved result cannot settle twice")
