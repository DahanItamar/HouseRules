extends GutTest

const WalkAtlas := preload("res://src/floor/character_walk_atlas.gd")


func test_atlas_uses_exact_integer_cells_with_transparent_gutters() -> void:
	var texture: Texture2D = load(
		"res://assets/production/characters/player_walk_v2.png"
	)
	var image := texture.get_image()
	assert_eq(image.get_size(), WalkAtlas.CELL_SIZE * Vector2i(WalkAtlas.COLUMNS, WalkAtlas.ROWS))
	for row: int in range(WalkAtlas.ROWS):
		for column: int in range(WalkAtlas.COLUMNS):
			var origin := Vector2i(column, row) * WalkAtlas.CELL_SIZE
			var far_corner := origin + WalkAtlas.CELL_SIZE - Vector2i.ONE
			assert_eq(image.get_pixelv(origin).a, 0.0)
			assert_eq(image.get_pixelv(far_corner).a, 0.0)
			var gutter_is_clear := true
			for offset: int in range(WalkAtlas.CELL_SIZE.x):
				gutter_is_clear = (
					gutter_is_clear
					and is_zero_approx(image.get_pixelv(origin + Vector2i(offset, 0)).a)
				)
				gutter_is_clear = (
					gutter_is_clear
					and is_zero_approx(
						image.get_pixelv(origin + Vector2i(offset, WalkAtlas.CELL_SIZE.y - 1)).a
					)
				)
			for offset: int in range(WalkAtlas.CELL_SIZE.y):
				gutter_is_clear = (
					gutter_is_clear
					and is_zero_approx(image.get_pixelv(origin + Vector2i(0, offset)).a)
				)
				gutter_is_clear = (
					gutter_is_clear
					and is_zero_approx(
						image.get_pixelv(origin + Vector2i(WalkAtlas.CELL_SIZE.x - 1, offset)).a
					)
				)
			assert_true(gutter_is_clear, "Every frame is isolated by transparent pixels")


func test_all_direction_and_phase_regions_have_unique_pixels() -> void:
	var texture: Texture2D = load(
		"res://assets/production/characters/player_walk_v2.png"
	)
	var image := texture.get_image()
	var hashes: Dictionary = {}
	for direction: int in range(8):
		for phase: int in range(4):
			var region := WalkAtlas.region(direction, phase)
			assert_eq(region.position, region.position.round(), "Region origin is integer exact")
			assert_eq(region.size, Vector2(WalkAtlas.CELL_SIZE))
			var frame := image.get_region(Rect2i(region))
			hashes[hash(frame.get_data())] = true
	assert_eq(hashes.size(), 32, "Eight authored directions provide four real leg phases each")


func test_direction_mapping_preserves_all_eight_compass_facings() -> void:
	var facings: Array[Vector2] = [
		Vector2.UP,
		Vector2(1, -1),
		Vector2.RIGHT,
		Vector2(1, 1),
		Vector2.DOWN,
		Vector2(-1, 1),
		Vector2.LEFT,
		Vector2(-1, -1),
	]
	for index: int in range(facings.size()):
		assert_eq(WalkAtlas.direction_index(facings[index]), index)
		var region := WalkAtlas.region(index, 0)
		assert_eq(int(region.position.x), index * WalkAtlas.CELL_SIZE.x)
		assert_false(WalkAtlas.is_mirrored(index), "Every facing is authored, none mirrored")


func test_rendered_face_turns_toward_the_direction_of_travel() -> void:
	# A walker moving screen-right must show his face right of his head's
	# centre; moving screen-left, left of it. This catches a moonwalking map.
	var image := TexturePixels.readable(
		load("res://assets/production/characters/player_walk_v2.png")
	)
	for phase: int in range(4):
		for index: int in [1, 2, 3]:
			assert_gt(_face_offset(image, index, phase), 1.0, "Facing %d looks right" % index)
		for index: int in [5, 6, 7]:
			assert_lt(_face_offset(image, index, phase), -1.0, "Facing %d looks left" % index)


## Mean x of skin pixels minus mean x of the head silhouette, in the top 26
## rows of the figure as drawn for this facing (mirroring included).
func _face_offset(image: Image, index: int, phase: int) -> float:
	var region := Rect2i(WalkAtlas.region(index, phase))
	var frame := image.get_region(region)
	if WalkAtlas.is_mirrored(index):
		frame.flip_x()
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


func test_avatar_advances_real_leg_frames_without_anchor_sliding() -> void:
	var avatar := FloorAvatar.new()
	add_child_autofree(avatar)
	var regions: Dictionary = {}
	for _phase: int in range(4):
		avatar.set_motion(Vector2.RIGHT * (FloorAvatar.WALK_CYCLE_DISTANCE / 4.0))
		regions[avatar._atlas.region] = true
		avatar._process(0.01)
		assert_eq(avatar._sprite.position, FloorAvatar.FOOT_OFFSET)
		assert_eq(avatar._sprite.rotation, 0.0)
	assert_eq(regions.size(), 4, "Movement advances through four photographed leg phases")
	assert_eq(avatar._sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
