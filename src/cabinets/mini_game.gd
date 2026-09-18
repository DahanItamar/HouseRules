class_name MiniGame
extends Node
## Cabinet boundary: input context in, one result per accepted round out.

signal round_resolved(result: RoundResult)
signal exit_requested

var context: MiniGameContext
var is_round_active: bool = false
var current_stake: int = 0
var selected_stake: int = 1
var panel: CabinetPanel


func begin(game_context: MiniGameContext) -> void:
	context = game_context
	selected_stake = context.definition.min_bet
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


func adjust_stake(direction: int) -> bool:
	if is_round_active or context == null or direction == 0:
		return false
	var available: Array[int] = stake_options().filter(
		func(amount: int) -> bool: return amount <= context.balance
	)
	if available.is_empty():
		return false
	var index: int = available.find(selected_stake)
	if index < 0:
		index = 0
	var next_index: int = clampi(index + signi(direction), 0, available.size() - 1)
	var changed: bool = selected_stake != available[next_index]
	selected_stake = available[next_index]
	return changed


func handle_common_input(event: InputEvent) -> bool:
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


func _ready() -> void:
	panel = CabinetPanel.new()
	panel.cabinet = self
	add_child(panel)


func _finish(result: RoundResult) -> void:
	if not is_round_active:
		return
	is_round_active = false
	round_resolved.emit(result)
	if panel != null:
		panel.show_result(result)


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
	elif not is_round_active and context != null:
		var changed := false
		if event.is_action_pressed("move_left"):
			changed = adjust_stake(-1)
		elif event.is_action_pressed("move_right"):
			changed = adjust_stake(1)
		if changed and panel != null:
			panel.refresh()
