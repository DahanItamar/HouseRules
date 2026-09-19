extends GutTest

const MAIN_SCENE := preload("res://src/ui/main.tscn")
const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")
var _original_platform: PlatformServices
var _original_test_mode: bool
var _original_reduced_motion: bool
var _original_motion_path: String
var _original_motion_persistence: bool


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	_original_reduced_motion = bool(ProjectSettings.get_setting(MotionPolicy.SETTING_PATH, false))
	_original_motion_path = MotionPolicy.preference_path
	_original_motion_persistence = MotionPolicy.persistence_enabled
	MotionPolicy.persistence_enabled = false
	SaveService.platform = LocalPlatform.new("user://tests/ui_%s" % Time.get_ticks_usec())
	SaveService.new_game(20260918)


func after_each() -> void:
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	MotionPolicy.set_reduced_motion(_original_reduced_motion)
	MotionPolicy.preference_path = _original_motion_path
	MotionPolicy.persistence_enabled = _original_motion_persistence
	SaveService.new_game(20260918)


func test_cashier_recovery_uses_floor_waypoint_not_a_global_game_banner() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	Wallet.set_test_mode(false)
	Wallet.reset(Economy.SOLVENCY_FLOOR - 1)
	main._message_panel.visible = false
	main._refresh_hud()
	assert_false(main._message_panel.visible, "Recovery guidance never covers a cabinet screen")


func test_ac042_all_runtime_labels_respect_the_body_text_floor() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var labels := main.find_children("*", "Label", true, false)
	assert_gt(labels.size(), 0)
	for label: Label in labels:
		assert_gte(
			label.get_theme_font_size("font_size"),
			Typography.BODY_MIN,
			"%s respects the body-text floor" % label.name
		)


func test_casino_ui_uses_bundled_msdf_ready_fonts() -> void:
	assert_not_null(Typography.UI_FONT)
	assert_not_null(Typography.DISPLAY_FONT)
	assert_string_contains(Typography.UI_FONT.resource_path, "BarlowCondensed-Medium.ttf")
	assert_string_contains(Typography.DISPLAY_FONT.resource_path, "BarlowCondensed-SemiBold.ttf")
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	assert_eq(session.cabinet.panel._title.get_theme_font("font"), Typography.DISPLAY_FONT)
	assert_eq(
		session.cabinet.panel._stake_selector._buttons[0].get_theme_font("font"),
		Typography.UI_FONT
	)


func test_ac042_chips_stake_and_multiplier_use_critical_text() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_gte(main._hud.get_theme_font_size("font_size"), Typography.CRITICAL)

	var definition: CabinetDefinition = VAULT_DEFINITION
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(definition)
	var panel: CabinetPanel = session.cabinet.panel
	assert_gte(panel._stake.get_theme_font_size("font_size"), Typography.CRITICAL)
	assert_gte(panel._detail.get_theme_font_size("font_size"), Typography.CRITICAL)


func test_each_game_has_chip_stakes_and_contextual_help() -> void:
	for definition: CabinetDefinition in [SLOT_DEFINITION, BLACKJACK_DEFINITION, VAULT_DEFINITION]:
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(definition)
		var game: MiniGame = session.cabinet
		var panel: CabinetPanel = game.panel
		assert_not_null(panel.find_child("StakeSelector", true, false))
		assert_not_null(panel.find_child("HowToPlayButton", true, false))
		assert_false(panel._controls.visible, "Key legend stays off the play surface")
		panel.set_help_open(true)
		assert_true(panel._help_overlay.visible)
		assert_string_contains(panel._help_title.text, tr(definition.name_key))
		assert_false(panel._help_rules.text.begins_with("HELP_"), "Rules are localized")
		panel.set_help_open(false)
		await wait_seconds(0.16)
		assert_false(panel._help_overlay.visible)


func test_hud_messages_have_bounded_reveal_and_dismiss_motion() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main._present_message("Contract complete")
	assert_true(main._message_panel.visible)
	assert_true(main._message.visible)
	assert_not_null(main._message_tween)
	main._dismiss_message()
	await wait_seconds(0.16)
	assert_false(main._message_panel.visible)
	assert_false(main._message.visible)
	assert_eq(main._message.text, "")


func test_global_hud_reacts_to_balance_and_contract_changes() -> void:
	MotionPolicy.set_reduced_motion(false)
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main._is_playing = true
	main._refresh_hud()
	main._on_balance_changed(100, 125)
	assert_gt(main._chip_icon.transaction_time, 0.0)
	assert_eq(main._chip_icon.transaction_direction, 1)
	assert_not_null(main._bank_feedback_tween)
	main._on_contracts_changed()
	assert_not_null(main._contract_feedback_tween)
	assert_lt(main._contracts.position.x, 623.0)


func test_reduced_motion_hud_keeps_static_transaction_feedback() -> void:
	MotionPolicy.set_reduced_motion(true)
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	main._is_playing = true
	main._refresh_hud()
	main._on_balance_changed(50, 40)
	assert_eq(main._bank_panel.scale, Vector2.ONE)
	assert_null(main._bank_feedback_tween)
	assert_eq(main._chip_icon.transaction_direction, -1)
	assert_gt(main._chip_icon.transaction_time, 0.0)


func test_stakes_move_between_casino_denominations() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_eq(game.stake_options(), [1, 2, 5, 10, 25, 50])
	game.selected_stake = 1
	assert_true(game.adjust_stake(1))
	assert_eq(game.selected_stake, 2)
	assert_true(game.adjust_stake(1))
	assert_eq(game.selected_stake, 5)


func test_available_stakes_include_an_exact_balance_cap_and_step_adjacent() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(VAULT_DEFINITION)
	var game: MiniGame = session.cabinet
	game.context.balance = 18
	game.selected_stake = 11
	assert_eq(game.available_stakes(), [1, 2, 5, 10, 18])
	assert_true(game.adjust_stake(-1))
	assert_eq(game.selected_stake, 10, "Left chooses the adjacent denomination")
	game.selected_stake = 11
	assert_true(game.adjust_stake(1))
	assert_eq(game.selected_stake, 18, "Right chooses the exact balance cap")


func test_shared_bet_console_applies_exact_add_and_multiplier_operations() -> void:
	var slot_session := CabinetSession.new()
	add_child_autofree(slot_session)
	slot_session.begin(SLOT_DEFINITION)
	var slot: MiniGame = slot_session.cabinet
	assert_eq(slot.selected_stake, 1)
	assert_true(slot.apply_bet(MiniGame.BetOperation.ADD_10))
	assert_eq(slot.selected_stake, 11)
	assert_true(slot.apply_bet(MiniGame.BetOperation.ADD_25))
	assert_eq(slot.selected_stake, 36)
	assert_false(slot.apply_bet(MiniGame.BetOperation.MULTIPLY_2), "72 exceeds the exact 50 cap")
	assert_eq(slot.selected_stake, 36, "Rejected operations never silently clamp the wager")
	assert_true(slot.apply_bet(MiniGame.BetOperation.MAX))
	assert_eq(slot.selected_stake, 50)
	assert_true(slot.apply_bet(MiniGame.BetOperation.MIN))
	assert_eq(slot.selected_stake, 1)

	var blackjack_session := CabinetSession.new()
	add_child_autofree(blackjack_session)
	blackjack_session.begin(BLACKJACK_DEFINITION)
	var blackjack: MiniGame = blackjack_session.cabinet
	assert_eq(blackjack.selected_stake, 5)
	assert_true(blackjack.apply_bet(MiniGame.BetOperation.ADD_10))
	assert_true(blackjack.apply_bet(MiniGame.BetOperation.ADD_25))
	assert_true(blackjack.apply_bet(MiniGame.BetOperation.MULTIPLY_2))
	assert_eq(blackjack.selected_stake, 80)
	assert_false(blackjack.apply_bet(MiniGame.BetOperation.MULTIPLY_5))


func test_shared_bet_console_respects_balance_and_locks_during_rounds() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(VAULT_DEFINITION)
	var game: MiniGame = session.cabinet
	game.context.balance = 18
	game.normalize_selected_stake()
	assert_true(game.apply_bet(MiniGame.BetOperation.ADD_10))
	assert_eq(game.selected_stake, 11)
	assert_false(game.apply_bet(MiniGame.BetOperation.ADD_10))
	assert_true(game.apply_bet(MiniGame.BetOperation.MAX))
	assert_eq(game.selected_stake, 18)
	assert_true(game.start_round(18))
	for operation: int in MiniGame.BetOperation.values():
		assert_false(game.can_apply_bet(operation))
	assert_eq(game.selected_stake, 18)


func test_every_game_exposes_direct_denomination_buttons_and_total_readout() -> void:
	for definition: CabinetDefinition in [SLOT_DEFINITION, BLACKJACK_DEFINITION, VAULT_DEFINITION]:
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(definition)
		var selector: StakeSelector = session.cabinet.panel._stake_selector
		assert_eq(selector._button_amounts, session.cabinet.available_stakes())
		assert_eq(
			selector._buttons.map(func(button: Button) -> String: return button.text),
			selector._button_amounts.map(func(amount: int) -> String: return str(amount))
		)
		var selector_bounds := Rect2(Vector2.ZERO, selector.size)
		for button_rect: Rect2 in selector.button_rects():
			assert_true(selector_bounds.encloses(button_rect), "Every bet action remains in its console")
		assert_gte(Typography.PROMINENT, Typography.CRITICAL)


func test_bet_buttons_select_the_exact_amount_and_show_persistent_feedback() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var selector: StakeSelector = session.cabinet.panel._stake_selector
	var amount := selector._button_amounts[3]
	selector._buttons[3].pressed.emit()
	assert_eq(session.cabinet.selected_stake, amount)
	assert_eq(selector._stake_value.target_value, amount)
	assert_true(selector._buttons[3].button_pressed)
	assert_gt(selector._bet_flash, 0.0)


func test_each_machine_has_distinct_ambient_motion() -> void:
	var cases: Array = [
		[SLOT_DEFINITION, CasinoAmbient.Mode.SLOT],
		[BLACKJACK_DEFINITION, CasinoAmbient.Mode.BLACKJACK],
		[VAULT_DEFINITION, CasinoAmbient.Mode.VAULT],
	]
	for entry: Array in cases:
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(entry[0])
		assert_eq(session.cabinet.panel._ambient.mode, entry[1])


func test_slot_anticipation_only_extends_a_genuine_matching_setup() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	session.cabinet.panel.begin_slot_spin([1, 1, 3], func() -> void: pass)
	assert_eq(session.cabinet.panel._slot_stop_times[2], 2.05)
	session.cabinet.panel.begin_slot_spin([1, 2, 3], func() -> void: pass)
	assert_eq(session.cabinet.panel._slot_stop_times[2], 1.59)


func test_cabinet_controls_stay_inside_horizontal_tv_safe_area() -> void:
	for definition: CabinetDefinition in [SLOT_DEFINITION, BLACKJACK_DEFINITION, VAULT_DEFINITION]:
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(definition)
		var panel: CabinetPanel = session.cabinet.panel
		var controls: Array[Control] = [panel._help_button, panel._stake_selector]
		if definition.id == &"slot_classic":
			controls.append(panel._slot_spin_label)
		elif definition.id == &"blackjack":
			controls.append_array([
				panel._blackjack_primary, panel._blackjack_stand, panel._blackjack_double
			])
		else:
			controls.append_array([panel._vault_open, panel._vault_cash_out])
		for control: Control in controls:
			assert_gte(control.position.x, 48.0, "%s keeps a 5%% left safe area" % control.name)
			assert_lte(
				control.position.x + control.size.x,
				912.0,
				"%s keeps a 5%% right safe area" % control.name
			)


func test_primary_controller_focus_and_help_focus_restore() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	await get_tree().process_frame
	var panel: CabinetPanel = session.cabinet.panel
	assert_eq(get_viewport().gui_get_focus_owner(), panel._slot_spin_label)
	panel.set_help_open(true)
	assert_eq(get_viewport().gui_get_focus_owner().name, "HelpClose")
	panel.set_help_open(false)
	assert_eq(get_viewport().gui_get_focus_owner(), panel._slot_spin_label)


func test_m5_each_cabinet_integrates_its_generated_art() -> void:
	var expected := {
		&"slot_classic": "SlotCabinetArt",
		&"blackjack": "BlackjackTableArt",
		&"minefield_vault": "VaultBackdropArt",
	}
	for id: StringName in expected:
		var definition: CabinetDefinition = load("res://data/cabinets/%s.tres" % id)
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(definition)
		assert_not_null(
			session.cabinet.panel.find_child(expected[id], true, false),
			"%s screen includes its generated cabinet art" % id
		)


func test_display_targets_render_canvas_items_at_native_resolution() -> void:
	var base := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	assert_eq(base, Vector2i(960, 540))
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "fractional")
	assert_true(ProjectSettings.get_setting("display/window/dpi/allow_hidpi"))
	assert_true(ProjectSettings.get_setting("gui/fonts/dynamic_fonts/use_oversampling"))
	assert_true(
		ProjectSettings.get_setting("gui/theme/default_font_multichannel_signed_distance_field")
	)
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 1)
	var targets := {
		"FHD / ROG Ally X": Vector2i(1920, 1080),
		"1440p": Vector2i(2560, 1440),
		"4K UHD": Vector2i(3840, 2160),
	}
	for target: String in targets:
		var dimensions: Vector2i = targets[target]
		assert_eq(
			float(dimensions.x) / dimensions.y,
			16.0 / 9.0,
			"%s fills the 16:9 canvas without letterboxing" % target
		)


func test_reference_captures_keep_a_full_16_by_9_frame() -> void:
	for filename: String in ["03_slot_idle.png", "05_blackjack.png", "06_vault.png"]:
		var texture: Texture2D = load("res://tests/results/screenshots/" + filename)
		assert_not_null(texture, "%s is imported" % filename)
		var dimensions := Vector2i(texture.get_width(), texture.get_height())
		assert_eq(dimensions.x * 9, dimensions.y * 16, "%s keeps the 16:9 frame" % filename)
		assert_gte(dimensions.x, 960, "%s is at least the logical canvas width" % filename)


func test_exact_fhd_qhd_and_uhd_release_journeys_are_native_resolution() -> void:
	var captures := {
		"res://tests/results/screenshots/fhd/01_menu.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/fhd/02_floor.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/fhd/02_floor_join.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/fhd/02_cashier_menu.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/fhd/03_slot_idle.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/fhd/05_blackjack.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/fhd/06_vault_reveal.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/qhd_exact/01_menu.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/qhd_exact/02_floor.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/qhd_exact/02_floor_join.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/qhd_exact/02_cashier_menu.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/qhd_exact/03_slot_idle.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/qhd_exact/05_blackjack.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/qhd_exact/06_vault_reveal.png": Vector2i(2560, 1440),
		"res://tests/results/screenshots/uhd/01_menu.png": Vector2i(3840, 2160),
		"res://tests/results/screenshots/uhd/02_floor.png": Vector2i(3840, 2160),
		"res://tests/results/screenshots/uhd/02_floor_join.png": Vector2i(3840, 2160),
		"res://tests/results/screenshots/uhd/02_cashier_menu.png": Vector2i(3840, 2160),
		"res://tests/results/screenshots/uhd/03_slot_idle.png": Vector2i(3840, 2160),
		"res://tests/results/screenshots/uhd/05_blackjack.png": Vector2i(3840, 2160),
		"res://tests/results/screenshots/uhd/06_vault_reveal.png": Vector2i(3840, 2160),
	}
	for path: String in captures:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s can be decoded" % path)
		assert_eq(image.get_size(), captures[path], "%s is pixel-exact" % path)


func test_redesigned_shell_uses_high_resolution_production_environments() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_not_null(main._menu.get_node_or_null("CasinoHallArt"))
	assert_not_null(main._menu.get_node_or_null("PromptPanel"))
	assert_not_null(main._menu.find_child("MenuLighting", true, false))
	assert_not_null(main._menu.find_child("MenuAmbient", true, false))
	main._process(2.1)
	assert_false(main._menu_first_breath, "The main CTA has a bounded idle attract beat")
	assert_not_null(main._menu_attract_tween)
	var menu_art: Texture2D = load(
		"res://assets/production/environments/casino_menu_hall.png"
	)
	var floor_art: Texture2D = load(
		"res://assets/production/environments/casino_floor_background_v2.png"
	)
	assert_gte(menu_art.get_width(), 1280)
	assert_eq(floor_art.get_width(), 3840, "Floor master is sharp at UHD")


func test_main_menu_exposes_a_focusable_reduced_motion_setting() -> void:
	MotionPolicy.set_reduced_motion(false)
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var toggle: Button = main._menu_motion_button
	assert_not_null(toggle)
	assert_eq(toggle.focus_mode, Control.FOCUS_ALL)
	assert_eq(toggle.size, Vector2(360, 56), "Setting keeps a generous controller target")
	assert_string_contains(toggle.text, tr("SETTING_OFF"))
	assert_string_contains(toggle.accessibility_name, tr("SETTING_OFF"))
	toggle.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), toggle)
	toggle.pressed.emit()
	assert_true(MotionPolicy.is_reduced())
	assert_true(toggle.button_pressed)
	assert_string_contains(toggle.text, tr("SETTING_ON"))
	assert_string_contains(toggle.accessibility_name, tr("SETTING_ON"))


func test_main_menu_motion_shortcut_works_for_keyboard_and_controller_action() -> void:
	MotionPolicy.set_reduced_motion(false)
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var shortcut := InputEventAction.new()
	shortcut.action = &"secondary"
	shortcut.pressed = true
	main._unhandled_input(shortcut)
	assert_true(MotionPolicy.is_reduced())
	assert_string_contains(main._menu_motion_button.text, InputRouter.glyph("secondary"))


func test_reduced_motion_preference_persists_and_reloads() -> void:
	var test_path := "user://tests/motion_%s.cfg" % Time.get_ticks_usec()
	MotionPolicy.preference_path = test_path
	MotionPolicy.persistence_enabled = true
	MotionPolicy.set_reduced_motion(true)
	ProjectSettings.set_setting(MotionPolicy.SETTING_PATH, false)
	assert_eq(MotionPolicy.load_preference(), OK)
	assert_true(MotionPolicy.is_reduced())


func test_walk_atlas_has_four_phases_per_eight_directions_and_transparency() -> void:
	var atlas: Texture2D = load(
		"res://assets/production/characters/casino_guest_walk_integer.png"
	)
	assert_not_null(atlas)
	assert_eq(atlas.get_size(), Vector2(1920, 960))
	assert_eq(
		atlas.get_width(),
		atlas.get_height() * 2,
		"Atlas retains eight integer square columns by four rows"
	)
	assert_eq(atlas.get_image().get_pixel(0, 0).a, 0.0)


func test_shared_scene_transition_and_lighting_layers_exist() -> void:
	assert_not_null(ScreenTransition.get_node_or_null("Fade"))
	assert_not_null(ScreenTransition.get_node_or_null("UpperShutter"))
	assert_not_null(ScreenTransition.get_node_or_null("LowerShutter"))
	assert_false(ScreenTransition.visible)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	assert_not_null(session.cabinet.panel.find_child("CabinetLighting", true, false))


func test_m5_cabinet_motion_runs_in_engine() -> void:
	var slot_session := CabinetSession.new()
	add_child_autofree(slot_session)
	slot_session.begin(SLOT_DEFINITION)
	slot_session.cabinet.panel.set_status("ROUND_SPINNING")
	assert_true(slot_session.cabinet.panel.has_active_motion(), "Slot reel motion is active")

	var vault_session := CabinetSession.new()
	add_child_autofree(vault_session)
	vault_session.begin(VAULT_DEFINITION)
	assert_true(vault_session.cabinet.panel.has_active_motion(), "Vault cursor pulse is active")
	for session: CabinetSession in [slot_session, vault_session]:
		assert_not_null(session.cabinet.panel.find_child("CasinoAmbient", true, false))
		assert_not_null(session.cabinet.panel.find_child("WinCelebration", true, false))


func test_higgsfield_win_effect_is_sharp_and_transparent() -> void:
	var texture: Texture2D = load("res://assets/production/effects/casino_win_burst.png")
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(1024, 1024))
	assert_eq(texture.get_image().get_pixel(0, 0).a, 0.0)
	var celebration := WinCelebration.new()
	add_child_autofree(celebration)
	celebration.burst(Vector2(480, 300), 4)
	assert_eq(celebration.get_child_count(), 4, "A win launches visible chip/coin pieces")


func test_slot_reels_spin_independently_and_gate_settlement() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_true(game.start_round(10))
	assert_true(game.is_round_active, "Wager remains active during the reel sequence")
	assert_eq(game.panel._slot_reels.size(), 3, "Physical presenter has three reel columns")
	game.panel._process(1.7)
	assert_false(game.is_round_active, "Settlement occurs after all three reels stop")
	assert_eq(game.panel._slot_stopped, [true, true, true])
	var settled_symbols: Array[int] = []
	for reel_index: int in range(3):
		settled_symbols.append(game.panel._slot_reel_cells[reel_index][2].symbol_index)
	assert_eq(settled_symbols, game.panel._result.detail.get("symbols"))
	game.panel.refresh()
	var refreshed_symbols: Array[int] = []
	for reel_index: int in range(3):
		refreshed_symbols.append(game.panel._slot_reel_cells[reel_index][2].symbol_index)
	assert_eq(refreshed_symbols, settled_symbols, "Result refresh never swaps a stopped symbol")


func test_higgsfield_slot_symbols_are_high_resolution_and_transparent() -> void:
	# Elven Court symbols keep the classic index semantics (cherry, lemon, bell,
	# bar, seven, diamond) with themed Higgsfield paintings.
	assert_eq(SlotSymbol.TEXTURES.size(), SlotMachineMath.Symbol.size())
	for texture: Texture2D in SlotSymbol.TEXTURES:
		var symbol_name := texture.resource_path
		assert_string_starts_with(symbol_name, "res://assets/production/slot/elven/symbol_")
		assert_eq(texture.get_size(), Vector2(1024, 1024), "%s retains its sharp master" % symbol_name)
		var image := texture.get_image()
		assert_eq(image.get_pixel(0, 0).a, 0.0, "%s magenta corner is transparent" % symbol_name)
		assert_gt(image.get_used_rect().size.x, 400, "%s retains a substantial opaque subject" % symbol_name)


func test_slot_uses_a_full_screen_sharp_higgsfield_stage() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	assert_eq(panel._frame.position, Vector2.ZERO)
	assert_eq(panel._frame.size, Vector2(960, 540))
	assert_eq(panel._slot_reels.size(), 3, "Classic rules expose exactly three evaluated reels")
	for reel: Control in panel._slot_reels:
		assert_gte(reel.size.x, 190.0, "Each reel is large enough for handheld readability")
		assert_gte(reel.size.y, 230.0, "Three visible rows fill the main stage")
	var bezel: Texture2D = load("res://assets/production/slot/elven/elven_court_bezel.png")
	assert_gte(bezel.get_width(), 3840, "The bezel retains a native 4K master")
	var bezel_image := bezel.get_image()
	assert_lt(
		bezel_image.get_pixel(bezel_image.get_width() / 2, bezel_image.get_height() / 2).a,
		0.05,
		"The reel aperture is true transparency, not magenta"
	)
	var selector: StakeSelector = panel._stake_selector
	var selector_bounds := Rect2(Vector2.ZERO, selector.size)
	for chip_rect: Rect2 in selector.chip_rects():
		assert_true(selector_bounds.encloses(chip_rect), "Every bet chip remains inside its tray")
	assert_true(panel._slot_spin_label is Button, "SPIN is an interactive button")
	assert_eq(panel._slot_spin_label.position, Vector2(530, 416))
	assert_eq(panel._slot_spin_label.size, Vector2(140, 110))
	assert_not_null(panel.find_child("SlotCreditsMeter", true, false))
	assert_not_null(panel.find_child("SlotResultMeter", true, false))


func test_slot_deck_exposes_bet_multiplier_and_return() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_true(game.select_stake(10))
	var result := RoundResult.create(
		10,
		190,
		RoundResult.Outcome.WIN,
		{"symbols": [SlotMachineMath.Symbol.SEVEN, SlotMachineMath.Symbol.SEVEN, SlotMachineMath.Symbol.SEVEN]}
	)
	game.panel._result = result
	game.panel.refresh()
	assert_eq(
		game.panel._slot_credit_value.text,
		"∞" if Wallet.test_mode_enabled else str(game.context.balance)
	)
	assert_eq(game.panel._slot_result_value.text, tr("SLOT_RETURNED") % 190)
	assert_eq(game.panel._slot_result_formula.text, tr("SLOT_RESULT_FORMULA") % [10, 19, 190])


func test_blackjack_and_vault_use_distinct_full_screen_stages() -> void:
	var blackjack_session := CabinetSession.new()
	add_child_autofree(blackjack_session)
	blackjack_session.begin(BLACKJACK_DEFINITION)
	var blackjack_panel: CabinetPanel = blackjack_session.cabinet.panel
	assert_eq(blackjack_panel._frame.size, Vector2(960, 540))
	var table := blackjack_panel.find_child("BlackjackTableArt", true, false) as Sprite2D
	assert_not_null(table)
	assert_gte(
		table.texture.get_width() * table.scale.x,
		800.0,
		"Blackjack felt owns the full game stage"
	)
	assert_gte(table.texture.get_width(), 3840, "Blackjack table retains a native 4K master")
	assert_not_null(blackjack_panel.find_child("BlackjackControlDeck", true, false))
	assert_true(blackjack_panel._blackjack_primary is Button)
	assert_true(blackjack_panel._blackjack_stand is Button)
	assert_true(blackjack_panel._blackjack_double is Button)

	var vault_session := CabinetSession.new()
	add_child_autofree(vault_session)
	vault_session.begin(VAULT_DEFINITION)
	var vault_panel: CabinetPanel = vault_session.cabinet.panel
	assert_eq(vault_panel._frame.size, Vector2(960, 540))
	assert_eq(vault_panel._vault_tiles.size(), 25)
	assert_eq(vault_panel._vault_tiles[0].size, Vector2(56, 56))
	assert_eq(vault_panel._vault_tiles[1].position.x - vault_panel._vault_tiles[0].position.x, 60.0)
	assert_eq(vault_panel._vault_cashout_meter.position, Vector2(48, 284))
	var vault_backdrop: Texture2D = load(
		"res://assets/production/vault/witcher/witcher_vault_backdrop.png"
	)
	assert_gte(vault_backdrop.get_width(), 3840, "Vault backdrop retains a native 4K master")
	assert_not_null(vault_panel.find_child("VaultControlDeck", true, false))
	assert_not_null(vault_panel.find_child("VaultStatusPanel", true, false))
	assert_true(vault_panel._vault_cashout_meter is VaultCashoutMeter)
	assert_true(vault_panel._vault_open is Button)
	assert_true(vault_panel._vault_cash_out is Button)


func test_blackjack_uses_dealt_cards_and_a_revealing_hole_card() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_true(game.start_round(10))
	assert_eq(game.panel._blackjack_cards.size(), 4)
	assert_true(game.panel._blackjack_cards[1].face_down, "Dealer hole card starts face-down")
	var original_cards: Array[int] = []
	for card: PlayingCard in game.panel._blackjack_cards:
		original_cards.append(card.get_instance_id())
	game.panel.refresh()
	var refreshed_cards: Array[int] = []
	for card: PlayingCard in game.panel._blackjack_cards:
		refreshed_cards.append(card.get_instance_id())
	assert_eq(refreshed_cards, original_cards, "Refresh preserves dealt card nodes")
	var result: RoundResult = game.get("math").stand()
	game.call("_resolve", result)
	assert_eq(
		game.panel._blackjack_cards[0].get_instance_id(),
		original_cards[0],
		"Dealer resolution updates cards instead of rebuilding the table"
	)
	for card: PlayingCard in game.panel._blackjack_cards:
		assert_false(card.face_down, "Resolved dealer hand is face-up")


func test_vault_uses_physical_tiles_with_flip_reveals() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(VAULT_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_true(game.start_round(10))
	assert_eq(game.panel._vault_tiles.size(), 25)
	var onboarding_text: String = game.panel._status.text
	game.get("math").reveal(0)
	game.panel.refresh()
	assert_true(game.panel._vault_tiles[0].is_flipping, "Newly revealed box starts its flip")
	assert_true(game.panel._vault_revealed.has(0))
	assert_ne(game.panel._status.text, onboarding_text, "First choice clears the persistent instruction")
	assert_eq(game.panel._status.text, game.panel._detail.text, "In-round status becomes live telemetry")
