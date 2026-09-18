extends MiniGame

var math := BlackjackMath.new()


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	panel.prepare_blackjack_round()
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


func request_primary() -> bool:
	if is_round_active:
		if not panel.blackjack_input_ready():
			return false
		_resolve(math.hit())
		return true
	return start_round(selected_stake)


func request_stand() -> bool:
	if not is_round_active or not panel.blackjack_input_ready():
		return false
	_resolve(math.stand())
	return true


func request_double() -> bool:
	if not is_round_active or not panel.blackjack_input_ready():
		return false
	if not math.can_double(context.balance):
		panel.set_status("BLACKJACK_DOUBLE_UNAVAILABLE")
		return false
	_resolve(math.double_down(context.balance))
	return true


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if is_round_active and not panel.blackjack_input_ready():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		request_primary()
		get_viewport().set_input_as_handled()
	elif is_round_active and event.is_action_pressed("secondary"):
		request_stand()
		get_viewport().set_input_as_handled()
	elif is_round_active and event.is_action_pressed("tertiary"):
		request_double()
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)
