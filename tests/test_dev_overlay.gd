extends GutTest
## The debug-only developer overlay: release gate, widget placement and
## persistence, room/spot/table navigation from anywhere, dev-flagged chip
## actions, test toggles and keyboard navigation of the panel.

const OVERLAY_SCRIPT := preload("res://src/ui/dev_menu/dev_overlay.gd")
## Everything the widget must never cover, in the 960x540 virtual canvas.
const HUD_RECTS: Dictionary = {
	"cabinet control deck": Rect2(48, 426, 864, 102),
	"floor bank HUD": Rect2(18, 10, 168, 52),
	"floor prompt band": Rect2(56, 454, 848, 54),
	"room back button": Rect2(48, 452, 212, 48),
}
const SCREEN := Rect2(0, 0, 960, 540)

var _original_platform: PlatformServices
var _original_test_mode: bool
var _floor: FloorController
var _overlay: CanvasLayer
var _settings_path: String


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	SaveService.platform = LocalPlatform.new("user://tests/dev_overlay_%s" % Time.get_ticks_usec())
	SaveService.new_game(20260919)
	OfficeState.clear_session()
	MotionPolicy.set_reduced_motion_for_tests(true)
	_floor = FloorController.new()
	add_child_autofree(_floor)
	_floor.set_physics_process(false)
	SceneRouter.register_floor(_floor)
	_settings_path = "user://tests/dev_overlay_settings_%s.cfg" % Time.get_ticks_usec()
	_overlay = _new_overlay(true)


func after_each() -> void:
	SceneRouter.return_to_floor()
	await get_tree().process_frame
	SceneRouter.floor = null
	MotionPolicy.clear_test_override()
	OfficeState.clear_session()
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	SaveService.new_game(20260919)


func _new_overlay(debug_build: bool) -> CanvasLayer:
	var overlay: CanvasLayer = OVERLAY_SCRIPT.new()
	overlay.debug_build_override = debug_build
	overlay.settings_path = _settings_path
	add_child_autofree(overlay)
	return overlay


func _panel() -> DevPanel:
	return _overlay.get("panel") as DevPanel


func _actions() -> DevActions:
	return _overlay.get("actions") as DevActions


func _launcher() -> DevLauncher:
	return _overlay.get("launcher") as DevLauncher


func _row(section: int, row_name: String) -> Button:
	_panel().select_section(section)
	for button: Button in _panel().items:
		if button.name == row_name:
			return button
	fail_test("Missing developer row %s" % row_name)
	return null


func _press(section: int, row_name: String) -> void:
	_overlay.call("open_panel")
	var button := _row(section, row_name)
	assert_false(button.disabled, "%s is available" % row_name)
	button.pressed.emit()
	await get_tree().process_frame


func _avatar_count() -> int:
	return (
		_floor
		. find_children("*", "", true, false)
		. filter(func(node: Node) -> bool: return node.get_script() == FloorAvatar)
		. size()
	)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# --- Release gate -------------------------------------------------------------------


func test_release_export_adds_nothing_and_handles_no_input() -> void:
	var release := _new_overlay(false)
	assert_false(bool(release.get("enabled")))
	assert_eq(release.get_child_count(), 0, "A release build adds no nodes at all")
	assert_false(release.is_processing_input(), "A release build handles no input")
	assert_false(release.is_processing())
	release.call("open_panel", true)
	assert_eq(release.get_child_count(), 0, "Opening is a no-op in release")
	assert_false(OVERLAY_SCRIPT.is_enabled_for(false))
	assert_true(OVERLAY_SCRIPT.is_enabled_for(true))


func test_autoload_is_registered_and_live_in_debug_runs() -> void:
	var registered := String(ProjectSettings.get_setting("autoload/DevOverlay", ""))
	assert_eq(registered, "*res://src/ui/dev_menu/dev_overlay.gd")
	var autoload := get_tree().root.get_node_or_null("DevOverlay") as CanvasLayer
	assert_not_null(autoload)
	assert_true(bool(autoload.get("enabled")), "Headless test runs are debug builds")
	assert_gt(autoload.layer, 10, "Above the HUD layer")


# --- Widget ---------------------------------------------------------------------------


func test_widget_sits_in_bounds_bottom_left_and_clear_of_the_hud() -> void:
	var launcher := _launcher()
	var rect := Rect2(launcher.position, launcher.size)
	assert_true(SCREEN.encloses(rect), "The widget is fully on screen")
	assert_gte(rect.size.x, 44.0, "44 px target")
	assert_gte(rect.size.y, 44.0, "44 px target")
	assert_lt(rect.get_center().x, 480.0, "Bottom-left by default")
	assert_gt(rect.get_center().y, 270.0, "Bottom-left by default")
	for label: String in HUD_RECTS:
		assert_false(rect.intersects(HUD_RECTS[label]), "Widget clears the %s" % label)
	assert_eq(launcher.focus_mode, Control.FOCUS_NONE, "A closed widget never takes focus")
	assert_false(_panel().visible, "The panel starts closed")
	assert_almost_eq(launcher.modulate.a, DevLauncher.REST_ALPHA, 0.01, "Translucent at rest")


func test_widget_snaps_to_an_edge_and_the_spot_persists() -> void:
	var screen := Vector2(960, 540)
	assert_eq(DevLauncher.snap_to_edge(Vector2(900, 260), screen).x, 914.0)
	assert_eq(DevLauncher.snap_to_edge(Vector2(400, 10), screen).y, 2.0)
	assert_eq(DevLauncher.snap_to_edge(Vector2(400, 530), screen).y, 494.0)
	assert_eq(DevLauncher.snap_to_edge(Vector2(-80, 900), screen), Vector2(2, 540 - 44 - 2))
	_launcher().dropped.emit(Vector2(930, 200))
	var parked := _launcher().position
	assert_eq(parked, Vector2(960 - 44 - 2, 200), "Dropped on the right edge")
	var reloaded := _new_overlay(true)
	var reloaded_launcher: DevLauncher = reloaded.get("launcher")
	assert_eq(reloaded_launcher.position, parked, "The spot survives a restart")
	reloaded.call("open_panel")
	var panel: DevPanel = reloaded.get("panel")
	assert_lt(panel.position.x + panel.size.x, parked.x, "The panel opens away from the edge")
	assert_true(SCREEN.encloses(Rect2(panel.position, panel.size)))


func test_panel_rows_are_44px_and_inside_the_panel() -> void:
	_overlay.call("open_panel")
	var panel := _panel()
	assert_true(SCREEN.encloses(Rect2(panel.position, panel.size)), "Panel stays on screen")
	for section: int in range(DevPanel.SECTION_NAMES.size()):
		panel.select_section(section)
		for button: Button in panel.focus_order():
			assert_gte(maxf(button.size.y, button.custom_minimum_size.y), 44.0, "%s" % button.name)


# --- Navigation ---------------------------------------------------------------------


func test_every_room_and_spot_button_arrives_with_one_player() -> void:
	var avatar := _floor._avatar_visual
	var balance := Wallet.balance
	for room_id: StringName in FloorController.ROOM_IDS:
		await _press(DevPanel.Section.ROOMS, "DevRoom_%s" % room_id)
		assert_false(_panel().visible, "Travel closes the panel")
		assert_eq(_floor.room.id, room_id, "Room button switches the whole environment")
		assert_same(_floor._avatar_visual, avatar)
	for spot: Dictionary in DevActions.destinations():
		await _press(DevPanel.Section.ROOMS, "DevSpot_%s_%s" % [spot.room, spot.anchor])
		assert_eq(_floor.room.id, spot.room)
		assert_eq(_floor.avatar_position, spot.position, "%s" % spot.label)
		assert_true(_floor.room.is_walkable(spot.position), "%s is open floor" % spot.label)
	assert_eq(_avatar_count(), 1, "Travel never creates a second player")
	assert_eq(Wallet.balance, balance, "Travel never touches the wallet")
	assert_false(_floor.dev_overlay_open, "Closing hands movement back to the floor")


func test_main_floor_spots_cover_cashier_office_wings_and_every_table() -> void:
	var anchors: Array[StringName] = []
	for spot: Dictionary in DevActions.destinations():
		if spot.room == FloorController.MAIN_FLOOR:
			anchors.append(spot.anchor)
	for required: StringName in [
		&"spawn",
		&"cashier",
		&"office",
		&"high_roller",
		&"vip",
		&"slot_classic",
		&"blackjack",
		&"minefield_vault"
	]:
		assert_has(anchors, required)


func test_every_table_opens_from_anywhere_and_returns_safely() -> void:
	Wallet.set_test_mode(true)
	var launcher_rect := Rect2(_launcher().position, _launcher().size)
	for cabinet_id: StringName in DevActions.cabinets():
		await _press(DevPanel.Section.GAMES, "DevGame_%s" % cabinet_id)
		var session := SceneRouter.session
		assert_not_null(session, "%s opened" % cabinet_id)
		assert_eq(_actions().active_cabinet_id(), cabinet_id, "The requested table is open")
		var seat := DevActions.cabinet_room(cabinet_id)
		if seat != &"":
			assert_eq(_floor.room.id, seat, "Seated in its own room")
		assert_eq(_avatar_count(), 1, "Opening %s never duplicates the player" % cabinet_id)
		for node: Node in session.find_children("*", "Control", true, false):
			var control := node as Control
			var interactive := control is BaseButton or String(control.name).contains("Deck")
			if interactive and control.is_visible_in_tree():
				assert_false(
					launcher_rect.intersects(control.get_global_rect()),
					"Widget clears %s in %s" % [control.name, cabinet_id]
				)
	var last_room := _floor.room.id
	await _press(DevPanel.Section.ROOMS, "DevRoom_%s" % FloorController.MAIN_FLOOR)
	assert_null(SceneRouter.session, "Room travel leaves the table through the router")
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR)
	assert_ne(last_room, &"")
	assert_eq(_avatar_count(), 1)


func test_a_table_short_of_chips_refuses_without_entering() -> void:
	Wallet.reset(0)
	assert_false(await _actions().open_cabinet(&"baccarat"))
	assert_null(SceneRouter.session)
	assert_string_contains(_actions().last_status, "needs")
	assert_eq(Wallet.balance, 0)


# --- Chips and toggles ------------------------------------------------------------------


func test_chip_actions_are_dev_flagged_and_respect_the_test_bank() -> void:
	var actions := _actions()
	assert_string_starts_with(_row(DevPanel.Section.TEST, "DevAction_grant").text, "DEV")
	assert_string_starts_with(_row(DevPanel.Section.TEST, "DevAction_low_bank").text, "DEV")
	Wallet.set_test_mode(true)
	assert_true(_row(DevPanel.Section.TEST, "DevAction_grant").disabled)
	assert_false(actions.grant_chips(), "The unlimited bank needs no grant")
	assert_eq(Wallet.persistent_balance(), 200, "The real bank is untouched")
	Wallet.set_test_mode(false)
	assert_true(actions.grant_chips())
	assert_eq(Wallet.balance, 200 + DevActions.DEV_GRANT)
	assert_string_contains(actions.last_status, "DEV")
	Wallet.set_test_mode(true)
	assert_true(actions.set_low_bank())
	assert_false(Wallet.test_mode_enabled, "Low bank leaves the test bank")
	assert_eq(Wallet.balance, DevActions.LOW_BANK)
	assert_true(Economy.is_below_solvency_floor(), "Ten chips is under the marker floor")
	assert_eq(SaveService.save(), OK)
	assert_eq(SaveService.state.chips, DevActions.LOW_BANK, "The save stays a valid profile")


func test_money_never_changes_under_a_live_table() -> void:
	Wallet.set_test_mode(true)
	assert_true(await _actions().open_cabinet(&"slot_classic"))
	assert_false(_actions().toggle_test_bank())
	assert_false(_actions().grant_chips())
	assert_false(_actions().set_low_bank())
	assert_true(Wallet.test_mode_enabled, "The bank a table opened with stays put")
	assert_true(_row(DevPanel.Section.TEST, "DevToggle_test_bank").disabled)
	assert_true(_row(DevPanel.Section.TEST, "DevToggle_collision").disabled, "Floor only")


func test_toggles_flip_real_game_state() -> void:
	var actions := _actions()
	assert_true(actions.toggle_collision_overlay())
	assert_true(_floor.collision_overlay_visible())
	assert_true(actions.toggle_collision_overlay())
	assert_false(_floor.collision_overlay_visible())
	assert_true(actions.toggle_test_bank())
	assert_true(Wallet.test_mode_enabled)
	assert_true(actions.toggle_test_bank())
	assert_false(Wallet.test_mode_enabled)
	var persisted := MotionPolicy.persistence_enabled
	var reduced := MotionPolicy.is_reduced()
	MotionPolicy.persistence_enabled = false
	MotionPolicy.clear_test_override()
	var before := MotionPolicy.is_reduced()
	assert_true(actions.toggle_reduced_motion())
	assert_ne(MotionPolicy.is_reduced(), before)
	MotionPolicy.set_reduced_motion(before)
	MotionPolicy.persistence_enabled = persisted
	MotionPolicy.set_reduced_motion_for_tests(reduced)
	_overlay.call("toggle_fps")
	assert_true(bool(_overlay.call("fps_visible")))
	_overlay.call("toggle_fps")
	assert_false(bool(_overlay.call("fps_visible")))


func test_wing_unlock_is_session_only() -> void:
	assert_false(_floor.is_wing_unlocked(FloorController.VIP))
	assert_true(_actions().toggle_wings())
	assert_true(_floor.is_wing_unlocked(FloorController.HIGH_ROLLER))
	assert_true(_floor.is_wing_unlocked(FloorController.VIP))
	OfficeState.record_invitation(FloorController.VIP)
	assert_true(OfficeState.has_invitation(FloorController.VIP))
	assert_false(SaveService.state.wing_invitations.has("vip"), "Unearned: not saved")
	assert_true(_actions().toggle_wings())
	assert_false(_floor.is_wing_unlocked(FloorController.VIP))


func test_tour_replay_and_reset_use_the_real_director() -> void:
	OfficeState.set_tutorial_state(SaveGame.TUTORIAL_DONE)
	assert_true(_actions().reset_tutorial())
	assert_eq(OfficeState.tutorial_state(), SaveGame.TUTORIAL_PENDING)
	_floor.enter_room(FloorController.VIP)
	assert_true(await _actions().replay_tutorial())
	var tour := _floor.office_host().tutorial
	assert_true(tour.is_active())
	assert_true(tour.replaying)
	assert_eq(_floor.room.id, FloorController.MAIN_FLOOR, "The tour starts on the Main Floor")
	tour.skip()


func test_glyph_toggle_is_wired_or_clearly_disabled() -> void:
	var row := _row(DevPanel.Section.TEST, "DevToggle_glyphs")
	var actions := _actions()
	if not actions.glyph_family_supported():
		assert_true(row.disabled)
		assert_string_contains(row.text, "not exposed")
		return
	assert_false(row.disabled)
	var device: int = InputRouter.get("active_device")
	var family: int = InputRouter.get("gamepad_family")
	for expected: String in ["Keyboard", "Xbox", "PlayStation", "Auto"]:
		assert_true(actions.cycle_glyph_family())
		assert_eq(actions.glyph_family_label(), expected)
		if expected == "PlayStation":
			assert_eq(InputRouter.get("active_device"), 1, "Pad prompts forced")
			assert_eq(InputRouter.get("gamepad_family"), 1, "PlayStation family pinned")
	assert_eq(InputRouter.get("_forced_family"), -1, "Auto releases the pin")
	InputRouter.call("force_prompt_family", device, family)
	InputRouter.call("force_prompt_family", -1, -1)


func test_info_reports_room_position_table_and_build() -> void:
	_floor.dev_warp(FloorController.MAIN_FLOOR, Vector2(480, 408))
	var lines := "\n".join(_actions().info_lines())
	assert_string_contains(lines, "Main Floor")
	assert_string_contains(lines, "480, 408")
	assert_string_contains(lines, "Table: none")
	assert_string_contains(lines, "Build: ")
	assert_string_contains(lines, "Godot 4.")
	assert_false(lines.to_lower().contains("higgsfield"), "The version names no vendor")
	_overlay.call("open_panel")
	_panel().select_section(DevPanel.Section.INFO)
	var shown := _panel().find_children("DevInfo_*", "Label", true, false)
	assert_eq(shown.size(), _actions().info_lines().size())


# --- Keyboard / controller ----------------------------------------------------------------


func test_keyboard_opens_navigates_activates_and_closes() -> void:
	var game_button := Button.new()
	add_child_autofree(game_button)
	game_button.grab_focus()
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F10
	toggle.pressed = true
	_overlay._input(toggle)
	var panel := _panel()
	assert_true(panel.visible, "F10 opens the panel")
	assert_true(_floor.dev_overlay_open, "The avatar holds still while the panel is open")
	assert_same(panel.focused_button(), panel.items[0], "Keyboard opens focus the first row")
	_overlay._input(_action(&"ui_down"))
	assert_same(panel.focused_button(), panel.items[1], "Down walks the rows")
	_overlay._input(_action(&"ui_up"))
	_overlay._input(_action(&"ui_up"))
	assert_same(panel.focused_button(), panel.tabs[DevPanel.Section.ROOMS], "Up reaches the tab")
	_overlay._input(_action(&"ui_right"))
	assert_eq(panel.section, DevPanel.Section.GAMES, "Right switches section")
	_overlay._input(_action(&"ui_right"))
	assert_eq(panel.section, DevPanel.Section.TEST)
	var fps_row := -1
	for index: int in range(panel.items.size()):
		if panel.items[index].name == "DevToggle_fps":
			fps_row = index
	for _step: int in range(fps_row + 1):
		_overlay._input(_action(&"ui_down"))
	assert_eq(panel.focused_button().name, "DevToggle_fps")
	_overlay._input(_action(&"ui_accept"))
	assert_true(bool(_overlay.call("fps_visible")), "Confirm presses the focused row")
	_overlay._input(_action(&"back"))
	assert_false(panel.visible, "Back closes the panel")
	assert_false(_floor.dev_overlay_open)
	assert_true(game_button.has_focus(), "Closing hands focus back to the game")
	var backquote := InputEventKey.new()
	backquote.keycode = KEY_QUOTELEFT
	backquote.pressed = true
	_overlay._input(backquote)
	assert_true(panel.visible, "` also toggles")
	_overlay._input(backquote)
	assert_false(panel.visible)


func test_mouse_open_leaves_game_focus_alone() -> void:
	var game_button := Button.new()
	add_child_autofree(game_button)
	game_button.grab_focus()
	_launcher().activated.emit()
	assert_true(_panel().visible, "A click opens the panel")
	assert_true(game_button.has_focus(), "A mouse open shows no focus ring")
	_launcher().activated.emit()
	assert_false(_panel().visible, "A second click closes it")
	assert_true(game_button.has_focus())


func test_the_table_list_is_built_from_the_scene_registry() -> void:
	var listed := DevActions.cabinets()
	for cabinet_id: StringName in CabinetSceneRegistry.SCENE_PATHS:
		if not CabinetSceneRegistry.has_scene(cabinet_id):
			continue
		if DevActions.definition(cabinet_id) == null:
			continue
		assert_has(listed, cabinet_id, "%s is offered without editing the menu" % cabinet_id)
		assert_not_null(
			_row(DevPanel.Section.GAMES, "DevGame_%s" % cabinet_id), "%s has a row" % cabinet_id
		)
	assert_eq(listed.size(), listed.duplicate().size(), "No table is listed twice")


func test_standing_row_is_dev_flagged_and_walks_the_ladder() -> void:
	var actions := _actions()
	var row := _row(DevPanel.Section.TEST, "DevAction_standing")
	assert_string_starts_with(row.text, "DEV")
	var balance := Wallet.balance
	for step: int in range(HouseLevel.TIERS.size()):
		assert_true(actions.cycle_standing())
	assert_eq(Wallet.balance, balance, "Standing never mints chips")
	assert_eq(Economy.lifetime_wagered, 0, "The ladder wraps back to the first rung")
