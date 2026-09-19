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


func test_floor_builds_ten_distinct_noninteractive_patrons() -> void:
	assert_eq(_floor._patrons.size(), 10)
	var profiles: Dictionary = {}
	var textures: Dictionary = {}
	for patron: Node2D in _floor._patrons:
		profiles[patron.get("profile_index")] = true
		textures[(patron as CasinoPatron).portrait_texture().resource_path] = true
		assert_false(patron.has_method("interact"), "Ambient patrons expose no gameplay action")
	assert_eq(profiles.size(), 10, "Every patron has a distinct visual profile")
	assert_eq(textures.size(), 10, "Every lady and gentleman uses different authored art")
	assert_false(
		textures.has(FloorAvatar.GUEST_TEXTURE.resource_path),
		"No ambient patron reuses the player character"
	)


func test_patrons_live_inside_existing_solid_furniture_zones() -> void:
	for patron: Node2D in _floor._patrons:
		assert_false(
			_floor._is_walkable(patron.position),
			"Patron %s stays off the navigation floor" % patron.name
		)
	for approach: Vector2 in _floor.cabinet_positions.values():
		assert_true(_floor._is_walkable(approach), "Patrons do not alter cabinet approaches")


func test_machine_guests_flank_game_art_and_peripheral_guests_use_real_landmarks() -> void:
	var expected_stations: Array[StringName] = [
		&"slot_left", &"slot_right", &"blackjack_left", &"blackjack_right",
		&"vault_left", &"vault_right", &"elevator", &"cashier", &"upper_couch",
		&"lower_couch",
	]
	var stations: Dictionary = {}
	for patron: CasinoPatron in _floor._patrons:
		stations[patron.get_meta("station")] = patron
	assert_eq(stations.size(), expected_stations.size())
	for station: StringName in expected_stations:
		assert_true(stations.has(station), "The %s landmark has its authored guest" % station)
	for game_id: StringName in _floor.cabinet_positions:
		var machine_x: float = (_floor.cabinet_positions[game_id] as Vector2).x
		for side: String in ["left", "right"]:
			var prefix := (
				"vault"
				if game_id == &"minefield_vault"
				else String(game_id).trim_suffix("_classic")
			)
			var patron: CasinoPatron = stations[StringName("%s_%s" % [prefix, side])]
			assert_gte(
				absf(patron.position.x - machine_x),
				48.0,
				"%s guest leaves the game identity and controls readable" % game_id
			)
	assert_gt((stations[&"cashier"] as CasinoPatron).position.y, 400.0)
	assert_gt((stations[&"lower_couch"] as CasinoPatron).position.y, 420.0)


func test_back_row_scale_is_quieter_than_the_old_foreground_scale() -> void:
	var cashier_height := 0.0
	for patron: CasinoPatron in _floor._patrons:
		var displayed_height := patron._sprite.texture.get_height() * patron._sprite_scale
		if patron.position.y < 300.0:
			assert_lte(displayed_height, 56.0)
			assert_eq(patron.z_index, 2)
		else:
			if patron.get_meta("station") == &"cashier":
				cashier_height = displayed_height
			assert_eq(patron.z_index, 3)
	assert_gt(cashier_height, 56.0, "The closer cashier attendant carries foreground scale")


func test_patron_gestures_are_phase_staggered_and_have_calm_cadences() -> void:
	var phases: Dictionary = {}
	for patron: Node2D in _floor._patrons:
		phases[patron.get("phase_offset")] = true
		assert_between(float(patron.get("gesture_interval")), 2.0, 5.0)
	assert_eq(phases.size(), 10)
	_floor._patrons[0].call("_process", 0.2)
	assert_gt(float(_floor._patrons[0].get("gesture_strength")), 0.0)


func test_patrons_use_bounded_identity_specific_gestures_without_moving_the_root() -> void:
	var patron: CasinoPatron = _floor._patrons[0] as CasinoPatron
	assert_not_null(patron.get_node_or_null("PatronPortrait"))
	var position_start := patron._sprite.position
	patron._process(0.2)
	assert_ne(
		patron._sprite.position,
		position_start,
		"The guest performs a restrained identity-specific gesture"
	)
	assert_eq(patron.rotation, 0.0, "The patron root remains stable")


func test_patron_assets_have_real_transparency_for_floor_compositing() -> void:
	for patron: CasinoPatron in _floor._patrons:
		var image := patron.portrait_texture().get_image()
		assert_true(image.detect_alpha() != Image.ALPHA_NONE)
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_eq(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a, 0.0)


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


func test_floor_foreground_restores_depth_above_avatar_and_patrons() -> void:
	assert_not_null(_floor._floor_foreground)
	assert_gt(_floor._floor_foreground.z_index, _floor._avatar_visual.z_index)
	for patron: CasinoPatron in _floor._patrons:
		assert_gt(_floor._floor_foreground.z_index, patron.z_index)
	assert_eq(_floor._floor_foreground.call("occluder_count"), 6)
