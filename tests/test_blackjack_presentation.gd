extends GutTest

const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")

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


func test_totals_are_badged_beside_the_cards_and_actions_stay_controller_ready() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	assert_not_null(panel.find_child("DealerTotalBadge", true, false))
	assert_not_null(panel.find_child("PlayerTotalBadge", true, false))
	assert_gt(panel._blackjack_dealer_total_panel.position.x, 600.0)
	assert_gt(panel._blackjack_player_total_panel.position.x, 600.0)
	assert_eq(panel._blackjack_primary.focus_mode, Control.FOCUS_ALL)
	assert_eq(panel._blackjack_stand.focus_mode, Control.FOCUS_ALL)
	assert_eq(panel._blackjack_double.focus_mode, Control.FOCUS_ALL)
	assert_gte(panel._blackjack_primary.size.x, 44.0)
	assert_gte(panel._blackjack_primary.size.y, 44.0)


func test_live_stake_places_a_readable_wager_stack_on_the_felt() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var game: MiniGame = session.cabinet
	var math: BlackjackMath = game.get("math")
	math.player.assign([10, 7])
	math.dealer.assign([9, 8])
	math.stake = 25
	math.active = true
	game.current_stake = 25
	game.is_round_active = true
	game.panel.refresh()
	var stack: Control = game.panel._blackjack_bet_stack
	assert_true(stack.visible)
	assert_true(stack.is_live)
	assert_eq(stack.wager, 25)
	assert_eq(stack.position, Vector2(286, 354), "Reduced motion lands directly at the final spot")
	assert_eq(stack.scale, Vector2.ONE)


func test_result_feedback_has_a_static_reduced_motion_end_state() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var result := RoundResult.create(10, 20, RoundResult.Outcome.WIN)
	panel._animate_blackjack_result(result)
	assert_true(panel._blackjack_result_banner.visible)
	assert_eq(panel._blackjack_result_banner.modulate.a, 1.0)
	assert_eq(panel._blackjack_result_banner.scale, Vector2.ONE)
	assert_eq(panel._blackjack_result_text.text, tr("ROUND_RESULT") % [10, 20])
	assert_eq(panel._blackjack_bet_stack.wager, 10)
	assert_false(panel._blackjack_fx_tween != null and panel._blackjack_fx_tween.is_running())
