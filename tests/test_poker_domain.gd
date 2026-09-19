extends GutTest
## Texas Hold'em domain: hand ranking, pots, rake, betting limits, NPCs, replay.

const POKER_DEFINITION: CabinetDefinition = preload("res://data/cabinets/poker.tres")
const RANKS := "23456789TJQKA"
const SUITS := "shdc"


## "As Kd" style notation -> card ints (rank index * 4 + suit, spade/heart/diamond/club).
func _cards(text: String) -> Array[int]:
	var cards: Array[int] = []
	for token: String in text.split(" ", false):
		cards.append(PokerHandEval.make_card(RANKS.find(token[0]), SUITS.find(token[1])))
	return cards


func _score(text: String) -> int:
	return PokerHandEval.evaluate(_cards(text))


func _category(text: String) -> int:
	return PokerHandEval.category_of(_score(text))


# --- Independent brute-force reference ---------------------------------------


func _reference_five(cards: Array[int]) -> int:
	var ranks: Array[int] = []
	var flush := true
	for card: int in cards:
		ranks.append(card >> 2)
		if card & 3 != cards[0] & 3:
			flush = false
	ranks.sort()
	ranks.reverse()
	var tally: Dictionary = {}
	for rank: int in ranks:
		tally[rank] = int(tally.get(rank, 0)) + 1
	var groups: Array = tally.keys()
	groups.sort_custom(
		func(a: int, b: int) -> bool:
			if tally[a] != tally[b]:
				return tally[a] > tally[b]
			return a > b
	)
	var pattern: Array[int] = []
	for rank: int in groups:
		pattern.append(tally[rank])
	var straight_high := -1
	if groups.size() == 5:
		if ranks[0] - ranks[4] == 4:
			straight_high = ranks[0]
		elif ranks == [12, 3, 2, 1, 0]:
			straight_high = 3
	var category := 0
	var order: Array[int] = []
	order.assign(groups)
	if straight_high >= 0 and flush:
		category = 8
		order = [straight_high]
	elif pattern == [4, 1]:
		category = 7
	elif pattern == [3, 2]:
		category = 6
	elif flush:
		category = 5
		order = ranks
	elif straight_high >= 0:
		category = 4
		order = [straight_high]
	elif pattern == [3, 1, 1]:
		category = 3
	elif pattern == [2, 2, 1]:
		category = 2
	elif pattern == [2, 1, 1, 1]:
		category = 1
	else:
		order = ranks
	var score := category << 20
	for index: int in range(order.size()):
		score |= order[index] << (16 - 4 * index)
	return score


func _reference_best(cards: Array[int]) -> int:
	var best := -1
	var count := cards.size()
	for a: int in range(count):
		for b: int in range(a + 1, count):
			for c: int in range(b + 1, count):
				for d: int in range(c + 1, count):
					for e: int in range(d + 1, count):
						best = maxi(
							best,
							_reference_five([cards[a], cards[b], cards[c], cards[d], cards[e]])
						)
	return best


func _random_hand(rng: RandomNumberGenerator, size: int) -> Array[int]:
	var deck: Array[int] = []
	for card: int in range(52):
		deck.append(card)
	var hand: Array[int] = []
	for index: int in range(size):
		var pick := rng.randi_range(index, 51)
		var swap := deck[index]
		deck[index] = deck[pick]
		deck[pick] = swap
		hand.append(deck[index])
	return hand


# --- Hand evaluation ----------------------------------------------------------


func test_every_category_is_recognised() -> void:
	var category := PokerHandEval.Category
	assert_eq(_category("Ah Kh Qh Jh Th 2c 3d"), category.STRAIGHT_FLUSH, "royal flush")
	assert_eq(_category("9s 9h 9d 9c 2h 3d 5s"), category.QUADS)
	assert_eq(_category("Ks Kh Kd 4c 4h 2d 7s"), category.FULL_HOUSE)
	assert_eq(_category("2c 7c 9c Jc Kc 3h 4d"), category.FLUSH)
	assert_eq(_category("5s 6h 7d 8c 9h Kd 2s"), category.STRAIGHT)
	assert_eq(_category("Qs Qh Qd 2c 7h 9d 4s"), category.TRIPS)
	assert_eq(_category("Js Jh 5d 5c Ah 9d 2s"), category.TWO_PAIR)
	assert_eq(_category("Ts Th 3d 6c Ah 9d 2s"), category.PAIR)
	assert_eq(_category("As Jh 8d 6c 4h 3d 2c"), category.HIGH_CARD)


func test_wheel_straights_rank_five_high() -> void:
	var wheel := _score("As 2h 3d 4c 5h Kd 9s")
	var six_high := _score("2s 3h 4d 5c 6h Kd 9s")
	assert_eq(PokerHandEval.category_of(wheel), PokerHandEval.Category.STRAIGHT)
	assert_gt(six_high, wheel, "A-2-3-4-5 is the lowest straight")
	var steel_wheel := _score("Ad 2d 3d 4d 5d Kc 9s")
	assert_eq(PokerHandEval.category_of(steel_wheel), PokerHandEval.Category.STRAIGHT_FLUSH)
	assert_lt(steel_wheel, _score("2d 3d 4d 5d 6d Kc 9s"))
	# Q-K-A-2-3 does not wrap around.
	assert_eq(_category("Qs Kh Ad 2c 3h 8d 9s"), PokerHandEval.Category.HIGH_CARD)


func test_known_comparisons_and_kickers() -> void:
	assert_gt(_score("Ah Kh Qh Jh Th"), _score("9s 9h 9d 9c Ah"), "straight flush beats quads")
	assert_gt(_score("9s 9h 9d 9c Ah"), _score("9s 9h 9d 9c Kh"), "quad kicker")
	assert_gt(_score("3s 3h 3d 2c 2h"), _score("2s 2h 2d Ac Ah"), "full house by trips first")
	assert_gt(_score("As Ah Ad 5c 5h 5d 2s"), _score("Ks Kh Kd Qc Qh Qd 2s"), "two trips")
	assert_eq(
		_score("As Ah Ad 5c 5h 5d 7s"),
		_score("As Ah Ad 5c 5h 7s 2d"),
		"second trips play as the pair"
	)
	assert_gt(_score("Ac 9c 7c 4c 2c"), _score("Kc Qc Jc 9c 7c"), "flush by high card")
	assert_gt(_score("Ac Kc 7c 4c 3c"), _score("Ac Kc 7c 4c 2c"), "flush fifth card")
	assert_gt(_score("2c 3c 4c 5c 7c"), _score("Ts Jh Qd Kc Ah"), "flush beats straight")
	assert_gt(_score("Js Jh 5d 5c Ah"), _score("Js Jh 5d 5c Kh"), "two pair kicker")
	assert_eq(
		_score("Js Jh 5d 5c 3h 3d Ah"),
		_score("Js Jh 5d 5c Ah 2d 4s"),
		"third pair never plays below an ace kicker"
	)
	assert_gt(
		_score("Js Jh 5d 5c 3h 3d 4s"), _score("Js Jh 5d 5c 2h 2d 3s"), "third pair as kicker"
	)
	assert_gt(_score("Ts Th Ad 6c 3h"), _score("Ts Th Kd Qc Jh"), "pair first kicker")
	assert_gt(_score("Ts Th Ad 6c 4h"), _score("Ts Th Ad 6c 3h"), "pair third kicker")
	assert_gt(_score("As Kh Qd Jc 9h"), _score("As Kh Qd Jc 8h"), "high card fifth kicker")
	assert_gt(_score("Ks Kh 2d 3c 4h"), _score("Qs Qh Ad Kc Jh"), "higher pair beats kickers")


func test_board_plays_splits_evenly() -> void:
	var board := "Ts Jh Qd Kc Ah"
	assert_eq(_score(board + " 2c 3d"), _score(board + " 4s 5h"), "broadway on board splits")
	assert_eq(_score("As Ad Kc Kd Qh 2s 3s"), _score("Ah Ac Ks Kh Qd 4c 5c"))


func test_seven_card_cross_check_against_brute_force_reference() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_202_609
	var mismatches := 0
	for trial: int in range(3000):
		var hand := _random_hand(rng, 7)
		if PokerHandEval.evaluate(hand) != _reference_best(hand):
			mismatches += 1
			if mismatches <= 3:
				gut.p("Mismatch: %s" % [hand])
	assert_eq(mismatches, 0, "fast evaluator equals brute-force best-of-21 on 3000 hands")


func test_five_and_six_card_cross_check() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var mismatches := 0
	for trial: int in range(1500):
		var size := 5 if trial % 2 == 0 else 6
		var hand := _random_hand(rng, size)
		if PokerHandEval.evaluate(hand) != _reference_best(hand):
			mismatches += 1
	assert_eq(mismatches, 0)


func test_pairwise_ordering_matches_reference() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var disagreements := 0
	for trial: int in range(1500):
		var dealt := _random_hand(rng, 9)
		var board: Array[int] = dealt.slice(4)
		var first: Array[int] = dealt.slice(0, 2)
		var second: Array[int] = dealt.slice(2, 4)
		first.append_array(board)
		second.append_array(board)
		var fast := signi(PokerHandEval.evaluate(first) - PokerHandEval.evaluate(second))
		var slow := signi(_reference_best(first) - _reference_best(second))
		if fast != slow:
			disagreements += 1
	assert_eq(disagreements, 0, "head-to-head winners and splits agree on 1500 deals")


func test_best_five_matches_score() -> void:
	var seven := _cards("As 2h 3d 4c 5h Kd 9s")
	var best := PokerHandEval.best_five(seven)
	assert_eq(best.size(), 5)
	assert_eq(PokerHandEval.evaluate(best), PokerHandEval.evaluate(seven))
	assert_false(best.has(_cards("Kd")[0]), "the wheel does not use the king")


func test_category_keys_and_display_ranks() -> void:
	assert_eq(PokerHandEval.category_key(_score("Js Jh 5d 5c Ah")), "POKER_HAND_TWO_PAIR")
	assert_eq(PokerHandEval.display_rank(_cards("As")[0]), 1)
	assert_eq(PokerHandEval.display_rank(_cards("Kd")[0]), 13)
	assert_eq(PokerHandEval.display_rank(_cards("2c")[0]), 2)
	assert_eq(PokerHandEval.suit_of(_cards("2c")[0]), 3)


# --- Odds ---------------------------------------------------------------------


func test_preflop_percentiles_order_starting_hands() -> void:
	var aces := PokerOdds.preflop_percentile(_cards("As")[0], _cards("Ah")[0])
	var suited_connector := PokerOdds.preflop_percentile(_cards("9s")[0], _cards("8s")[0])
	var junk := PokerOdds.preflop_percentile(_cards("7c")[0], _cards("2d")[0])
	assert_lt(aces, 0.01)
	assert_lt(aces, suited_connector)
	assert_lt(suited_connector, junk)
	assert_gt(junk, 0.9)
	assert_eq(PokerOdds.chen_score(_cards("As")[0], _cards("Ah")[0]), 20)
	assert_eq(PokerOdds.chen_score(_cards("2s")[0], _cards("2h")[0]), 5)


func test_equity_is_deterministic_and_sensible() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4
	var hole := _cards("As Ah")
	var board := _cards("Ad 7c 2h")
	var first := PokerOdds.equity(hole, board, 1, 200, rng_a)
	assert_eq(first, PokerOdds.equity(hole, board, 1, 200, rng_b), "same stream, same answer")
	assert_gt(first, 0.9, "top set is a huge favourite")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var air := PokerOdds.equity(_cards("3c 8d"), _cards("As Kh Qs Jd"), 3, 200, rng)
	assert_lt(air, 0.15)


# --- Table flow -----------------------------------------------------------------


func _stream(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _event_summary(math: PokerMath) -> Array:
	var summary: Array = []
	for event: Dictionary in math.events:
		summary.append([event.type, event.get("seat", -1), event.get("amount", -1)])
	return summary


func test_identical_seed_and_inputs_replay_identically() -> void:
	var runs: Array = []
	for attempt: int in range(2):
		var math := PokerMath.new()
		var rng := _stream(20260918)
		var history: Array = []
		for hand: int in range(25):
			var result := math.play_baseline(10, rng, 5000, 16)
			history.append([result.stake, result.payout, result.outcome, _event_summary(math)])
		runs.append(history)
	assert_eq(runs[0], runs[1], "AC-014: same seed and choices replay the same 25 hands")


func test_chips_are_conserved_and_integer() -> void:
	var math := PokerMath.new()
	var rng := _stream(77)
	for hand: int in range(150):
		var result := math.play_baseline(10, rng, 3000, 12)
		var start: Array = math.events[0].stacks
		var finish: Dictionary = math.events[math.events.size() - 1]
		var before := 0
		var after := 0
		for index: int in range(start.size()):
			before += int(start[index])
			after += int(finish.stacks[index])
		assert_eq(after + int(finish.rake), before, "no chip is created or lost (hand %d)" % hand)
		assert_typeof(result.stake, TYPE_INT)
		assert_typeof(result.payout, TYPE_INT)
		assert_true(result.payout >= 0)
		assert_eq(result.stake, math.committed[0])


func test_player_never_commits_beyond_balance_and_side_pots_settle() -> void:
	var math := PokerMath.new()
	var rng := _stream(313)
	var all_in_hands := 0
	for hand: int in range(200):
		var balance := 10 + (hand % 5) * 7
		var result := math.begin(10, rng, balance)
		while result == null:
			var legal := math.legal_actions()
			# Always push: raise when allowed, otherwise call.
			var action := PokerMath.Action.RAISE if legal.can_raise else PokerMath.Action.CALL
			result = math.act(action)
		assert_true(result.stake <= balance, "stake %d within balance %d" % [result.stake, balance])
		if math.all_in[0]:
			all_in_hands += 1
	assert_gt(all_in_hands, 20, "short stacks reach all-in and side pots")


func test_build_pots_splits_side_pots_by_contribution() -> void:
	var math := PokerMath.new()
	math.stake = 10
	math.committed = [30, 80, 80, 10, 0, 0]
	math.folded = [false, false, false, true, true, true]
	var pots := math.build_pots()
	assert_eq(pots.size(), 2)
	assert_eq(int(pots[0].amount), 30 + 30 + 30 + 10, "main pot holds the folded blind")
	assert_eq(pots[0].eligible, [0, 1, 2])
	assert_eq(int(pots[1].amount), 100)
	assert_eq(pots[1].eligible, [1, 2])


func test_split_pot_and_odd_chip_go_clockwise_from_button() -> void:
	var math := PokerMath.new()
	var rng := _stream(1)
	math.begin(10, rng, 1000)
	# Rig a showdown between the player and seat 3 with a board that plays.
	math.board = _cards("Ts Jh Qd Kc Ah")
	math.holes[0] = _cards("2c 3d")
	math.holes[3] = _cards("4s 5h")
	# Seat 4 folded a single chip into the pot, making the split pot odd.
	math.committed = [15, 0, 0, 15, 1, 0]
	math.folded = [false, true, true, false, true, true]
	math.button = 1
	var result := math._finish_hand()
	# 31 chips: 15 each and the odd chip to seat 3, first clockwise from the button.
	@warning_ignore("integer_division")
	var expected_rake: int = 15 * math.rules.rake_percent / 100
	assert_eq(result.detail.rake, expected_rake, "rake only on the player's 15 chip share")
	assert_eq(result.payout, 15 - expected_rake)
	var award: Dictionary = {}
	for event: Dictionary in math.events:
		if event.type == &"award":
			award = event
	assert_eq(award.shares, {3: 16, 0: 15})


func test_rake_is_capped_and_skipped_without_a_flop() -> void:
	var math := PokerMath.new()
	var rng := _stream(2)
	math.begin(10, rng, 1000)
	math.board = _cards("As Ad 7c 2h 9s")
	math.holes[0] = _cards("Ah Ac")
	math.holes[1] = _cards("Kd Kh")
	math.committed = [240, 240, 240, 240, 0, 0]
	math.folded = [false, false, false, false, true, true]
	var big := math._finish_hand()
	assert_eq(big.detail.rake, 30, "the percentage of 960 is capped at three stakes")
	assert_eq(big.payout, 960 - 30)
	var preflop := PokerMath.new()
	preflop.begin(10, _stream(3), 1000)
	preflop.board.clear()
	preflop.committed = [10, 5, 0, 0, 0, 0]
	preflop.folded = [false, true, true, true, true, true]
	var walk := preflop._finish_hand()
	assert_eq(walk.detail.rake, 0, "no flop, no drop")
	assert_eq(walk.payout, 15)
	assert_eq(walk.outcome, RoundResult.Outcome.WIN)


func test_uncalled_bet_is_returned_without_rake() -> void:
	var math := PokerMath.new()
	math.begin(10, _stream(4), 1000)
	math.board = _cards("As Ad 7c 2h 9s")
	math.committed = [60, 40, 0, 0, 0, 0]
	math.folded = [false, true, true, true, true, true]
	var result := math._finish_hand()
	# 20 of the player's 60 were never called: they return unraked. Only the
	# contested 80 chip pot pays rake.
	@warning_ignore("integer_division")
	var expected_rake: int = 80 * math.rules.rake_percent / 100
	assert_eq(result.detail.rake, expected_rake)
	assert_eq(result.payout, 100 - expected_rake)
	assert_eq(result.outcome, RoundResult.Outcome.WIN)


func test_betting_is_capped_at_four_bets_per_street() -> void:
	var math := PokerMath.new()
	var rng := _stream(99)
	for hand: int in range(120):
		var result := math.begin(10, rng, 100000)
		while result == null:
			var legal := math.legal_actions()
			result = math.act(PokerMath.Action.RAISE if legal.can_raise else PokerMath.Action.CALL)
		var raises: Dictionary = {}
		for event: Dictionary in math.events:
			if (
				event.type == &"action"
				and event.action in [PokerMath.Action.BET, PokerMath.Action.RAISE]
			):
				var street: int = event.street
				raises[street] = int(raises.get(street, 0)) + 1
		for street: int in raises:
			var limit := 3 if street == 0 else 4
			assert_true(
				raises[street] <= limit, "street %d raised %d times" % [street, raises[street]]
			)


func test_fixed_limit_bet_sizes() -> void:
	var math := PokerMath.new()
	var rng := _stream(5)
	for hand: int in range(80):
		var result := math.begin(10, rng, 100000)
		while result == null:
			var legal := math.legal_actions()
			result = math.act(PokerMath.Action.RAISE if legal.can_raise else PokerMath.Action.CALL)
		for event: Dictionary in math.events:
			if (
				event.type == &"action"
				and event.action in [PokerMath.Action.BET, PokerMath.Action.RAISE]
			):
				var step := 10 if int(event.street) <= PokerMath.Street.FLOP else 20
				assert_eq(int(event.street_total) % step, 0, "bets move in fixed increments")


func test_illegal_player_actions_are_refused() -> void:
	var math := PokerMath.new()
	var rng := _stream(6)
	var checked := false
	for hand: int in range(40):
		var result := math.begin(10, rng, 1000)
		while result == null:
			var legal := math.legal_actions()
			if legal.can_check:
				var events_before := math.events.size()
				assert_null(math.act(PokerMath.Action.FOLD), "folding for free is refused")
				assert_eq(math.events.size(), events_before)
				checked = true
				result = math.act(PokerMath.Action.CHECK)
			else:
				assert_null(math.act(PokerMath.Action.CHECK), "cannot check facing a bet")
				result = math.act(PokerMath.Action.FOLD)
	assert_true(checked)
	assert_true(math.legal_actions().is_empty(), "no actions between hands")


func test_abandon_forfeits_committed_chips() -> void:
	var math := PokerMath.new()
	var rng := _stream(8)
	var result := math.begin(10, rng, 1000)
	while result != null:
		result = math.begin(10, rng, 1000)
	math.act(
		PokerMath.Action.CALL if math.legal_actions().call_amount > 0 else PokerMath.Action.CHECK
	)
	if math.active:
		var committed := math.player_committed()
		var abandoned := math.abandon()
		assert_eq(abandoned.outcome, RoundResult.Outcome.ABANDONED)
		assert_eq(abandoned.stake, committed)
		assert_eq(abandoned.payout, 0)
		assert_null(math.abandon(), "abandon is idempotent")


func test_npc_stacks_rebuy_and_never_touch_the_wallet() -> void:
	var math := PokerMath.new()
	var rng := _stream(10)
	for hand: int in range(60):
		math.play_baseline(10, rng, 900, 12)
		for seat: int in range(1, 6):
			assert_true(math.stacks[seat] >= 0)
	math.begin(10, rng, 900)
	var start: Array = math.events[0].stacks
	for seat: int in range(1, 6):
		assert_true(int(start[seat]) >= 24 * 10, "NPC topped up to cover a capped hand")
	assert_eq(int(start[0]), 900, "seat 0 mirrors the player's balance only")


func test_personalities_are_distinct() -> void:
	var math := PokerMath.new()
	var rng := _stream(424242)
	var voluntary: Array[int] = [0, 0, 0, 0, 0, 0]
	var raises: Array[int] = [0, 0, 0, 0, 0, 0]
	var folds_facing: Array[int] = [0, 0, 0, 0, 0, 0]
	var facing: Array[int] = [0, 0, 0, 0, 0, 0]
	var hands := 400
	for hand: int in range(hands):
		math.begin(10, rng, 100000)
		# The player folds at once so the NPCs play among themselves.
		while math.is_player_turn():
			if math.legal_actions().can_fold:
				math.act(PokerMath.Action.FOLD)
			else:
				math.act(PokerMath.Action.CHECK)
		var played: Dictionary = {}
		for event: Dictionary in math.events:
			if event.type != &"action" or int(event.seat) == 0:
				continue
			var seat: int = event.seat
			var action: int = event.action
			if int(event.street) == 0 and action in [PokerMath.Action.CALL, PokerMath.Action.RAISE]:
				played[seat] = true
			if action in [PokerMath.Action.BET, PokerMath.Action.RAISE]:
				raises[seat] += 1
			if (
				int(event.street) > 0
				and action in [PokerMath.Action.FOLD, PokerMath.Action.CALL, PokerMath.Action.RAISE]
			):
				facing[seat] += 1
				if action == PokerMath.Action.FOLD:
					folds_facing[seat] += 1
		for seat: int in played:
			voluntary[seat] += 1
	# Seats: 1 Shark, 2 Rock, 3 Maniac, 4 Calling Station, 5 Tourist.
	gut.p("VPIP %s raises %s fold-to-bet %s/%s" % [voluntary, raises, folds_facing, facing])
	assert_lt(voluntary[2], voluntary[1], "the Rock plays fewer hands than the Shark")
	assert_gt(voluntary[3], voluntary[1], "the Maniac plays more hands than the Shark")
	assert_gt(voluntary[4], voluntary[1], "the Calling Station plays more hands than the Shark")
	assert_gt(raises[3], raises[4] * 3, "the Maniac raises far more than the Calling Station")
	var station_fold := float(folds_facing[4]) / maxf(facing[4], 1.0)
	var rock_fold := float(folds_facing[2]) / maxf(facing[2], 1.0)
	assert_lt(station_fold, rock_fold, "the Calling Station folds to bets less than the Rock")


func test_tourist_makes_visible_mistakes() -> void:
	var tourist: PokerNpc = PokerNpc.roster()[4]
	var shark: PokerNpc = PokerNpc.roster()[0]
	var rng := _stream(12)
	var view := {
		"hole": _cards("As Ah"),
		"board": _cards("Ad Ac 7h"),
		"street": 1,
		"to_call": 20,
		"pot": 60,
		"stake": 10,
		"bet_size": 10,
		"bets": 1,
		"can_raise": true,
		"opponents": 2,
		"position": 0.5,
	}
	var tourist_folds := 0
	var shark_folds := 0
	for trial: int in range(400):
		tourist.reset_hand()
		shark.reset_hand()
		if tourist.decide(view, rng) == PokerMath.Action.FOLD:
			tourist_folds += 1
		if shark.decide(view, rng) == PokerMath.Action.FOLD:
			shark_folds += 1
	assert_gt(tourist_folds, 10, "the Tourist sometimes folds four aces")
	assert_lt(shark_folds, tourist_folds)


func test_rake_rules_ship_as_documented() -> void:
	var rules: PokerRules = load("res://data/paytables/poker.tres")
	assert_eq(rules.rake_percent, 10)
	assert_eq(rules.rake_cap_stakes, 3)
	assert_true(rules.no_flop_no_drop)
	assert_eq(rules.max_bets_per_street, 4)
	assert_true(rules.npc_rebuy_below_stakes >= 24, "NPCs always cover a capped hand")


func test_recorded_baseline_matches_the_declared_target() -> void:
	## The 100k-hand baseline lives in rtp.json (tests/poker_economics.gd); the
	## declared target must sit inside its documented tolerance (docs/cabinets/poker.md).
	var definition := POKER_DEFINITION
	var report: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/results/rtp.json")
	)
	assert_true(report is Dictionary)
	var entry: Dictionary = {}
	for candidate: Variant in (report as Dictionary).get("results", []):
		if candidate is Dictionary and str(candidate.get("cabinet", "")) == "poker":
			entry = candidate
	assert_false(entry.is_empty(), "poker baseline recorded")
	if entry.is_empty():
		return
	assert_true(bool(entry.skill_dependent), "labelled skill-dependent, not a fixed RTP")
	assert_gte(int(entry.rounds), 20000)
	assert_almost_eq(float(entry.observed_rtp), definition.target_rtp, 0.03)


func test_baseline_sample_stays_near_the_declared_target() -> void:
	var definition := POKER_DEFINITION
	var math := PokerMath.new()
	var rng := _stream(777)
	var wagered := 0
	var returned := 0
	for hand: int in range(1500):
		var result := math.play_baseline(10, rng, 100000, 12)
		wagered += result.stake
		returned += result.payout
	var observed := float(returned) / float(wagered)
	gut.p("Baseline 1500-hand sample: %.4f (target %.3f)" % [observed, definition.target_rtp])
	# About 3.5 standard errors at 1500 hands; the tight check is the 100k record.
	assert_almost_eq(observed, definition.target_rtp, 0.25)
