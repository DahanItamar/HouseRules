extends MiniGame
## Texas Hold'em cabinet: one hand per round against five NPC regulars.
##
## PokerMath resolves every NPC decision synchronously; PokerTablePanel replays
## the recorded events (blinds, deals, NPC actions, board, showdown, awards) at
## table pace and reports when the player's decision point is on screen. Wallet
## changes only through CabinetSession once the hand's result is presented.

const TABLE_PANEL := preload("res://src/ui/poker/poker_table_panel.gd")
const STAKES: Array[int] = [4, 10, 20, 50, 100]

var math := PokerMath.new()


func stake_options() -> Array[int]:
	var options: Array[int] = []
	for amount: int in STAKES:
		if amount >= context.definition.min_bet and amount <= context.definition.max_bet:
			options.append(amount)
	return options


func _create_panel() -> CabinetPanel:
	return TABLE_PANEL.new()


func _gates_result_on_reveal() -> bool:
	return true


func table_panel() -> PokerTablePanel:
	return panel as PokerTablePanel


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	table_panel().prepare_hand()
	is_round_active = true
	AudioService.play(&"chip")
	var result := math.begin(amount, context.rng, context.balance)
	_after_math(result)
	return true


func abandon() -> void:
	if is_round_active:
		_finish(math.abandon())


## The player's turn is live only once the table has caught up on screen.
func input_ready() -> bool:
	return (
		is_round_active
		and not is_result_pending
		and math.is_player_turn()
		and table_panel().presentation_idle()
	)


## A / Enter: deal a new hand, otherwise check or call.
func request_primary() -> bool:
	if is_result_pending:
		return false
	if not is_round_active:
		return start_round(selected_stake)
	if not input_ready():
		return false
	var legal := math.legal_actions()
	return _player_act(PokerMath.Action.CHECK if legal.can_check else PokerMath.Action.CALL)


## X: fold (only when facing a bet; checking is free).
func request_fold() -> bool:
	if not input_ready() or not bool(math.legal_actions().can_fold):
		return false
	return _player_act(PokerMath.Action.FOLD)


## Y: bet or raise by the fixed limit for this street.
func request_raise() -> bool:
	if not input_ready():
		return false
	var legal := math.legal_actions()
	if not bool(legal.can_raise):
		AudioService.play(&"loss")
		return false
	return _player_act(PokerMath.Action.BET if legal.raise_is_bet else PokerMath.Action.RAISE)


func _player_act(action: PokerMath.Action) -> bool:
	if action != PokerMath.Action.FOLD and action != PokerMath.Action.CHECK:
		AudioService.play(&"chip")
	_after_math(math.act(action))
	return true


func _after_math(result: RoundResult) -> void:
	current_stake = math.player_committed()
	if result != null:
		_finish(result)
	else:
		table_panel().play_new_events()


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if event.is_action_pressed("back"):
		super._unhandled_input(event)
		return
	if is_result_pending or (is_round_active and not input_ready()):
		if (
			event.is_action_pressed("interact")
			or event.is_action_pressed("secondary")
			or event.is_action_pressed("tertiary")
		):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		request_primary()
		get_viewport().set_input_as_handled()
	elif is_round_active and event.is_action_pressed("secondary"):
		request_fold()
		get_viewport().set_input_as_handled()
	elif is_round_active and event.is_action_pressed("tertiary"):
		request_raise()
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)
