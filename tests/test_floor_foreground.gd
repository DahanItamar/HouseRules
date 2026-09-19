extends GutTest

const FOREGROUND_SCRIPT := preload("res://src/floor/floor_foreground.gd")


func _foreground(room_id: StringName) -> FloorForeground:
	var foreground := FOREGROUND_SCRIPT.new() as FloorForeground
	foreground.configure(FloorRoomLayout.load_room(room_id))
	add_child_autofree(foreground)
	return foreground


func test_every_room_builds_one_textured_piece_per_authored_occluder() -> void:
	for room_id: StringName in FloorController.ROOM_IDS:
		var foreground := _foreground(room_id)
		assert_eq(foreground.occluder_count(), foreground.layout.occluders.size())
		assert_gt(foreground.occluder_count(), 10, "%s has real object fronts" % room_id)
		assert_true(foreground.y_sort_enabled, "Pieces sort with the characters")
		for occluder: Dictionary in foreground.layout.occluders:
			var patch := foreground.piece(String(occluder.name))
			assert_not_null(patch)
			assert_same(patch.texture, foreground.texture())
			assert_eq(patch.polygon.size(), patch.uv.size())
			assert_eq(patch.position, Vector2(0, occluder.baseline))


func test_pieces_sample_the_foreground_exactly_where_they_are_drawn() -> void:
	var foreground := _foreground(FloorController.MAIN_FLOOR)
	var scale := Vector2(foreground.texture().get_size()) / FloorForeground.VIEW_SIZE
	assert_eq(scale, Vector2(4, 4), "3840x2160 masters map to the 960x540 canvas")
	for patch: Polygon2D in foreground.get_children():
		for index: int in range(patch.polygon.size()):
			var screen := patch.position + patch.polygon[index]
			assert_eq(patch.uv[index], screen * scale)


func test_foreground_layers_are_transparent_except_for_object_fronts() -> void:
	for room_id: StringName in FloorController.ROOM_IDS:
		var layout := FloorRoomLayout.load_room(room_id)
		var image := TexturePixels.readable(layout.foreground())
		assert_eq(image.get_size(), Vector2i(3840, 2160))
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE)
		for corner: Vector2i in [
			Vector2i(0, 0),
			Vector2i(image.get_width() - 1, 0),
			Vector2i(0, image.get_height() - 1),
			Vector2i(image.get_width() - 1, image.get_height() - 1),
		]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [room_id, corner])
		# The open carpet in front of every spawn never belongs to the foreground.
		var spawn_texel := Vector2i(layout.spawn * 4.0)
		assert_eq(image.get_pixelv(spawn_texel).a, 0.0, "%s spawn carpet is clear" % room_id)


func test_depth_order_follows_the_foot_line() -> void:
	# y-sort draws larger y later: feet above a baseline sit behind the object,
	# feet below it pass in front.
	var foreground := _foreground(FloorController.MAIN_FLOOR)
	var lamp := foreground.piece("PlanterLampLeft")
	assert_not_null(lamp)
	var behind := Vector2(368, 456)
	var in_front := Vector2(368, 500)
	assert_lt(behind.y, lamp.position.y, "A guest north of the lamp is covered by it")
	assert_gt(in_front.y, lamp.position.y, "A guest south of the lamp is drawn over it")
