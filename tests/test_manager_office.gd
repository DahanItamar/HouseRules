extends GutTest
## The Manager's Office: layered room art, collision, the Main Floor door,
## the reception contracts board, the Manager's markers and wing invitations,
## and the secretary's first-run tour.

const OFFICE := FloorController.OFFICE
const STAFF_MASTERS: Array[String] = [
	"res://assets/production/characters/staff/secretary.png",
	"res://assets/production/characters/staff/secretary_explain.png",
	"res://assets/production/characters/staff/secretary_point.png",
	"res://assets/production/characters/staff/manager.png",
	"res://assets/production/characters/staff/manager_offer.png",
	"res://assets/production/characters/staff/manager_toast.png",
]
## Points just outside, then just inside, each visible furniture edge.
const EDGE_SAMPLES: Array[Dictionary] = [
	{"outside": Vector2(480, 238), "inside": Vector2(480, 214), "name": "manager's rug front"},
	{"outside": Vector2(700, 380), "inside": Vector2(740, 380), "name": "reception platform"},
	{"outside": Vector2(480, 516), "inside": Vector2(480, 492), "name": "entrance threshold"},
	{"outside": Vector2(290, 262), "inside": Vector2(252, 262), "name": "lounge rug"},
	{"outside": Vector2(100, 512), "inside": Vector2(100, 484), "name": "left railing"},
]
const TV_SAFE := Rect2(48, 27, 864, 486)

var _original_platform: PlatformServices
var _original_test_mode: bool
var _floor: FloorController


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	SaveService.platform = LocalPlatform.new(
		"user://tests/manager_office_%s" % Time.get_ticks_usec()
	)
	SaveService.new_game(20260919)
	Wallet.set_test_mode(false)
	OfficeState.clear_session()
	MotionPolicy.set_reduced_motion_for_tests(true)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	OfficeState.clear_session()
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	SaveService.new_game(20260919)


# --- Room layers, collision and depth -------------------------------------


func test_office_layers_are_uhd_with_clear_alpha_corners() -> void:
	var room := FloorRoomLayout.load_room(OFFICE)
	assert_eq(room.label, "MANAGER'S OFFICE")
	assert_false(room.preview_only)
	assert_eq(room.background().get_size(), Vector2(3840, 2160))
	assert_eq(room.foreground().get_size(), Vector2(3840, 2160))
	var foreground := TexturePixels.readable(room.foreground())
	for corner: Vector2i in [
		Vector2i(0, 539 * 4), Vector2i(959 * 4, 539 * 4), Vector2i(480 * 4, 300 * 4)
	]:
		assert_eq(foreground.get_pixelv(corner).a, 0.0, "Open carpet is clear at %s" % corner)
	for anchor_id: StringName in room.anchors:
		var at := Vector2i(room.anchor(anchor_id) * 4.0)
		assert_eq(foreground.get_pixelv(at).a, 0.0, "%s carpet is clear" % anchor_id)
	assert_gt(room.solids.size(), 3)
	assert_gt(room.occluders.size(), 3)


func test_staff_masters_are_unique_transparent_and_large_enough() -> void:
	var seen: Dictionary = {}
	for path: String in STAFF_MASTERS:
		assert_false(seen.has(path))
		seen[path] = true
		var texture := load(path) as Texture2D
		assert_gte(texture.get_width(), 1024, path)
		assert_gte(texture.get_height(), 1536, path)
		var image := TexturePixels.readable(texture)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner is transparent" % path)
	for host_path: String in DirAccess.get_files_at("res://assets/production/characters/hosts"):
		assert_false(host_path.begins_with("secretary") or host_path.begins_with("manager"))


func test_office_spawn_and_destinations_are_walkable_and_connected() -> void:
	var room := FloorRoomLayout.load_room(OFFICE)
	var reachable := _reachable_cells(room)
	var destinations: Dictionary = room.anchors.duplicate()
	destinations[&"spawn"] = room.spawn
	destinations[&"return_point"] = room.return_point
	for id: StringName in [&"exit", &"reception", &"manager"]:
		assert_true(room.anchors.has(id), "The office has a %s anchor" % id)
	for id: StringName in destinations:
		var at: Vector2 = destinations[id]
		assert_true(room.is_walkable(at), "%s is walkable" % id)
		assert_true(_touches(reachable, at), "%s connects to the spawn" % id)


func test_office_collision_follows_visible_furniture_edges() -> void:
	var room := FloorRoomLayout.load_room(OFFICE)
	for sample: Dictionary in EDGE_SAMPLES:
		assert_true(room.is_walkable(sample.outside), "Open carpet before the %s" % sample.name)
		assert_false(room.is_walkable(sample.inside), "Solid past the %s" % sample.name)


func test_office_foreground_draws_over_a_player_behind_the_entrance() -> void:
	_floor.enter_room(OFFICE)
	var portal := (_floor._floor_foreground as FloorForeground).piece("EntrancePortal")
	assert_not_null(portal)
	_floor.avatar_position = Vector2(346, 400)
	_floor.move_avatar(Vector2.ZERO, 0.0)
	assert_lt(_floor._avatar_visual.position.y, portal.position.y, "Feet above the portal base")
	_floor.avatar_position = FloorRoomLayout.load_room(OFFICE).spawn
	_floor.move_avatar(Vector2.ZERO, 0.0)
	assert_gt(_floor._avatar_visual.position.y, portal.position.y, "In front below its base")
	assert_true(_floor._depth_layer.y_sort_enabled)


func test_office_avatar_matches_the_closer_camera() -> void:
	_floor.enter_room(OFFICE)
	assert_almost_eq(_floor._avatar_visual.scale.x, _floor.room.avatar_scale, 0.001)
	assert_gt(_floor.room.avatar_scale, 1.0)
	_floor.return_to_main_floor()
	assert_eq(_floor._avatar_visual.scale, Vector2.ONE)


# --- The Main Floor door and room switching --------------------------------


func test_office_door_is_reachable_from_the_main_floor_spawn() -> void:
	var main := FloorRoomLayout.load_room(FloorController.MAIN_FLOOR)
	var door := main.anchor(FloorController.OFFICE_DOOR_ANCHOR)
	assert_true(main.anchors.has(FloorController.OFFICE_DOOR_ANCHOR))
	assert_true(main.is_walkable(door))
	assert_true(_touches(_reachable_cells(main), door), "The office door connects to spawn")
	assert_false(main.is_walkable(Vector2(900, 250)), "The door wall itself is solid")
	_floor.avatar_position = door
	_floor.refresh_proximity()
	assert_true(_floor.nearby_office_door)
	assert_eq(_floor.nearby_wing, &"", "The door wins over the nearby VIP lift")
	assert_string_contains(_floor._prompt.text, InputRouter.glyph("interact"))
	_floor.avatar_position = FloorController.WING_POSITIONS[FloorController.VIP]
	_floor.refresh_proximity()
	assert_false(_floor.nearby_office_door)
	assert_eq(_floor.nearby_wing, FloorController.VIP, "The VIP lift keeps its own spot")


func test_entering_and_leaving_the_office_keeps_one_player_and_the_wallet() -> void:
	Wallet.reset(321)
	_floor.avatar_position = _floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR)
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	assert_eq(_floor.room.id, OFFICE)
	assert_eq(_floor.avatar_position, _floor.room.spawn)
	assert_true(_floor._room_layer.visible, "A visible Back control is offered")
	var back := InputEventAction.new()
	back.action = &"back"
	back.pressed = true
	_floor._unhandled_input(back)
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR, "Escape/B returns to the Main Floor")
	assert_eq(_floor.avatar_position, _floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR))
	_floor.enter_room(OFFICE)
	_floor._room_back.pressed.emit()
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR, "The Back control returns too")
	assert_eq(_floor.avatar_position, _floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR))
	assert_eq(Wallet.balance, 321)
	var avatars := _floor.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node is FloorAvatar
	)
	assert_eq(avatars.size(), 1, "Room switching never creates a second player")


func test_developer_panel_lists_the_office_and_its_door() -> void:
	var ids: Array[StringName] = []
	for target: Dictionary in FloorController.DEV_TARGETS:
		ids.append(target.id)
	assert_has(ids, OFFICE)
	assert_has(ids, &"office_door")
	_floor._dev_warp_to(OFFICE)
	assert_eq(_floor.room.id, OFFICE)
	_floor._dev_warp_to(&"office_door")
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR)
	assert_true(_floor.nearby_office_door)


# --- Reception: House Contracts board --------------------------------------


func test_contracts_board_matches_economy_and_logs_completions() -> void:
	var office := _enter_office_at(&"reception")
	assert_eq(_floor.nearby_station, &"reception")
	assert_true(_floor.interact(), "Speaking with the secretary")
	assert_eq(office.conversation, &"reception")
	office.dialogue.choice_selected.emit(&"contracts")
	assert_true(office.board.is_open())
	var rows := office.board.row_data()
	var economy_rows := Economy.contract_rows()
	assert_eq(rows.size(), Economy.CONTRACT_SLOTS)
	for index: int in range(rows.size()):
		var expected: Dictionary = economy_rows[index]
		assert_eq(rows[index].title, tr(expected.title_key))
		assert_eq(
			rows[index].progress,
			tr("CONTRACT_BOARD_PROGRESS") % [expected.progress, expected.target]
		)
		assert_eq(rows[index].reward, tr("CONTRACT_BOARD_REWARD") % expected.reward)
	assert_eq(office.board.log_text(), PackedStringArray([tr("CONTRACT_BOARD_LOG_EMPTY")]))
	# Completion stays Economy's: the board only reflects it.
	Economy.active_contracts[0] = {"id": &"slot_rounds", "progress": 24}
	var balance := Wallet.balance
	Economy.record_round(&"slot_classic", _slot_loss())
	assert_eq(Wallet.balance, balance + 300)
	assert_eq(Economy.contract_completions, 1)
	assert_string_contains(office.board.log_text()[0], tr("CONTRACT_SLOT_ROUNDS"))
	assert_eq(office.board.row_data().size(), Economy.CONTRACT_SLOTS)
	SaveService.save()
	Economy.completion_log.clear()
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Economy.completion_log.size(), 1, "The completion log survives save and load")
	var close := InputEventAction.new()
	close.action = &"back"
	close.pressed = true
	_floor._unhandled_input(close)
	assert_false(office.board.is_open())
	assert_eq(_floor.room.id, OFFICE, "Back closes the board before leaving the room")


func test_hud_contract_lines_share_the_board_rows() -> void:
	var lines := Economy.contract_lines()
	var rows := Economy.contract_rows()
	assert_eq(lines.size(), rows.size())
	for index: int in range(rows.size()):
		assert_string_contains(lines[index], tr(rows[index].title_key))


# --- The Manager: markers and invitations ----------------------------------


func test_markers_moved_from_the_cashier_to_the_manager_with_the_same_rules() -> void:
	Wallet.reset(10)
	Economy.debt = 0
	_floor.avatar_position = FloorController.CASHIER_POSITION
	_floor.refresh_proximity()
	assert_true(_floor.interact())
	assert_false(_floor._cashier_marker.visible, "The cashier no longer offers markers")
	assert_false(_floor._cashier_repay.visible)
	_floor._close_cashier()
	var office := _enter_office_at(&"manager")
	assert_true(_floor.interact(), "Speaking with the Manager")
	assert_has(office.dialogue.choice_ids(), &"markers")
	office.dialogue.choice_selected.emit(&"markers")
	assert_true(_floor._cashier_open)
	assert_true(_floor._cashier_marker.visible)
	assert_eq(_floor._cashier_title.text, tr("MARKER_DESK_NAME"))
	assert_eq(_floor._cashier_marker.disabled, not Economy.can_take_marker())
	_floor._cashier_marker.pressed.emit()
	assert_eq(Wallet.balance, 10 + Economy.MARKER_STIPEND, "Same stipend as the old cashier")
	assert_eq(Economy.debt, Economy.MARKER_STIPEND)
	assert_true(_floor._cashier_marker.disabled, "Above the solvency floor, no second marker")
	_floor._cashier_repay_amount = 40
	_floor._cashier_repay.pressed.emit()
	assert_eq(Economy.debt, Economy.MARKER_STIPEND - 40)
	assert_eq(Wallet.balance, 10 + Economy.MARKER_STIPEND - 40)
	SaveService.state = null
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Economy.debt, Economy.MARKER_STIPEND - 40, "The marker is saved as before")


func test_manager_invites_once_per_wing_and_the_invitation_persists() -> void:
	Economy.lifetime_wagered = FloorController.WING_THRESHOLDS[FloorController.HIGH_ROLLER]
	assert_eq(OfficeState.pending_invitations(_floor), [FloorController.HIGH_ROLLER])
	_floor.avatar_position = _floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR)
	_floor.refresh_proximity()
	assert_eq(_floor._prompt.text, tr("OFFICE_DOOR_INVITATION") % InputRouter.glyph("interact"))
	var office := _enter_office_at(&"manager")
	assert_true(_floor.interact())
	assert_eq(office.dialogue.choice_ids(), [&"invitation"] as Array[StringName])
	office.dialogue.choice_selected.emit(&"invitation")
	assert_true(office.invitation.is_open())
	assert_eq(office.invitation.title_text(), tr("INVITE_WING_HIGH_ROLLER"))
	assert_true(_floor._cashier_panel.visible == false)
	assert_has(SaveService.state.wing_invitations, "high_roller")
	office.invitation.accept_button().pressed.emit()
	assert_false(office.invitation.is_open())
	assert_has(office.dialogue.choice_ids(), &"markers", "Business resumes after the card")
	office.end_conversation()
	SaveService.state = null
	assert_eq(SaveService.load_game(), OK)
	assert_true(OfficeState.has_invitation(FloorController.HIGH_ROLLER))
	assert_true(OfficeState.pending_invitations(_floor).is_empty())
	_floor.refresh_proximity()
	assert_true(_floor.interact(), "A second visit goes straight to business")
	assert_has(office.dialogue.choice_ids(), &"markers")
	assert_does_not_have(office.dialogue.choice_ids(), &"invitation")
	assert_true(_floor.is_wing_unlocked(FloorController.HIGH_ROLLER), "Unlock rule unchanged")


func test_test_bank_invitations_never_mark_the_real_save() -> void:
	Wallet.set_test_mode(true)
	assert_eq(OfficeState.pending_invitations(_floor).size(), 2, "Test mode opens both wings")
	OfficeState.record_invitation(FloorController.VIP)
	assert_true(OfficeState.has_invitation(FloorController.VIP))
	assert_false(SaveService.state.wing_invitations.has("vip"))


# --- The secretary's tour ---------------------------------------------------


func test_new_saves_start_the_tour_and_legacy_saves_do_not() -> void:
	assert_eq(SaveService.state.tutorial_state, SaveGame.TUTORIAL_PENDING)
	assert_eq(SaveGame.from_dict({}).tutorial_state, SaveGame.TUTORIAL_DONE)
	assert_eq(
		SaveGame.from_dict({"tutorial_state": "bogus"}).tutorial_state, SaveGame.TUTORIAL_DONE
	)
	assert_true(_floor.begin_first_run_tutorial())
	var office := _floor.office_host()
	assert_true(office.tutorial.is_active())
	assert_eq(office.tutorial.current_step_id(), &"welcome")
	assert_false(_floor.begin_first_run_tutorial(), "One tour at a time")
	assert_eq(office.dialogue.speaker_text(), tr("SPEAKER_SECRETARY"))


func test_tour_advances_on_real_actions_and_saves_completion() -> void:
	var office := _floor.office_host()
	var tour := office.tutorial
	assert_true(_floor.begin_first_run_tutorial())
	assert_true(office.blocks_movement(), "A talking step holds the player")
	office.dialogue.choice_selected.emit(&"tutorial_next")
	assert_eq(tour.current_step_id(), &"move")
	assert_false(office.blocks_movement(), "Action steps leave the floor free")
	_floor.move_avatar(Vector2.LEFT, 0.25)
	assert_eq(tour.current_step_id(), &"move", "A short shuffle is not yet a walk")
	_floor.move_avatar(Vector2.LEFT, 0.25)
	assert_eq(tour.current_step_id(), &"inlay", "Walking completes the move step")
	_floor.avatar_position = _floor.cabinet_positions[&"slot_classic"]
	_floor.refresh_proximity()
	assert_eq(tour.current_step_id(), &"join", "Reaching an inlay completes that step")
	var secondary := InputEventAction.new()
	secondary.action = &"secondary"
	secondary.pressed = true
	_floor._unhandled_input(secondary)
	for expected: StringName in [&"cashier", &"contracts", &"manager", &"help"]:
		assert_eq(tour.current_step_id(), expected)
		office.dialogue.choice_selected.emit(&"tutorial_next")
	assert_false(tour.is_active())
	assert_eq(SaveService.state.tutorial_state, SaveGame.TUTORIAL_DONE)
	SaveService.state = null
	assert_eq(SaveService.load_game(), OK)
	assert_eq(OfficeState.tutorial_state(), SaveGame.TUTORIAL_DONE)
	assert_false(_floor.begin_first_run_tutorial(), "A finished tour does not restart")


func test_tour_is_skippable_at_any_step_and_the_skip_is_saved() -> void:
	var office := _floor.office_host()
	assert_true(_floor.begin_first_run_tutorial())
	office.dialogue.choice_selected.emit(&"tutorial_next")
	var back := InputEventAction.new()
	back.action = &"back"
	back.pressed = true
	_floor._unhandled_input(back)
	assert_false(office.tutorial.is_active())
	assert_false(office.dialogue.is_open())
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR, "Skipping never leaves the floor")
	SaveService.state = null
	assert_eq(SaveService.load_game(), OK)
	assert_eq(OfficeState.tutorial_state(), SaveGame.TUTORIAL_SKIPPED)


func test_tour_replays_from_reception() -> void:
	OfficeState.set_tutorial_state(SaveGame.TUTORIAL_DONE)
	var office := _enter_office_at(&"reception")
	assert_true(_floor.interact())
	assert_has(office.dialogue.choice_ids(), &"tour")
	office.dialogue.choice_selected.emit(&"tour")
	assert_true(office.tutorial.is_active())
	assert_true(office.tutorial.replaying)
	assert_eq(office.tutorial.current_step_id(), &"welcome")
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR, "The tour is given on the floor")


func test_speaking_motion_is_subtle_and_reduced_motion_is_static() -> void:
	var office := _floor.office_host()
	MotionPolicy.set_reduced_motion_for_tests(false)
	assert_true(_floor.begin_first_run_tutorial())
	assert_true(office.dialogue.is_revealing(), "Full motion reveals the line")
	assert_eq(office.dialogue.visible_body_characters(), 0)
	var cameo := office.dialogue.cameo_texture_rect()
	var largest_scale := 0.0
	var largest_bob := 0.0
	for _frame: int in range(40):
		office.dialogue._process(1.0 / 60.0)
		largest_scale = maxf(largest_scale, cameo.scale.y - 1.0)
		largest_bob = maxf(largest_bob, absf(cameo.position.y))
		assert_eq(cameo.rotation, 0.0)
	assert_gt(largest_bob, 0.2, "She visibly talks")
	assert_lte(largest_bob, 2.0, "The talk bob stays within two pixels")
	assert_gt(largest_scale, 0.0, "She breathes")
	assert_lte(largest_scale, 0.01, "Breathing stays under one percent")
	assert_eq(cameo.pivot_offset.y, cameo.size.y, "Breathing rises from the frame edge")
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(office.dialogue.is_revealing())
	assert_eq(office.dialogue.visible_body_characters(), -1, "Reduced motion: whole line")
	assert_eq(cameo.scale, Vector2.ONE, "Reduced motion: static pose")
	assert_eq(cameo.position, Vector2.ZERO)
	office.dialogue.choice_selected.emit(&"tutorial_next")
	assert_eq(office.dialogue.visible_body_characters(), -1, "Instant text on every line")


func test_speaker_is_a_cameo_inside_the_panel_turned_toward_the_text() -> void:
	var office := _floor.office_host()
	assert_eq(office.dialogue.find_children("*", "TextureRect", true, false).size(), 1)
	# Main Floor tour: no one is painted here, so only the in-panel cameo speaks.
	for at: Vector2 in [Vector2(480, 408), Vector2(324, 246), Vector2(870, 266)]:
		_floor.avatar_position = at
		_floor.refresh_proximity()
		office.speak(&"secretary_point", tr("TUTORIAL_INLAY"), [] as Array[Dictionary])
		var panel := office.dialogue.panel_rect()
		assert_true(panel.encloses(office.dialogue.cameo_rect()), "The cameo stays in the panel")
		assert_true(office.dialogue.speaker_faces_text(), "She turns toward the text at %s" % at)
		assert_false(office.dialogue.pointer_visible(), "No pointer where she is not present")
		var near_left := panel.get_center().x < 480.0
		assert_eq(office.dialogue.cameo_side, &"left" if near_left else &"right")
	office.dialogue.close()
	# In the office the painted people are the speakers: the panel sits beside
	# them, points at them, and the cameo faces the text.
	for station: StringName in [&"reception", &"manager"]:
		_enter_office_at(station)
		assert_true(_floor.interact())
		assert_eq(office.dialogue.layout_name, &"anchored", "%s panel is anchored" % station)
		assert_true(office.dialogue.pointer_visible())
		assert_true(office.dialogue.speaker_faces_text(), "%s faces the text" % station)
		assert_eq(office.dialogue.cameo_side, &"right", "The cameo sits nearest the speaker")
		var painted := (
			(
				OfficeHost
				. OFFICE_PLACEMENTS[&"secretary" if station == &"reception" else &"manager"]
				. pointer
			)
			as Vector2
		)
		assert_false(
			office.dialogue.occupied_rect().has_point(painted), "The painted speaker stays visible"
		)
		office.end_conversation()


func test_every_pose_of_a_person_shares_one_colour_grade() -> void:
	for person: Array in [
		["secretary", ["secretary_explain", "secretary_point"], OfficeHost.SECRETARY_REGION],
		["manager", ["manager_offer", "manager_toast"], OfficeHost.MANAGER_REGION],
	]:
		var base := _head_colour(person[0], person[2])
		for pose: String in person[1]:
			var colour := _head_colour(pose, person[2])
			for channel: int in range(3):
				assert_almost_eq(
					colour[channel], base[channel], 0.07, "%s matches %s" % [pose, person[0]]
				)


# --- Layout: never covering the player, targets or HUD; TV-safe; 44px -----


func test_dialogue_never_covers_the_player_or_hud_controls() -> void:
	var stations: Array[Array] = [
		[FloorController.MAIN_FLOOR, Vector2(480, 408)],
		[FloorController.MAIN_FLOOR, Vector2(324, 246)],
		[FloorController.MAIN_FLOOR, Vector2(671, 246)],
		[FloorController.MAIN_FLOOR, FloorController.CASHIER_POSITION],
		[FloorController.MAIN_FLOOR, Vector2(870, 266)],
		[FloorController.MAIN_FLOOR, Vector2(150, 274)],
		[OFFICE, Vector2(480, 522)],
		[OFFICE, Vector2(744, 452)],
		[OFFICE, Vector2(480, 238)],
	]
	var office := _floor.office_host()
	for station: Array in stations:
		_floor.enter_room(station[0])
		_floor.avatar_position = station[1]
		_floor._avatar_visual.position = station[1]
		_floor.refresh_proximity()
		var rects := office.avoid_rects()
		var choices: Array[Dictionary] = [{"id": &"leave", "label": tr("DIALOGUE_GOODBYE")}]
		office.speak(&"secretary", tr("TUTORIAL_WELCOME"), choices)
		var placed := office.dialogue.occupied_rect()
		assert_true(TV_SAFE.encloses(placed), "%s stays TV-safe" % placed)
		for blocked: Rect2 in rects.hard:
			assert_false(
				placed.intersects(blocked), "%s clears %s at %s" % [placed, blocked, station]
			)
		office.dialogue.close()


func test_office_panels_are_tv_safe_with_44px_targets() -> void:
	var office := _enter_office_at(&"manager")
	for layout: Dictionary in DialoguePanel.LAYOUTS:
		assert_true(TV_SAFE.encloses(layout.panel), "Panel %s is TV-safe" % layout.name)
	for placement: Dictionary in OfficeHost.OFFICE_PLACEMENTS.values():
		assert_true(TV_SAFE.encloses(placement.panel), "Office panel %s is TV-safe" % placement)
	assert_true(TV_SAFE.encloses(ContractsBoard.RECT))
	assert_true(TV_SAFE.encloses(WingInvitationCard.RECT))
	var back := _floor.room_back_button_rect()
	assert_false(ContractsBoard.RECT.intersects(back), "The board leaves the Back control clear")
	assert_false(WingInvitationCard.RECT.intersects(back))
	var player := Rect2(_floor.avatar_position - Vector2(20, 96), Vector2(40, 98))
	assert_false(WingInvitationCard.RECT.intersects(player), "The card leaves the player clear")
	office.talk_to_manager()
	var buttons: Array[Button] = office.dialogue.choice_buttons()
	office.open_contracts_board()
	buttons.append(office.board.close_button())
	buttons.append(office.invitation.accept_button())
	for button: Button in buttons:
		assert_gte(button.size.y, 44.0, "%s is a 44px target" % button.name)
		assert_gte(button.size.x, 44.0)


func test_contract_hud_text_is_gone_from_the_main_hud() -> void:
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	assert_false("_contracts" in main)
	assert_false("_contracts_panel" in main)


# --- Helpers ----------------------------------------------------------------


func _enter_office_at(station: StringName) -> OfficeHost:
	_floor.enter_room(OFFICE)
	_floor.avatar_position = _floor.room.anchor(station)
	_floor._avatar_visual.position = _floor.avatar_position
	_floor.refresh_proximity()
	return _floor.office_host()


## Mean colour of the opaque head texels at the top of a pose's cameo region.
func _head_colour(pose: String, region: Rect2) -> Color:
	var image := TexturePixels.readable(
		load("res://assets/production/characters/staff/%s.png" % pose) as Texture2D
	)
	var total := Vector3.ZERO
	var count := 0
	for y: int in range(int(region.position.y) + 120, int(region.position.y) + 300, 3):
		for x: int in range(int(region.get_center().x) - 70, int(region.get_center().x) + 70, 3):
			var texel := image.get_pixel(x, y)
			if texel.a > 0.98 and texel.r > texel.g and texel.g > texel.b:
				total += Vector3(texel.r, texel.g, texel.b)
				count += 1
	assert_gt(count, 100, "%s has a lit face to measure" % pose)
	total /= float(count)
	return Color(total.x, total.y, total.z)


func _slot_loss() -> RoundResult:
	return RoundResult.create(
		10,
		0,
		RoundResult.Outcome.LOSS,
		{
			"symbols":
			[
				SlotMachineMath.Symbol.CHERRY,
				SlotMachineMath.Symbol.LEMON,
				SlotMachineMath.Symbol.BELL
			]
		}
	)


func _reachable_cells(room: FloorRoomLayout) -> Dictionary:
	var start := Vector2i(roundi(room.spawn.x / 4.0), roundi(room.spawn.y / 4.0))
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
