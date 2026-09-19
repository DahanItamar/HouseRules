extends MiniGame
## Velvet Baccarat (Punto Banco). Chips go on Player, Banker, Tie and the two
## pair spots between coups; DEAL draws one whole coup from the cabinet stream
## and settles every spot together. The dealing, squeeze and reveal only
## present the coup that was already decided.

const CHIP_VALUES: Array[int] = [20, 40, 100, 200]

var math := BaccaratMath.new()


func _create_panel() -> CabinetPanel:
	return BaccaratTablePanel.new()


func _gates_result_on_reveal() -> bool:
	return true


func stake_options() -> Array[int]:
	var options: Array[int] = []
	if context == null:
		return options
	for amount: int in CHIP_VALUES:
		if amount >= context.definition.min_bet and amount <= context.definition.max_bet:
			options.append(amount)
	return options


## Chip denominations only: the table limit is a sum, so it never becomes a chip.
func available_stakes() -> Array[int]:
	var cap := bet_cap()
	return stake_options().filter(func(amount: int) -> bool: return amount <= cap)


func normalize_selected_stake() -> void:
	if context == null:
		return
	var available := available_stakes()
	if available.is_empty():
		selected_stake = 0
		return
	if available.has(selected_stake):
		return
	var best: int = available[0]
	for amount: int in available:
		if amount <= maxi(selected_stake, available[0]):
			best = amount
	selected_stake = best


func is_betting_open() -> bool:
	return context != null and not is_round_active and not is_result_pending


func request_place(spot_id: String) -> bool:
	if not is_betting_open() or selected_stake <= 0:
		return false
	if not math.place(spot_id, selected_stake, bet_cap()):
		AudioService.play(&"loss")
		_table().show_notice("BACCARAT_LIMIT_REACHED")
		return false
	AudioService.play(&"chip")
	_table().bets_changed()
	return true


func request_remove(spot_id: String) -> bool:
	if not is_betting_open() or math.remove(spot_id, maxi(selected_stake, 1)) <= 0:
		return false
	AudioService.play(&"move")
	_table().bets_changed()
	return true


func request_clear() -> bool:
	if not is_betting_open() or math.bets.is_empty():
		return false
	math.clear()
	AudioService.play(&"move")
	_table().bets_changed()
	return true


func request_rebet() -> bool:
	if not is_betting_open():
		return false
	if not math.rebet(bet_cap()):
		AudioService.play(&"loss")
		_table().show_notice("BACCARAT_REBET_UNAVAILABLE")
		return false
	AudioService.play(&"chip")
	_table().bets_changed()
	return true


func request_deal() -> bool:
	if not is_betting_open():
		return false
	var total := math.total_bet()
	if total <= 0 or total > bet_cap():
		AudioService.play(&"loss")
		_table().show_notice("BACCARAT_PLACE_FIRST")
		return false
	current_stake = total
	is_round_active = true
	# The whole coup (every card, both totals, the winner) is decided here,
	# before the first card leaves the shoe.
	var result := math.deal(context.rng)
	_table().begin_deal(result)
	_finish(result)
	return true


func abandon() -> void:
	if is_round_active and not is_result_pending:
		_finish(RoundResult.create(current_stake, 0, RoundResult.Outcome.ABANDONED))


func _table() -> BaccaratTablePanel:
	return panel as BaccaratTablePanel


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if event.is_action_pressed("back"):
		super._unhandled_input(event)
		return
	if is_round_active or is_result_pending:
		if _is_table_action(event):
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("tertiary"):
		request_deal()
	elif event.is_action_pressed("secondary"):
		request_remove(_table().focused_spot_id())
	elif event.is_action_pressed("move_up"):
		handled = _table().navigate(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		handled = _table().navigate(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		handled = _table().navigate(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		handled = _table().navigate(Vector2i.RIGHT)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _is_table_action(event: InputEvent) -> bool:
	for action: String in [
		"interact", "secondary", "tertiary", "move_up", "move_down", "move_left", "move_right"
	]:
		if event.is_action_pressed(action):
			return true
	return false
