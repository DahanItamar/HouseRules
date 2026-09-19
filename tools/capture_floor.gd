extends Node
## Floor composition QA: renders the player around every major furniture group,
## the collision overlay and each room, then writes a JSON report.
##
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_floor.tscn
##     -- --capture-dir=floor_fhd --capture-size=1920x1080 [--reduced-motion]

const OUTPUT := "res://tests/results/screenshots"
## Foot positions chosen on walkable carpet next to each object's visible edge.
const STATIONS: Array[Dictionary] = [
	{"name": "spawn", "position": Vector2(480, 408)},
	{"name": "slot_rug_front", "position": Vector2(334, 212)},
	{"name": "blackjack_rug_front", "position": Vector2(504, 212)},
	{"name": "vault_rug_front", "position": Vector2(680, 212)},
	{"name": "elevator_plant_behind", "position": Vector2(792, 148)},
	{"name": "vip_entrance", "position": Vector2(862, 216)},
	{"name": "cashier_above", "position": Vector2(860, 274)},
	{"name": "cashier_left", "position": Vector2(668, 402)},
	{"name": "cashier_below_ropes", "position": Vector2(840, 516)},
	{"name": "planter_above_lamp", "position": Vector2(368, 456)},
	{"name": "planter_above_foliage", "position": Vector2(470, 456)},
	{"name": "planter_left", "position": Vector2(262, 480)},
	{"name": "lounge_right", "position": Vector2(232, 440)},
	{"name": "staircase_below", "position": Vector2(150, 274)},
]

var _output := OUTPUT
var _requested_size := Vector2i.ZERO
var _reduced_motion := false
var _report: Dictionary = {"stations": {}, "rooms": {}}


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
	scene_root.get_node("MotionPolicy").call("set_reduced_motion_for_tests", _reduced_motion)
	var isolated := _output.path_join("session_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(20260918)
	main._start_playing()
	await get_tree().create_timer(0.9).timeout
	var floor: FloorController = main._floor
	floor.set_physics_process(false)
	for station: Dictionary in STATIONS:
		var at: Vector2 = station.position
		floor.avatar_position = at
		floor._avatar_visual.position = at
		floor._avatar_visual.call("set_motion", Vector2.UP * 0.5)
		floor.refresh_proximity()
		_report.stations[station.name] = {
			"position": [at.x, at.y],
			"walkable": floor._is_walkable(at),
			"clearance": snappedf(floor.room.clearance(at), 0.01),
		}
		await _snapshot("floor_%s" % station.name)
	floor.avatar_position = Vector2(480, 408)
	floor._avatar_visual.position = floor.avatar_position
	floor.refresh_proximity()
	floor.toggle_collision_overlay(true)
	await _snapshot("floor_collision_overlay")
	floor.toggle_collision_overlay(false)
	for room_id: StringName in [&"high_roller", &"vip"]:
		floor.enter_room(room_id)
		await get_tree().create_timer(0.3).timeout
		await _snapshot("room_%s" % room_id)
		floor.toggle_collision_overlay(true)
		await _snapshot("room_%s_collision" % room_id)
		floor.toggle_collision_overlay(false)
		_report.rooms[room_id] = {
			"label": floor.room.label,
			"preview_only": floor.room.preview_only,
			"spawn_walkable": floor._is_walkable(floor.room.spawn),
			"room_hud_visible": floor._room_layer.visible,
		}
		floor.return_to_main_floor()
		await get_tree().create_timer(0.2).timeout
		_report.rooms[room_id]["returned_to"] = String(floor.room.id)
		_report.rooms[room_id]["return_position"] = [
			floor.avatar_position.x, floor.avatar_position.y
		]
	await _snapshot("floor_after_rooms")
	var file := FileAccess.open(_output.path_join("floor_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	print("FLOOR REPORT ", _report)
	scene_root.get_node("MotionPolicy").call("clear_test_override")
	main._quit_game()


func _snapshot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(label + ".png"))
	assert(error == OK, "Screenshot write failed")
	print("SCREENSHOT ", label, " ", image.get_size())
