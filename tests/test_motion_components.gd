extends GutTest

const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")


func test_slot_spin_strength_is_clamped_and_presentation_only() -> void:
	var symbol := SlotSymbol.new()
	symbol.size = Vector2(120, 120)
	add_child_autofree(symbol)
	symbol.symbol_index = 4
	symbol.set_spin_strength(1.7)
	assert_eq(symbol.spin_strength, 1.0)
	assert_eq(symbol.symbol_index, 4, "Motion never changes the evaluated symbol")
	symbol.set_spin_strength(-0.5)
	assert_eq(symbol.spin_strength, 0.0)


func test_playing_card_uses_real_suit_glyphs_and_logical_state_updates_immediately() -> void:
	assert_eq(PlayingCard.SUITS, ["\u2660", "\u2665", "\u2666", "\u2663"])
	var card := PlayingCard.new()
	card.size = Vector2(88, 124)
	add_child_autofree(card)
	card.configure(12, 1, true)
	assert_true(card.face_down)
	card.reveal()
	assert_false(card.face_down, "Input and rules can observe reveal before presentation settles")
	assert_gt(card._sheen_remaining, 0.0)


func test_vault_reveal_exposes_a_presentation_effect_hook() -> void:
	var tile := VaultTile.new()
	tile.size = Vector2(48, 48)
	add_child_autofree(tile)
	watch_signals(tile)
	tile.reveal(VaultTile.Face.MINE)
	assert_true(tile.is_flipping)
	assert_gt(tile._warning_remaining, 0.0)
	await wait_seconds(0.22)
	assert_signal_emitted(tile, "reveal_effect_requested")
	assert_eq(tile.face, VaultTile.Face.MINE)
	assert_gt(tile._flash_remaining, 0.0)


func test_vault_safe_reveal_finishes_with_a_pop_and_restored_scale() -> void:
	var tile := VaultTile.new()
	tile.size = Vector2(48, 48)
	add_child_autofree(tile)
	watch_signals(tile)
	tile.reveal(VaultTile.Face.SAFE)
	await wait_seconds(0.48)
	assert_false(tile.is_flipping)
	assert_eq(tile.face, VaultTile.Face.SAFE)
	assert_eq(tile.scale, Vector2.ONE)
	assert_signal_emitted(tile, "reveal_completed")


func test_number_ticker_reaches_exact_target_and_handles_infinity() -> void:
	var ticker := AnimatedNumberLabel.new()
	add_child_autofree(ticker)
	ticker.set_number(10, "%d", false)
	ticker.set_number(110)
	assert_eq(ticker.target_value, 110)
	await wait_seconds(0.65)
	assert_eq(ticker.text, "110")
	assert_eq(int(ticker.displayed_value), 110)
	ticker.set_infinity()
	assert_eq(ticker.text, "∞")


func test_blackjack_input_unlocks_from_completed_deal_motion() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	assert_true(session.cabinet.start_round(10))
	assert_false(session.cabinet.panel.blackjack_input_ready())
	assert_gt(session.cabinet.panel._blackjack_pending_motions, 0)
	await wait_seconds(0.62)
	assert_true(session.cabinet.panel.blackjack_input_ready())
	assert_eq(session.cabinet.panel._blackjack_pending_motions, 0)
