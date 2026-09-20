extends Node
## Walk-cycle QA: drives the player in all eight directions on the Main Floor.
##
## Writes into tests/results/screenshots/<capture-dir>/:
## - walk_sheet.png: columns N, NE, E, SE, S, SW, W, NW; rows are the eight
##   atlas phases of one gait cycle, starting at the heel contact on row 0.
## - loop_###.png: a square walk (right, down, left, up) around the spawn, one
##   frame per 1/30 s, for turning into walk_loop.gif.
## - closeup_###.png: each direction walked for one full cycle, cropped tight
##   around the avatar and upscaled 3x, one frame per 1/30 s, for
##   walk_rig_closeup.gif. closeup_index.txt lists the frame range per facing.
##
## Godot_v4.7.2-stable_win64_console.exe --path . res://tools/capture_walk.tscn
##     -- --capture-dir=walk_fhd --capture-size=1920x1080
##
## With --scale-check it instead stands the player beside painted adults in each
## room and writes scale_<spot>.png crops (add --legacy-scale for the old flat
## per-room scales, to compare before and after the depth calibration).

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
const NAMES: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
## Virtual-pixel box around the foot anchor that holds the whole figure.
const CROP := Rect2(-28, -86, 56, 108)
const SHEET_BEATS := 8
const CLOSEUP_SCALE := 3
const STEP_DELTA := 1.0 / 60.0
## Scale-check spots: room, player foot position, facing column, crop window.
const SCALE_SPOTS: Array[Dictionary] = [
	{
		"name": "office_manager",
		"room": &"manager_office",
		"at": Vector2(540, 240),
		"facing": 6,
		"window": Rect2(380, 0, 240, 270),
	},
	{
		"name": "main_cashier_guest",
		"room": &"main_floor",
		"at": Vector2(762, 470),
		"facing": 2,
		"window": Rect2(680, 340, 200, 160),
	},
	{
		"name": "main_lounge_waitress",
		"room": &"main_floor",
		"at": Vector2(236, 486),
		"facing": 6,
		"window": Rect2(130, 360, 180, 150),
	},
	{
		"name": "vip_bar_guest",
		"room": &"vip",
		"at": Vector2(840, 222),
		"facing": 2,
		"window": Rect2(760, 60, 180, 190),
	},
	{
		"name": "high_roller_receptionist",
		"room": &"high_roller",
		"at": Vector2(772, 206),
		"facing": 2,
		"window": Rect2(700, 60, 180, 170),
	},
]
## Room scales before the depth calibration.
const LEGACY_SCALES := {&"manager_office": 1.35}

var _output := OUTPUT
var _requested_size := Vector2i.ZERO
var _scale_check := false
var _legacy_scale := false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_output = OUTPUT.path_join(argument.trim_prefix("--capture-dir="))
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_requested_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
		elif argument == "--scale-check":
			_scale_check = true
		elif argument == "--legacy-scale":
			_legacy_scale = true
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
	if _scale_check:
		await _record_scale_check(floor)
	else:
		await _record_sheet(floor)
		await _record_loop(floor)
		await _record_closeup(floor)
	main._quit_game()


## Stands the idle player beside painted adults so their heights can be compared.
func _record_scale_check(floor: FloorController) -> void:
	for spot: Dictionary in SCALE_SPOTS:
		var room_id: StringName = spot["room"]
		if floor.room.id != room_id:
			floor.enter_room(room_id)
			await get_tree().create_timer(0.6).timeout
		if _legacy_scale:
			var legacy := float(LEGACY_SCALES.get(room_id, 1.0))
			floor.room.avatar_scale_far = legacy
			floor.room.avatar_scale_near = legacy
		var at: Vector2 = spot["at"]
		if not floor.room.is_walkable(at):
			push_warning("Scale spot %s is not walkable" % spot["name"])
		_place(floor, at)
		floor._apply_avatar_scale()
		var avatar: FloorAvatar = floor._avatar_visual
		avatar.is_walking = false
		avatar.facing_index = int(spot["facing"])
		avatar.display_index = avatar.facing_index
		avatar._update_region()
		for _frame: int in range(3):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var window: Rect2 = spot["window"]
		var suffix := "before" if _legacy_scale else "after"
		_frame_crop(Vector2.ZERO, window).save_png(
			_output.path_join("scale_%s_%s.png" % [spot["name"], suffix])
		)
		print(
			(
				"SCALE %s room=%s at=%s scale=%.3f height_px=%.1f"
				% [
					spot["name"],
					room_id,
					at,
					avatar.scale.x,
					200.0 * FloorAvatar.GUEST_SCALE * avatar.scale.x
				]
			)
		)


func _place(floor: FloorController, at: Vector2) -> void:
	floor.avatar_position = at
	floor._avatar_visual.position = at


func _frame_crop(center: Vector2, box: Rect2) -> Image:
	var frame: Image = get_tree().root.get_texture().get_image()
	var scale := float(frame.get_width()) / 960.0
	var region := Rect2i(Vector2i((center + box.position) * scale), Vector2i(box.size * scale))
	return frame.get_region(region)


## One sheet row per eighth of a cycle; the walker first takes a cycle and a
## bit to reach full stride, then each beat is captured at its exact phase.
func _record_sheet(floor: FloorController) -> void:
	var sheet: Image = null
	for column: int in range(DIRECTIONS.size()):
		var direction := DIRECTIONS[column].normalized()
		_place(floor, START - direction * 34.0)
		var avatar: FloorAvatar = floor._avatar_visual
		avatar.walk_cycles = 0.0
		await get_tree().process_frame
		for beat: int in range(SHEET_BEATS):
			# Absolute cycle count; land in the middle of the beat's atlas row.
			var target := 1.0 + (float(beat) + 0.5) / SHEET_BEATS
			while avatar.walk_cycles < target - 0.0001:
				var remaining := target - avatar.walk_cycles
				var screen := remaining * CharacterWalkAtlas.cycle_distance(direction)
				screen *= avatar.scale.x
				# Steps under 0.1 px are below the avatar's motion dead-zone.
				var delta := clampf(screen / FloorController.SPEED, 0.2 / FloorController.SPEED, STEP_DELTA)
				var before := floor.avatar_position
				floor.move_avatar(direction, delta)
				await get_tree().process_frame
				if floor.avatar_position.is_equal_approx(before):
					push_warning("Walk sheet blocked walking %s" % NAMES[column])
					break
			await RenderingServer.frame_post_draw
			var crop := _frame_crop(floor.avatar_position, CROP)
			if sheet == null:
				sheet = Image.create(
					crop.get_width() * DIRECTIONS.size(),
					crop.get_height() * SHEET_BEATS,
					false,
					crop.get_format()
				)
			var size := crop.get_size()
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, size), size * Vector2i(column, beat))
			print(
				(
					"WALK dir=%s beat=%d facing_index=%d frame=%d phase=%.3f"
					% [
						NAMES[column],
						beat,
						avatar.facing_index,
						avatar.walk_frame,
						avatar.walk_phase / TAU
					]
				)
			)
	var error := sheet.save_png(_output.path_join("walk_sheet.png"))
	assert(error == OK, "Walk sheet write failed")


## Records a short square walk (right, down, left, up) around the spawn as
## numbered frames of one fixed window, for turning into an animated preview.
func _record_loop(floor: FloorController) -> void:
	var window := Rect2(Vector2(-90, -110), Vector2(220, 170))
	_place(floor, START)
	var legs: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var index := 0
	for leg: Vector2 in legs:
		for step: int in range(40):
			floor.move_avatar(leg, STEP_DELTA)
			await get_tree().process_frame
			if step % 2 == 1:
				await RenderingServer.frame_post_draw
				_frame_crop(START, window).save_png(_output.path_join("loop_%03d.png" % index))
				index += 1


## Each facing walks one full cycle after a short run-up; the crop follows the
## avatar so the carpet slides under planted feet only if they slip.
func _record_closeup(floor: FloorController) -> void:
	var box := Rect2(-34, -84, 68, 106)
	var index := 0
	var ranges: PackedStringArray = []
	for column: int in range(DIRECTIONS.size()):
		var direction := DIRECTIONS[column].normalized()
		var start := START - direction * 40.0
		_place(floor, start)
		var avatar: FloorAvatar = floor._avatar_visual
		await get_tree().process_frame
		# Run-up to full stride, then capture exactly one cycle.
		for _step: int in range(10):
			floor.move_avatar(direction, STEP_DELTA)
			await get_tree().process_frame
		# Measured from the ground actually covered, not from the avatar's own
		# phase, so a slow capture frame cannot stretch or cut the clip.
		var cycle := CharacterWalkAtlas.cycle_distance(direction) * avatar.scale.x
		var travelled := 0.0
		var first := index
		var step := 0
		while travelled < cycle:
			var before := floor.avatar_position
			floor.move_avatar(direction, STEP_DELTA)
			await get_tree().process_frame
			var moved := floor.avatar_position.distance_to(before)
			if moved < 0.05:
				push_warning("Close-up blocked walking %s" % NAMES[column])
				break
			travelled += moved
			if step % 2 == 0:
				await RenderingServer.frame_post_draw
				var crop := _frame_crop(floor.avatar_position, box)
				crop.resize(
					crop.get_width() * CLOSEUP_SCALE,
					crop.get_height() * CLOSEUP_SCALE,
					Image.INTERPOLATE_LANCZOS
				)
				crop.save_png(_output.path_join("closeup_%03d.png" % index))
				index += 1
			step += 1
		ranges.append(
			"%s %d %d facing=%d" % [NAMES[column], first, index - 1, avatar.facing_index]
		)
	var file := FileAccess.open(_output.path_join("closeup_index.txt"), FileAccess.WRITE)
	file.store_string("\n".join(ranges) + "\n")
	file.close()
