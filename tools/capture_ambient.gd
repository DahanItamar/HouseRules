extends Node
## Ambient-life capture: short frame runs of every floor room and a few cabinets,
## recorded in-engine at the real window size and downscaled for GIF assembly.
##
## Run at a fixed frame rate so every frame advances exactly 1/fps seconds:
##   Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 25
##       res://tools/capture_ambient.tscn -- --capture-size=1920x1080
##       --frames-dir=<absolute dir> [--frames=75] [--reduced-motion] [--stills]
##       [--targets=main_floor,vip,slot_classic] [--no-ambience]
##
## `--no-ambience` drops the ambient layers and captures the same runs without
## them, which isolates what ambient life actually adds to a frame.
## tools/art/assemble_ambient_gifs.py turns the frame folders into GIFs.

const OUTPUT := "res://tests/results/screenshots/ambient"
const ROOMS: Array[StringName] = [&"main_floor", &"high_roller", &"vip", &"manager_office"]
const CABINETS: Array[StringName] = [
	&"slot_classic",
	&"blackjack",
	&"minefield_vault",
	&"roulette",
	&"poker",
	&"baccarat",
	&"match_point",
]
## The Main Floor run walks past the lounge lamps so the contact shadow and the
## light pools can be judged together.
const WALK_START := Vector2(430, 404)
const WALK_DIRECTION := Vector2(-1.0, -0.25)

var _output := OUTPUT
var _frames_dir := ""
var _frame_count := 75
var _requested_size := Vector2i(1920, 1080)
var _reduced_motion := false
var _stills := false
var _targets: Array[StringName] = []
var _ambience := true


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument.begins_with("--frames-dir="):
			_frames_dir = argument.trim_prefix("--frames-dir=")
		elif argument.begins_with("--frames="):
			_frame_count = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--targets="):
			for target: String in argument.trim_prefix("--targets=").split(","):
				_targets.append(StringName(target))
		elif argument == "--reduced-motion":
			_reduced_motion = true
		elif argument == "--stills":
			_stills = true
		elif argument == "--no-ambience":
			_ambience = false
	if _targets.is_empty():
		_targets.append_array(ROOMS)
		_targets.append_array(CABINETS)
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
	scene_root.get_node("MotionPolicy").call("set_reduced_motion_for_tests", _reduced_motion)
	var isolated := "user://capture_ambient_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(20260918)
	main._start_playing()
	await _wait_frames(30)
	wallet.call("set_test_mode", true)
	var floor: FloorController = main._floor
	floor.set_physics_process(false)
	for target: StringName in _targets:
		if target in ROOMS:
			await _capture_room(floor, target)
	floor.enter_room(&"main_floor")
	floor.avatar_position = floor.room.spawn
	floor._avatar_visual.position = floor.avatar_position
	for target: StringName in _targets:
		if target in CABINETS:
			router.enter_cabinet(load("res://data/cabinets/%s.tres" % target))
			await _wait_frames(40)
			if not _ambience:
				for layer: Node in scene_root.find_children(
					CabinetAmbience.NODE_NAME, "", true, false
				):
					layer.free()
			await _record(String(target), Callable())
			router.return_to_floor()
			await _wait_frames(30)
	scene_root.get_node("MotionPolicy").call("clear_test_override")
	main._quit_game()


func _capture_room(floor: FloorController, room_id: StringName) -> void:
	floor.enter_room(room_id)
	await _wait_frames(20)
	var ambience: Node = floor.get_node_or_null("FloorAmbience")
	if not _ambience and ambience != null:
		ambience.free()
		ambience = null
	var step := Callable()
	if room_id == &"main_floor":
		floor.avatar_position = WALK_START
		floor._avatar_visual.position = WALK_START
		var delta := 1.0 / float(Engine.physics_ticks_per_second)
		step = func(_frame: int) -> void: floor.move_avatar(WALK_DIRECTION, delta * 2.0)
	# Start just before a brass glint so a sweep lands inside the short capture.
	if ambience != null and not _reduced_motion:
		ambience.set("elapsed", maxf(float(ambience.call("next_glint_time")) - 0.8, 0.0))
	await _record(String(room_id), step)


func _record(label: String, step: Callable) -> void:
	if _stills:
		await _snapshot(label)
	if _frames_dir.is_empty():
		return
	var folder := _frames_dir.path_join(label + ("_reduced" if _reduced_motion else ""))
	DirAccess.make_dir_recursive_absolute(folder)
	for frame: int in range(_frame_count):
		if step.is_valid():
			step.call(frame)
		await RenderingServer.frame_post_draw
		var image: Image = get_tree().root.get_texture().get_image()
		image.resize(960, 540, Image.INTERPOLATE_CUBIC)
		image.save_png(folder.path_join("%03d.png" % frame))
	print("FRAMES ", label, " ", _frame_count)


func _snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var suffix := "_reduced" if _reduced_motion else ""
	image.save_png(_output.path_join(label + suffix + ".png"))
	print("SCREENSHOT ", label, " ", image.get_size())


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
