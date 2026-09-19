extends Node
## Captures the Ruby Roulette table at real output size: idle, chips placed,
## spinning, ball landing, settled result and a reduced-motion round. Saves and
## the instance lock are isolated from the player's data.
##
##   godot --path . tools/capture_roulette.tscn -- --capture-size=1920x1080

const OUTPUT := "res://tests/results/screenshots/roulette_fhd"
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
	wallet.call("reset", 500)
	router.enter_cabinet(load("res://data/cabinets/roulette.tres"))
	await get_tree().create_timer(0.9).timeout
	var game: Node = router.session.cabinet
	var panel: RouletteTablePanel = game.panel
	await _snapshot("01_idle")
	panel.set_help_open(true)
	await get_tree().create_timer(0.35).timeout
	await _snapshot("02_help")
	panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	_place_bets(game, panel)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("03_bets_placed")
	var spun: bool = game.call("request_spin")
	assert(spun, "Roulette spin must start")
	var pocket: int = panel._spin_result.detail.pocket
	await get_tree().create_timer(0.2).timeout
	await _snapshot("04_spin_launch")
	await get_tree().create_timer(1.3).timeout
	await _snapshot("05_spinning")
	await get_tree().create_timer(1.6).timeout
	await _snapshot("06_ball_dropping")
	await _wait_until(func() -> bool: return panel._ball_landed)
	await get_tree().create_timer(0.1).timeout
	await _snapshot("07_ball_landed")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.7).timeout
	await _snapshot("08_result")
	_write_proof(pocket, panel)
	await get_tree().create_timer(2.4).timeout
	await _snapshot("09_swept_next_round")
	motion_policy.call("set_reduced_motion_for_tests", true)
	await get_tree().process_frame
	var rebet: bool = game.call("request_rebet")
	assert(rebet, "Rebet must restore the previous chips")
	var reduced_spin: bool = game.call("request_spin")
	assert(reduced_spin, "Reduced-motion spin must start")
	await get_tree().process_frame
	await _snapshot("10_reduced_motion_landed")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.2).timeout
	await _snapshot("11_reduced_motion_result")
	motion_policy.call("clear_test_override")
	router.return_to_floor()
	await get_tree().create_timer(0.3).timeout
	main._quit_game()


func _place_bets(game: Node, panel: RouletteTablePanel) -> void:
	var picks: Array = [
		[25, RouletteMath.spot_id(RouletteMath.BetKind.RED)],
		[10, RouletteMath.spot_id(RouletteMath.BetKind.STRAIGHT, [17])],
		[5, RouletteMath.spot_id(RouletteMath.BetKind.SPLIT, [20, 23])],
		[5, RouletteMath.spot_id(RouletteMath.BetKind.CORNER, [25, 26, 28, 29])],
		[10, RouletteMath.group_spot_id(RouletteMath.BetKind.DOZEN, 2)],
		[5, RouletteMath.spot_id(RouletteMath.BetKind.STREET, [31, 32, 33])],
	]
	for pick: Array in picks:
		game.select_stake(int(pick[0]))
		var placed: bool = game.call("request_place", String(pick[1]))
		assert(placed, "Chip placement failed: %s" % pick[1])
	panel.board.set_cursor(panel.board.geometry.index_of(String(picks[2][1])))


func _wait_until(condition: Callable, timeout_seconds: float = 8.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			assert(false, "Roulette capture timed out")
			return
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())


func _write_proof(pocket: int, panel: RouletteTablePanel) -> void:
	var proof := {
		"decided_pocket": pocket,
		"ball_pocket": panel.wheel.ball_pocket,
		"board_marker": panel.board.result_pocket,
		"matches": pocket == panel.wheel.ball_pocket and pocket == panel.board.result_pocket,
	}
	var file := FileAccess.open(_output.path_join("roulette_motion_proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(proof, "\t") + "\n")
	print("ROULETTE PROOF ", proof)
