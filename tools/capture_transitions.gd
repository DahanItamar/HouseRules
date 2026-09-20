extends Node
## Room-passage QA. Plays every themed passage (Grand Staircase, VIP lift and
## office door, in and back out) through the real floor and records each as
## numbered frames at a fixed frame rate, ready for tools/transition_gifs.py.
## With --perf it instead plays the same passages in real time and prints the
## frame-time profile of each one. Saves and the instance lock are isolated.
##
##   Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 25
##       res://tools/capture_transitions.tscn -- --capture-size=1920x1080
##       --frames-dir=<absolute scratch dir> [--reduced-motion]
##   Godot_v4.7.2-stable_win64_console.exe --path .
##       res://tools/capture_transitions.tscn -- --capture-size=1920x1080 --perf

const SEED := 20260919
## Matches the --fixed-fps the frames are recorded at.
const CAPTURE_FPS: float = 25.0
const PRE_ROLL: float = 0.4
const POST_ROLL: float = 0.5
## Each clip: where the avatar starts (near the entry, so the walk-in shows)
## and the room the passage starts from.
const CLIPS: Array[Dictionary] = [
	{"name": "stairs_up", "room": &"main_floor", "start": Vector2(184, 298)},
	{"name": "stairs_down", "room": &"high_roller", "start": Vector2(440, 512)},
	{"name": "lift_up", "room": &"main_floor", "start": Vector2(822, 252)},
	{"name": "lift_down", "room": &"vip", "start": Vector2(522, 352)},
	{"name": "office_in", "room": &"main_floor", "start": Vector2(836, 266)},
	{"name": "office_out", "room": &"manager_office", "start": Vector2(522, 524)},
]

var _frames_dir := ""
var _requested_size := Vector2i.ZERO
var _perf := false
var _reduced := false
var _deltas: Array[float] = []
var _sampling := false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--frames-dir="):
			_frames_dir = argument.trim_prefix("--frames-dir=")
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument == "--perf":
			_perf = true
		elif argument == "--reduced-motion":
			_reduced = true
	if _requested_size.x > 0 and _requested_size.y > 0:
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		get_window().size = _requested_size
	if _perf:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("_run")


func _process(delta: float) -> void:
	if _sampling:
		_deltas.append(delta * 1000.0)


func _run() -> void:
	var scene_root := get_tree().root
	var saves: Node = scene_root.get_node("SaveService")
	var motion_policy: Node = scene_root.get_node("MotionPolicy")
	motion_policy.call("set_reduced_motion_for_tests", _reduced)
	var isolated := "user://capture_transitions"
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	scene_root.add_child(main)
	saves.new_game(SEED)
	scene_root.get_node("Economy").lifetime_wagered = 200_000
	main._start_playing()
	await get_tree().create_timer(1.0).timeout
	var floor: FloorController = main._floor
	var transition := floor.room_transition()
	for clip: Dictionary in CLIPS:
		if floor.room.id != clip["room"]:
			floor.enter_room(clip["room"])
		floor.avatar_position = clip["start"]
		floor.move_avatar(Vector2.ZERO, 0.0)
		floor.refresh_proximity()
		await get_tree().create_timer(0.3).timeout
		if _perf:
			await _profile(String(clip["name"]), floor, transition)
		else:
			await _record(String(clip["name"]), floor, transition)
	motion_policy.call("clear_test_override")
	print("TRANSITION CAPTURE DONE")
	main._quit_game()


func _record(clip_name: String, floor: FloorController, transition: RoomTransition) -> void:
	var directory := _frames_dir.path_join(clip_name + ("_reduced" if _reduced else ""))
	DirAccess.make_dir_recursive_absolute(directory)
	var index := 0
	for _frame: int in range(roundi(PRE_ROLL * CAPTURE_FPS)):
		index = await _grab(directory, index)
	var began := index
	var confirmed := floor.interact()
	assert(confirmed, "%s: the entry must accept the confirm" % clip_name)
	while transition.is_active():
		index = await _grab(directory, index)
	var passage_frames := index - began
	for _frame: int in range(roundi(POST_ROLL * CAPTURE_FPS)):
		index = await _grab(directory, index)
	print(
		(
			"CLIP %-12s kind=%-9s frames=%3d passage_frames=%3d room=%s"
			% [clip_name, transition.kind, index, passage_frames, floor.room.id]
		)
	)


func _grab(directory: String, index: int) -> int:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join("frame_%03d.png" % index))
	return index + 1


func _profile(clip_name: String, floor: FloorController, transition: RoomTransition) -> void:
	_deltas.clear()
	_sampling = true
	var began := Time.get_ticks_usec()
	floor.interact()
	while transition.is_active():
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_usec() - began) / 1_000_000.0
	await get_tree().create_timer(0.3).timeout
	_sampling = false
	var sorted := _deltas.duplicate()
	sorted.sort()
	var average := 0.0
	for sample: float in sorted:
		average += sample
	average /= maxf(sorted.size(), 1)
	print(
		(
			"PERF %-12s kind=%-9s passage=%.2fs frames=%4d avg=%6.2fms p95=%6.2fms max=%6.2fms"
			% [
				clip_name,
				transition.kind,
				elapsed,
				sorted.size(),
				average,
				sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0,
				sorted.back() if not sorted.is_empty() else 0.0,
			]
		)
	)
