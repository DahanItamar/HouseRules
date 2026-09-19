extends GutTest


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_live_win_coins_clear_immediately_without_touching_the_wallet() -> void:
	var starting_balance := Wallet.balance
	watch_signals(Wallet)
	var celebration := WinCelebration.new()
	add_child_autofree(celebration)
	celebration.burst(Vector2(240, 160), 10)
	var active_tokens: Array[Node] = []
	active_tokens.assign(celebration.get_children())
	assert_eq(active_tokens.size(), 10)
	for token: Control in active_tokens:
		assert_false(token.is_queued_for_deletion())
		assert_gt(token.modulate.a, 0.0)

	MotionPolicy.set_reduced_motion_for_tests(true)

	for token: Control in active_tokens:
		assert_true(
			token.is_queued_for_deletion() or not token.visible or token.modulate.a <= 0.001,
			"An already-flying win token must have no visible travel after the handoff"
		)
	assert_eq(Wallet.balance, starting_balance, "Presentation settlement cannot mutate chips")
	assert_signal_not_emitted(Wallet, "balance_changed")
	await get_tree().process_frame
	assert_eq(celebration.get_child_count(), 0, "Settled win tokens leave no hidden tween work")


func test_live_impact_burst_clears_immediately_without_touching_the_wallet() -> void:
	var starting_balance := Wallet.balance
	watch_signals(Wallet)
	var host := Node2D.new()
	add_child_autofree(host)
	var burst := ImpactBurst.spawn(host, Vector2(80, 60), Color.GOLD, true)
	assert_true(burst.particles.emitting)
	assert_false(burst.is_queued_for_deletion())

	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_true(
		burst.is_queued_for_deletion() or not burst.visible,
		"An active impact burst must disappear on the same preference-change signal"
	)
	assert_eq(Wallet.balance, starting_balance, "Presentation settlement cannot mutate chips")
	assert_signal_not_emitted(Wallet, "balance_changed")
	await get_tree().process_frame
	assert_false(is_instance_valid(burst), "No active particle process survives the handoff")


func test_live_vault_reveal_fx_clears_immediately_without_touching_the_wallet() -> void:
	var starting_balance := Wallet.balance
	watch_signals(Wallet)
	var host := Node2D.new()
	add_child_autofree(host)
	var safe_effect := VaultRevealFX.spawn(host, Vector2(50, 60), VaultRevealFX.Kind.SAFE)
	var mine_effect := VaultRevealFX.spawn(host, Vector2(110, 60), VaultRevealFX.Kind.MINE)
	assert_true(safe_effect.shard_particles.emitting)
	assert_not_null(safe_effect.sparkle_particles, "The safe reveal begins with full-motion sparkle")
	assert_true(mine_effect.debris_particles.emitting)
	assert_not_null(mine_effect.smoke_particles, "The mine reveal begins with full-motion smoke")
	assert_false(safe_effect.is_queued_for_deletion())
	assert_false(mine_effect.is_queued_for_deletion())

	MotionPolicy.set_reduced_motion_for_tests(true)

	for effect: VaultRevealFX in [safe_effect, mine_effect]:
		assert_true(
			effect.is_queued_for_deletion() or not effect.visible,
			"Active vault shards, shockwave, debris, and smoke must clear on the same signal"
		)
	assert_eq(Wallet.balance, starting_balance, "Presentation settlement cannot mutate chips")
	assert_signal_not_emitted(Wallet, "balance_changed")
	await get_tree().process_frame
	assert_false(is_instance_valid(safe_effect), "No safe-reveal particle survives the handoff")
	assert_false(is_instance_valid(mine_effect), "No mine particle or drawn shockwave survives the handoff")
