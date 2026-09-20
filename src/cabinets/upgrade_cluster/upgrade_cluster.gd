extends MiniGame
## Upgrade Cluster cabinet. One press of PLAY draws the entire round - the grid,
## every tumble and the upgrade bar - from the cabinet's RNG stream before a
## single tile moves. The screen then replays that script, and the wallet settles
## once, after the replay finishes.

const STAKE_OPTIONS: Array[int] = [1, 2, 5, 10, 25, 50, 100]

var math := UpgradeClusterMath.new()


func _create_panel() -> CabinetPanel:
	return UpgradeClusterPanel.new()


## The cascade replay is the reveal; settlement waits for it.
func _gates_result_on_reveal() -> bool:
	return true


func stake_options() -> Array[int]:
	var options: Array[int] = []
	if context == null:
		return options
	for amount: int in STAKE_OPTIONS:
		if amount >= context.definition.min_bet and amount <= context.definition.max_bet:
			options.append(amount)
	return options


func is_idle() -> bool:
	return context != null and not is_round_active and not is_result_pending


func can_play() -> bool:
	return is_idle() and selected_stake > 0 and selected_stake <= bet_cap()


## Draws and resolves the whole round here; the panel only presents it.
func request_play() -> bool:
	if not can_play():
		AudioService.play(&"loss")
		_board().show_notice("CLUSTER_NEED_BET")
		return false
	current_stake = selected_stake
	is_round_active = true
	var result := math.play(current_stake, context.rng)
	_board().begin_round(result)
	_finish(result)
	return true


func abandon() -> void:
	if is_round_active and not is_result_pending:
		_finish(RoundResult.create(current_stake, 0, RoundResult.Outcome.ABANDONED))


func _board() -> UpgradeClusterPanel:
	return panel as UpgradeClusterPanel


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if event.is_action_pressed("back"):
		super._unhandled_input(event)
		return
	if is_round_active or is_result_pending:
		# A round in flight swallows its own actions so a second press cannot
		# start another one or skip the replay into settlement.
		if _is_board_action(event):
			get_viewport().set_input_as_handled()
		return
	if handle_bet_input(event):
		get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("interact"):
		request_play()
	elif event.is_action_pressed("move_left"):
		handled = adjust_stake(-1)
	elif event.is_action_pressed("move_right"):
		handled = adjust_stake(1)
	else:
		handled = false
	if handled:
		if panel != null:
			panel.refresh()
		get_viewport().set_input_as_handled()


func _is_board_action(event: InputEvent) -> bool:
	for action: String in ["interact", "secondary", "tertiary", "bet_down", "bet_up", "bet_max"]:
		if event.is_action_pressed(action):
			return true
	return false
