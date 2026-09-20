extends GutTest
## Regression coverage for the layered floor: source resolution, alpha, depth
## ordering, destination walkability and collision boundaries in every room.

const EIGHT_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2(1, -1),
	Vector2.RIGHT,
	Vector2(1, 1),
	Vector2.DOWN,
	Vector2(-1, 1),
	Vector2.LEFT,
	Vector2(-1, -1),
]
## Points on each island's visible rug border (just outside, then just inside).
const MAIN_FLOOR_EDGE_SAMPLES: Array[Dictionary] = [
	{"outside": Vector2(334, 210), "inside": Vector2(334, 196), "name": "slot rug front"},
	{"outside": Vector2(504, 210), "inside": Vector2(504, 196), "name": "blackjack rug front"},
	{"outside": Vector2(680, 210), "inside": Vector2(680, 196), "name": "vault rug front"},
	{"outside": Vector2(240, 380), "inside": Vector2(205, 380), "name": "lounge dais edge"},
	{"outside": Vector2(480, 452), "inside": Vector2(480, 470), "name": "entrance planter"},
	{"outside": Vector2(672, 360), "inside": Vector2(700, 360), "name": "cashier rail"},
]

var _floor: FloorController


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_every_room_has_sharp_layered_masters() -> void:
	for room_id: StringName in FloorController.ROOM_IDS:
		var room := FloorRoomLayout.load_room(room_id)
		assert_eq(room.id, room_id)
		assert_false(room.label.is_empty(), "%s has a developer label" % room_id)
		if room.preview_only:
			assert_true(room.cabinets.is_empty(), "%s: a preview room lists no tables" % room_id)
		for cabinet_id: StringName in room.cabinets:
			assert_true(
				room.anchors.has(cabinet_id), "%s: %s has a join anchor" % [room_id, cabinet_id]
			)
		assert_eq(
			room.background().get_size(), Vector2(3840, 2160), "%s background is UHD" % room_id
		)
		assert_eq(
			room.foreground().get_size(), Vector2(3840, 2160), "%s foreground is UHD" % room_id
		)
		assert_gt(room.solids.size(), 3)
		assert_gt(room.occluders.size(), 3)


func test_rooms_are_distinct_destinations() -> void:
	var backgrounds: Dictionary = {}
	for room_id: StringName in FloorController.ROOM_IDS:
		backgrounds[FloorRoomLayout.load_room(room_id).background_path] = true
	assert_eq(backgrounds.size(), FloorController.ROOM_IDS.size())


func test_every_destination_is_walkable_and_reachable_from_spawn() -> void:
	for room_id: StringName in FloorController.ROOM_IDS:
		var room := FloorRoomLayout.load_room(room_id)
		var reachable := _reachable_cells(room)
		var destinations: Dictionary = room.anchors.duplicate()
		destinations[&"return_point"] = room.return_point
		for id: StringName in destinations:
			var at: Vector2 = destinations[id]
			assert_true(room.is_walkable(at), "%s %s is walkable" % [room_id, id])
			assert_true(_touches(reachable, at), "%s %s connects to spawn" % [room_id, id])


func test_main_floor_collision_follows_the_visible_edges() -> void:
	for sample: Dictionary in MAIN_FLOOR_EDGE_SAMPLES:
		assert_true(_floor._is_walkable(sample.outside), "Open carpet before the %s" % sample.name)
		assert_false(_floor._is_walkable(sample.inside), "Solid past the %s" % sample.name)


func test_all_eight_directions_move_and_diagonals_slide_along_edges() -> void:
	for direction: Vector2 in EIGHT_DIRECTIONS:
		_floor.avatar_position = Vector2(480, 330)
		_floor.move_avatar(direction, 0.1)
		assert_almost_eq(
			_floor.avatar_position.distance_to(Vector2(480, 330)), FloorController.SPEED * 0.1, 0.01
		)
	# Pressed diagonally into the Blackjack rug, the player keeps sliding sideways.
	_floor.avatar_position = Vector2(504, 212)
	for _frame: int in range(60):
		_floor.move_avatar(Vector2(1, -1), 1.0 / 60.0)
	assert_true(_floor._is_walkable(_floor.avatar_position))
	assert_gt(_floor.avatar_position.x, 530.0, "Diagonal input slides along the rug edge")


func test_high_frame_delta_never_tunnels_through_furniture() -> void:
	for start: Vector2 in [Vector2(334, 230), Vector2(504, 230), Vector2(680, 230)]:
		_floor.avatar_position = start
		for _hitch: int in range(20):
			_floor.move_avatar(Vector2.UP, 5.0)
		assert_true(_floor._is_walkable(_floor.avatar_position))
		assert_gte(_floor.avatar_position.y, 206.0, "No hitch reaches the island at %s" % start)


func test_foreground_draws_over_the_player_behind_an_object() -> void:
	var lamp := (_floor._floor_foreground as FloorForeground).piece("PlanterLampLeft")
	assert_not_null(lamp)
	_floor.avatar_position = Vector2(368, 440)
	_floor.move_avatar(Vector2.ZERO, 0.0)
	assert_lt(_floor._avatar_visual.position.y, lamp.position.y, "Feet above the baseline")
	# Y-sort draws the larger y later: the lamp front covers the player's legs.
	assert_true(_floor._depth_layer.y_sort_enabled)
	_floor.avatar_position = Vector2(368, 500)
	_floor.move_avatar(Vector2.ZERO, 0.0)
	assert_gt(_floor._avatar_visual.position.y, lamp.position.y, "In front below the baseline")


func test_foreground_layer_is_transparent_outside_object_fronts() -> void:
	for room_id: StringName in FloorController.ROOM_IDS:
		var room := FloorRoomLayout.load_room(room_id)
		var image := TexturePixels.readable(room.foreground())
		for anchor_id: StringName in room.anchors:
			var at := Vector2i(room.anchor(anchor_id) * 4.0)
			assert_eq(image.get_pixelv(at).a, 0.0, "%s %s carpet is clear" % [room_id, anchor_id])


func test_collision_overlay_is_debug_only_and_toggles() -> void:
	assert_true(OS.is_debug_build())
	assert_false(_floor.collision_overlay_visible())
	_floor.toggle_collision_overlay(true)
	assert_true(_floor.collision_overlay_visible())
	_floor.toggle_collision_overlay(false)
	assert_false(_floor.collision_overlay_visible())


func test_unlocked_wings_open_their_rooms_and_locked_ones_stay_shut() -> void:
	var was_test_mode := Wallet.test_mode_enabled
	var wagered := Economy.lifetime_wagered
	Wallet.set_test_mode(false)
	Economy.lifetime_wagered = 0
	_floor.avatar_position = FloorController.WING_POSITIONS[FloorController.VIP]
	_floor.refresh_proximity()
	assert_false(_floor.interact(), "The VIP elevator stays locked below its threshold")
	Economy.lifetime_wagered = FloorController.WING_THRESHOLDS[FloorController.VIP]
	_floor.refresh_proximity()
	assert_true(_floor.interact(), "Reaching the threshold opens the VIP elevator")
	assert_eq(_floor.room.id, FloorController.VIP)
	Economy.lifetime_wagered = wagered
	Wallet.set_test_mode(was_test_mode)


func test_hud_panels_leave_the_floor_play_area_clear() -> void:
	# HUD plaques stay in the back-wall strip above every island and entrance.
	for room_id: StringName in FloorController.ROOM_IDS:
		var room := FloorRoomLayout.load_room(room_id)
		for anchor_id: StringName in room.anchors:
			assert_gt(room.anchor(anchor_id).y, FloorController.HUD_BAND_HEIGHT)


func test_hud_plates_are_opaque_and_nothing_darkens_the_full_width_header() -> void:
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	for plate: Panel in [main._bank_panel, main._message_panel]:
		var style := plate.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.bg_color.a, 1.0, "%s carries its own opaque surface" % plate.name)
	var bank: Rect2 = main._bank_panel.get_rect()
	assert_true(Rect2(48, 27, 864, 486).encloses(bank), "The bank plate sits inside TV-safe")
	assert_lte(bank.end.y, DialoguePanel.LAYOUTS[1].panel.position.y, "It clears the dialogue lane")
	var back_style := _floor._room_back.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(back_style.bg_color.a, 1.0, "The room Back plate is opaque")
	# No full-width dark strip across the top of a room or a cabinet: the painted
	# back wall (and the people in it) is never cut by a header band.
	var header_band := RegEx.create_from_string(
		"draw_rect\\(\\s*Rect2\\(\\s*0\\s*,\\s*0\\s*,\\s*(960|size\\.x)\\s*,(?!\\s*(540|size\\.y))"
	)
	for path: String in [
		"res://src/floor/floor_controller.gd",
		"res://src/ui/casino_lighting.gd",
		"res://src/ui/main.gd",
		"res://src/ui/cabinet_panel.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_null(header_band.search(source), "%s draws no full-width header band" % path)


func _reachable_cells(room: FloorRoomLayout) -> Dictionary:
	var start := _cell(room.spawn)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if seen.has(next) or next.x < 0 or next.y < 0 or next.x > 240 or next.y > 135:
				continue
			if room.is_walkable(Vector2(next) * 4.0):
				seen[next] = true
				queue.append(next)
	return seen


func _touches(reachable: Dictionary, point: Vector2) -> bool:
	var base := Vector2i(floori(point.x / 4.0), floori(point.y / 4.0))
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if reachable.has(base + offset):
			return true
	return false


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x / 4.0), roundi(point.y / 4.0))
