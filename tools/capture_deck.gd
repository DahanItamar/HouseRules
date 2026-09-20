extends Node
## Captures the control-deck pilot (Blackjack), the input prompts and the help card
## in real rendering. Save and lock paths are isolated from player data.
##
##   godot --path . res://tools/capture_deck.tscn -- --capture-size=1920x1080
##       [--capture-dir=deck_pilot] [--phase=before] [--reduced-motion]
##
## Every Blackjack state is captured three times: keyboard keycaps, Xbox glyphs and
## PlayStation glyphs (the gamepad family is forced, no controller is needed).

const OUTPUT := "res://tests/results/screenshots"
const SEED := 20260918
const BLACKJACK_PATH := "res://data/cabinets/blackjack.tres"
const FAMILIES: Array[Dictionary] = [
	{"suffix": "kbd", "device": 0, "family": 0},
	{"suffix": "xbox", "device": 1, "family": 0},
	{"suffix": "ps", "device": 1, "family": 1},
]
var _output := OUTPUT.path_join("deck_pilot")
var _requested_size := Vector2i.ZERO
var _phase := "after"
var _reduced := false
var _router: Node
var _input: Node


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = OUTPUT.path_join(argument.trim_prefix("--capture-dir="))
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument.begins_with("--phase="):
			_phase = argument.trim_prefix("--phase=")
		elif argument == "--reduced-motion":
			_reduced = true
	if _requested_size.x > 0 and _requested_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().size = _requested_size
	DirAccess.make_dir_recursive_absolute(_output)
	get_tree().create_timer(240.0).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("_capture")


func _capture() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	_router = scene_root.get_node("SceneRouter")
	_input = scene_root.get_node("InputRouter")
	var wallet: Node = scene_root.get_node("Wallet")
	var motion_policy: Node = scene_root.get_node("MotionPolicy")
	motion_policy.call("set_reduced_motion_for_tests", _reduced)
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
	var prefix := "before_" if _phase == "before" else ""
	if _phase == "before":
		await _capture_before(main, wallet)
	elif _phase == "before_band":
		await _capture_rooms(main, "before_")
	else:
		await _capture_rooms(main, "")
		await _capture_floor(main, wallet)
		await _capture_blackjack(wallet)
		await _capture_help(wallet)
		await _capture_tutorial(main)
	print("DECK CAPTURE DONE ", prefix)
	motion_policy.call("clear_test_override")
	main._quit_game()


func _capture_before(main: Node, wallet: Node) -> void:
	wallet.call("set_test_mode", true)
	wallet.call("reset", 200)
	var floor_controller: Node = main._floor
	floor_controller.avatar_position = floor_controller.cabinet_positions[&"blackjack"]
	floor_controller._avatar_visual.position = floor_controller.avatar_position
	floor_controller.refresh_proximity()
	await get_tree().create_timer(0.4).timeout
	await _snapshot("before_floor_join")
	_router.enter_cabinet(load(BLACKJACK_PATH))
	await get_tree().create_timer(0.7).timeout
	var game: Node = _router.session.cabinet
	game.select_stake(50)
	await get_tree().create_timer(0.3).timeout
	await _snapshot("before_blackjack_idle")
	game.panel.set_help_open(true)
	await get_tree().create_timer(0.4).timeout
	await _snapshot("before_help_card")
	game.panel.set_help_open(false)
	await get_tree().create_timer(0.3).timeout
	assert(game.start_round(50))
	await get_tree().create_timer(1.0).timeout
	await _snapshot("before_blackjack_decision")
	game.request_stand()
	await get_tree().create_timer(1.6).timeout
	await _snapshot("before_blackjack_result")
	_router.return_to_floor()
	await get_tree().create_timer(0.4).timeout


## The Main Floor top edge and the Manager's Office, for the header-band check.
func _capture_rooms(main: Node, prefix: String) -> void:
	var floor_controller: Node = main._floor
	floor_controller.avatar_position = Vector2(480, 408)
	floor_controller._avatar_visual.position = floor_controller.avatar_position
	floor_controller.refresh_proximity()
	await get_tree().create_timer(0.5).timeout
	await _snapshot(prefix + "room_main_floor")
	floor_controller.enter_room(&"manager_office")
	await get_tree().create_timer(0.9).timeout
	await _snapshot(prefix + "room_manager_office")
	floor_controller.enter_room(&"high_roller")
	await get_tree().create_timer(0.9).timeout
	await _snapshot(prefix + "room_high_roller")
	floor_controller.enter_room(&"main_floor")
	await get_tree().create_timer(0.6).timeout


func _set_family(entry: Dictionary) -> void:
	if _input.has_method("force_prompt_family"):
		_input.call("force_prompt_family", int(entry.device), int(entry.family))
	await get_tree().create_timer(0.12).timeout


func _capture_floor(main: Node, wallet: Node) -> void:
	wallet.call("set_test_mode", true)
	wallet.call("reset", 200)
	var floor_controller: Node = main._floor
	floor_controller.avatar_position = floor_controller.cabinet_positions[&"blackjack"]
	floor_controller._avatar_visual.position = floor_controller.avatar_position
	floor_controller.refresh_proximity()
	await get_tree().create_timer(0.4).timeout
	for entry: Dictionary in FAMILIES:
		await _set_family(entry)
		await _snapshot("floor_join_%s" % entry.suffix)


func _capture_blackjack(wallet: Node) -> void:
	wallet.call("set_test_mode", true)
	wallet.call("reset", 200)
	_router.enter_cabinet(load(BLACKJACK_PATH))
	await get_tree().create_timer(0.7).timeout
	var game: Node = _router.session.cabinet
	var math: BlackjackMath = game.get("math")
	game.select_stake(50)
	await get_tree().create_timer(0.3).timeout
	for entry: Dictionary in FAMILIES:
		await _set_family(entry)
		await _snapshot("bj_01_betting_%s" % entry.suffix)
	# Hover the + stepper so the micro-interaction is visible in evidence.
	var rounds := 0
	var captured_decision := false
	var captured_drawing := false
	var captured_result := false
	while rounds < 8 and not (captured_decision and captured_drawing and captured_result):
		rounds += 1
		if not game.start_round(50):
			break
		await get_tree().create_timer(1.1).timeout
		if game.is_round_active and not game.is_result_pending and not captured_decision:
			for entry: Dictionary in FAMILIES:
				await _set_family(entry)
				await _snapshot("bj_02_decision_%s" % entry.suffix)
			captured_decision = true
		if game.is_round_active and not game.is_result_pending:
			game.request_stand()
			await get_tree().process_frame
			if game.is_result_pending and not captured_drawing:
				for entry: Dictionary in FAMILIES:
					_input.call("force_prompt_family", int(entry.device), int(entry.family))
					await _snapshot("bj_03_dealer_drawing_%s" % entry.suffix)
				captured_drawing = true
		await _until(func() -> bool: return not game.is_round_active, 6.0)
		await get_tree().create_timer(0.9).timeout
		var result: RoundResult = game.panel._result
		if result != null and not captured_result and result.payout > result.stake:
			for entry: Dictionary in FAMILIES:
				await _set_family(entry)
				await _snapshot("bj_04_result_win_%s" % entry.suffix)
			captured_result = true
		elif result != null and rounds >= 6 and not captured_result:
			for entry: Dictionary in FAMILIES:
				await _set_family(entry)
				await _snapshot("bj_04_result_%s" % entry.suffix)
			captured_result = true
	# A loss or push frame for the accent colours, whichever comes next.
	var extra := 0
	while extra < 6:
		extra += 1
		if not game.start_round(50):
			break
		await get_tree().create_timer(1.1).timeout
		if game.is_round_active and not game.is_result_pending:
			game.request_stand()
		await _until(func() -> bool: return not game.is_round_active, 6.0)
		await get_tree().create_timer(0.9).timeout
		var result: RoundResult = game.panel._result
		if result != null and result.payout < result.stake:
			await _set_family(FAMILIES[1])
			await _snapshot("bj_05_result_loss_xbox")
			break
	# Hover and focus micro-interaction on the stepper and primary action.
	await _set_family(FAMILIES[0])
	var bet: Control = game.panel.find_child("BetControl", true, false)
	if bet != null:
		var plus: Button = bet.find_child("BetStepUp", true, false)
		if plus != null:
			plus.mouse_entered.emit()
			await get_tree().create_timer(0.2).timeout
			await _snapshot("bj_06_hover_plus_kbd")
			plus.mouse_exited.emit()
	# No funds: the deck explains instead of greying an action out.
	wallet.call("set_test_mode", false)
	wallet.call("reset", 0)
	game.normalize_selected_stake()
	game.panel.refresh()
	await get_tree().create_timer(0.4).timeout
	await _snapshot("bj_07_no_funds_kbd")
	wallet.call("reset", 200)
	wallet.call("set_test_mode", true)
	game.normalize_selected_stake()
	game.panel.refresh()
	if math == null:
		return


func _capture_help(_wallet: Node) -> void:
	var game: Node = _router.session.cabinet
	await _set_family(FAMILIES[0])
	await get_tree().create_timer(0.2).timeout
	var help_button: Control = game.panel._help_button
	help_button.mouse_entered.emit()
	await get_tree().create_timer(0.2).timeout
	await _snapshot("help_button_hover_kbd")
	help_button.mouse_exited.emit()
	for entry: Dictionary in FAMILIES:
		await _set_family(entry)
		game.panel.set_help_open(true)
		await get_tree().create_timer(0.45).timeout
		await _snapshot("help_card_p1_%s" % entry.suffix)
		if game.panel.has_method("help_page_step"):
			game.panel.help_page_step(1)
			await get_tree().create_timer(0.3).timeout
			await _snapshot("help_card_p2_%s" % entry.suffix)
		game.panel.set_help_open(false)
		await get_tree().create_timer(0.3).timeout
	_router.return_to_floor()
	await get_tree().create_timer(0.5).timeout
	# The shared card on the other two cabinets that still use the legacy deck.
	for id: String in ["slot_classic", "minefield_vault", "roulette"]:
		_router.enter_cabinet(load("res://data/cabinets/%s.tres" % id))
		await get_tree().create_timer(0.8).timeout
		await _set_family(FAMILIES[1])
		var other: Node = _router.session.cabinet
		other.panel.set_help_open(true)
		await get_tree().create_timer(0.45).timeout
		await _snapshot("help_card_%s_xbox" % id)
		other.panel.set_help_open(false)
		await get_tree().create_timer(0.3).timeout
		await _snapshot("idle_%s_xbox" % id)
		_router.return_to_floor()
		await get_tree().create_timer(0.5).timeout


func _capture_tutorial(main: Node) -> void:
	var floor_controller: Node = main._floor
	var office: Node = floor_controller.office_host()
	if office == null:
		return
	floor_controller.avatar_position = Vector2(480, 408)
	floor_controller._avatar_visual.position = floor_controller.avatar_position
	floor_controller.refresh_proximity()
	var tutorial: Node = office.get("tutorial")
	tutorial.call("start", true)
	await get_tree().create_timer(0.3).timeout
	tutorial.call("advance")
	await get_tree().create_timer(1.6).timeout
	for entry: Dictionary in FAMILIES:
		await _set_family(entry)
		await get_tree().create_timer(0.2).timeout
		await _snapshot("tutorial_move_%s" % entry.suffix)
	tutorial.call("_show", 3)
	await get_tree().create_timer(2.2).timeout
	for entry: Dictionary in FAMILIES:
		await _set_family(entry)
		await _snapshot("tutorial_join_%s" % entry.suffix)
	tutorial.call("_show", 7)
	await get_tree().create_timer(2.2).timeout
	await _set_family(FAMILIES[2])
	await _snapshot("tutorial_help_ps")
	tutorial.call("skip")
	await get_tree().create_timer(0.3).timeout


func _until(condition: Callable, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
