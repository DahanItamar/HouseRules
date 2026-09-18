extends GutTest

const MAIN_SCENE := preload("res://src/ui/main.tscn")
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

	var definition: CabinetDefinition = load("res://data/cabinets/minefield_vault.tres")
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(definition)
	var panel: CabinetPanel = session.cabinet.panel
	assert_gte(panel._stake.get_theme_font_size("font_size"), Typography.CRITICAL)
	assert_gte(panel._detail.get_theme_font_size("font_size"), Typography.CRITICAL)
