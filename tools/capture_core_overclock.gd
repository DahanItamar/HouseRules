extends Node
## Captures the Corsair's Reach cabinet (id core_overclock) at real output size:
## the deck between runs, the guide, the countdown, an early climb, a long climb,
## a run hauled in and paid out, one the sea takes, the recent-runs strip once it
## has a few on it, the auto-haul target set, and a reduced-motion climb.
##
##   godot --path . tools/capture_core_overclock.tscn -- --capture-size=1920x1080
##
## Runs are started from a chosen uniform through CoreOverclockMath.begin_from,
## so a long climb and a crash can both be shown on demand. That only chooses
## which honest run is replayed: the distribution and the settlement are the
## shipped ones. Saves and the instance lock are isolated from the player's data.

const OUTPUT := "res://tests/results/screenshots/core_overclock_fhd"
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
	saves.new_game(20260920)
	main._start_playing()
	await get_tree().create_timer(0.4).timeout
	wallet.call("set_test_mode", false)
	wallet.call("reset", 5000)
	router.enter_cabinet(load("res://data/cabinets/core_overclock.tres"))
	await get_tree().create_timer(0.9).timeout
	var game: Node = router.session.cabinet
	var panel: CoreOverclockPanel = game.panel
	await _snapshot("01_idle")
	panel.set_help_open(true)
	await get_tree().create_timer(0.35).timeout
	await _snapshot("02_help")
	panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	game.select_stake(200)
	while game.get("math").auto_centi != 0:
		game.call("cycle_auto_target")
	await _launch(game, 4_000_000)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("03_countdown")
	await _wait_until(func() -> bool: return _centi(game) > 130)
	await _snapshot("04_early_climb")
	await _wait_until(func() -> bool: return _centi(game) > 900)
	await _snapshot("05_long_climb")
	game.call("request_pull")
	await get_tree().create_timer(0.12).timeout
	await _snapshot("06_hauled_in")
	_record(game, panel, "hauled_in")
	await get_tree().create_timer(1.4).timeout
	await _snapshot("07_paid_out")
	# A run the sea ends early: the largest seeds crash under 1.10x.
	await _launch(game, 900_000_000)
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.1).timeout
	await _snapshot("08_crashed")
	_record(game, panel, "crashed")
	for uniform: int in [40_000_000, 600_000_000, 120_000_000, 200_000_000]:
		await _launch(game, uniform)
		await _wait_until(func() -> bool: return not game.is_round_active, 30.0)
		await get_tree().create_timer(0.2).timeout
	await _snapshot("09_history_strip")
	# The auto-haul target set before the run, shown on the readout and the curve.
	while game.get("math").auto_centi != 200:
		game.call("cycle_auto_target")
	await get_tree().create_timer(0.3).timeout
	await _snapshot("10_auto_haul_set")
	motion_policy.call("set_reduced_motion_for_tests", true)
	await get_tree().process_frame
	await _launch(game, 3_000_000)
	await _wait_until(func() -> bool: return _centi(game) > 180)
	await _snapshot("11_reduced_motion_climb")
	await _wait_until(func() -> bool: return not game.is_round_active, 30.0)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("12_reduced_motion_result")
	_record(game, panel, "reduced_motion")
	_write_proof()
	motion_policy.call("clear_test_override")
	router.return_to_floor()
	await get_tree().create_timer(0.3).timeout
	main._quit_game()


func _centi(game: Node) -> int:
	return (game.get("math") as CoreOverclockMath).multiplier_centi


## Starts a run whose crash point comes from `uniform`, through the cabinet, so
## the stake, the panel and the settlement are the shipped ones.
func _launch(game: Node, uniform: int) -> void:
	var math: CoreOverclockMath = game.get("math")
	game.current_stake = game.selected_stake
	game.is_round_active = true
	math.reset()
	math.begin_from(game.current_stake, uniform)
	game.panel.begin_run()
	await get_tree().process_frame


func _record(game: Node, panel: CoreOverclockPanel, label: String) -> void:
	var math: CoreOverclockMath = game.get("math")
	(
		_proof
		. append(
			{
				"label": label,
				"uniform": math.value,
				"crash_centi": math.crash_centi,
				"crash": CoreOverclockMath.multiplier_text(math.crash_centi),
				"settled_centi": math.settled_centi,
				"auto_centi": math.auto_centi,
				"state": math.state,
				"dial_reads": CoreOverclockMath.multiplier_text(panel.gauge.centi),
				"matches": panel.gauge.centi == math.multiplier_centi,
			}
		)
	)


func _write_proof() -> void:
	var file := FileAccess.open(
		_output.path_join("core_overclock_motion_proof.json"), FileAccess.WRITE
	)
	file.store_string(JSON.stringify(_proof, "\t") + "\n")
	print("CORSAIR PROOF ", _proof)


func _wait_until(condition: Callable, timeout_seconds: float = 12.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			push_warning("Corsair capture timed out waiting")
			return
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
