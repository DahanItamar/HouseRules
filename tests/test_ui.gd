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


func test_slot_reels_spin_independently_and_gate_settlement() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_true(game.start_round(10))
	assert_true(game.is_round_active, "Wager remains active during the reel sequence")
	assert_eq(game.panel._slot_reels.size(), 3, "Physical presenter has three reel columns")
	game.panel._process(1.3)
	assert_false(game.is_round_active, "Settlement occurs after all three reels stop")
	assert_eq(game.panel._slot_stopped, [true, true, true])


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


func test_blackjack_uses_dealt_cards_and_a_revealing_hole_card() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var game: MiniGame = session.cabinet
	assert_true(game.start_round(10))
	assert_eq(game.panel._blackjack_cards.size(), 4)
	assert_true(game.panel._blackjack_cards[1].face_down, "Dealer hole card starts face-down")
	var result: RoundResult = game.get("math").stand()
	game.call("_resolve", result)
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
