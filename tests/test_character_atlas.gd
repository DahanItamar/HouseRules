extends GutTest
## The player's full-body walk atlas and the avatar that plays it.
##
## The atlas is eight authored facings across by eight phases of one filmed walk
## cycle down (tools/art/build_player_walk_video.py). Nothing is mirrored at
## runtime and no leg is drawn procedurally, so these tests check the sheet
## itself -- integer cells, transparent gutters, real alpha, a distinct pose per
## phase, a face that looks where the walker is going -- and then that the avatar
## reads it from the distance actually walked.

const WalkAtlas := preload("res://src/floor/character_walk_atlas.gd")
const FACINGS: Array[Vector2] = [
	Vector2.UP,
	Vector2(1, -1),
	Vector2.RIGHT,
	Vector2(1, 1),
	Vector2.DOWN,
	Vector2(-1, 1),
	Vector2.LEFT,
	Vector2(-1, -1),
]

var _atlas_image: Image


func before_all() -> void:
	_atlas_image = TexturePixels.readable(load(WalkAtlas.ATLAS_PATH))


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func _cell(direction: int, phase: int) -> Image:
	return _atlas_image.get_region(Rect2i(WalkAtlas.region(direction, phase)))


func test_atlas_uses_exact_integer_cells_with_transparent_gutters() -> void:
	assert_eq(
		_atlas_image.get_size(),
		WalkAtlas.CELL_SIZE * Vector2i(WalkAtlas.COLUMNS, WalkAtlas.ROWS),
		"Eight facings across, eight phases down, at exactly the cell size"
	)
	assert_eq(WalkAtlas.CELL_SIZE.x, WalkAtlas.CONTENT_SIZE.x + WalkAtlas.GUTTER.x * 2)
	assert_eq(WalkAtlas.CELL_SIZE.y, WalkAtlas.CONTENT_SIZE.y + WalkAtlas.GUTTER.y * 2)
	for direction: int in range(WalkAtlas.COLUMNS):
		for phase: int in range(WalkAtlas.ROWS):
			var cell := _cell(direction, phase)
			var gutter_is_clear := true
			for offset: int in range(WalkAtlas.CELL_SIZE.x):
				for edge: Vector2i in [
					Vector2i(offset, 0),
					Vector2i(offset, WalkAtlas.CELL_SIZE.y - 1),
					Vector2i(0, offset),
					Vector2i(WalkAtlas.CELL_SIZE.x - 1, offset),
				]:
					gutter_is_clear = gutter_is_clear and is_zero_approx(cell.get_pixelv(edge).a)
			assert_true(
				gutter_is_clear, "Facing %d phase %d is isolated by alpha" % [direction, phase]
			)


func test_every_phase_of_every_facing_is_a_distinct_pose() -> void:
	# A duplicated row would read as a hitch in the gait; a duplicated column
	# would mean a facing never got its own art.
	var seen: Dictionary = {}
	for direction: int in range(WalkAtlas.COLUMNS):
		for phase: int in range(WalkAtlas.ROWS):
			var fingerprint := _cell(direction, phase).get_data().hex_encode()
			assert_false(
				seen.has(fingerprint),
				"Facing %d phase %d repeats %s" % [direction, phase, seen.get(fingerprint, "")]
			)
			seen[fingerprint] = "facing %d phase %d" % [direction, phase]


func test_each_phase_stands_on_the_foot_line_inside_the_cell() -> void:
	for direction: int in range(WalkAtlas.COLUMNS):
		for phase: int in range(WalkAtlas.ROWS):
			var bounds := _figure_bounds(_cell(direction, phase))
			assert_between(
				bounds.end.y,
				WalkAtlas.FOOT_LINE - 14.0,
				WalkAtlas.FOOT_LINE,
				"Facing %d phase %d keeps its soles on the foot line" % [direction, phase]
			)
			assert_between(
				bounds.size.y,
				180.0,
				205.0,
				"Facing %d phase %d is one adult tall" % [direction, phase]
			)
			assert_gte(bounds.position.x, float(WalkAtlas.GUTTER.x))
			assert_lte(bounds.end.x, float(WalkAtlas.CELL_SIZE.x - WalkAtlas.GUTTER.x))


func test_the_cycle_alternates_legs_with_contacts_and_passing_beats() -> void:
	# Phases 0 and 4 are heel contacts, where the feet are farthest apart;
	# phases 2 and 6 are passing beats, where they are closest. A cycle that
	# opened and closed once would be a limp, not a walk.
	for direction: int in range(WalkAtlas.COLUMNS):
		var spread: Array[float] = []
		var widest := 0
		var narrowest := 0
		for phase: int in range(WalkAtlas.ROWS):
			spread.append(_foot_spread(_cell(direction, phase)))
			if spread[phase] > spread[widest]:
				widest = phase
			if spread[phase] < spread[narrowest]:
				narrowest = phase
		assert_true(widest in [0, 4], "Facing %d is widest at a contact" % direction)
		assert_true(narrowest in [2, 6], "Facing %d is narrowest at a passing" % direction)
		assert_gt(spread[0], spread[2], "Facing %d opens then closes its legs" % direction)
		assert_gt(
			(spread[0] + spread[4]) * 0.5,
			(spread[2] + spread[6]) * 0.5 * 1.1,
			"Facing %d parts the feet at both contacts, not once a cycle" % direction
		)


func test_the_idle_frame_is_a_passing_beat() -> void:
	assert_true(
		WalkAtlas.IDLE_ROW in [2, 6], "Standing still shows a passing beat, feet under the body"
	)


func test_alpha_is_anti_aliased_and_carries_no_grey_matte() -> void:
	for direction: int in range(WalkAtlas.COLUMNS):
		var cell := _cell(direction, 0)
		var partial := 0
		var matte := 0
		for y: int in range(cell.get_height()):
			for x: int in range(cell.get_width()):
				var pixel := cell.get_pixel(x, y)
				if pixel.a <= 0.02 or pixel.a >= 0.98:
					continue
				partial += 1
				# The plate was flat mid grey; a surviving matte shows up as a
				# desaturated mid tone along the silhouette.
				var spread: float = (
					maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b))
				)
				var value := (pixel.r + pixel.g + pixel.b) / 3.0
				if spread < 0.05 and value > 0.39 and value < 0.75:
					matte += 1
		assert_gt(partial, 200, "Facing %d has a soft, real alpha edge" % direction)
		assert_lt(
			float(matte) / float(partial),
			0.12,
			"Facing %d keeps no flat grey matte around the figure" % direction
		)


func test_direction_mapping_preserves_all_eight_compass_facings() -> void:
	for index: int in range(FACINGS.size()):
		assert_eq(WalkAtlas.direction_index(FACINGS[index]), index)
		assert_eq(WalkAtlas.direction_index(WalkAtlas.direction_vector(index)), index)
		for phase: int in range(WalkAtlas.ROWS):
			var region := WalkAtlas.region(index, phase)
			assert_eq(int(region.position.x), index * WalkAtlas.CELL_SIZE.x)
			assert_eq(int(region.position.y), phase * WalkAtlas.CELL_SIZE.y)
		assert_false(WalkAtlas.is_mirrored(index), "Every facing has its own column")


func test_rendered_face_turns_toward_the_direction_of_travel() -> void:
	# A walker moving screen-right must show his face right of his head's
	# centre; moving screen-left, left of it. This catches a moonwalking map.
	for index: int in [1, 2, 3]:
		assert_gt(_face_offset(_cell(index, 0), index), 1.0, "Facing %d looks right" % index)
	for index: int in [5, 6, 7]:
		assert_lt(_face_offset(_cell(index, 0), index), -1.0, "Facing %d looks left" % index)


## Mean x of skin pixels minus mean x of the head silhouette, in the top 26
## rows of the figure as drawn for this facing.
func _face_offset(frame: Image, _index: int) -> float:
	var top := -1
	for y: int in range(frame.get_height()):
		for x: int in range(frame.get_width()):
			if frame.get_pixel(x, y).a > 0.5:
				top = y
				break
		if top >= 0:
			break
	var head_sum := 0.0
	var head_count := 0
	var skin_sum := 0.0
	var skin_count := 0
	for y: int in range(top, top + 26):
		for x: int in range(frame.get_width()):
			var pixel := frame.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			head_sum += x
			head_count += 1
			if pixel.r8 > 150 and pixel.g8 > 100 and pixel.r8 - pixel.b8 > 40:
				skin_sum += x
				skin_count += 1
	return skin_sum / maxf(skin_count, 1) - head_sum / maxf(head_count, 1)


func _figure_bounds(frame: Image) -> Rect2:
	var left := frame.get_width()
	var right := -1
	var top := frame.get_height()
	var bottom := -1
	for y: int in range(frame.get_height()):
		for x: int in range(frame.get_width()):
			if frame.get_pixel(x, y).a <= 0.5:
				continue
			left = mini(left, x)
			right = maxi(right, x)
			top = mini(top, y)
			bottom = maxi(bottom, y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


## Width of the figure across its lower legs and shoes, where a stride shows.
func _foot_spread(frame: Image) -> float:
	var bounds := _figure_bounds(frame)
	var from := int(bounds.position.y + bounds.size.y * 0.84)
	var left := frame.get_width()
	var right := -1
	for y: int in range(from, int(bounds.end.y) + 1):
		for x: int in range(frame.get_width()):
			if frame.get_pixel(x, y).a <= 0.5:
				continue
			left = mini(left, x)
			right = maxi(right, x)
	return float(right - left)


func _avatar() -> FloorAvatar:
	var avatar := FloorAvatar.new()
	add_child_autofree(avatar)
	return avatar


## Walks the avatar like FloorController does: move the node, then report the
## displacement.
func _walk(avatar: FloorAvatar, step: Vector2) -> void:
	avatar.position += step
	avatar.set_motion(step)


func test_facing_selects_the_matching_atlas_column() -> void:
	var avatar := _avatar()
	for index: int in range(FACINGS.size()):
		_walk(avatar, FACINGS[index].normalized() * 5.0)
		assert_eq(avatar.facing_index, index)
		assert_eq(avatar._atlas.region.position.x, float(index * WalkAtlas.CELL_SIZE.x))
		assert_false(avatar._sprite.flip_h, "Nothing is mirrored at runtime")


func test_one_cycle_of_walking_shows_all_eight_phases_in_order() -> void:
	var avatar := _avatar()
	var step := Vector2.RIGHT * (WalkAtlas.CYCLE_DISTANCE / 64.0)
	_walk(avatar, step)
	var order: Array[int] = []
	var travelled := 0.0
	while travelled < WalkAtlas.CYCLE_DISTANCE:
		_walk(avatar, step)
		travelled += step.length()
		if order.is_empty() or order.back() != avatar.walk_frame:
			order.append(avatar.walk_frame)
	var seen: Dictionary = {}
	for frame: int in order:
		seen[frame] = true
	assert_eq(seen.size(), WalkAtlas.ROWS, "One cycle steps through every atlas phase")
	assert_eq(WalkAtlas.ROWS, 8, "The cycle is authored in eight phases")
	for index: int in range(1, order.size()):
		assert_eq(
			order[index],
			posmod(order[index - 1] + 1, WalkAtlas.ROWS),
			"Phases advance one at a time, never skipping or reversing"
		)


func test_the_frame_comes_from_distance_walked_not_from_time() -> void:
	var coarse := _avatar()
	var fine := _avatar()
	for _step: int in range(9):
		_walk(coarse, Vector2(4.0, 0.0))
	for _step: int in range(36):
		_walk(fine, Vector2(1.0, 0.0))
	assert_almost_eq(coarse.walk_cycles, fine.walk_cycles, 0.0001)
	assert_eq(coarse.walk_frame, fine.walk_frame, "Same ground covered, same pose")
	# A long frame and a short one covering the same ground land on the same
	# phase: nothing here is driven by elapsed time.
	coarse._process(0.03)
	fine._process(0.004)
	_walk(coarse, Vector2(6.0, 0.0))
	for _step: int in range(6):
		_walk(fine, Vector2(1.0, 0.0))
	assert_eq(coarse.walk_frame, fine.walk_frame)


func test_a_full_cycle_covers_two_strides_at_the_drawn_size() -> void:
	# The soles only stay planted if a cycle advances the avatar by the stride
	# the art actually draws: two steps of the east contact frames.
	# How far the feet open between a passing beat and the next contact is the
	# step the art draws; a cycle is two of them.
	var stride := _foot_spread(_cell(2, 0)) - _foot_spread(_cell(2, 2))
	var expected := 2.0 * stride * FloorAvatar.GUEST_SCALE
	assert_almost_eq(
		WalkAtlas.CYCLE_DISTANCE, expected, expected * 0.12, "One cycle walks two drawn strides"
	)


func test_cadence_stays_in_a_natural_walking_band() -> void:
	var cycles_per_second := FloorController.SPEED / WalkAtlas.CYCLE_DISTANCE
	assert_between(cycles_per_second, 1.6, 2.2, "Roughly two steps a second, not a scurry")


func test_idle_returns_to_the_standing_frame_and_breathes() -> void:
	var avatar := _avatar()
	for _step: int in range(12):
		_walk(avatar, Vector2(2.0, 0.4))
	avatar._process(0.5)
	assert_false(avatar.is_walking)
	assert_eq(avatar.walk_frame, WalkAtlas.IDLE_ROW, "Standing still shows the neutral frame")
	assert_eq(avatar._atlas.region.position.y, float(WalkAtlas.IDLE_ROW * WalkAtlas.CELL_SIZE.y))
	var resting := avatar._sprite.scale.y
	avatar._process(0.6)
	assert_ne(avatar._sprite.scale.y, resting, "The idle figure breathes")
	assert_almost_eq(
		avatar._sprite.scale.x,
		FloorAvatar.GUEST_SCALE,
		0.0001,
		"Breathing never stretches sideways"
	)


func test_reduced_motion_drops_the_breathing_but_keeps_the_walk() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var avatar := _avatar()
	var frames: Dictionary = {}
	var step := Vector2.DOWN * (WalkAtlas.CYCLE_DISTANCE / 20.0)
	for _index: int in range(60):
		_walk(avatar, step)
		avatar._process(0.016)
		frames[avatar.walk_frame] = true
		assert_eq(avatar._sprite.scale, Vector2.ONE * FloorAvatar.GUEST_SCALE)
		assert_eq(avatar._sprite.position, FloorAvatar.FOOT_OFFSET)
	assert_eq(frames.size(), WalkAtlas.ROWS, "Walking still animates: it is gameplay feedback")


func test_blocked_walk_does_not_animate_in_place() -> void:
	var avatar := _avatar()
	for _step: int in range(10):
		_walk(avatar, Vector2.RIGHT * 1.4)
	var cycles := avatar.walk_cycles
	var frame := avatar.walk_frame
	for _step: int in range(20):
		avatar.set_motion(Vector2.ZERO)
	assert_almost_eq(avatar.walk_cycles, cycles, 0.0001, "No displacement, no gait")
	assert_eq(avatar.walk_frame, frame)


func test_the_avatar_scales_with_the_room_depth_under_its_feet() -> void:
	var room := FloorRoomLayout.load_room(&"main_floor")
	var avatar := _avatar()
	avatar.position = Vector2(480.0, room.avatar_depth_top)
	avatar.follow_room_scale(room)
	var far := avatar.scale.x
	avatar.position = Vector2(480.0, room.avatar_depth_bottom)
	avatar._process(0.016)
	assert_gt(avatar.scale.x, far, "The player grows as he walks toward the camera")


func test_facing_does_not_flicker_when_sliding_along_a_wall() -> void:
	var avatar := _avatar()
	_walk(avatar, Vector2.RIGHT * 2.0)
	var changes := 0
	var last := avatar.facing_index
	for index: int in range(40):
		# Wall sliding wobbles either side of the E/SE boundary (22.5 degrees).
		var angle := deg_to_rad(22.5 + (4.0 if index % 2 == 0 else -4.0))
		_walk(avatar, Vector2.from_angle(angle) * 1.4)
		if avatar.facing_index != last:
			changes += 1
			last = avatar.facing_index
	assert_eq(changes, 0, "A wobble across a wedge boundary keeps the facing")
	_walk(avatar, Vector2.DOWN * 1.4)
	assert_eq(avatar.facing_index, 4, "A real turn still switches immediately")
