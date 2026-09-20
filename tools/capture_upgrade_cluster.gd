extends Node
## Captures the Harlequin Masquerade cabinet at real output size: the idle board,
## the guide, a bet placed, and then every phase of the sequential cascade
## timeline - the cluster pulse, the floating arithmetic, the shatter, the tumble
## - followed by a big, a super and a mega win, and a reduced-motion round.
##
##   godot --path . tools/capture_upgrade_cluster.tscn -- --capture-size=1920x1080
##
## Every captured round is a real round from the cabinet's own stream. To reach a
## rare tier the tool walks a copy of that stream forward until the shipped math
## produces one, then rewinds the cabinet's stream to just before it. Nothing is
## faked and no result is constructed by hand. Saves and the instance lock are
## isolated from the player's data.

const OUTPUT := "res://tests/results/screenshots/upgrade_cluster_fhd"
const STAKE: int = 10
## Attempts allowed when walking the stream for a tier. A mega win is about one
## round in ten thousand, so this is generous.
const SEEK_LIMIT: int = 600_000

var _output := OUTPUT
var _requested_size := Vector2i(1920, 1080)
var _proof: Array = []


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
	wallet.call("reset", 5000)
	router.enter_cabinet(load("res://data/cabinets/upgrade_cluster.tres"))
	await get_tree().create_timer(0.8).timeout
	var game: Node = router.session.cabinet
	var panel: UpgradeClusterPanel = game.panel
	await _snapshot("01_idle")
	panel.set_help_open(true)
	await get_tree().create_timer(0.4).timeout
	await _snapshot("02_help")
	panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	game.select_stake(STAKE)
	await get_tree().process_frame
	await _snapshot("03_bet_placed")

	# One ordinary winning round, captured phase by phase.
	_arm(router, 0.1)
	_play(game)
	await get_tree().create_timer(0.16).timeout
	await _snapshot("04_cluster_pulse")
	await _wait_until(func() -> bool: return panel.popup.visible)
	await get_tree().create_timer(0.22).timeout
	await _snapshot("05_floating_math")
	await _wait_until(func() -> bool: return not panel.popup.visible)
	await get_tree().create_timer(0.06).timeout
	await _snapshot("06_shatter")
	await get_tree().create_timer(0.22).timeout
	await _snapshot("07_tumble")
	await _wait_until(func() -> bool: return not game.is_round_active)
	await get_tree().create_timer(0.4).timeout
	await _snapshot("08_settled")

	for tier: Array in [
		[ClusterTheme.BIG_WIN_MULTIPLE, "09_big_win"],
		[ClusterTheme.SUPER_WIN_MULTIPLE, "10_super_win"],
		[ClusterTheme.MEGA_WIN_MULTIPLE, "11_mega_win"],
	]:
		var expected := _arm(router, float(tier[0]))
		_play(game)
		await _wait_until(func() -> bool: return panel.celebration.is_running(), 30.0)
		# Late in the count-up, so the banner shows the tier the win earned.
		await _wait_until(func() -> bool: return panel.celebration.shown_payout >= expected, 30.0)
		await get_tree().process_frame
		await _snapshot(String(tier[1]))
		(
			_proof
			. append(
				{
					"frame": tier[1],
					"payout": expected,
					"multiple": float(expected) / float(STAKE),
					"tier": panel.celebration.tier,
					"banner": panel.celebration.tier_text(),
				}
			)
		)
		await _wait_until(func() -> bool: return not game.is_round_active, 30.0)
		await get_tree().create_timer(0.3).timeout

	motion_policy.call("set_reduced_motion_for_tests", true)
	await get_tree().process_frame
	_arm(router, 0.1)
	_play(game)
	await get_tree().create_timer(0.12).timeout
	await _snapshot("12_reduced_motion")
	await _wait_until(func() -> bool: return not game.is_round_active, 30.0)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("13_reduced_motion_result")
	motion_policy.call("clear_test_override")
	_write_proof()
	router.return_to_floor()
	await get_tree().create_timer(0.3).timeout
	main._quit_game()


func _play(game: Node) -> void:
	var started: bool = game.call("request_play")
	assert(started, "Upgrade Cluster round must start")


## Rewinds the cabinet's stream to the next round whose payout reaches
## `minimum_multiple` of the stake, and returns that payout.
func _arm(router: Node, minimum_multiple: float) -> int:
	var rng: RandomNumberGenerator = router.session.context.rng
	var probe := RandomNumberGenerator.new()
	probe.seed = rng.seed
	probe.state = rng.state
	var math := UpgradeClusterMath.new()
	for _attempt: int in SEEK_LIMIT:
		var before := probe.state
		var result := math.play(STAKE, probe)
		if float(result.payout) / float(STAKE) >= minimum_multiple:
			rng.state = before
			return result.payout
	assert(false, "No round reached %.1fx in %d attempts" % [minimum_multiple, SEEK_LIMIT])
	return 0


func _wait_until(condition: Callable, timeout_seconds: float = 12.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			assert(false, "Upgrade Cluster capture timed out")
			return
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())


func _write_proof() -> void:
	var file := FileAccess.open(_output.path_join("upgrade_cluster_tiers.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"tiers": _proof}, "\t") + "\n")
	print("TIER PROOF ", JSON.stringify(_proof))
