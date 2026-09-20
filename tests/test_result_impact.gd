extends GutTest

const DEFINITIONS: Array[CabinetDefinition] = [
	preload("res://data/cabinets/slot_classic.tres"),
	preload("res://data/cabinets/blackjack.tres"),
	preload("res://data/cabinets/minefield_vault.tres"),
]
const EXPECTED_WIN_CUES: Array[StringName] = [
	&"slot_win",
	&"blackjack_win",
	&"vault_cashout",
]

var _original_output: bool


func before_each() -> void:
	_original_output = AudioService.output_enabled
	AudioService.output_enabled = false
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	AudioService.output_enabled = _original_output
	MotionPolicy.clear_test_override()


func test_each_game_starts_a_bounded_win_impact_with_its_result_sound() -> void:
	var heard_cues: Array[StringName] = []
	var record_cue := func(cue: StringName) -> void: heard_cues.append(cue)
	AudioService.cue_played.connect(record_cue)
	for index: int in range(DEFINITIONS.size()):
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(DEFINITIONS[index])
		var panel: CabinetPanel = session.cabinet.panel
		var result := RoundResult.create(
			10,
			20,
			RoundResult.Outcome.WIN,
			{
				"symbols":
				[
					SlotMachineMath.Symbol.CHERRY,
					SlotMachineMath.Symbol.BELL,
					SlotMachineMath.Symbol.CHERRY
				]
			}
		)
		heard_cues.clear()
		panel.show_result(result)
		assert_eq(heard_cues, [EXPECTED_WIN_CUES[index]], "Result sound starts in the impact call")
		assert_eq(panel._last_result_impact_tier, CabinetPanel.ResultImpactTier.WIN)
		assert_not_null(panel._result_impact_tween)
		assert_true(panel._result_impact_tween.is_running())
	AudioService.cue_played.disconnect(record_cue)


func test_big_win_shake_is_bounded_and_returns_the_stage_to_origin() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(DEFINITIONS[0])
	var panel: CabinetPanel = session.cabinet.panel
	var result := RoundResult.create(
		10,
		100,
		RoundResult.Outcome.WIN,
		{
			"symbols":
			[
				SlotMachineMath.Symbol.SEVEN,
				SlotMachineMath.Symbol.SEVEN,
				SlotMachineMath.Symbol.SEVEN
			]
		}
	)
	panel.show_result(result)
	assert_eq(panel._last_result_impact_tier, CabinetPanel.ResultImpactTier.BIG_WIN)
	assert_true(panel.has_active_motion(), "Capture and transition gates include the impact")
	await wait_seconds(0.06)
	assert_gt(panel._art_root.position.length(), 0.0, "A major payout visibly displaces the stage")
	assert_lte(panel._art_root.position.length(), 6.5, "Shake never escapes its six-pixel envelope")
	await wait_seconds(0.30)
	assert_almost_eq(panel._art_root.position.x, 0.0, 0.01)
	assert_almost_eq(panel._art_root.position.y, 0.0, 0.01)
	assert_false(panel._result_impact_tween.is_running(), "The impact is finite")


func test_reduced_motion_keeps_result_audio_but_removes_stage_displacement() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(DEFINITIONS[0])
	var panel: CabinetPanel = session.cabinet.panel
	var result := RoundResult.create(
		10,
		100,
		RoundResult.Outcome.WIN,
		{
			"symbols":
			[
				SlotMachineMath.Symbol.SEVEN,
				SlotMachineMath.Symbol.SEVEN,
				SlotMachineMath.Symbol.SEVEN
			]
		}
	)
	watch_signals(AudioService)
	panel.show_result(result)
	assert_signal_emitted_with_parameters(AudioService, "cue_played", [&"slot_win"])
	assert_eq(panel._last_result_impact_tier, CabinetPanel.ResultImpactTier.BIG_WIN)
	assert_null(panel._result_impact_tween)
	assert_eq(panel._art_root.position, Vector2.ZERO)
