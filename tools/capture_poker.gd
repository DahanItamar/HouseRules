extends Node
## Captures the Hold'em table in real rendering; save/lock paths are isolated.
##
##   godot --path . res://tools/capture_poker.tscn -- --capture-size=1920x1080
##
## Frames land in tests/results/screenshots/poker_fhd/ (or --capture-dir=NAME):
## idle, deal, preflop decision, flop, an NPC raise, showdown, result, the help
## card, the live-hand exit confirmation and a reduced-motion hand.

const OUTPUT := "res://tests/results/screenshots"
const SEED := 20260918
var _output := OUTPUT.path_join("poker_fhd")
var _requested_size := Vector2i.ZERO
var _router: Node
var _game: Node
var _panel: PokerTablePanel
var _captured: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = OUTPUT.path_join(argument.trim_prefix("--capture-dir="))
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if _requested_size.x > 0 and _requested_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().size = _requested_size
	DirAccess.make_dir_recursive_absolute(_output)
	# Watchdog: a stuck capture must never hang the pipeline.
	get_tree().create_timer(180.0).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("_capture")


func _capture() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	_router = scene_root.get_node("SceneRouter")
	var wallet: Node = scene_root.get_node("Wallet")
	var motion_policy: Node = scene_root.get_node("MotionPolicy")
	motion_policy.call("set_reduced_motion_for_tests", false)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(SEED)
	main._refresh_hud()
	main._start_playing()
	await get_tree().create_timer(0.6).timeout
	wallet.call("set_test_mode", false)
	wallet.call("reset", 2000)
	_router.enter_cabinet(load("res://data/cabinets/poker.tres"))
	await get_tree().create_timer(0.7).timeout
	_game = _router.session.cabinet
	_panel = _game.panel as PokerTablePanel
	_game.select_stake(10)
	await _snapshot("01_idle")
	# Full-motion hands: call down until every beat has been captured.
	var hands := 0
	while (
		hands < 12
		and not _has_all(
			["03_preflop_decision", "04_flop", "05_npc_raise", "06_showdown", "07_result"]
		)
	):
		hands += 1
		await _play_hand(hands == 1)
	# Help card and live-hand exit confirmation on a fresh hand.
	assert(_game.start_round(10))
	await _until(func() -> bool: return _game.input_ready(), 8.0)
	_panel.set_help_open(true)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("08_help")
	_panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	_game.exit_confirmation.present(_game.current_stake)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("09_exit_confirmation")
	_game.exit_confirmation.cancel()
	await get_tree().create_timer(0.2).timeout
	while _game.is_round_active:
		await _until(func() -> bool: return _game.input_ready() or not _game.is_round_active, 8.0)
		if _game.input_ready() and not _game.request_fold():
			_game.request_primary()
		await get_tree().process_frame
	await _until(func() -> bool: return not _game.is_result_pending, 10.0)
	await get_tree().create_timer(0.5).timeout
	# Reduced motion: instant deals and reveals, short NPC thinking.
	motion_policy.call("set_reduced_motion_for_tests", true)
	await get_tree().create_timer(0.2).timeout
	assert(_game.start_round(10))
	await get_tree().create_timer(0.05).timeout
	await _snapshot("10_reduced_deal")
	await _until(func() -> bool: return _game.input_ready(), 8.0)
	await _snapshot("11_reduced_decision")
	while _game.is_round_active:
		await _until(func() -> bool: return _game.input_ready() or not _game.is_round_active, 8.0)
		if _game.input_ready():
			_game.request_primary()
		await get_tree().process_frame
	await _until(func() -> bool: return not _game.is_result_pending, 10.0)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("12_reduced_result")
	motion_policy.call("clear_test_override")
	print("POKER CAPTURE DONE ", _captured.keys())
	_router.return_to_floor()
	await get_tree().create_timer(0.3).timeout
	main._quit_game()


func _play_hand(first: bool) -> void:
	assert(_game.start_round(10), "Poker hand must start")
	if first:
		await get_tree().create_timer(0.72).timeout
		await _snapshot("02_deal")
	var math: PokerMath = _game.math
	while _game.is_round_active or _game.is_result_pending:
		# Watch every presented event for the beats we want.
		var shown := _panel._cursor - 1
		if shown >= 0 and shown < math.events.size():
			var event: Dictionary = math.events[shown]
			if (
				not _captured.has("05_npc_raise")
				and event.type == &"action"
				and int(event.seat) != 0
				and int(event.action) in [PokerMath.Action.BET, PokerMath.Action.RAISE]
			):
				await get_tree().create_timer(0.12).timeout
				await _snapshot("05_npc_raise")
			elif not _captured.has("06_showdown") and event.type == &"award":
				var had_showdown := false
				for earlier: Dictionary in math.events:
					if earlier.type == &"showdown":
						had_showdown = true
				if had_showdown and not bool(math.folded[0]):
					await get_tree().create_timer(0.5).timeout
					await _snapshot("06_showdown")
		if _game.input_ready():
			if not _captured.has("03_preflop_decision") and math.street == PokerMath.Street.PREFLOP:
				await get_tree().create_timer(0.2).timeout
				await _snapshot("03_preflop_decision")
			elif not _captured.has("04_flop") and math.street == PokerMath.Street.FLOP:
				await get_tree().create_timer(0.35).timeout
				await _snapshot("04_flop")
			_game.request_primary()
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	if not _captured.has("07_result") and _game.math.last_result != null:
		if bool(_game.math.last_result.detail.get("showdown", false)):
			await _snapshot("07_result")
	await get_tree().create_timer(0.2).timeout


func _has_all(labels: Array) -> bool:
	for label: String in labels:
		if not _captured.has(label):
			return false
	return true


func _until(predicate: Callable, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	_captured[label] = true
	print("SCREENSHOT ", label, " ", image.get_size())
