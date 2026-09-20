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


# --- Ambient life: breathing lamps, ceiling shade, glints, sparks ------------------

const AMBIENT_ROOMS: Array[StringName] = [&"main_floor", &"high_roller", &"vip", &"manager_office"]
const CANVAS := Rect2(0, 0, 960, 540)
const AMBIENT_SAMPLES: Array[float] = [0.0, 0.4, 1.3, 2.9, 4.4, 6.1, 8.8, 11.7, 14.2, 23.5, 47.9]


func _ambience() -> FloorAmbientLights:
	return _floor.get_node("FloorAmbience") as FloorAmbientLights


func test_every_room_authors_lights_inside_the_canvas() -> void:
	for room_id: StringName in AMBIENT_ROOMS:
		var data := FloorAmbientLights.room_ambience(room_id)
		assert_gte((data["lights"] as Array).size(), 10, "%s lights its painted lamps" % room_id)
		for light: Dictionary in data["lights"]:
			var at := Vector2(light["at"][0], light["at"][1])
			assert_true(CANVAS.has_point(at), "%s %s is on the canvas" % [room_id, light["name"]])
			assert_between(float(light["radius"]), 12.0, 60.0, "A pool, not a wash")
			assert_between(float(light["period"]), 3.0, 7.0, "Breathes on a 3-7 s period")
			assert_lte(
				float(light["strength"]) * (1.0 + float(light["flicker"])),
				AmbientLayer.POOL_ALPHA_CAP + 0.0001,
				"%s %s is authored under the pool cap" % [room_id, light["name"]]
			)
		for glint: Dictionary in data["glints"]:
			var rect := Rect2(glint["at"][0], glint["at"][1], glint["size"][0], glint["size"][1])
			assert_true(
				CANVAS.encloses(rect), "%s glint %s is on the canvas" % [room_id, glint["name"]]
			)
			assert_between(float(glint["interval"]), 8.0, 15.0)
		for shadow: Dictionary in data["ceiling_shadows"]:
			var reach := (
				float(shadow["radius"]) * 1.1
				+ Vector2(shadow["sway"][0], shadow["sway"][1]).length()
			)
			var at := Vector2(shadow["at"][0], shadow["at"][1])
			assert_true(
				CANVAS.encloses(Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2.0))
			)
			assert_lte(float(shadow["alpha"]), AmbientLayer.SHADOW_ALPHA_CAP)
		for point: Array in data["screen_sparkles"]:
			assert_true(CANVAS.has_point(Vector2(point[0], point[1])))


func test_every_light_sits_on_a_painted_lamp() -> void:
	for room_id: StringName in AMBIENT_ROOMS:
		var layout := FloorRoomLayout.load_room(room_id)
		var image := layout.background().get_image()
		if image.is_compressed():
			image.decompress()
		var texel := Vector2(image.get_size()) / CANVAS.size
		var sources: Array[Vector2] = []
		for light: Dictionary in FloorAmbientLights.room_ambience(room_id)["lights"]:
			sources.append(Vector2(light["at"][0], light["at"][1]))
		if room_id == &"main_floor":
			for fixture: Dictionary in PracticalLightRig.FIXTURES:
				sources.append(fixture["lamp"])
		for source: Vector2 in sources:
			var brightest := 0.0
			for dy: int in range(-7, 8):
				for dx: int in range(-7, 8):
					var at := (source + Vector2(dx, dy)).clamp(
						Vector2.ZERO, CANVAS.size - Vector2.ONE
					)
					brightest = maxf(
						brightest, image.get_pixelv(Vector2i(at * texel)).get_luminance()
					)
			assert_gt(brightest, 0.6, "%s light at %s sits on a lit lamp" % [room_id, source])


func test_ambient_alpha_caps_hold_in_every_room() -> void:
	var ambience := _ambience()
	for room_id: StringName in AMBIENT_ROOMS:
		if room_id != _floor.room.id:
			_floor.enter_room(room_id)
		for at_time: float in AMBIENT_SAMPLES:
			var peaks: Dictionary = ambience.sample_alpha_peaks(at_time)
			assert_lte(peaks["pool"], AmbientLayer.POOL_ALPHA_CAP, "%s pools stay pools" % room_id)
			assert_lte(peaks["shadow"], AmbientLayer.SHADOW_ALPHA_CAP)
			assert_lte(peaks["sweep"], AmbientLayer.SWEEP_ALPHA_CAP)
			assert_lte(peaks["spark"], AmbientLayer.SPARK_ALPHA_CAP)
		var breathing := false
		for index: int in range(ambience.light_count()):
			if not is_equal_approx(
				ambience.light_alpha(index, 0.0), ambience.light_alpha(index, 2.0)
			):
				breathing = true
		assert_true(breathing, "%s lamps breathe" % room_id)


func test_reduced_motion_freezes_the_floor_ambience() -> void:
	var ambience := _ambience()
	ambience._process(3.0)
	assert_gt(ambience.elapsed, 0.0)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_true(ambience.reduced_motion)
	assert_eq(ambience.elapsed, AmbientLayer.REST_ELAPSED)
	ambience._process(2.0)
	assert_eq(ambience.elapsed, AmbientLayer.REST_ELAPSED, "The clock never advances")
	var data := FloorAmbientLights.room_ambience(_floor.room.id)
	for index: int in range(ambience.light_count()):
		var average := float(data["lights"][index]["strength"])
		for at_time: float in AMBIENT_SAMPLES:
			assert_almost_eq(ambience.light_alpha(index, at_time), average, 0.00001)
	for index: int in range(ambience.glint_count()):
		for at_time: float in AMBIENT_SAMPLES:
			assert_eq(ambience.glint_strength(index, at_time), 0.0, "No glints")
	for at_time: float in AMBIENT_SAMPLES:
		assert_eq(ambience.sample_alpha_peaks(at_time)["spark"], 0.0, "No sparks or motes")
	for index: int in range(ambience.shadow_count()):
		assert_eq(
			ambience.shadow_center(index, 9.0), ambience.shadow_center(index, 0.0), "No drift"
		)
	for child: Node in ambience.get_children():
		if child is AmbientSweep:
			assert_false((child as AmbientSweep).visible)


func test_ambient_layers_sit_between_the_room_and_the_hud() -> void:
	var ambience := _ambience()
	assert_same(ambience.get_parent(), _floor, "Ambience is room art, not a depth-sorted actor")
	var depth := _floor._depth_layer.z_index
	# Shade, contact shadow and screen sparks lie on the carpet under people and fronts.
	assert_lt(ambience.shade_canvas.z_index, depth)
	assert_lt(ambience.surface_canvas.z_index, depth)
	# Lamp light falls on people too, but stays under every prompt and HUD layer.
	assert_gt(ambience.light_canvas.z_index, depth)
	var prompt := _floor.get("_prompt") as CanvasItem
	if prompt != null:
		assert_lt(ambience.light_canvas.z_index, prompt.z_index)
	for child: Node in ambience.get_children():
		if child is AmbientSweep:
			assert_lte((child as AmbientSweep).z_index, ambience.light_canvas.z_index)
	for child: Node in _floor.get_children():
		if child is CanvasLayer:
			assert_gt((child as CanvasLayer).layer, 0, "HUD layers draw above the room canvas")


func test_room_change_swaps_the_authored_ambience() -> void:
	var ambience := _ambience()
	for room_id: StringName in AMBIENT_ROOMS:
		if room_id != _floor.room.id:
			_floor.enter_room(room_id)
		var data := FloorAmbientLights.room_ambience(room_id)
		assert_eq(ambience.room_id, room_id)
		assert_eq(ambience.light_count(), (data["lights"] as Array).size())
		assert_eq(ambience.glint_count(), (data["glints"] as Array).size())
		assert_eq(ambience.shadow_count(), (data["ceiling_shadows"] as Array).size())
	_floor.return_to_main_floor()
	assert_eq(ambience.room_id, &"main_floor")


func test_glints_fire_every_eight_to_fifteen_seconds() -> void:
	var ambience := _ambience()
	assert_gt(ambience.glint_count(), 0)
	for start: float in [0.0, 7.3, 21.9]:
		var next := ambience.next_glint_time(start)
		assert_between(next - start, 0.0, 15.0)
		var lit := false
		for index: int in range(ambience.glint_count()):
			if ambience.glint_strength(index, next + FloorAmbientLights.GLINT_SECONDS * 0.5) > 0.05:
				lit = true
		assert_true(lit, "A brass glint sweeps at %.1f" % next)


func test_contact_shadow_follows_the_feet() -> void:
	var ambience := _ambience()
	_floor.move_avatar(Vector2.RIGHT, 0.2)
	assert_eq(ambience._avatar_feet(), _floor.avatar_position)
	_floor.enter_room(&"manager_office")
	assert_eq(ambience._avatar_feet(), _floor.room.spawn, "Follows into other rooms")
