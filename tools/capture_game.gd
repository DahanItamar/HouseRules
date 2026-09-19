extends Node
## Captures actual rendered UI; save and lock paths are isolated from player data.

const OUTPUT := "res://tests/results/screenshots"
var _output := OUTPUT
var _requested_size := Vector2i.ZERO
var _reduced_motion := false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = OUTPUT.path_join(argument.trim_prefix("--capture-dir="))
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument == "--reduced-motion":
			_reduced_motion = true
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
	var motion_policy: Node = scene_root.get_node("MotionPolicy")
	motion_policy.call("set_reduced_motion_for_tests", _reduced_motion)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(20260918)
	main._refresh_hud()
	await get_tree().create_timer(0.16).timeout
	await _snapshot("01_menu_motion_a")
	await get_tree().create_timer(0.39).timeout
	await get_tree().create_timer(0.55).timeout
	await _snapshot("01_menu")
	main._start_playing()
	await get_tree().create_timer(0.55).timeout
	await _snapshot("02_floor_motion_a")
	await get_tree().create_timer(0.80).timeout
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
	main._floor.open_marker_desk()
	await get_tree().create_timer(0.25).timeout
	await _snapshot("02_cashier_menu")
	await get_tree().create_timer(0.35).timeout
	await _snapshot("02_cashier_idle_a")
	await get_tree().create_timer(0.30).timeout
	await _snapshot("02_cashier_idle_b")
	main._floor._cashier_repay_amount = 10
	main._floor._confirm_cashier_repayment()
	await get_tree().create_timer(0.10).timeout
	await _snapshot("02_cashier_transaction")
	await get_tree().create_timer(0.55).timeout
	await _snapshot("02_cashier_settled")
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
	# Overlay motion is captured on a real cabinet so evidence includes the
	# composition it blocks and the focusable content a player actually sees.
	slot_panel.set_help_open(true)
	await _snapshot("03_help_reveal_start")
	await get_tree().create_timer(0.08).timeout
	await _snapshot("03_help_reveal_mid")
	await get_tree().create_timer(0.16).timeout
	await _snapshot("03_help_open")
	slot_panel.set_help_open(false)
	await get_tree().create_timer(0.07).timeout
	await _snapshot("03_help_dismiss_mid")
	await get_tree().create_timer(0.10).timeout
	await _snapshot("03_help_dismissed")
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
	await _snapshot("04_exit_reveal_start")
	await get_tree().create_timer(0.08).timeout
	await _snapshot("04_exit_reveal_mid")
	await get_tree().create_timer(0.14).timeout
	await _snapshot("04_exit_confirmation")
	slot_game.exit_confirmation.cancel()
	await get_tree().create_timer(0.06).timeout
	await _snapshot("04_exit_cancel_mid")
	await get_tree().create_timer(0.09).timeout
	await _snapshot("04_exit_cancelled")
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
	# A second live wager proves the destructive confirmation route all the way
	# back to the floor. This is isolated from the settled outcome above.
	assert(slot_game.start_round(10), "Exit-confirmation proof round must start")
	slot_game.exit_confirmation.present(10)
	await get_tree().create_timer(0.20).timeout
	await _snapshot("04_exit_confirm_ready")
	slot_game.exit_confirmation.confirm_leave()
	await get_tree().create_timer(0.55).timeout
	await _snapshot("04_exit_confirmed_floor")
	router.enter_cabinet(load("res://data/cabinets/blackjack.tres"))
	await get_tree().create_timer(0.55).timeout
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.start_round(10)
	await _snapshot("05_blackjack_deal_start")
	await get_tree().create_timer(0.24).timeout
	await _snapshot("05_blackjack_deal_mid")
	await get_tree().create_timer(0.7).timeout
	await _snapshot("05_blackjack")
	# Exercise the same live-hand reflow path used by Hit without changing the
	# deterministic round. Restore the authoritative hand before the real Stand.
	var blackjack_game: Node = router.session.cabinet
	var blackjack_panel: CabinetPanel = blackjack_game.panel
	var blackjack_math: BlackjackMath = blackjack_game.get("math")
	var authoritative_player: Array[int] = blackjack_math.player.duplicate()
	var authoritative_dealer: Array[int] = blackjack_math.dealer.duplicate()
	var hit_fixture: Array[int] = authoritative_player.duplicate()
	hit_fixture.append(1)
	blackjack_panel._render_blackjack_hand(hit_fixture, authoritative_dealer, true)
	await _snapshot("05_blackjack_hit_start")
	await get_tree().create_timer(0.10).timeout
	await _snapshot("05_blackjack_hit_mid")
	await get_tree().create_timer(0.42).timeout
	blackjack_panel._clear_blackjack_cards()
	blackjack_panel._blackjack_dealt = false
	blackjack_panel._render_blackjack_hand(authoritative_player, authoritative_dealer, true)
	await get_tree().create_timer(0.55).timeout
	assert(router.session.cabinet.request_stand(), "Deterministic blackjack stand must resolve")
	await _snapshot("05_blackjack_reveal_start")
	await get_tree().create_timer(0.18).timeout
	await _snapshot("05_blackjack_reveal_mid")
	await get_tree().create_timer(0.72).timeout
	await _snapshot("05_blackjack_result")
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
	vault_game.get("snap_cursor").set("index", safe_index)
	assert(vault_game.call("request_open"), "Deterministic safe vault reveal must start")
	await _snapshot("06_vault_reveal_start")
	await get_tree().create_timer(0.12).timeout
	await _snapshot("06_vault_reveal_mid")
	await get_tree().create_timer(0.38).timeout
	await _snapshot("06_vault_reveal")
	var mine_index: int = (vault_math.get("mines") as Array)[0]
	vault_game.get("snap_cursor").set("index", mine_index)
	assert(vault_game.call("request_open"), "Deterministic vault hazard reveal must start")
	await _snapshot("06_vault_hazard_start")
	await get_tree().create_timer(0.10).timeout
	await _snapshot("06_vault_hazard_warning")
	await get_tree().create_timer(0.09).timeout
	await _snapshot("06_vault_hazard_impact")
	await get_tree().create_timer(0.35).timeout
	await _snapshot("06_vault_hazard_result")
	_write_motion_proof()
	router.return_to_floor()
	motion_policy.call("clear_test_override")
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


func _write_motion_proof() -> void:
	var proof := {
		"seed": 20260918,
		"reduced_motion": _reduced_motion,
		"sequences": {
			"menu": ["01_menu_motion_a.png", "01_menu.png"],
			"floor_practical_lights": ["02_floor_motion_a.png", "02_floor.png"],
			"help_reveal": ["03_help_reveal_start.png", "03_help_reveal_mid.png"],
			"help_dismiss": ["03_help_open.png", "03_help_dismiss_mid.png"],
			"exit_reveal": ["04_exit_reveal_start.png", "04_exit_reveal_mid.png"],
			"exit_cancel": ["04_exit_confirmation.png", "04_exit_cancel_mid.png"],
			"exit_confirm": ["04_exit_confirm_ready.png", "04_exit_confirmed_floor.png"],
			"cashier": [
				"02_cashier_menu.png",
				"02_cashier_transaction.png",
				"02_cashier_settled.png",
			],
			"blackjack_deal": [
				"05_blackjack_deal_start.png",
				"05_blackjack_deal_mid.png",
				"05_blackjack.png",
			],
			"blackjack_hit": [
				"05_blackjack_hit_start.png",
				"05_blackjack_hit_mid.png",
			],
			"blackjack_reveal": [
				"05_blackjack_reveal_start.png",
				"05_blackjack_reveal_mid.png",
				"05_blackjack_result.png",
			],
			"vault_reveal": [
				"06_vault_reveal_start.png",
				"06_vault_reveal_mid.png",
				"06_vault_reveal.png",
			],
			"vault_hazard": [
				"06_vault_hazard_warning.png",
				"06_vault_hazard_impact.png",
				"06_vault_hazard_result.png",
			],
		},
	}
	var file := FileAccess.open(_output.path_join("motion_proof.json"), FileAccess.WRITE)
	assert(file != null, "Motion proof write failed")
	file.store_string(JSON.stringify(proof, "\t") + "\n")
	print("MOTION PROOF ", proof)
