extends GutTest

const MAIN_SCENE := preload("res://src/ui/main.tscn")
const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
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


func test_ac040_target_displays_use_sharp_integer_scaling() -> void:
	var base := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	assert_eq(base, Vector2i(960, 540))
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")
	var targets := {
		"FHD / ROG Ally X": [Vector2i(1920, 1080), 2],
		"DCI 2K": [Vector2i(2048, 1080), 2],
		"1440p": [Vector2i(2560, 1440), 2],
		"4K UHD": [Vector2i(3840, 2160), 4],
	}
	for target: String in targets:
		var dimensions: Vector2i = targets[target][0]
		var scale: int = mini(dimensions.x / base.x, dimensions.y / base.y)
		assert_eq(scale, targets[target][1], "%s uses the reviewed integer scale" % target)
		assert_lte(base.x * scale, dimensions.x)
		assert_lte(base.y * scale, dimensions.y)


func test_m5_machine_captures_match_the_pixel_base() -> void:
	for filename: String in ["03_slot_idle.png", "05_blackjack.png", "06_vault.png"]:
		var texture: Texture2D = load("res://tests/results/screenshots/" + filename)
		assert_not_null(texture, "%s is imported" % filename)
		assert_eq(texture.get_size(), Vector2(960, 540), "%s uses the pixel base" % filename)


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
