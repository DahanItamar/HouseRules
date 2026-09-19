extends GutTest

const CASINO_PATRON_SCRIPT := preload("res://src/floor/casino_patron.gd")
var _floor: FloorController


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_floor_builds_three_distinct_noninteractive_patrons() -> void:
	assert_eq(_floor._patrons.size(), 3)
	var profiles: Dictionary = {}
	for patron: Node2D in _floor._patrons:
		profiles[patron.get("profile_index")] = true
		assert_false(patron.has_method("interact"), "Ambient patrons expose no gameplay action")
	assert_eq(profiles.size(), 3, "Every patron has a distinct visual profile")


func test_patrons_live_inside_existing_solid_furniture_zones() -> void:
	for patron: Node2D in _floor._patrons:
		assert_false(
			_floor._is_walkable(patron.position),
			"Patron %s stays off the navigation floor" % patron.name
		)
	for approach: Vector2 in _floor.cabinet_positions.values():
		assert_true(_floor._is_walkable(approach), "Patrons do not alter cabinet approaches")


func test_patron_gestures_are_phase_staggered_and_have_calm_cadences() -> void:
	var phases: Dictionary = {}
	for patron: Node2D in _floor._patrons:
		phases[patron.get("phase_offset")] = true
		assert_between(float(patron.get("gesture_interval")), 2.0, 5.0)
	assert_eq(phases.size(), 3)
	_floor._patrons[0].call("_process", 0.2)
	assert_gt(float(_floor._patrons[0].get("gesture_strength")), 0.0)


func test_patrons_cycle_through_authored_limb_poses_without_moving_the_root() -> void:
	var patron: CasinoPatron = _floor._patrons[0] as CasinoPatron
	assert_not_null(patron.get_node_or_null("PatronPortrait"))
	var region_start := patron.authored_pose_region()
	patron._process(0.2)
	assert_ne(
		patron.authored_pose_region(),
		region_start,
		"The guest changes to an authored frame with different arm and leg positions"
	)
	assert_eq(patron.rotation, 0.0, "The patron root remains stable")


func test_reduced_motion_holds_every_patron_joint_in_a_stable_rest_pose() -> void:
	var patron: CasinoPatron = _floor._patrons[0] as CasinoPatron
	patron._process(0.2)
	MotionPolicy.set_reduced_motion_for_tests(true)
	var rest_region := patron.authored_pose_region()
	var rest_position := patron._sprite.position
	patron._process(1.0)
	assert_eq(patron.elapsed, 0.0)
	assert_eq(patron.gesture_strength, 0.0)
	assert_eq(patron.authored_pose_region(), rest_region)
	assert_eq(patron._sprite.position, rest_position)


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
