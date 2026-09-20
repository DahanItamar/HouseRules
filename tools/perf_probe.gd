extends Node
## Performance probe: walks the floor and visits every cabinet, logging frame
## time, draw calls and video memory. Run windowed:
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/perf_probe.tscn --
##     --capture-size=1920x1080 [--no-ambience]
##
## `--no-ambience` frees the floor and cabinet ambient layers right after they
## are built, which gives the "before" half of an A/B measurement of ambient life
## without having to check out an older revision of the scripts.

const AMBIENCE_NODE := "FloorAmbience"

var _samples: Array[float] = []
var _phase := ""
var _ambience := true


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var dims := argument.trim_prefix("--capture-size=").split("x")
			get_window().mode = Window.MODE_WINDOWED
			get_window().size = Vector2i(int(dims[0]), int(dims[1]))
		elif argument == "--no-ambience":
			_ambience = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _process(delta: float) -> void:
	if not _phase.is_empty():
		_samples.append(delta * 1000.0)


func _run() -> void:
	var root := get_tree().root
	var saves: Node = root.get_node("SaveService")
	var isolated := "user://perf_probe"
	DirAccess.make_dir_recursive_absolute(isolated)
	saves.platform = LocalPlatform.new(isolated)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	main._guard._lock_path = isolated.path_join("instance.lock")
	root.add_child(main)
	saves.new_game(1)
	Engine.max_fps = 0
	main._start_playing()
	await get_tree().create_timer(1.0).timeout
	var floor: FloorController = main._floor
	_strip_floor_ambience(floor)
	await _measure("floor_idle", 2.0)
	_phase = "floor_walk"
	_samples.clear()
	var elapsed := 0.0
	while elapsed < 3.0:
		var dt := get_process_delta_time()
		floor.move_avatar(Vector2(cos(elapsed * 1.3), sin(elapsed * 1.7)).normalized(), dt)
		elapsed += dt
		await get_tree().process_frame
	_report()
	for room_id: StringName in [&"high_roller", &"vip", &"manager_office"]:
		floor.enter_room(room_id)
		await _measure("room_%s" % room_id, 1.5)
		floor.return_to_main_floor()
	var router: Node = root.get_node("SceneRouter")
	for id: String in [
		"slot_classic",
		"blackjack",
		"minefield_vault",
		"roulette",
		"poker",
		"baccarat",
		"match_point"
	]:
		router.enter_cabinet(load("res://data/cabinets/%s.tres" % id))
		await get_tree().create_timer(0.8).timeout
		_strip_cabinet_ambience(root)
		await _measure("cabinet_%s" % id, 2.0)
		router.return_to_floor()
		await get_tree().create_timer(0.8).timeout
	main._quit_game()


## Drops the room ambience node so the floor renders exactly as it did before
## ambient life existed. The node rebuilds itself per room, so every room change
## has to be stripped again.
func _strip_floor_ambience(floor: FloorController) -> void:
	if _ambience or floor == null:
		return
	if not floor.room_changed.is_connected(_on_room_changed):
		floor.room_changed.connect(_on_room_changed.bind(floor))
	var ambience := floor.get_node_or_null(AMBIENCE_NODE)
	if ambience != null:
		ambience.queue_free()


func _on_room_changed(_room_id: StringName, floor: FloorController) -> void:
	_strip_floor_ambience(floor)


func _strip_cabinet_ambience(root: Node) -> void:
	if _ambience:
		return
	for layer: Node in root.find_children(CabinetAmbience.NODE_NAME, "", true, false):
		layer.queue_free()


func _measure(label: String, seconds: float) -> void:
	_phase = label
	_samples.clear()
	await get_tree().create_timer(seconds).timeout
	_report()


func _report() -> void:
	var sorted := _samples.duplicate()
	sorted.sort()
	var avg := 0.0
	for s: float in sorted:
		avg += s
	avg /= maxf(sorted.size(), 1)
	var p95: float = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0
	print(
		(
			"PERF %-26s frames=%4d avg=%6.2fms p95=%6.2fms max=%6.2fms draws=%d vram=%dMB tex=%dMB"
			% [
				_phase,
				sorted.size(),
				avg,
				p95,
				sorted.back() if not sorted.is_empty() else 0.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			]
		)
	)
	_phase = ""
