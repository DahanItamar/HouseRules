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
	await wait_seconds(0.28)
	var burst_count := 0
	for child: Node in panel._art_root.get_children():
		if child is ImpactBurst:
			burst_count += 1
	assert_eq(burst_count, 0, "Reduced motion removes the sequential particle cascade")
	for symbol: SlotSymbol in panel._slot_symbols:
		assert_almost_eq(symbol.scale.x, 1.0, 0.01)
