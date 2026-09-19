extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_balance = Wallet.balance
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.test_mode_enabled = false
	Wallet.reset(500)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func test_live_slot_spin_settles_exactly_and_finishes_once_when_reduced_motion_turns_on() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var game: MiniGame = session.cabinet
	var panel: CabinetPanel = session.cabinet.panel
	watch_signals(game)
	assert_true(game.request_spin())
	var evaluated_symbols: Array = game.get("_pending").detail.get("symbols", []).duplicate()
	panel._process(0.24)
	assert_true(panel._slot_spinning)
	assert_true(game.is_round_active)
	assert_false(panel._slot_stopped.all(func(stopped: bool) -> bool: return stopped))
	assert_true(
		panel._slot_offsets != panel._slot_total_offsets,
		"The preference changes while reel travel is visibly in progress"
	)

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_true(panel._slot_spinning, "Accessibility never resolves semantic play early")
	assert_true(game.is_round_active, "The authoritative round remains pending")
	assert_eq(panel._slot_stopped, [false, false, false])
	assert_eq(panel._slot_offsets, panel._slot_total_offsets, "Every reel reaches its exact stop offset")
	assert_eq(panel._slot_spin_targets, evaluated_symbols, "Presentation settlement preserves the outcome")
	assert_true(panel._slot_finish_callback.is_valid(), "Normal timed completion remains pending")
	assert_signal_not_emitted(game, "round_resolved")
	for reel_index: int in range(panel._slot_reel_cells.size()):
		var center: SlotSymbol = panel._slot_reel_cells[reel_index][2]
		assert_eq(center.symbol_index, evaluated_symbols[reel_index])
		assert_eq(panel._slot_reels[reel_index].position.y, CabinetPanel.SLOT_REEL_TOP)
		for cell: SlotSymbol in panel._slot_reel_cells[reel_index]:
			assert_eq(cell.spin_strength, 0.0, "No blur strength survives the handoff")
	assert_false(panel._slot_anticipating_third)
	assert_false(panel._slot_anticipation_frame.visible)

	var remaining: float = panel._slot_stop_times.max() - panel._slot_spin_elapsed
	panel._process(remaining - 0.01)
	assert_true(panel._slot_spinning)
	assert_true(game.is_round_active)
	assert_signal_not_emitted(game, "round_resolved")
	panel._process(0.02)
	assert_false(panel._slot_spinning)
	assert_false(game.is_round_active)
	assert_false(panel._slot_finish_callback.is_valid(), "The callback is consumed at canonical timing")
	assert_signal_emit_count(game, "round_resolved", 1)
	panel._process(4.0)
	assert_signal_emit_count(game, "round_resolved", 1, "Later frames cannot resolve twice")


func test_live_ambient_event_energy_returns_to_exact_zero_when_reduced_motion_turns_on() -> void:
	var ambient := CasinoAmbient.new()
	ambient.size = Vector2(960, 110)
	add_child_autofree(ambient)
	ambient.trigger_event(1.0)
	ambient._process(0.10)
	assert_gt(ambient.event_energy, 0.0, "The event is active before the preference handoff")

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_eq(ambient.event_energy, 0.0, "A live toggle leaves no frozen ambient event residue")
	assert_false(ambient.is_processing())
	ambient._process(2.0)
	assert_eq(ambient.event_energy, 0.0, "The reduced-motion rest state remains exact")


func test_live_cabinet_entrance_tween_settles_to_its_canonical_pose() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	assert_not_null(panel._entrance_tween)
	assert_true(panel._entrance_tween.is_running())

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_eq(panel._art_root.modulate.a, 1.0)
	assert_eq(panel._art_root.position.y, 0.0)
	assert_true(
		panel._entrance_tween == null or not panel._entrance_tween.is_running(),
		"The tracked entrance tween cannot keep travelling after a live toggle"
	)
