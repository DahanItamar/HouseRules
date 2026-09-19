extends Node
## Walk-cycle QA: drives the player in all eight directions on the Main Floor and
## writes one crop per direction and leg phase, plus a combined sheet whose
## columns run N, NE, E, SE, S, SW, W, NW and whose rows are the four phases.
##
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_walk.tscn
##     -- --capture-dir=walk_fhd --capture-size=1920x1080

const OUTPUT := "res://tests/results/screenshots"
const START := Vector2(480, 380)
const DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2(1, -1),
	Vector2.RIGHT,
	Vector2(1, 1),
	Vector2.DOWN,
	Vector2(-1, 1),
	Vector2.LEFT,
	Vector2(-1, -1),
]
## Virtual-pixel box around the foot anchor that holds the whole figure.
const CROP := Rect2(-24, -80, 48, 88)

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
	var sheet: Image = null
	for column: int in range(DIRECTIONS.size()):
		floor.avatar_position = START
		floor._avatar_visual.position = START
		var avatar: FloorAvatar = floor._avatar_visual
		for phase: int in range(4):
			# Walk one quarter cycle so the next leg phase is showing.
			var walked := 0.0
			while walked < FloorAvatar.WALK_CYCLE_DISTANCE / 4.0:
				var before := floor.avatar_position
				floor.move_avatar(DIRECTIONS[column].normalized(), 1.0 / 60.0)
				walked += floor.avatar_position.distance_to(before)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = scene_root.get_texture().get_image()
			var scale := float(frame.get_width()) / 960.0
			var box := Rect2i(
				Vector2i((floor.avatar_position + CROP.position) * scale), Vector2i(CROP.size * scale)
			)
			var crop := frame.get_region(box)
			if sheet == null:
				sheet = Image.create(
					box.size.x * DIRECTIONS.size(), box.size.y * 4, false, crop.get_format()
				)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, box.size), box.size * Vector2i(column, phase))
			print(
				"WALK dir=%d phase=%d facing_index=%d flip=%s frame=%d"
				% [column, phase, avatar.facing_index, avatar._sprite.flip_h, avatar.walk_frame]
			)
	var error := sheet.save_png(_output.path_join("walk_sheet.png"))
	assert(error == OK, "Walk sheet write failed")
	await _record_loop(floor)
	main._quit_game()


## Records a short square walk (right, down, left, up) around the spawn as
## numbered frames of one fixed window, for turning into an animated preview.
func _record_loop(floor: FloorController) -> void:
	var window := Rect2(START + Vector2(-90, -110), Vector2(220, 170))
	floor.avatar_position = START
	floor._avatar_visual.position = START
	var legs: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var index := 0
	for leg: Vector2 in legs:
		for _step: int in range(40):
			floor.move_avatar(leg, 1.0 / 60.0)
			await get_tree().process_frame
			if _step % 2 == 1:
				await RenderingServer.frame_post_draw
				var frame: Image = get_tree().root.get_texture().get_image()
				var scale := float(frame.get_width()) / 960.0
				var box := Rect2i(Vector2i(window.position * scale), Vector2i(window.size * scale))
				frame.get_region(box).save_png(_output.path_join("loop_%03d.png" % index))
				index += 1
