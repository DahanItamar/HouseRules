class_name MiniGame
extends Node
## Cabinet boundary: input context in, one result per accepted round out.

signal round_resolved(result: RoundResult)
signal exit_requested

var context: MiniGameContext
var is_round_active: bool = false
var is_result_pending: bool = false
var _pending_result: RoundResult
var current_stake: int = 0
var selected_stake: int = 1
var panel: CabinetPanel
var exit_confirmation: CabinetExitConfirmation

enum BetOperation { MIN, ADD_10, ADD_25, MULTIPLY_2, MULTIPLY_5, MAX }


func begin(game_context: MiniGameContext) -> void:
	context = game_context
	normalize_selected_stake()
	if panel != null:
		panel.refresh()


func abandon() -> void:
	if is_round_active:
		_finish(RoundResult.create(current_stake, 0, RoundResult.Outcome.ABANDONED))


func can_stake(amount: int) -> bool:
	return (
		not is_round_active
		and context != null
		and amount >= context.definition.min_bet
		and amount <= context.definition.max_bet
		and amount <= context.balance
	)


func stake_options() -> Array[int]:
	var by_game: Dictionary = {
		&"slot_classic": [1, 2, 5, 10, 25, 50],
		&"blackjack": [5, 10, 25, 50, 100],
		&"minefield_vault": [1, 2, 5, 10, 25],
	}
	var options: Array[int] = []
	for amount: int in by_game.get(context.definition.id, [context.definition.min_bet]):
		if amount >= context.definition.min_bet and amount <= context.definition.max_bet:
			options.append(amount)
	return options


func available_stakes() -> Array[int]:
	if context == null:
		return []
	var cap := bet_cap()
	var available: Array[int] = stake_options().filter(
		func(amount: int) -> bool: return amount <= cap
	)
	if cap >= context.definition.min_bet and not available.has(cap):
		available.append(cap)
	available.sort()
	return available


func bet_cap() -> int:
	if context == null:
		return 0
	return mini(context.definition.max_bet, context.balance)


func bet_candidate(operation: int) -> int:
	if context == null:
		return 0
	match operation:
		BetOperation.MIN:
			return context.definition.min_bet
		BetOperation.ADD_10:
			return selected_stake + 10
		BetOperation.ADD_25:
			return selected_stake + 25
		BetOperation.MULTIPLY_2:
			return selected_stake * 2
		BetOperation.MULTIPLY_5:
			return selected_stake * 5
		BetOperation.MAX:
			return bet_cap()
	return selected_stake


func can_apply_bet(operation: int) -> bool:
	if is_round_active or context == null:
		return false
	var candidate := bet_candidate(operation)
	return (
		candidate >= context.definition.min_bet
		and candidate <= bet_cap()
		and candidate != selected_stake
	)


func apply_bet(operation: int) -> bool:
	if not can_apply_bet(operation):
		AudioService.play(&"loss")
		return false
	selected_stake = bet_candidate(operation)
	AudioService.play(&"confirm")
	if panel != null:
		panel.refresh()
	return true


func normalize_selected_stake() -> void:
	if context == null:
		return
	var cap := bet_cap()
	if cap < context.definition.min_bet:
		selected_stake = 0
	elif selected_stake < context.definition.min_bet:
		selected_stake = context.definition.min_bet
	elif selected_stake > cap:
		selected_stake = cap


func adjust_stake(direction: int) -> bool:
	if is_round_active or context == null or direction == 0:
		return false
	var available := available_stakes()
	if available.is_empty():
		return false
	var index: int = available.find(selected_stake)
	if index < 0:
		index = 0
		while index < available.size() and available[index] < selected_stake:
			index += 1
		if direction < 0:
			index -= 1
		index = clampi(index, 0, available.size() - 1)
		var changed_to_nearest := selected_stake != available[index]
		selected_stake = available[index]
		return changed_to_nearest
	var next_index: int = clampi(index + signi(direction), 0, available.size() - 1)
	var changed: bool = selected_stake != available[next_index]
	selected_stake = available[next_index]
	return changed


func select_stake(amount: int) -> bool:
	if is_round_active or amount == selected_stake:
		return false
	if context == null or amount < context.definition.min_bet or amount > bet_cap():
		return false
	selected_stake = amount
	if panel != null:
		panel.refresh()
	AudioService.play(&"confirm")
	return true


func handle_common_input(event: InputEvent) -> bool:
	if exit_confirmation != null and exit_confirmation.handle_input(event):
		return true
	if event.is_action_pressed("help"):
		panel.toggle_help()
		get_viewport().set_input_as_handled()
		return true
	if panel.help_open:
		if event.is_action_pressed("back"):
			panel.set_help_open(false)
		get_viewport().set_input_as_handled()
		return true
	return false


## Games with their own table presentation return a CabinetPanel subclass.
func _create_panel() -> CabinetPanel:
	return CabinetPanel.new()


## Games whose result waits for an on-screen reveal (cards, tiles, a wheel)
## hold settlement until the panel reports that the reveal finished.
func _gates_result_on_reveal() -> bool:
	return context.definition.id in [&"blackjack", &"minefield_vault"]


func _ready() -> void:
	panel = _create_panel()
	panel.cabinet = self
	add_child(panel)
	exit_confirmation = CabinetExitConfirmation.new()
	exit_confirmation.name = "CabinetExitConfirmation"
	exit_confirmation.leave_confirmed.connect(func() -> void: exit_requested.emit())
	add_child(exit_confirmation)


func _finish(result: RoundResult) -> void:
	if not is_round_active or is_result_pending:
		return
	if exit_confirmation != null:
		exit_confirmation.dismiss()
	if (
		result.outcome != RoundResult.Outcome.ABANDONED
		and panel != null
		and _gates_result_on_reveal()
	):
		is_result_pending = true
		_pending_result = result
		panel.present_result_after_reveal(result, _complete_finish.bind(result))
		return
	_complete_finish(result)


func _complete_finish(result: RoundResult) -> void:
	if not is_round_active:
		return
	is_result_pending = false
	_pending_result = null
	is_round_active = false
	round_resolved.emit(result)
	if panel != null:
		panel.show_result(result)


func complete_pending_result() -> void:
	if is_result_pending and _pending_result != null:
		_complete_finish(_pending_result)


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		if is_round_active:
			exit_confirmation.present(current_stake)
		else:
			exit_requested.emit()
	elif not is_round_active and context != null:
		var changed := false
		if event.is_action_pressed("move_left"):
			changed = adjust_stake(-1)
		elif event.is_action_pressed("move_right"):
			changed = adjust_stake(1)
		if changed and panel != null:
			panel.refresh()
