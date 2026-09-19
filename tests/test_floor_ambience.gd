extends GutTest

var _floor: FloorController


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_only_the_player_and_object_fronts_share_the_depth_layer() -> void:
	assert_true(_floor._depth_layer.y_sort_enabled)
	assert_same(_floor._avatar_visual.get_parent(), _floor._depth_layer)
	assert_same(_floor._floor_foreground.get_parent(), _floor._depth_layer)
	assert_eq(_floor._depth_layer.get_child_count(), 2, "Guests are painted into blocked zones")


func test_painted_in_guests_are_baked_only_inside_solid_zones() -> void:
	var spec: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/art/bake_main_floor.json")
	)
	assert_eq("res://" + String(spec.output), _floor.room.background_path)
	var solid_names: Dictionary = {}
	for solid: Dictionary in _floor.room.solids:
		solid_names[solid.name] = solid.points
	assert_gte(spec.patches.size(), 3, "Lounges, islands, cashier and wing entrances are populated")
	for patch: Dictionary in spec.patches:
		for zone: String in patch.zones:
			assert_true(solid_names.has(zone), "Baked guests sit inside the %s zone" % zone)
			var points: PackedVector2Array = solid_names[zone]
			var center := Vector2.ZERO
			for point: Vector2 in points:
				center += point
			center /= float(points.size())
			assert_false(_floor._is_walkable(center), "%s is unreachable" % zone)


func test_camera_focus_is_bounded_and_recenters_after_leaving_machine() -> void:
	var slot_position: Vector2 = _floor.cabinet_positions[&"slot_classic"]
	_floor.avatar_position = slot_position
	_floor.refresh_proximity()
	await wait_seconds(0.3)
	assert_eq(_floor._floor_camera.zoom, FloorController.CAMERA_FOCUS_ZOOM)
	assert_lte(
		_floor._floor_camera.position.distance_to(FloorController.CAMERA_CENTER),
		FloorController.CAMERA_FOCUS_OFFSET + 0.01
	)
	_floor.avatar_position = Vector2(480, 360)
	_floor.refresh_proximity()
	await wait_seconds(0.3)
	assert_almost_eq(_floor._floor_camera.position.x, FloorController.CAMERA_CENTER.x, 0.01)
	assert_almost_eq(_floor._floor_camera.position.y, FloorController.CAMERA_CENTER.y, 0.01)
	assert_eq(_floor._floor_camera.zoom, Vector2.ONE)
