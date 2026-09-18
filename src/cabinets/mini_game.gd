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
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
	elif not is_round_active and context != null:
		if event.is_action_pressed("move_left"):
			selected_stake = maxi(context.definition.min_bet, selected_stake - 1)
		elif event.is_action_pressed("move_right"):
			selected_stake = mini(
				mini(context.definition.max_bet, context.balance), selected_stake + 1
			)
		if panel != null:
			panel.refresh()
