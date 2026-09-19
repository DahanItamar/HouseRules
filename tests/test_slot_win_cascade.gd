extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_win_sequence_targets_only_symbols_that_form_the_payout() -> void:
	var panel := CabinetPanel.new()
	var three_sevens := RoundResult.create(
		10, 190, RoundResult.Outcome.WIN,
		{"symbols": [SlotMachineMath.Symbol.SEVEN, SlotMachineMath.Symbol.SEVEN, SlotMachineMath.Symbol.SEVEN]}
	)
	var two_cherries := RoundResult.create(
		10, 20, RoundResult.Outcome.WIN,
		{"symbols": [SlotMachineMath.Symbol.CHERRY, SlotMachineMath.Symbol.BELL, SlotMachineMath.Symbol.CHERRY]}
	)
	assert_eq(panel._slot_win_indices(three_sevens), [0, 1, 2])
	assert_eq(panel._slot_win_indices(two_cherries), [0, 2])
	panel.free()


func test_slot_win_cascade_is_bounded_and_does_not_change_symbols() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var result := RoundResult.create(
		10, 20, RoundResult.Outcome.WIN,
		{"symbols": [SlotMachineMath.Symbol.CHERRY, SlotMachineMath.Symbol.BELL, SlotMachineMath.Symbol.CHERRY]}
	)
	var before: Array[int] = []
	for symbol: SlotSymbol in panel._slot_symbols:
		before.append(symbol.symbol_index)
	panel._pulse_slot_win(result)
	assert_eq(panel._slot_last_win_indices, [0, 2])
	assert_eq(panel._slot_cascade_clones.size(), 4, "Each winner gets one outgoing and incoming presentation clone")
	for clone: SlotSymbol in panel._slot_cascade_clones:
		assert_true(clone.get_parent() in panel._slot_reels, "Cascade clones stay clipped by a reel")
		assert_eq(
			clone.symbol_index,
			panel._slot_symbols[panel._slot_reels.find(clone.get_parent())].symbol_index,
			"A clone mirrors its evaluated symbol"
		)
	await wait_seconds(0.30)
	var bursts: Array[Node] = []
	for child: Node in panel._art_root.get_children():
		if child is ImpactBurst:
			bursts.append(child)
	assert_eq(bursts.size(), 2, "One restrained spark burst follows each winning symbol")
	var after: Array[int] = []
	for symbol: SlotSymbol in panel._slot_symbols:
		after.append(symbol.symbol_index)
	assert_eq(after, before, "Presentation feedback never changes evaluated symbols")
	await wait_seconds(0.25)
	for reel_index: int in panel._slot_last_win_indices:
		assert_almost_eq(panel._slot_symbols[reel_index].scale.x, 1.0, 0.01)
	assert_eq(panel._slot_cascade_clones.size(), 0, "Bounded cascade nodes clean themselves up")
	assert_false(panel._slot_win_band.visible, "Winning-row emphasis clears after the beat")


func test_third_reel_anticipation_appears_only_for_a_real_matching_setup() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	panel.begin_slot_spin([SlotMachineMath.Symbol.BELL, SlotMachineMath.Symbol.BELL, SlotMachineMath.Symbol.BAR], func() -> void: pass)
	assert_true(panel._slot_anticipating_third)
	panel._process(1.4)
	assert_true(panel._slot_anticipation_frame.visible, "The frame appears after two matching reels stop")
	panel._process(0.8)
	assert_false(panel._slot_anticipation_frame.visible, "The frame clears when reel three settles")

	panel.begin_slot_spin([SlotMachineMath.Symbol.BELL, SlotMachineMath.Symbol.BAR, SlotMachineMath.Symbol.BELL], func() -> void: pass)
	assert_false(panel._slot_anticipating_third)
	panel._process(1.4)
	assert_false(panel._slot_anticipation_frame.visible, "No false near-miss frame is fabricated")


func test_reduced_motion_keeps_the_win_readable_without_particle_cascade() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var result := RoundResult.create(
		10, 190, RoundResult.Outcome.WIN,
		{"symbols": [SlotMachineMath.Symbol.SEVEN, SlotMachineMath.Symbol.SEVEN, SlotMachineMath.Symbol.SEVEN]}
	)
	panel._pulse_slot_win(result)
	assert_eq(panel._slot_last_win_indices, [0, 1, 2])
	assert_eq(panel._slot_cascade_clones.size(), 0, "Reduced motion uses a static winning row")
	assert_true(panel._slot_win_band.visible)
	await wait_seconds(0.28)
	var burst_count := 0
	for child: Node in panel._art_root.get_children():
		if child is ImpactBurst:
			burst_count += 1
	assert_eq(burst_count, 0, "Reduced motion removes the sequential particle cascade")
	for symbol: SlotSymbol in panel._slot_symbols:
		assert_almost_eq(symbol.scale.x, 1.0, 0.01)
