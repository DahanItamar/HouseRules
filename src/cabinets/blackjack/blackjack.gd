extends MiniGame

var math := BlackjackMath.new()


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	current_stake = amount
	is_round_active = true
	_resolve(math.begin(amount, context.rng))
	return true


func abandon() -> void:
	if is_round_active:
		_finish(math.abandon())


func _resolve(result: RoundResult) -> void:
	current_stake = math.stake
	if result != null:
		_finish(result)
	elif panel != null:
		panel.set_status("BLACKJACK_DECIDE")
	panel.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if is_round_active:
			_resolve(math.hit())
		else:
			start_round(selected_stake)
		get_viewport().set_input_as_handled()
	elif is_round_active and event.is_action_pressed("secondary"):
		_resolve(math.stand())
		get_viewport().set_input_as_handled()
	elif is_round_active and event.is_action_pressed("tertiary"):
		if math.can_double(context.balance):
			_resolve(math.double_down(context.balance))
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)
