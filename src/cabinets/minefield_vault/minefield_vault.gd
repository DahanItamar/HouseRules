extends MiniGame

var math := MinefieldMath.new()
var mine_count: int = 3
var snap_cursor := SnapCursor.new(5, 5)


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	current_stake = amount
	is_round_active = true
	AudioService.play(&"chip")
	AudioService.play(&"vault_tension")
	snap_cursor.reset()
	math.begin(amount, mine_count, context.rng)
	panel.set_status("VAULT_REVEAL")
	return true


func abandon() -> void:
	if is_round_active:
		_finish(math.abandon())


func request_open() -> bool:
	if is_result_pending:
		return false
	var result: RoundResult
	if is_round_active:
		if not math.revealed.has(snap_cursor.index):
			AudioService.play(&"vault_tension")
		result = math.reveal(snap_cursor.index)
	else:
		return start_round(selected_stake)
	if result != null:
		_finish(result)
	panel.refresh()
	return true


func request_cash_out() -> bool:
	if is_result_pending or not is_round_active:
		return false
	var result := math.cash_out()
	if result != null:
		_finish(result)
	panel.refresh()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if is_result_pending:
		get_viewport().set_input_as_handled()
		return
	var result: RoundResult
	if event.is_action_pressed("interact"):
		request_open()
	elif is_round_active and event.is_action_pressed("secondary"):
		request_cash_out()
	elif is_round_active and InputRouter.move_snap_cursor(snap_cursor, event):
		pass
	elif not is_round_active and event.is_action_pressed("move_up"):
		mine_count = mini(24, mine_count + 1)
	elif not is_round_active and event.is_action_pressed("move_down"):
		mine_count = maxi(1, mine_count - 1)
	else:
		super._unhandled_input(event)
		return
	if result != null:
		_finish(result)
	panel.refresh()
	get_viewport().set_input_as_handled()
