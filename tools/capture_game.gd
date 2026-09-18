extends SceneTree
## Captures actual rendered UI; save and lock paths are isolated from player data.

const OUTPUT := "res://tests/results/screenshots"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var saves: Node = root.get_node("SaveService")
	var router: Node = root.get_node("SceneRouter")
	var isolated := OUTPUT.path_join("session_" + str(OS.get_process_id()))
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
	await _snapshot("05_blackjack")
	router.return_to_floor()
	router.enter_cabinet(load("res://data/cabinets/minefield_vault.tres"))
	router.session.cabinet.selected_stake = 10
	router.session.cabinet.start_round(10)
	await _snapshot("06_vault")
	router.return_to_floor()
	main._quit_game()


func _snapshot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(OUTPUT.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
