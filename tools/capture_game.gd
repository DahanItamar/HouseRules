extends Node
## Captures actual rendered UI; save and lock paths are isolated from player data.

const OUTPUT := "res://tests/results/screenshots"
var _output := OUTPUT
var _requested_size := Vector2i.ZERO


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
	call_deferred("_capture")


func _capture() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	var router: Node = scene_root.get_node("SceneRouter")
	var wallet: Node = scene_root.get_node("Wallet")
	var economy: Node = scene_root.get_node("Economy")
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(20260918)
	main._refresh_hud()
	await get_tree().create_timer(0.55).timeout
	await _snapshot("01_menu")
	main._start_playing()
	await get_tree().create_timer(0.55).timeout
	await _snapshot("02_floor")
	wallet.call("set_test_mode", false)
	wallet.call("reset", 10)
	main._floor.avatar_position = Vector2(480, 360)
	main._floor._avatar_visual.position = main._floor.avatar_position
	main._floor.refresh_proximity()
	await _snapshot("02_cashier_waypoint")
	wallet.call("reset", 37)
	economy.set("debt", 25)
	main._floor.avatar_position = main._floor.CASHIER_POSITION
	main._floor._avatar_visual.position = main._floor.avatar_position
	main._floor.refresh_proximity()
	main._floor.interact()
	await get_tree().create_timer(0.25).timeout
	await _snapshot("02_cashier_menu")
	main._floor._close_cashier()
	await get_tree().create_timer(0.18).timeout
	wallet.call("set_test_mode", true)
	wallet.call("reset", 200)
	economy.set("debt", 0)
	main._floor.avatar_position = main._floor.cabinet_positions[&"slot_classic"]
	main._floor._avatar_visual.position = main._floor.avatar_position
	main._floor.refresh_proximity()
	await get_tree().create_timer(0.18).timeout
	await _snapshot("02_floor_join")
	router.enter_cabinet(load("res://data/cabinets/slot_classic.tres"))
	await get_tree().create_timer(0.55).timeout
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.panel.refresh()
	await _snapshot("03_slot_idle")
	var slot_game: Node = router.session.cabinet
	var slot_panel: CabinetPanel = slot_game.panel
	assert(slot_game.start_round(10), "Deterministic slot round must start")
	var expected_symbols: Array[int] = []
	for symbol: int in slot_panel._slot_spin_targets:
		expected_symbols.append(symbol)
	await _snapshot("04_slot_spin_start")
	await get_tree().create_timer(0.35).timeout
	await _snapshot("04_slot_spinning")
	await get_tree().create_timer(0.45).timeout
	await _snapshot("04_slot_spin_progress")
	slot_game.exit_confirmation.present(10)
	await _snapshot("04_exit_confirmation")
	slot_game.exit_confirmation.cancel()
	await _wait_for_slot_settle(slot_game, slot_panel)
	var observed_symbols := _slot_center_symbols(slot_panel)
	assert(
		observed_symbols == expected_symbols,
		"Settled reel symbols must match the evaluated outcome: expected %s, got %s"
		% [expected_symbols, observed_symbols]
	)
	# Earlier frames prove the number ticker is alive; the result frame must show
	# the authoritative final payout so visual QA never reads as contradictory.
	await get_tree().create_timer(0.85).timeout
	await _snapshot("04_slot_result")
	_write_slot_motion_proof(expected_symbols, observed_symbols)
	router.return_to_floor()
	await get_tree().create_timer(0.55).timeout
	router.enter_cabinet(load("res://data/cabinets/blackjack.tres"))
	await get_tree().create_timer(0.55).timeout
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.start_round(10)
	await get_tree().create_timer(0.7).timeout
	await _snapshot("05_blackjack")
	router.return_to_floor()
	await get_tree().create_timer(0.55).timeout
	router.enter_cabinet(load("res://data/cabinets/minefield_vault.tres"))
	await get_tree().create_timer(0.55).timeout
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.start_round(10)
	await _snapshot("06_vault")
	var vault_game: Node = router.session.cabinet
	var vault_math: RefCounted = vault_game.get("math")
	var safe_index: int = 0
	while safe_index in (vault_math.get("mines") as Array):
		safe_index += 1
	vault_math.call("reveal", safe_index)
	(vault_game.get("panel") as CanvasLayer).call("refresh")
	await get_tree().create_timer(0.3).timeout
	await _snapshot("06_vault_reveal")
	router.return_to_floor()
	main._quit_game()


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())


func _wait_for_slot_settle(game: Node, panel: CabinetPanel, timeout_seconds := 5.0) -> void:
	var deadline_msec := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while panel._slot_spinning or game.is_round_active:
		if Time.get_ticks_msec() >= deadline_msec:
			assert(false, "Slot did not settle within %.1f seconds" % timeout_seconds)
			return
		await get_tree().process_frame
	assert(panel._slot_stopped.all(func(stopped: bool) -> bool: return stopped))


func _slot_center_symbols(panel: CabinetPanel) -> Array[int]:
	var symbols: Array[int] = []
	for reel_cells: Array in panel._slot_reel_cells:
		var center: SlotSymbol = reel_cells[2]
		symbols.append(center.symbol_index)
	return symbols


func _write_slot_motion_proof(expected: Array[int], observed: Array[int]) -> void:
	var proof := {
		"seed": 20260918,
		"frames": [
			"04_slot_spin_start.png",
			"04_slot_spinning.png",
			"04_slot_spin_progress.png",
			"04_slot_result.png",
		],
		"expected_symbols": expected,
		"observed_symbols": observed,
		"outcome_matches_render": expected == observed,
	}
	var file := FileAccess.open(_output.path_join("04_slot_motion_proof.json"), FileAccess.WRITE)
	assert(file != null, "Slot motion proof write failed")
	file.store_string(JSON.stringify(proof, "\t") + "\n")
	print("SLOT MOTION PROOF ", proof)
