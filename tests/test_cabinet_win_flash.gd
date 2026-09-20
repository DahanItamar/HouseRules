extends GutTest

const DEFINITIONS: Array[CabinetDefinition] = [
	preload("res://data/cabinets/slot_classic.tres"),
	preload("res://data/cabinets/blackjack.tres"),
	preload("res://data/cabinets/minefield_vault.tres"),
]
const FLASH_SCRIPT := preload("res://src/ui/cabinet_win_flash.gd")

var _original_audio_output: bool


func before_each() -> void:
	_original_audio_output = AudioService.output_enabled
	AudioService.output_enabled = false
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	AudioService.output_enabled = _original_audio_output


func test_flash_uses_a_gl_compatible_canvas_shader_without_screen_sampling() -> void:
	var flash: Control = _flash()
	assert_true(flash.material is ShaderMaterial)
	var source: String = (flash.material as ShaderMaterial).shader.code
	assert_string_contains(source, "shader_type canvas_item")
	assert_string_contains(source, "blend_add")
	assert_false(source.contains("SCREEN_TEXTURE"))


func test_big_flash_runs_a_bounded_sweep_and_settles_exactly() -> void:
	var flash: Control = _flash()
	flash.play(Color.GOLD, true)
	assert_true(flash.visible)
	assert_true(flash.last_big)
	assert_true(flash.is_playing())
	await wait_seconds(0.10)
	assert_gt(flash.energy_value, 0.0)
	assert_gt(flash.sweep_value, -0.15)
	await wait_seconds(0.58)
	assert_false(flash.visible)
	assert_false(flash.is_playing())
	assert_almost_eq(flash.energy_value, 0.0, 0.001)


func test_reduced_flash_acknowledges_without_a_travelling_sweep() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var flash: Control = _flash()
	flash.play(Color.CYAN, false)
	assert_almost_eq(flash.sweep_value, 0.5, 0.001)
	assert_almost_eq(flash.energy_value, 0.28, 0.001)
	await wait_seconds(0.24)
	assert_false(flash.visible)
	assert_almost_eq(flash.energy_value, 0.0, 0.001)


func test_switching_to_reduced_motion_settles_an_active_sweep() -> void:
	var flash: Control = _flash()
	flash.play(Color.GOLD, true)
	await wait_seconds(0.08)
	assert_true(flash.is_playing())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(flash.is_playing())
	assert_false(flash.visible)
	assert_almost_eq(flash.energy_value, 0.0, 0.001)
	assert_almost_eq(flash.sweep_value, -0.15, 0.001)


func test_every_cabinet_result_uses_the_shared_flash_without_mutating_result() -> void:
	for definition: CabinetDefinition in DEFINITIONS:
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(definition)
		var result := RoundResult.create(
			10, 100, RoundResult.Outcome.WIN, {"symbols": [4, 4, 4], "evidence": definition.id}
		)
		var original_detail: Dictionary = result.detail.duplicate(true)
		session.cabinet.panel.show_result(result)
		assert_true(session.cabinet.panel._win_flash.is_playing())
		assert_true(session.cabinet.panel._win_flash.last_big)
		assert_eq(result.stake, 10)
		assert_eq(result.payout, 100)
		assert_eq(result.detail, original_detail)


func _flash() -> Control:
	var flash: Control = FLASH_SCRIPT.new()
	flash.size = Vector2(960, 540)
	add_child_autofree(flash)
	return flash
