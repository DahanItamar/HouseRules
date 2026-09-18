extends SceneTree
## Captures actual rendered UI; save and lock paths are isolated from player data.

const OUTPUT := "res://tests/results/screenshots"
var _output := OUTPUT


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = OUTPUT.path_join(argument.trim_prefix("--capture-dir="))
	call_deferred("_capture")


func _capture() -> void:
	var saves: Node = root.get_node("SaveService")
	var router: Node = root.get_node("SceneRouter")
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	root.add_child(main)
	saves.new_game(20260918)
	main._refresh_hud()
	await _snapshot("01_menu")
	main._start_playing()
	await _snapshot("02_floor")
	router.enter_cabinet(load("res://data/cabinets/slot_classic.tres"))
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.panel.refresh()
	await _snapshot("03_slot_idle")
	router.session.cabinet.start_round(10)
	await create_timer(0.35).timeout
	await _snapshot("04_slot_spinning")
	router.session.cabinet.resolve_pending()
	await _snapshot("04_slot_result")
	router.return_to_floor()
	router.enter_cabinet(load("res://data/cabinets/blackjack.tres"))
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.start_round(10)
	await create_timer(0.7).timeout
	await _snapshot("05_blackjack")
	router.return_to_floor()
	router.enter_cabinet(load("res://data/cabinets/minefield_vault.tres"))
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
	await create_timer(0.3).timeout
	await _snapshot("06_vault_reveal")
	router.return_to_floor()
	main._quit_game()


func _snapshot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
