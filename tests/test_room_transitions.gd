extends GutTest
## Themed room passages: the Grand Staircase, the VIP lift and the office door
## each play their own overlay; floor input is locked for the passage and
## restored after it; arrivals are walkable; reduced motion is a short
## crossfade; a passage cannot be entered twice; Escape mid-passage is safe;
## and developer warps bypass the passage entirely.

const MAIN := FloorController.MAIN_FLOOR
## Each wing, the passage leading to it, and the cue that marks it.
const ENTRIES: Array[Dictionary] = [
	{"room": &"high_roller", "kind": RoomTransition.STAIRS, "cue": &"stair_steps"},
	{"room": &"vip", "kind": RoomTransition.LIFT, "cue": &"lift_chime"},
	{"room": &"manager_office", "kind": RoomTransition.DOOR, "cue": &"door_latch"},
]
const PASSAGE_TIMEOUT: float = 3.0

var _floor: FloorController
var _transition: RoomTransition
var _original_platform: PlatformServices
var _original_test_mode: bool
var _original_wagered: int
var _cues: Array[StringName] = []
var _entry_positions: Array[Vector2] = []


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	SaveService.platform = LocalPlatform.new("user://tests/transitions_%s" % Time.get_ticks_usec())
	SaveService.new_game(4321)
	Wallet.set_test_mode(false)
	_original_wagered = Economy.lifetime_wagered
	Economy.lifetime_wagered = int(FloorController.WING_THRESHOLDS[&"vip"])
	MotionPolicy.set_reduced_motion_for_tests(false)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	SceneRouter.register_floor(_floor)
	_transition = _floor.room_transition()
	_transition.animations_enabled = true
	_cues.clear()
	_entry_positions.clear()
	AudioService.cue_played.connect(_record_cue)
	_transition.switched.connect(_record_entry_position)


func after_each() -> void:
	if AudioService.cue_played.is_connected(_record_cue):
		AudioService.cue_played.disconnect(_record_cue)
	if is_instance_valid(_transition):
		_transition.cancel()
	MotionPolicy.clear_test_override()
	Economy.lifetime_wagered = _original_wagered
	SceneRouter.floor = null
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	SaveService.new_game(1234)


func _record_cue(cue: StringName) -> void:
	_cues.append(cue)


func _record_entry_position(_room_id: StringName) -> void:
	_entry_positions.append(_floor.avatar_position)


func _entry_anchor(room_id: StringName) -> Vector2:
	var main_floor := FloorRoomLayout.load_room(MAIN)
	if room_id == FloorController.OFFICE:
		return main_floor.anchor(FloorController.OFFICE_DOOR_ANCHOR)
	return FloorController.WING_POSITIONS[room_id]


func _stand_at_entry(room_id: StringName) -> void:
	_floor.avatar_position = _entry_anchor(room_id)
	_floor.refresh_proximity()


func _stand_at_exit() -> void:
	_floor.avatar_position = _floor.room.anchor(FloorController.EXIT_ANCHOR)
	_floor.refresh_proximity()


func _finish_passage() -> void:
	if _transition.is_active():
		await wait_for_signal(_transition.finished, PASSAGE_TIMEOUT)
	assert_false(_transition.is_active(), "The passage finishes on its own")


func _overlay_layer() -> CanvasLayer:
	return _transition.overlay().get_parent() as CanvasLayer


func _press(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _assert_clear_of_solids(point: Vector2, label: String) -> void:
	assert_true(_floor.room.is_walkable(point), "%s arrival is walkable" % label)
	for solid: Dictionary in _floor.room.solids:
		assert_false(
			Geometry2D.is_point_in_polygon(point, solid["points"]),
			"%s arrival is outside %s" % [label, solid["name"]]
		)


func test_headless_runs_keep_room_switches_instant_by_default() -> void:
	var fresh := RoomTransition.new()
	assert_false(fresh.animations_enabled, "Headless runs switch rooms synchronously")
	fresh.free()


func test_every_entry_plays_its_themed_passage_both_ways() -> void:
	for entry: Dictionary in ENTRIES:
		var room_id: StringName = entry["room"]
		assert_eq(RoomTransition.themed_kind(MAIN, room_id), entry["kind"])
		assert_eq(RoomTransition.themed_kind(room_id, MAIN), entry["kind"])
		_stand_at_entry(room_id)
		_cues.clear()
		assert_true(_floor.interact(), "Confirming the %s entry starts a passage" % room_id)
		assert_true(_transition.is_active())
		assert_eq(_transition.kind, entry["kind"], "%s uses its themed passage" % room_id)
		assert_eq(_transition.overlay().get("kind"), entry["kind"], "The overlay draws it")
		assert_true(_transition.overlay().get("ascending"), "Going in runs up / in")
		assert_eq(_floor.room.id, MAIN, "The room only switches behind the closed overlay")
		await _finish_passage()
		assert_eq(_floor.room.id, room_id)
		assert_eq(_floor.avatar_position, _floor.room.spawn, "Arrival lands on the spawn")
		assert_has(_cues, entry["cue"], "%s plays its own cue" % room_id)
		assert_does_not_have(_cues, &"confirm", "The themed cue replaces the generic one")
		_stand_at_exit()
		assert_true(_floor.interact(), "The %s exit starts the passage back" % room_id)
		assert_eq(_transition.kind, entry["kind"], "%s returns the same way" % room_id)
		assert_false(_transition.overlay().get("ascending"), "Coming back runs down / out")
		await _finish_passage()
		assert_eq(_floor.room.id, MAIN)
		assert_eq(_floor.avatar_position, _entry_anchor(room_id), "Back where the player left")


func test_input_is_locked_for_the_passage_and_restored_after() -> void:
	_floor.set_physics_process(true)
	_floor.set_process_unhandled_input(true)
	_stand_at_entry(&"vip")
	assert_true(_floor.interact())
	assert_false(_floor.is_processing_unhandled_input(), "Floor input is off mid-passage")
	assert_false(_floor.is_physics_processing(), "Stick movement is off mid-passage")
	assert_true(_overlay_layer().visible, "The overlay is up")
	assert_eq(
		_transition.overlay().mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"The overlay swallows pointer input"
	)
	await wait_seconds(0.3)
	assert_false(_floor.is_processing_unhandled_input(), "Still off while the doors close")
	await _finish_passage()
	assert_true(_floor.is_processing_unhandled_input(), "Floor input comes back")
	assert_true(_floor.is_physics_processing(), "Movement comes back")
	assert_false(_overlay_layer().visible, "The overlay is gone")
	var camera := _floor.get_node("FloorCamera") as Camera2D
	assert_eq(camera.offset, Vector2.ZERO, "The camera is left where it was")
	assert_eq(camera.zoom, Vector2.ONE)


func test_input_lock_keeps_a_floor_that_was_already_paused_paused() -> void:
	_floor.set_physics_process(false)
	_stand_at_entry(&"high_roller")
	assert_true(_floor.interact())
	await _finish_passage()
	assert_false(_floor.is_physics_processing(), "The passage restores, never invents, state")


func test_arrivals_step_out_of_the_entry_onto_walkable_floor() -> void:
	for entry: Dictionary in ENTRIES:
		var room_id: StringName = entry["room"]
		_stand_at_entry(room_id)
		_entry_positions.clear()
		assert_true(_floor.interact())
		await _finish_passage()
		var threshold: Vector2 = RoomTransition.THRESHOLDS[room_id]["room"]
		assert_eq(_entry_positions, [threshold], "%s: the avatar starts in the entry" % room_id)
		_assert_clear_of_solids(_floor.avatar_position, String(room_id))
		assert_gt(
			_floor.avatar_position.distance_to(threshold),
			12.0,
			"%s: the avatar steps at least a step out of the entry" % room_id
		)
		_stand_at_exit()
		_entry_positions.clear()
		assert_true(_floor.interact())
		await _finish_passage()
		assert_eq(_entry_positions, [RoomTransition.THRESHOLDS[room_id]["floor"]])
		_assert_clear_of_solids(_floor.avatar_position, "Main Floor from %s" % room_id)


func test_reduced_motion_uses_a_short_crossfade_without_walking() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var timing: Dictionary = RoomTransition.TIMINGS[RoomTransition.CROSSFADE]
	var total := 0.0
	for phase: float in timing.values():
		total += phase
	assert_lte(total, 0.25, "The reduced-motion crossfade stays short")
	var camera := _floor.get_node("FloorCamera") as Camera2D
	for entry: Dictionary in ENTRIES:
		var room_id: StringName = entry["room"]
		_stand_at_entry(room_id)
		var start := _floor.avatar_position
		_cues.clear()
		_entry_positions.clear()
		var began := Time.get_ticks_msec()
		assert_true(_floor.interact())
		assert_eq(_transition.kind, RoomTransition.CROSSFADE, "%s crossfades" % room_id)
		await get_tree().process_frame
		if _floor.room.id == MAIN:
			assert_eq(_floor.avatar_position, start, "No walk-in under reduced motion")
		await _finish_passage()
		assert_lt(Time.get_ticks_msec() - began, 600, "The crossfade is over quickly")
		assert_eq(_entry_positions, [_floor.room.spawn], "No step-out under reduced motion")
		assert_eq(camera.offset, Vector2.ZERO, "No camera drift under reduced motion")
		assert_eq(camera.zoom, Vector2.ONE)
		assert_has(_cues, entry["cue"], "The passage is still heard")
		_floor.enter_room(MAIN)
	# Let the rebuilt foreground pieces of each visited room finish freeing.
	await get_tree().process_frame


func test_a_passage_cannot_be_entered_twice() -> void:
	watch_signals(_floor)
	_stand_at_entry(&"high_roller")
	assert_true(_floor.interact())
	assert_false(_floor.interact(), "A second confirm is ignored")
	assert_false(_transition.travel(&"vip"), "No second passage starts")
	_floor.return_to_main_floor()
	_floor._room_back.pressed.emit()
	await wait_seconds(0.2)
	assert_false(_floor.interact(), "Still ignored mid-passage")
	await _finish_passage()
	assert_eq(_floor.room.id, &"high_roller")
	assert_signal_emit_count(_floor, "room_changed", 1, "Exactly one room switch")


func test_escape_mid_passage_is_safe() -> void:
	watch_signals(SceneRouter)
	var balance := Wallet.balance
	var avatar := _floor._avatar_visual
	_stand_at_entry(&"vip")
	assert_true(_floor.interact())
	await wait_seconds(0.12)
	_press(&"back")
	await get_tree().process_frame
	await wait_for_signal(_transition.switched, PASSAGE_TIMEOUT)
	_press(&"back")
	await get_tree().process_frame
	await _finish_passage()
	assert_eq(_floor.room.id, &"vip", "Escape neither aborts nor reverses the passage")
	assert_signal_not_emitted(SceneRouter, "menu_requested", "Escape never leaves for the menu")
	assert_null(SceneRouter.session)
	assert_eq(Wallet.balance, balance, "The wallet is untouched")
	assert_same(_floor._avatar_visual, avatar, "The same player walks through")
	assert_eq(_floor.find_children("*", "FloorAvatar", true, false).size(), 1, "Exactly one player")
	assert_true(_floor.is_processing_unhandled_input(), "Input is back after the passage")


func test_developer_warps_bypass_and_cancel_the_passage() -> void:
	_floor._dev_warp_to(&"vip")
	assert_eq(_floor.room.id, &"vip", "The developer warp switches at once")
	assert_false(_transition.is_active(), "No passage runs for a developer warp")
	_floor._dev_warp_to(MAIN)
	assert_eq(_floor.room.id, MAIN)
	_stand_at_entry(&"high_roller")
	assert_true(_floor.interact())
	await wait_seconds(0.1)
	_floor._dev_warp_to(&"vip")
	assert_eq(_floor.room.id, &"vip", "A warp mid-passage wins")
	assert_false(_transition.is_active(), "The passage is cancelled")
	assert_false(_overlay_layer().visible)
	assert_true(_floor.is_processing_unhandled_input(), "Input is restored by the cancel")
	await wait_seconds(1.3)
	assert_eq(_floor.room.id, &"vip", "The cancelled passage never switches late")


func test_locked_wings_start_no_passage() -> void:
	Economy.lifetime_wagered = 0
	for wing_id: StringName in FloorController.WING_POSITIONS:
		_stand_at_entry(wing_id)
		assert_false(_floor.interact(), "%s stays locked" % wing_id)
		assert_false(_transition.is_active(), "No passage starts for a locked wing")
		assert_false(_overlay_layer().visible)
		assert_eq(_floor.room.id, MAIN)


func test_back_control_away_from_the_exit_takes_the_plain_dip() -> void:
	_floor.enter_room(&"vip")
	_floor.avatar_position = Vector2(200, 300)
	_floor.refresh_proximity()
	_floor._room_back.pressed.emit()
	assert_eq(_transition.kind, RoomTransition.DIP, "Leaving from mid-room dips to warm black")
	await _finish_passage()
	assert_eq(_floor.room.id, MAIN)
	assert_eq(_floor.avatar_position, FloorController.WING_POSITIONS[&"vip"])


func test_passage_cues_are_distinct_cached_pcm() -> void:
	var fingerprints: Dictionary = {}
	for cue: StringName in [&"lift_chime", &"door_latch", &"stair_steps"]:
		assert_true(AudioService.CUES.has(cue), "%s is registered" % cue)
		var stream := AudioService.cue_stream(cue)
		assert_same(stream, AudioService.cue_stream(cue), "%s is cached" % cue)
		assert_false(fingerprints.has(hash(stream.data)), "%s has its own waveform" % cue)
		fingerprints[hash(stream.data)] = cue
