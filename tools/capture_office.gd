extends Node
## Manager's Office QA: renders the Main Floor door, the office, foreground
## coverage at reception, the desk and the entrance, the contracts board, the
## Manager's marker dialogue and desk, a wing invitation and every step of the
## secretary's tour, then writes a JSON report.
##
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_office.tscn
##     -- --capture-dir=office_fhd --capture-size=1920x1080 [--reduced-motion]

const OUTPUT := "res://tests/results/screenshots"

var _output := OUTPUT
var _requested_size := Vector2i.ZERO
var _reduced_motion := false
var _report: Dictionary = {"shots": {}}
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
	var wallet: Node = scene_root.get_node("Wallet")
	var economy: Node = scene_root.get_node("Economy")
	scene_root.get_node("MotionPolicy").call("set_reduced_motion_for_tests", _reduced_motion)
	DirAccess.make_dir_recursive_absolute(_output)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	_main = load("res://src/ui/main.tscn").instantiate()
	_main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(_main)
	wallet.call("set_test_mode", false)
	saves.new_game(20260918)
	_main._start_playing()
	await get_tree().create_timer(0.9).timeout
	_floor = _main._floor
	_floor.set_physics_process(false)
	_office = _floor.office_host()

	# The secretary's first-run tour, one screenshot per step.
	await _place(Vector2(480, 408))
	_office.begin_first_run_tutorial()
	await _tour_shot("welcome")
	_office.dialogue.choice_selected.emit(&"tutorial_next")
	await _tour_shot("move")
	for _step: int in range(3):
		_floor.move_avatar(Vector2(-1, -0.4), 0.25)
	await _tour_shot("inlay")
	await _place(_floor.cabinet_positions[&"slot_classic"])
	await _tour_shot("join")
	_floor._unhandled_input(_action(&"secondary"))
	await _tour_shot("cashier")
	for step: String in ["contracts", "manager", "help"]:
		_office.dialogue.choice_selected.emit(&"tutorial_next")
		await _tour_shot(step)
	_office.dialogue.choice_selected.emit(&"tutorial_next")
	_report.tutorial_state = saves.state.tutorial_state

	# The office door on the Main Floor.
	await _place(_floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR))
	await _snapshot("01_main_floor_office_door")
	await _place(Vector2(872, 236))
	await _snapshot("02_main_floor_beside_door_wall")
	_floor.toggle_collision_overlay(true)
	await _snapshot("03_main_floor_door_collision")
	_floor.toggle_collision_overlay(false)

	# The office itself.
	await _place(_floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR))
	_floor.interact()
	await get_tree().create_timer(0.4).timeout
	_report.office = {
		"room": String(_floor.room.id),
		"spawn": [_floor.avatar_position.x, _floor.avatar_position.y],
		"avatar_scale": _floor._avatar_visual.scale.x,
	}
	await _snapshot("04_office_overview")
	_floor.toggle_collision_overlay(true)
	await _snapshot("05_office_collision")
	_floor.toggle_collision_overlay(false)
	await _place(Vector2(322, 468))
	await _snapshot("06_office_behind_entrance_plant")
	await _place(Vector2(858, 118))
	await _snapshot("07_office_behind_back_plant")
	await _place(Vector2(100, 440))
	await _snapshot("07b_office_behind_left_railing")
	await _place(_floor.room.anchor(&"reception"))
	await _snapshot("08_office_near_reception")
	await _place(_floor.room.anchor(&"manager"))
	await _snapshot("09_office_near_desk")
	await _place(Vector2(640, 220))
	await _snapshot("10_office_beside_desk_rug")

	# Reception: the House Contracts board with progress and a completion. The
	# completion toast is allowed to finish before the office frames.
	economy.active_contracts[0] = {"id": &"slot_rounds", "progress": 24}
	economy.active_contracts[1].progress = 2
	economy.record_round(&"slot_classic", _slot_loss())
	await get_tree().create_timer(3.8).timeout
	await _place(_floor.room.anchor(&"reception"))
	_floor.interact()
	await _settled_snapshot("11_reception_dialogue")
	_office.dialogue.choice_selected.emit(&"contracts")
	await _snapshot("12_contracts_board")
	_office.board.close()

	# The Manager: markers, then a formal invitation.
	wallet.call("reset", 10)
	await _place(_floor.room.anchor(&"manager"))
	_floor.interact()
	await _settled_snapshot("13_manager_dialogue")
	_office.dialogue.choice_selected.emit(&"markers")
	await get_tree().create_timer(0.9).timeout
	await _snapshot("14_marker_desk")
	_floor._cashier_marker.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	await _snapshot("15_marker_taken")
	_floor._close_cashier()
	await get_tree().create_timer(0.3).timeout
	economy.lifetime_wagered = FloorController.WING_THRESHOLDS[FloorController.HIGH_ROLLER]
	_floor.refresh_proximity()
	_floor.interact()
	await _settled_snapshot("16_manager_invitation_line")
	_office.dialogue.choice_selected.emit(&"invitation")
	await _snapshot("17_invitation_card")
	_office.invitation.accept_button().pressed.emit()
	await _settled_snapshot("18_manager_after_invitation")
	_report.invitations = saves.state.wing_invitations.duplicate()
	_office.end_conversation()

	# The cashier keeps the chip counter only.
	_floor.return_to_main_floor()
	await _place(FloorController.CASHIER_POSITION)
	_floor.interact()
	await get_tree().create_timer(0.9).timeout
	await _snapshot("19_cashier_chip_counter")
	_floor._close_cashier()
	await get_tree().create_timer(0.3).timeout

	var file := FileAccess.open(_output.path_join("office_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	print("OFFICE REPORT ", _report)
	scene_root.get_node("MotionPolicy").call("clear_test_override")
	_main._quit_game()


func _place(at: Vector2) -> void:
	_floor.avatar_position = at
	_floor._avatar_visual.position = at
	_floor._avatar_visual.call("set_motion", Vector2.UP * 0.5)
	_floor.refresh_proximity()
	await get_tree().create_timer(0.25).timeout


func _tour_shot(step: String) -> void:
	_report.shots["tour_" + step] = {
		"step": String(_office.tutorial.current_step_id()),
		"layout": String(_office.dialogue.layout_name),
		"panel": str(_office.dialogue.panel_rect()),
		"cameo": str(_office.dialogue.cameo_rect()),
		"cameo_side": String(_office.dialogue.cameo_side),
		"faces_text": _office.dialogue.speaker_faces_text(),
	}
	await _settled_snapshot("tour_%d_%s" % [TutorialDirector.index_of(StringName(step)), step])


func _settled_snapshot(label: String) -> void:
	await get_tree().create_timer(0.2).timeout
	_office.dialogue.finish_reveal()
	await get_tree().create_timer(0.3).timeout
	await _snapshot(label)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _slot_loss() -> RoundResult:
	return RoundResult.create(
		10,
		0,
		RoundResult.Outcome.LOSS,
		{
			"symbols":
			[
				SlotMachineMath.Symbol.CHERRY,
				SlotMachineMath.Symbol.LEMON,
				SlotMachineMath.Symbol.BELL
			]
		}
	)


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
