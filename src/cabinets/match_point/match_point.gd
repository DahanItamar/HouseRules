extends MiniGame
## Match Point, a tennis-ball Plinko board. The player picks a stake and a risk
## table, then serves. One draw from the cabinet stream decides the court and the
## ball's left/right path before anything moves; the board only animates that
## decided path, and settlement waits until the ball is in the court.

const CHIP_VALUES: Array[int] = [10, 20, 50, 100, 200]

var math := MatchPointMath.new()
var risk: MatchPointMath.Risk = MatchPointMath.Risk.MEDIUM


func _create_panel() -> CabinetPanel:
	return MatchPointPanel.new()


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


## Chip denominations only: every stake stays a multiple of the stake unit, so
## fractional multipliers always settle to whole chips.
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


func is_serve_open() -> bool:
	return context != null and not is_round_active and not is_result_pending


func can_serve() -> bool:
	return (
		is_serve_open()
		and math.is_legal_stake(selected_stake)
		and available_stakes().has(selected_stake)
		and can_stake(selected_stake)
	)


func request_risk(next_risk: MatchPointMath.Risk) -> bool:
	if not is_serve_open() or next_risk == risk:
		return false
	risk = next_risk
	AudioService.play(&"confirm")
	_board().risk_changed()
	return true


func cycle_risk() -> bool:
	return request_risk(((risk + 1) % MatchPointMath.RISK_KEYS.size()) as MatchPointMath.Risk)


func request_serve() -> bool:
	if not is_serve_open():
		return false
	if not can_serve():
		AudioService.play(&"loss")
		_board().show_notice("MATCH_POINT_NEED_STAKE")
		return false
	current_stake = selected_stake
	is_round_active = true
	# The court and the path are decided here, before the ball is served.
	var result := math.drop(current_stake, risk, context.rng)
	_board().begin_drop(result)
	_finish(result)
	return true


func abandon() -> void:
	if is_round_active and not is_result_pending:
		_finish(RoundResult.create(current_stake, 0, RoundResult.Outcome.ABANDONED))


func _board() -> MatchPointPanel:
	return panel as MatchPointPanel


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
		request_serve()
	elif event.is_action_pressed("secondary"):
		cycle_risk()
	elif event.is_action_pressed("interact"):
		# Nothing focused: A serves, the most common action on this cabinet.
		request_serve()
	elif event.is_action_pressed("move_up"):
		handled = _board().navigate(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		handled = _board().navigate(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		handled = _board().navigate(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		handled = _board().navigate(Vector2i.RIGHT)
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
