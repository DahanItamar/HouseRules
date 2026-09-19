extends Node
## Captures the Match Point cabinet at real output size: idle, help, each risk
## table, the serve, mid-drop, the Back confirmation mid-drop, an edge landing
## on the High table, a centre landing, and a reduced-motion round. Saves and
## the instance lock are isolated from the player's data.
##
##   godot --path . tools/capture_match_point.tscn -- --capture-size=1920x1080
##
## To show a rare edge court on demand, the capture re-seeds the cabinet stream
## with the first seed whose next draw lands there. That only chooses which
## honest draw is shown; the math and the board are untouched.

const OUTPUT := "res://tests/results/screenshots/match_point_fhd"
var _output := OUTPUT
var _requested_size := Vector2i(1920, 1080)
var _proof: Array[Dictionary] = []


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
	wallet.call("reset", 2000)
	router.enter_cabinet(load("res://data/cabinets/match_point.tres"))
	await get_tree().create_timer(0.9).timeout
	var game: Node = router.session.cabinet
	var panel: MatchPointPanel = game.panel
	await _snapshot("01_idle")
	panel.set_help_open(true)
	await get_tree().create_timer(0.35).timeout
	await _snapshot("02_help")
	panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	for risk: int in [
		MatchPointMath.Risk.LOW, MatchPointMath.Risk.MEDIUM, MatchPointMath.Risk.HIGH
	]:
		game.call("request_risk", risk)
		await get_tree().create_timer(0.25).timeout
		await _snapshot("03_risk_%s" % MatchPointMath.RISK_KEYS[risk].to_lower())
	game.select_stake(50)
	_seed_for(game, func(court: int) -> bool: return court == 0 or court == 12)
	var served: bool = game.call("request_serve")
	assert(served, "Match Point serve must start")
	await get_tree().create_timer(0.3).timeout
	await _snapshot("04_serve")
	await get_tree().create_timer(0.75).timeout
	await _snapshot("05_mid_drop")
	await _wait_until(func() -> bool: return panel._ball_landed)
	await get_tree().create_timer(0.05).timeout
	await _snapshot("06_landed_edge_high")
	_record(game, panel, "edge_high")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.8).timeout
	await _snapshot("07_result_edge_high")
	game.call("request_risk", MatchPointMath.Risk.MEDIUM)
	game.select_stake(20)
	_seed_for(game, func(court: int) -> bool: return court == 6)
	served = game.call("request_serve")
	assert(served, "Centre serve must start")
	await get_tree().create_timer(1.0).timeout
	game.exit_confirmation.present(game.current_stake)
	await get_tree().create_timer(0.35).timeout
	await _snapshot("08_back_confirm_mid_drop")
	game.exit_confirmation.cancel()
	await _wait_until(func() -> bool: return panel._ball_landed)
	await get_tree().create_timer(0.05).timeout
	await _snapshot("09_landed_centre")
	_record(game, panel, "centre_medium")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.8).timeout
	await _snapshot("10_result_centre")
	motion_policy.call("set_reduced_motion_for_tests", true)
	await get_tree().process_frame
	game.select_stake(10)
	served = game.call("request_serve")
	assert(served, "Reduced-motion serve must start")
	await get_tree().process_frame
	await _snapshot("11_reduced_motion_landed")
	_record(game, panel, "reduced_motion")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.2).timeout
	await _snapshot("12_reduced_motion_result")
	_write_proof()
	motion_policy.call("clear_test_override")
	router.return_to_floor()
	await get_tree().create_timer(0.3).timeout
	main._quit_game()


## Re-seeds the cabinet stream so its next draw lands in a court `wanted` accepts.
func _seed_for(game: Node, wanted: Callable) -> void:
	var math: MatchPointMath = game.get("math")
	var probe := RandomNumberGenerator.new()
	for seed_value: int in range(1, 400000):
		probe.seed = seed_value
		if wanted.call(math.slot_for_draw(probe.randi_range(0, math.total_paths() - 1))):
			game.context.rng.seed = seed_value
			return
	assert(false, "No seed found for the requested court")


func _record(game: Node, panel: MatchPointPanel, label: String) -> void:
	var math: MatchPointMath = game.get("math")
	var decided: int = panel._drop_result.detail.slot
	(
		_proof
		. append(
			{
				"label": label,
				"draw": panel._drop_result.detail.draw,
				"decided_court": decided,
				"path": panel._drop_result.detail.path,
				"board_court": panel.board.landed_court,
				"ball_at": [panel.board.ball_position.x, panel.board.ball_position.y],
				"court_rest":
				[MatchPointBoard.court_rest(decided).x, MatchPointBoard.court_rest(decided).y],
				"multiplier":
				MatchPointMath.multiplier_text(
					math.multiplier_tenths(panel._drop_result.detail.risk, decided)
				),
				"matches": decided == panel.board.landed_court,
			}
		)
	)


func _write_proof() -> void:
	var file := FileAccess.open(
		_output.path_join("match_point_motion_proof.json"), FileAccess.WRITE
	)
	file.store_string(JSON.stringify(_proof, "\t") + "\n")
	print("MATCH POINT PROOF ", _proof)


func _wait_until(condition: Callable, timeout_seconds: float = 8.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			assert(false, "Match Point capture timed out")
			return
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
