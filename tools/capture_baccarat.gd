extends Node
## Captures the Velvet Baccarat table at real output size: idle, help, chips
## placed, the deal, a squeeze, a third card, and settled Banker, Player and Tie
## coups, then a reduced-motion coup. Saves and the instance lock are isolated
## from the player's data.
##
##   godot --path . tools/capture_baccarat.tscn -- --capture-size=1920x1080
##
## To show all three results in one run, the tool advances the cabinet stream
## (whole draws, never edited cards) until the next coup is the one it wants.
## The coup itself is still dealt and settled by BaccaratMath.

const OUTPUT := "res://tests/results/screenshots/baccarat_fhd"
var _output := OUTPUT
var _requested_size := Vector2i(1920, 1080)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = "res://tests/results/screenshots".path_join(
				argument.trim_prefix("--capture-dir=")
			)
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	get_window().mode = Window.MODE_WINDOWED
	get_window().borderless = true
	get_window().size = _requested_size
	DirAccess.make_dir_recursive_absolute(_output)
	call_deferred("_capture")


func _capture() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	var router: Node = scene_root.get_node("SceneRouter")
	var wallet: Node = scene_root.get_node("Wallet")
	var motion_policy: Node = scene_root.get_node("MotionPolicy")
	motion_policy.call("set_reduced_motion_for_tests", false)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(20260918)
	main._start_playing()
	await get_tree().create_timer(0.4).timeout
	wallet.call("set_test_mode", false)
	wallet.call("reset", 1500)
	router.enter_cabinet(load("res://data/cabinets/baccarat.tres"))
	await get_tree().create_timer(0.9).timeout
	var game: Node = router.session.cabinet
	var panel: BaccaratTablePanel = game.panel
	await _snapshot("01_idle")
	panel.set_help_open(true)
	await get_tree().create_timer(0.35).timeout
	await _snapshot("02_help")
	panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	_place(game, [[40, "banker"], [20, "banker"], [20, "player_pair"], [20, "tie"]])
	(panel.spots["banker"] as Control).grab_focus()
	await get_tree().create_timer(0.3).timeout
	await _snapshot("03_bets_placed")
	# Banker wins after both hands draw a third card.
	_steer(
		game,
		func(coup: Dictionary) -> bool:
			return (
				coup.winner == BaccaratRules.Winner.BANKER
				and (coup.player_cards as Array).size() == 3
				and (coup.banker_cards as Array).size() == 3
			)
	)
	var started_1: bool = game.call("request_deal")
	assert(started_1, "Baccarat deal must start")
	await get_tree().create_timer(0.45).timeout
	await _snapshot("04_dealing")
	await _wait_until(
		func() -> bool: return panel.phase == &"squeeze_player" and panel.cards[0].peel >= 0.5
	)
	await _snapshot("05_squeeze")
	await _wait_until(
		func() -> bool:
			var third := panel._card_at(1, 2)
			return panel.phase == &"third_banker" and third != null and third.peel >= 0.45
	)
	await _snapshot("06_third_card")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.7).timeout
	await _snapshot("07_result_banker")
	_write_proof(panel)
	_place(game, [[100, "player"], [20, "player_pair"]])
	_steer(
		game,
		func(coup: Dictionary) -> bool:
			return coup.winner == BaccaratRules.Winner.PLAYER and coup.natural
	)
	var started_2: bool = game.call("request_deal")
	assert(started_2, "Player coup must start")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.7).timeout
	await _snapshot("08_result_player")
	_place(game, [[40, "player"], [40, "banker"], [20, "tie"]])
	_steer(game, func(coup: Dictionary) -> bool: return coup.winner == BaccaratRules.Winner.TIE)
	var started_3: bool = game.call("request_deal")
	assert(started_3, "Tie coup must start")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.7).timeout
	await _snapshot("09_result_tie")
	motion_policy.call("set_reduced_motion_for_tests", true)
	await get_tree().process_frame
	var started_4: bool = game.call("request_rebet")
	assert(started_4, "Rebet must restore the previous chips")
	_steer(game, func(coup: Dictionary) -> bool: return coup.winner == BaccaratRules.Winner.BANKER)
	var started_5: bool = game.call("request_deal")
	assert(started_5, "Reduced-motion coup must start")
	await get_tree().process_frame
	await _snapshot("10_reduced_motion_revealed")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.2).timeout
	await _snapshot("11_reduced_motion_result")
	motion_policy.call("clear_test_override")
	router.return_to_floor()
	await get_tree().create_timer(0.3).timeout
	main._quit_game()


func _place(game: Node, picks: Array) -> void:
	for pick: Array in picks:
		game.select_stake(int(pick[0]))
		var placed: bool = game.call("request_place", String(pick[1]))
		assert(placed, "Chip placement failed: %s" % pick[1])


## Advances the cabinet stream by whole draws until the next coup satisfies `want`.
func _steer(game: Node, want: Callable) -> void:
	var rng: RandomNumberGenerator = game.context.rng
	var math: BaccaratMath = game.get("math")
	for attempt: int in range(20000):
		var probe := RandomNumberGenerator.new()
		probe.seed = rng.seed
		probe.state = rng.state
		if want.call(math.deal_coup(probe)):
			return
		rng.randi()
	assert(false, "No matching coup found")


func _wait_until(condition: Callable, timeout_seconds: float = 12.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			assert(false, "Baccarat capture timed out")
			return
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())


func _write_proof(panel: BaccaratTablePanel) -> void:
	var coup: Dictionary = panel._coup
	var shown: Array = []
	for card: BaccaratCard in panel.cards:
		shown.append([card.hand, card.slot, card.card_id])
	var proof := {
		"player_cards": coup.player_cards,
		"banker_cards": coup.banker_cards,
		"player_total": coup.player_total,
		"banker_total": coup.banker_total,
		"shown_totals": [panel.zones[0].total, panel.zones[1].total],
		"shown_cards": shown,
		"matches":
		panel.zones[0].total == coup.player_total and panel.zones[1].total == coup.banker_total,
	}
	var file := FileAccess.open(_output.path_join("baccarat_deal_proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(proof, "\t") + "\n")
	print("BACCARAT PROOF ", proof)
