extends MiniGame
## Forno d'Oro, a crash game dressed as a pizza bake. The player sets a stake and
## an optional oven timer, then sends the pizza in. The multiplier is how far
## along the bake is; pulling it out pays stake x multiplier, and if it burns
## first the stake is gone.
##
## The crash point is drawn from the cabinet stream when the pizza goes in,
## before anything moves, and the climb only replays it. The wallet settles
## once, when the bake ends. Leaving mid-bake forfeits the stake, so Back is
## never an escape.

const STAKE_KEYS: Array[int] = [100, 200, 500, 1000]

var math := CoreOverclockMath.new()


func _create_panel() -> CabinetPanel:
	return CoreOverclockPanel.new()


## The bake itself is the reveal: the result settles when it ends, not held.
func _gates_result_on_reveal() -> bool:
	return false


func stake_options() -> Array[int]:
	var options: Array[int] = []
	if context == null:
		return options
	for amount: int in STAKE_KEYS:
		if amount >= context.definition.min_bet and amount <= context.definition.max_bet:
			options.append(amount)
	return options


## Whole stake units only: every payout then settles to exact chips.
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


func is_deck_open() -> bool:
	return context != null and not is_round_active and not is_result_pending


func can_bake() -> bool:
	return (
		is_deck_open()
		and math.is_legal_stake(selected_stake)
		and available_stakes().has(selected_stake)
		and can_stake(selected_stake)
	)


## The key the player holds: pull the pizza while one is baking, otherwise send
## the next one in.
func request_primary() -> bool:
	if is_round_active:
		return request_pull()
	return request_bake()


func request_bake() -> bool:
	if not is_deck_open():
		return false
	if not can_bake():
		AudioService.play(&"loss")
		_screen().show_notice("CORE_OVERCLOCK_NEED_STAKE")
		return false
	current_stake = selected_stake
	is_round_active = true
	math.reset()
	# The crash point is decided here, before the pizza is on the stone.
	math.begin(current_stake, context.rng)
	_screen().begin_bake()
	return true


## Pulls the pizza at the multiplier now on the dial.
func request_pull() -> bool:
	if not is_round_active or is_result_pending:
		return false
	var result := math.cash_out()
	if result == null:
		return false
	_finish(result)
	return true


## Steps the oven timer through the presets. Only between bakes, so it can never
## be a reaction to a multiplier already on the dial.
func cycle_auto_target() -> bool:
	if not is_deck_open():
		return false
	var targets := math.paytable.auto_targets
	if targets.is_empty():
		return false
	var index: int = Array(targets).find(math.auto_centi)
	if not math.set_auto_target(targets[(index + 1) % targets.size()]):
		return false
	AudioService.play(&"confirm")
	_screen().refresh()
	return true


func abandon() -> void:
	if is_round_active and not is_result_pending:
		var result := math.abandon()
		_finish(
			(
				result
				if result != null
				else RoundResult.create(current_stake, 0, RoundResult.Outcome.ABANDONED)
			)
		)


func _process(delta: float) -> void:
	var screen := _screen()
	if screen == null or context == null:
		return
	var result: RoundResult = null
	if is_round_active and not is_result_pending:
		result = math.advance(delta)
	screen.tick(delta)
	if result != null:
		_finish(result)


func _screen() -> CoreOverclockPanel:
	return panel as CoreOverclockPanel


func _unhandled_input(event: InputEvent) -> void:
	if _refuse_help_mid_bake(event):
		return
	if handle_common_input(event):
		return
	if event.is_action_pressed("back"):
		super._unhandled_input(event)
		return
	if event.is_action_pressed("interact"):
		request_primary()
		get_viewport().set_input_as_handled()
		return
	if is_round_active or is_result_pending:
		if _is_table_action(event):
			get_viewport().set_input_as_handled()
		return
	if handle_bet_input(event):
		get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("secondary"):
		cycle_auto_target()
	elif event.is_action_pressed("tertiary"):
		request_primary()
	elif event.is_action_pressed("move_up"):
		handled = _screen().navigate(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		handled = _screen().navigate(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		handled = _screen().navigate(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		handled = _screen().navigate(Vector2i.RIGHT)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## The guide would pause a bake the player is meant to be watching, so it opens
## between bakes only.
func _refuse_help_mid_bake(event: InputEvent) -> bool:
	if not event.is_action_pressed("help") or not math.is_running():
		return false
	AudioService.play(&"loss")
	_screen().show_notice("CORE_OVERCLOCK_HELP_LOCKED")
	get_viewport().set_input_as_handled()
	return true


func _is_table_action(event: InputEvent) -> bool:
	for action: String in [
		"interact", "secondary", "tertiary", "move_up", "move_down", "move_left", "move_right"
	]:
		if event.is_action_pressed(action):
			return true
	return false
