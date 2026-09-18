extends GutTest


func _rng(seed_value: int = 1234) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_slot_shipped_paytable_exhaustive_symbol_combinations() -> void:
	var math := SlotMachineMath.new()
	var weighted_return: int = 0
	var stops: int = 0
	for weight in math.paytable.weights:
		stops += weight
	for left in 6:
		for center in 6:
			for right in 6:
				var symbols: Array[int] = [left, center, right]
				var result := math.evaluate(symbols, 1)
				var expected: int = 0
				if left == center and center == right:
					expected = math.paytable.multipliers[left]
				elif symbols.count(0) == 2:
					expected = math.paytable.two_cherry_multiplier
				assert_eq(result.payout, expected)
				weighted_return += (
					result.payout
					* math.paytable.weights[left]
					* math.paytable.weights[center]
					* math.paytable.weights[right]
				)
	assert_almost_eq(float(weighted_return) / (stops * stops * stops), 0.954952838105468, 0.000001)


func test_ac014_seed_and_inputs_reproduce_all_three_cabinets() -> void:
	var first := _rng()
	var second := _rng()
	var slot_a := SlotMachineMath.new()
	var slot_b := SlotMachineMath.new()
	for index in 100:
		var a := slot_a.spin(10, first)
		var b := slot_b.spin(10, second)
		assert_eq(a.payout, b.payout)
		assert_eq(a.detail, b.detail)
	first = _rng()
	second = _rng()
	var blackjack_a := BlackjackMath.new()
	var blackjack_b := BlackjackMath.new()
	for index in 100:
		var a := blackjack_a.play_basic_strategy(10, first)
		var b := blackjack_b.play_basic_strategy(10, second)
		assert_eq(a.stake, b.stake)
		assert_eq(a.payout, b.payout)
		assert_eq(a.detail, b.detail)
	first = _rng()
	second = _rng()
	var vault_a := MinefieldMath.new()
	var vault_b := MinefieldMath.new()
	for index in 100:
		vault_a.begin(25, 3, first)
		vault_b.begin(25, 3, second)
		assert_eq(vault_a.mines, vault_b.mines)
		vault_a.active = false
		vault_b.active = false


func test_blackjack_ace_revaluation_and_soft_seventeen() -> void:
	assert_eq(BlackjackMath.hand_value([1, 1, 9]), 21)
	assert_eq(BlackjackMath.hand_value([1, 13, 5]), 16)
	assert_true(BlackjackMath.is_soft([1, 6]))
	assert_false(BlackjackMath.is_soft([1, 6, 13]))
	var math := BlackjackMath.new()
	math.begin(10, _rng())
	math.active = true
	math.player.assign([10, 8])
	math.dealer.assign([1, 6])
	var remaining := math.remaining_cards()
	var result := math.stand()
	assert_eq(result.payout, 20, "Dealer must stand on soft 17")
	assert_eq(math.remaining_cards(), remaining)


func test_blackjack_natural_and_double_return_integer_chips() -> void:
	var math := BlackjackMath.new()
	math.rng = _rng()
	# A full shoe keeps the between-hand reshuffle from replacing the forced deal.
	math.shoe.resize(60)
	math.shoe.fill(10)
	math.shoe[59] = 1
	var result := math.begin(10, math.rng)
	assert_not_null(result)
	if result != null:
		assert_eq(result.payout, 25)
	math.begin(10, _rng())
	math.active = true
	math.stake = 10
	math.player.assign([5, 6])
	math.dealer.assign([10, 8])
	math.shoe.append(10)
	assert_false(math.can_double(19))
	assert_true(math.can_double(20))
	result = math.double_down(20)
	assert_eq(result.stake, 20)
	assert_eq(result.payout, 40)
	assert_false(math.active)


func test_vault_unique_fixed_mines_cashout_and_duplicate_reveal() -> void:
	var math := MinefieldMath.new()
	math.begin(25, 3, _rng())
	assert_eq(math.mines.size(), 3)
	var unique := {}
	for tile in math.mines:
		unique[tile] = true
	assert_eq(unique.size(), 3)
	assert_null(math.cash_out(), "No cash-out before a safe reveal")
	var initial_mines := math.mines.duplicate()
	for tile in 25:
		if not tile in math.mines:
			assert_null(math.reveal(tile))
			assert_eq(math.safe_reveals, 1)
			assert_null(math.reveal(tile))
			assert_eq(math.safe_reveals, 1)
			break
	assert_eq(math.mines, initial_mines)
	var result := math.cash_out()
	assert_eq(result.payout, MinefieldMath.payout_for(25, 3, 1))
	assert_false(math.active)
	math.begin(25, 3, _rng())
	result = math.reveal(math.mines[0])
	assert_eq(result.payout, 0)
	assert_false(math.active)


func test_vault_all_clear_and_cap() -> void:
	var math := MinefieldMath.new()
	math.begin(20, 24, _rng())
	for tile in 25:
		if not tile in math.mines:
			var result := math.reveal(tile)
			assert_not_null(result)
			assert_eq(result.payout, 485)
	assert_false(math.active)
	assert_lte(MinefieldMath.payout_for(25, 12, 13), 125_000)
