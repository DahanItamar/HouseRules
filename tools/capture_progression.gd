extends Node
## House standing QA: the floor HUD plate at several rungs, a rung being
## reached, the Manager's compact bars at three standings, the contracts board,
## the ledger's two views and the deed.
##
## The rig writes cabinet records and a lifetime-wagered total straight into an
## isolated profile, because the alternative is grinding a million rounds for a
## screenshot. Every number shown is still read back through the same code the
## game uses; nothing is drawn from a made-up figure.
##
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_progression.tscn
##     -- --capture-dir=progression --capture-size=1920x1080

const OUTPUT := "res://tests/results/screenshots"
## Cabinet records a mid-game profile plausibly holds, used for the ledger.
const SAMPLE_STATS: Dictionary = {
	"slot_classic": {"rounds": "412", "wagered": "8240", "returned": "7864", "best_win": "1500"},
	"blackjack": {"rounds": "168", "wagered": "8400", "returned": "8520", "best_win": "600"},
	"minefield_vault": {"rounds": "96", "wagered": "4800", "returned": "4210", "best_win": "2400"},
	"roulette": {"rounds": "54", "wagered": "2700", "returned": "2180", "best_win": "1750"},
}

var _output := OUTPUT
var _requested_size := Vector2i.ZERO
var _main: Node
var _floor: FloorController
var _office: OfficeHost


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
	scene_root.get_node("MotionPolicy").call("set_reduced_motion_for_tests", false)
	DirAccess.make_dir_recursive_absolute(_output)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	_main = load("res://src/ui/main.tscn").instantiate()
	_main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(_main)
	saves.new_game(20260920)
	for cabinet_id: String in SAMPLE_STATS:
		SaveService.state.cabinet_stats[cabinet_id] = CabinetStats.from_dict(
			SAMPLE_STATS[cabinet_id]
		)
	SaveService.state.longest_win_streak = 7
	SaveService.state.played_seconds = 12_480.0
	Progression.apply_state(SaveService.state)
	Wallet.reset(400_000)
	_main._start_playing()
	await get_tree().create_timer(1.2).timeout
	_floor = _main._floor
	_office = _floor.office_host()

	await _capture_hud()
	await _capture_office()
	get_tree().quit()


## The floor plate at four standings, then a rung being reached.
func _capture_hud() -> void:
	var labels: Array[String] = ["guest", "regular", "high_roller", "whale"]
	for index: int in range(labels.size()):
		_set_standing(int(HouseLevel.TIERS[index].target) + _midpoint(index), false)
		await get_tree().create_timer(0.5).timeout
		await _snapshot("0%d_hud_%s" % [index + 1, labels[index]])
	_set_standing(int(HouseLevel.TIERS[2].target) - 200, false)
	await get_tree().create_timer(0.3).timeout
	_set_standing(int(HouseLevel.TIERS[2].target), true)
	await get_tree().create_timer(0.5).timeout
	await _snapshot("05_hud_new_rung_high_roller")
	await get_tree().create_timer(3.4).timeout


## Everything in the Manager's Office: the secretary's board, the ledger's two
## views, the Manager's bars at three standings, and the deed.
func _capture_office() -> void:
	var actions := DevActions.new()
	add_child(actions)
	await actions.go_to_destination(FloorController.OFFICE, &"reception")
	await get_tree().create_timer(0.8).timeout
	_floor.interact()
	await get_tree().create_timer(0.6).timeout
	await _snapshot("06_reception_choices")
	_office.open_contracts_board()
	await get_tree().create_timer(0.6).timeout
	await _snapshot("07_contracts_board_bars")
	_office.board.close()
	_office.open_ledger(StatsPanel.View.OVERVIEW)
	await get_tree().create_timer(0.6).timeout
	await _snapshot("08_ledger_overview")
	_office.ledger.select_view(StatsPanel.View.CABINETS)
	await get_tree().create_timer(0.5).timeout
	await _snapshot("09_ledger_cabinets")
	_office.ledger.close()
	_office.end_conversation()
	await get_tree().create_timer(0.4).timeout

	await actions.go_to_destination(FloorController.OFFICE, &"manager")
	var standings: Array[Dictionary] = [
		{"label": "regular", "wagered": 2_400},
		{"label": "whale", "wagered": 320_000},
		{"label": "owner", "wagered": HouseLevel.OWNERSHIP_TARGET},
	]
	for index: int in range(standings.size()):
		_set_standing(int(standings[index].wagered), false)
		_office.end_conversation()
		await get_tree().create_timer(0.3).timeout
		_floor.interact()
		await _clear_invitations()
		await get_tree().create_timer(1.4).timeout
		await _snapshot("1%d_manager_standing_%s" % [index, standings[index].label])
	# The deed: the Manager sells, and the card states what was actually paid.
	_office.dialogue.choice_selected.emit(&"deed")
	await get_tree().create_timer(1.0).timeout
	await _snapshot("13_deed_bought")
	_office.deed.close()
	await get_tree().create_timer(0.6).timeout
	await _snapshot("14_manager_after_the_deed")
	_office.open_ledger(StatsPanel.View.OVERVIEW)
	await get_tree().create_timer(0.6).timeout
	await _snapshot("15_ledger_owner")
	_office.ledger.close()


## A standing that jumps past a wing threshold makes the Manager offer that
## wing's invitation first. The rig accepts them so the standing board, which
## is what these shots are for, is the panel on screen.
func _clear_invitations() -> void:
	for attempt: int in range(4):
		await get_tree().create_timer(0.5).timeout
		if _office.invitation.is_open():
			_office.invitation.accept_button().pressed.emit()
			continue
		if _office.dialogue.is_open() and _office.dialogue._choice_ids.has(&"invitation"):
			_office.dialogue.choice_selected.emit(&"invitation")
			continue
		return


## Partway up a rung, so a captured bar is never empty or full by accident.
func _midpoint(index: int) -> int:
	if index + 1 >= HouseLevel.TIERS.size():
		return 0
	return int((int(HouseLevel.TIERS[index + 1].target) - int(HouseLevel.TIERS[index].target)) / 3)


func _set_standing(wagered: int, announce: bool) -> void:
	Economy.lifetime_wagered = wagered
	Progression.refresh_standing(announce)


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
