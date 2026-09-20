extends GutTest

const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_REVEAL_FX := preload("res://src/ui/vault_reveal_fx.gd")


func after_each() -> void:
	MotionPolicy.clear_test_override()


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
	var second_card := PlayingCard.new()
	add_child_autofree(second_card)
	second_card.configure(7, 3, false)
	assert_ne(card._idle_phase, second_card._idle_phase, "Card glints are deliberately staggered")


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


func test_vault_tile_uses_authored_faces_for_every_state() -> void:
	assert_eq(VaultTile.FACE_TEXTURES.size(), 3)
	for texture: Texture2D in VaultTile.FACE_TEXTURES:
		assert_not_null(texture)
		assert_eq(texture.get_size(), Vector2(1024, 1024))


func test_vault_faces_are_sharp_transparent_production_art() -> void:
	var paths := [
		"res://assets/production/vault/witcher/tile_sealed.png",
		"res://assets/production/vault/witcher/tile_safe_coins.png",
		"res://assets/production/vault/witcher/tile_cursed_rune.png",
	]
	for path: String in paths:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_eq(image.get_size(), Vector2i(1024, 1024), "%s retains its 1024 px master" % path)
		for corner: Vector2i in [
			Vector2i.ZERO, Vector2i(1023, 0), Vector2i(0, 1023), Vector2i(1023, 1023)
		]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s has a clean alpha gutter" % path)
		assert_gt(image.get_pixel(512, 512).a, 0.95, "%s has an opaque readable center" % path)


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
	assert_eq(tile._press_depth, 0.0)
	assert_eq(tile._impact_strength, 0.0)


func test_vault_reveal_has_physical_press_and_readable_mine_anticipation() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)
	var tile := VaultTile.new()
	tile.size = Vector2(56, 56)
	add_child_autofree(tile)
	tile.reveal(VaultTile.Face.MINE)
	await wait_seconds(0.04)
	assert_gt(tile._press_depth, 0.0, "Reveal starts with visible deposit-box key travel")
	assert_gt(tile._warning_remaining, 0.0, "Mine keeps a distinct anticipation window")
	await wait_seconds(0.24)
	assert_eq(tile.face, VaultTile.Face.MINE)
	assert_gt(tile._impact_strength, 0.0, "Mine impact has a bounded physical settle cue")


func test_vault_safe_effect_uses_procedural_diamond_shards() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var effect = VAULT_REVEAL_FX.spawn(host, Vector2(32, 24), VAULT_REVEAL_FX.Kind.SAFE)
	assert_eq(effect.kind, VAULT_REVEAL_FX.Kind.SAFE)
	assert_not_null(effect.shard_particles)
	assert_eq(effect.shard_particles.name, "DiamondShards")
	assert_not_null(effect.shard_particles.texture, "Safe reveal has a generated shard texture")
	assert_not_null(
		effect.sparkle_particles, "Full motion adds a separate diamond facet sparkle layer"
	)
	assert_eq(effect.sparkle_particles.name, "DiamondSparkles")
	assert_null(effect.debris_particles)
	assert_null(effect.smoke_particles)


func test_vault_mine_effect_layers_shockwave_debris_and_smoke() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var effect = VAULT_REVEAL_FX.spawn(host, Vector2.ZERO, VAULT_REVEAL_FX.Kind.MINE)
	assert_eq(effect.kind, VAULT_REVEAL_FX.Kind.MINE)
	assert_not_null(effect.debris_particles)
	assert_not_null(effect.smoke_particles)
	assert_eq(effect.debris_particles.name, "MineDebris")
	assert_eq(effect.smoke_particles.name, "MineSmoke")
	assert_gt(effect.lifetime, 0.5, "Mine impact has time for its layered shockwave to read")


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
	ticker.set_number(110)
	assert_eq(ticker.text, "110", "Returning to the same target clears infinity state")
	assert_false(ticker._showing_infinity)


func test_number_ticker_snaps_when_reduced_motion_changes_mid_count() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)
	var ticker := AnimatedNumberLabel.new()
	add_child_autofree(ticker)
	ticker.set_number(10, "%d", false)
	ticker.set_number(500)
	assert_true(ticker._number_tween.is_running())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_eq(ticker.text, "500")
	assert_eq(int(ticker.displayed_value), 500)
	assert_null(ticker._number_tween)
	MotionPolicy.set_reduced_motion_for_tests(false)


func test_primary_spin_button_has_a_restrained_idle_breath() -> void:
	var spin := SlotSpinButton.new()
	spin.size = Vector2(140, 110)
	add_child_autofree(spin)
	var before := spin.idle_time
	spin._process(0.2)
	assert_gt(spin.idle_time, before)
	spin.disabled = true
	before = spin.idle_time
	spin._process(0.2)
	assert_eq(spin.idle_time, before, "Disabled primary actions do not pulse")


func test_win_burst_uses_integer_gutter_safe_regions() -> void:
	var texture: Texture2D = load("res://assets/production/effects/casino_win_burst_integer.png")
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(1024, 1032))
	assert_eq(WinCelebration.CELL_SIZE, Vector2i(256, 344))
	var image := texture.get_image()
	for row: int in range(3):
		for column: int in range(4):
			var origin := Vector2i(column * 256, row * 344)
			assert_eq(
				image.get_pixelv(origin).a, 0.0, "Every particle frame starts with a clear gutter"
			)


func test_blackjack_input_unlocks_from_completed_deal_motion() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	var math: BlackjackMath = session.cabinet.get("math")
	var shoe: Array[int] = []
	for _index: int in range(48):
		shoe.append(2)
	# pop_back deal order: player 10, dealer 9, player 7, dealer 8.
	shoe.append_array([8, 7, 9, 10])
	math.shoe = shoe
	assert_true(session.cabinet.start_round(10))
	assert_false(session.cabinet.panel.blackjack_input_ready())
	assert_gt(session.cabinet.panel._blackjack_pending_motions, 0)
	await wait_seconds(0.62)
	assert_true(session.cabinet.panel.blackjack_input_ready())
	assert_eq(session.cabinet.panel._blackjack_pending_motions, 0)
