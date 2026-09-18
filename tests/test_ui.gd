extends GutTest

const MAIN_SCENE := preload("res://src/ui/main.tscn")
const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")
var _original_platform: PlatformServices


func before_each() -> void:
	_original_platform = SaveService.platform
	SaveService.platform = LocalPlatform.new("user://tests/ui_%s" % Time.get_ticks_usec())
	SaveService.new_game(20260918)


func after_each() -> void:
	SaveService.platform = _original_platform
	SaveService.new_game(20260918)


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
		assert_false(panel._help_overlay.visible)


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


func test_exact_fhd_and_qhd_slot_captures_are_native_resolution() -> void:
	var captures := {
		"res://tests/results/screenshots/fhd/03_slot_idle.png": Vector2i(1920, 1080),
		"res://tests/results/screenshots/qhd_exact/03_slot_idle.png": Vector2i(2560, 1440),
	}
	for path: String in captures:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s can be decoded" % path)
		assert_eq(image.get_size(), captures[path], "%s is pixel-exact" % path)


func test_redesigned_shell_uses_high_resolution_production_environments() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_not_null(main._menu.get_node_or_null("CasinoHallArt"))
	var menu_art: Texture2D = load(
		"res://assets/production/environments/casino_menu_hall.png"
	)
	var floor_art: Texture2D = load("res://assets/production/environments/casino_floor.png")
	assert_gte(menu_art.get_width(), 1280)
	assert_gte(floor_art.get_width(), 1280)


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
	for symbol_name: String in ["cherry", "lemon", "bell", "bar", "seven", "diamond"]:
		var path := "res://assets/production/slot/symbols/%s.png" % symbol_name
		var texture: Texture2D = load(path)
		assert_not_null(texture, "%s runtime symbol is imported" % symbol_name)
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
	var bezel: Texture2D = load(
		"res://assets/production/slot/symbols/slot_fullscreen_bezel.png"
	)
	assert_gte(bezel.get_width(), 1200, "The bezel retains a high-resolution master")
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
	assert_eq(panel._slot_spin_label.position, Vector2(522, 430))
	assert_eq(panel._slot_spin_label.size, Vector2(140, 88))
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
	assert_eq(game.panel._slot_credit_value.text, str(game.context.balance))
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
	assert_eq(vault_panel._vault_tiles[0].size, Vector2(48, 48))
	assert_not_null(vault_panel.find_child("VaultControlDeck", true, false))
	assert_not_null(vault_panel.find_child("VaultStatusPanel", true, false))
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
	game.get("math").reveal(0)
	game.panel.refresh()
	assert_true(game.panel._vault_tiles[0].is_flipping, "Newly revealed box starts its flip")
	assert_true(game.panel._vault_revealed.has(0))
