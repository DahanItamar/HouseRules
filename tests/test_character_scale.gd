extends GutTest
## Guards how big a person may be drawn in any room.
##
## The Manager's Office once shipped a 2.6-3.2 depth ramp, which drew the player
## a third of the screen tall. It reached the user because nothing checked the
## ramps; these tests walk every room at every depth so it cannot happen quietly
## again.

const ROOMS: Array[StringName] = [&"main_floor", &"high_roller", &"vip", &"manager_office"]


func _walk_span(room: FloorRoomLayout) -> Vector2:
	var top := INF
	var bottom := -INF
	for point: Vector2 in room.walk_bounds:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	return Vector2(top, bottom)


func test_every_room_draws_an_adult_at_a_believable_height() -> void:
	for room_id: StringName in ROOMS:
		var room := FloorRoomLayout.load_room(room_id)
		var span := _walk_span(room)
		for step: int in range(21):
			var y: float = lerpf(span.x, span.y, float(step) / 20.0)
			var height := CharacterScaler.drawn_height_px(CharacterScaler.ramp_at(room, y))
			assert_between(
				height,
				CharacterScaler.BAND_MIN_PX,
				CharacterScaler.BAND_MAX_PX,
				"%s draws an adult %.1f px tall at y=%.0f" % [room_id, height, y]
			)


func test_walking_toward_the_camera_never_makes_anyone_smaller() -> void:
	for room_id: StringName in ROOMS:
		var room := FloorRoomLayout.load_room(room_id)
		var span := _walk_span(room)
		var previous := -INF
		for step: int in range(21):
			var y: float = lerpf(span.x, span.y, float(step) / 20.0)
			var scale := CharacterScaler.ramp_at(room, y)
			assert_gte(scale, previous - 0.0001, "%s ramp never reverses" % room_id)
			previous = scale


func test_the_office_is_the_same_size_as_the_floor() -> void:
	# The office is a room a man walks into, not a head-and-shoulders close-up.
	var office := FloorRoomLayout.load_room(&"manager_office")
	var main := FloorRoomLayout.load_room(&"main_floor")
	assert_almost_eq(office.avatar_scale_far, main.avatar_scale_far, 0.001)
	assert_almost_eq(office.avatar_scale_near, main.avatar_scale_near, 0.001)


func test_the_manager_is_imposing_but_still_standing_in_the_room() -> void:
	var office := FloorRoomLayout.load_room(&"manager_office")
	var span := _walk_span(office)
	var y: float = lerpf(span.x, span.y, 0.5)
	var worker := CharacterScaler.scale_at(office, y)
	var boss := CharacterScaler.scale_at(office, y, true)
	assert_gt(boss, worker, "The Manager reads as the biggest person in the room")
	assert_lte(
		boss / worker, CharacterScaler.BOSS_MODIFIER_MAX + 0.0001, "and never by more than the cap"
	)
	assert_true(CharacterScaler.is_in_band(boss), "even the Manager stays in the band")


func test_a_bad_ramp_is_clamped_rather_than_drawn() -> void:
	# The exact ramp that shipped the bug, held against the guard.
	var office := FloorRoomLayout.load_room(&"manager_office")
	office.avatar_scale_far = 2.6
	office.avatar_scale_near = 3.2
	var span := _walk_span(office)
	assert_false(
		CharacterScaler.is_in_band(CharacterScaler.ramp_at(office, span.y)),
		"The rejected ramp is out of band"
	)
	assert_true(
		CharacterScaler.is_in_band(CharacterScaler.scale_at(office, span.y)),
		"and the scaler refuses to draw it that way"
	)
