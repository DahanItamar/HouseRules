extends MiniGame

var math := MinefieldMath.new()
var mine_count: int = 3
var cursor: int = 0


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	current_stake = amount
	is_round_active = true
	cursor = 0
	math.begin(amount, mine_count, context.rng)
	panel.set_status("VAULT_REVEAL")
	return true


func abandon() -> void:
	if is_round_active:
		_finish(math.abandon())


func _unhandled_input(event: InputEvent) -> void:
	var result: RoundResult
	if event.is_action_pressed("interact"):
		if is_round_active:
			result = math.reveal(cursor)
		else:
			start_round(selected_stake)
	elif is_round_active and event.is_action_pressed("secondary"):
		result = math.cash_out()
	elif is_round_active and event.is_action_pressed("move_left"):
		cursor = (cursor / 5) * 5 + posmod(cursor % 5 - 1, 5)
	elif is_round_active and event.is_action_pressed("move_right"):
		cursor = (cursor / 5) * 5 + posmod(cursor % 5 + 1, 5)
	elif is_round_active and event.is_action_pressed("move_up"):
		cursor = posmod(cursor - 5, 25)
	elif is_round_active and event.is_action_pressed("move_down"):
		cursor = posmod(cursor + 5, 25)
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
