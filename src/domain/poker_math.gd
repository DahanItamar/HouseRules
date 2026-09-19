class_name PokerMath
extends RefCounted
## Fixed-limit Texas Hold'em for one player against five NPCs.
##
## One round is one hand. The selected stake is the small bet and the big blind;
## the small blind is half of it; turn and river bets are twice the stake; each
## street allows one bet and three raises. The player's RoundResult stake is every
## chip they put in the pot this hand and the payout is their share of the pots
## they win (split pots and side pots included) minus the house rake. NPC stacks
## are table chips only and never touch the wallet.
##
## Everything resolves synchronously: `begin()` and `act()` run the NPCs until
## the player must decide (returning null) or the hand ends (returning the
## result). Every step is appended to `events` so presentation can replay it at
## its own pace without ever feeding back into the rules.

enum Street { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }
enum Action { FOLD, CHECK, CALL, BET, RAISE }

const PLAYER_SEAT: int = 0

var rules: PokerRules = preload("res://data/paytables/poker.tres")
var npcs: Array[PokerNpc] = PokerNpc.roster()
var rng: RandomNumberGenerator
var stake: int = 0
var hands_played: int = 0
var button: int = -1
var small_blind_seat: int = 0
var big_blind_seat: int = 0
var street: Street = Street.PREFLOP
var active: bool = false
## Table stacks. Seat 0 mirrors the player's spendable balance for the hand.
var stacks: Array[int] = []
var committed: Array[int] = []
var street_bets: Array[int] = []
var folded: Array[bool] = []
var all_in: Array[bool] = []
var acted: Array[bool] = []
var holes: Array = []
var board: Array[int] = []
var deck: Array[int] = []
var current_bet: int = 0
var bets_this_street: int = 0
var to_act: int = -1
var events: Array[Dictionary] = []
var last_result: RoundResult


func seat_count() -> int:
	return rules.seats


func is_player_turn() -> bool:
	return active and to_act == PLAYER_SEAT


func bet_size() -> int:
	return stake if street <= Street.FLOP else stake * 2


func pot_total() -> int:
	var total := 0
	for amount: int in committed:
		total += amount
	return total


func to_call(seat: int) -> int:
	return mini(current_bet - street_bets[seat], stacks[seat])


func player_committed() -> int:
	return committed[PLAYER_SEAT] if not committed.is_empty() else 0


func player_hole() -> Array[int]:
	var cards: Array[int] = []
	if not holes.is_empty():
		cards.assign(holes[PLAYER_SEAT])
	return cards


## Opponents still contesting the pot from `seat`'s point of view.
func live_opponents(seat: int) -> int:
	var count := 0
	for other: int in range(seat_count()):
		if other != seat and not folded[other]:
			count += 1
	return count


func can_raise(seat: int) -> bool:
	return (
		active
		and bets_this_street < rules.max_bets_per_street
		and stacks[seat] > current_bet - street_bets[seat]
		and _able_opponents(seat) > 0
	)


## What the player may do right now; empty when it is not their turn.
func legal_actions() -> Dictionary:
	if not is_player_turn():
		return {}
	var owed := to_call(PLAYER_SEAT)
	var raise_to := current_bet + bet_size()
	var raise_cost := mini(raise_to - street_bets[PLAYER_SEAT], stacks[PLAYER_SEAT])
	return {
		"can_fold": owed > 0,
		"can_check": owed == 0,
		"call_amount": owed,
		"call_all_in": owed > 0 and owed >= stacks[PLAYER_SEAT],
		"can_raise": can_raise(PLAYER_SEAT),
		"raise_is_bet": current_bet == 0,
		"raise_cost": raise_cost,
		"raise_to": street_bets[PLAYER_SEAT] + raise_cost,
	}


func begin(risked: int, stream: RandomNumberGenerator, player_balance: int) -> RoundResult:
	assert(not active and risked > 0 and player_balance >= risked)
	rng = stream
	stake = risked
	hands_played += 1
	var seats := seat_count()
	button = (button + 1) % seats
	_reset_hand_state(player_balance)
	for npc: PokerNpc in npcs:
		npc.reset_hand()
	_shuffle()
	active = true
	last_result = null
	small_blind_seat = (button + 1) % seats
	big_blind_seat = (button + 2) % seats
	(
		events
		. append(
			{
				"type": &"hand_start",
				"button": button,
				"small_blind": small_blind_seat,
				"big_blind": big_blind_seat,
				"stacks": stacks.duplicate(),
				"stake": stake,
			}
		)
	)
	@warning_ignore("integer_division")
	_post_blind(small_blind_seat, maxi(1, stake / 2))
	_post_blind(big_blind_seat, stake)
	current_bet = stake
	bets_this_street = 1
	for round_index: int in range(2):
		for offset: int in range(seats):
			var seat := (small_blind_seat + offset) % seats
			(holes[seat] as Array[int]).append(deck.pop_back())
	var order: Array[int] = []
	for offset: int in range(seats):
		order.append((small_blind_seat + offset) % seats)
	events.append({"type": &"hole_cards", "order": order, "player": player_hole()})
	to_act = (big_blind_seat + 1) % seats
	return _advance()


## The player's decision. Returns the result when the hand ends, else null.
func act(action: Action) -> RoundResult:
	if not is_player_turn():
		return null
	var owed := to_call(PLAYER_SEAT)
	match action:
		Action.FOLD:
			if owed == 0:
				return null
		Action.CHECK:
			if owed != 0:
				return null
		Action.CALL:
			if owed == 0:
				action = Action.CHECK
		Action.BET, Action.RAISE:
			if not can_raise(PLAYER_SEAT):
				return null
	_apply(PLAYER_SEAT, action)
	return _advance()


## Leaving mid-hand forfeits every chip already committed.
func abandon() -> RoundResult:
	if not active:
		return null
	active = false
	to_act = -1
	last_result = RoundResult.create(
		player_committed(), 0, RoundResult.Outcome.ABANDONED, {"abandoned": true}
	)
	return last_result


## Public information an NPC may use, plus its own hole cards.
func npc_view(seat: int) -> Dictionary:
	var seats := seat_count()
	# 0 for the first to act after the button, 1 for the button itself.
	var position := float(posmod(seat - button - 1, seats)) / float(seats - 1)
	var hole: Array[int] = []
	hole.assign(holes[seat])
	var view_board: Array[int] = board.duplicate()
	return {
		"hole": hole,
		"board": view_board,
		"street": int(street),
		"to_call": to_call(seat),
		"pot": pot_total(),
		"stake": stake,
		"bet_size": bet_size(),
		"bets": bets_this_street,
		"can_raise": can_raise(seat),
		"opponents": live_opponents(seat),
		"position": position,
	}


## A simple, sound baseline used by the economics harness and tests: plays the
## top quarter of starting hands, raises the top tenth, then bets or raises
## strong equity, calls by pot odds and otherwise checks or folds.
func baseline_action(samples: int = 32) -> Action:
	var legal := legal_actions()
	var hole := player_hole()
	var owed: int = legal.call_amount
	if street == Street.PREFLOP:
		var percentile := PokerOdds.preflop_percentile(hole[0], hole[1])
		if percentile <= 0.10 and legal.can_raise and bets_this_street < 3:
			return Action.RAISE
		if percentile <= 0.25 or owed == 0:
			return Action.CALL if owed > 0 else Action.CHECK
		return Action.FOLD
	var opponents := live_opponents(PLAYER_SEAT)
	var equity := PokerOdds.equity(hole, board, mini(opponents, 4), samples, rng)
	var strength := equity * float(opponents + 1)
	if strength >= 1.6 and legal.can_raise:
		return Action.BET if legal.raise_is_bet else Action.RAISE
	if owed == 0:
		return Action.CHECK
	if equity >= float(owed) / float(pot_total() + owed):
		return Action.CALL
	return Action.FOLD


func play_baseline(
	risked: int, stream: RandomNumberGenerator, player_balance: int, samples: int = 32
) -> RoundResult:
	var result := begin(risked, stream, player_balance)
	while result == null:
		result = act(baseline_action(samples))
	return result


func _reset_hand_state(player_balance: int) -> void:
	var seats := seat_count()
	if stacks.size() != seats:
		stacks.resize(seats)
		stacks.fill(0)
	stacks[PLAYER_SEAT] = player_balance
	for seat: int in range(1, seats):
		if stacks[seat] < rules.npc_rebuy_below_stakes * stake:
			stacks[seat] = rules.npc_buy_in_stakes * stake
	committed.resize(seats)
	committed.fill(0)
	street_bets.resize(seats)
	street_bets.fill(0)
	folded.resize(seats)
	folded.fill(false)
	all_in.resize(seats)
	all_in.fill(false)
	acted.resize(seats)
	acted.fill(false)
	holes.clear()
	for seat: int in range(seats):
		var hole: Array[int] = []
		holes.append(hole)
	board.clear()
	events.clear()
	street = Street.PREFLOP
	current_bet = 0
	bets_this_street = 0


func _shuffle() -> void:
	deck.clear()
	for card: int in range(52):
		deck.append(card)
	for index: int in range(deck.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var card: int = deck[index]
		deck[index] = deck[other]
		deck[other] = card


func _post_blind(seat: int, amount: int) -> void:
	var paid := _commit(seat, amount)
	(
		events
		. append(
			{
				"type": &"blind",
				"seat": seat,
				"amount": paid,
				"street_total": street_bets[seat],
				"stack": stacks[seat],
				"all_in": all_in[seat],
				"pot": pot_total(),
			}
		)
	)


func _commit(seat: int, amount: int) -> int:
	var paid := mini(amount, stacks[seat])
	stacks[seat] -= paid
	committed[seat] += paid
	street_bets[seat] += paid
	if stacks[seat] == 0:
		all_in[seat] = true
	return paid


func _able_opponents(seat: int) -> int:
	var count := 0
	for other: int in range(seat_count()):
		if other != seat and not folded[other] and not all_in[other]:
			count += 1
	return count


func _apply(seat: int, requested: Action) -> void:
	var action := requested
	var paid := 0
	var owed := to_call(seat)
	if action == Action.CHECK and owed > 0:
		action = Action.FOLD
	elif action == Action.CALL and owed == 0:
		action = Action.CHECK
	elif action == Action.FOLD and owed == 0:
		action = Action.CHECK
	elif (action == Action.BET or action == Action.RAISE) and not can_raise(seat):
		action = Action.CALL if owed > 0 else Action.CHECK
	match action:
		Action.FOLD:
			folded[seat] = true
		Action.CALL:
			paid = _commit(seat, owed)
		Action.BET, Action.RAISE:
			action = Action.BET if current_bet == 0 else Action.RAISE
			var target := current_bet + bet_size()
			paid = _commit(seat, target - street_bets[seat])
			if street_bets[seat] > current_bet:
				var full_raise := street_bets[seat] >= target
				current_bet = street_bets[seat]
				if full_raise:
					bets_this_street += 1
				for other: int in range(seat_count()):
					if other != seat:
						acted[other] = false
	acted[seat] = true
	(
		events
		. append(
			{
				"type": &"action",
				"seat": seat,
				"action": action,
				"amount": paid,
				"street_total": street_bets[seat],
				"stack": stacks[seat],
				"all_in": all_in[seat],
				"pot": pot_total(),
				"street": int(street),
				"reason": int(npcs[seat - 1].last_reason) if seat != PLAYER_SEAT else -1,
			}
		)
	)
	to_act = _next_seat(seat)


func _next_seat(seat: int) -> int:
	var seats := seat_count()
	for offset: int in range(1, seats + 1):
		var candidate := (seat + offset) % seats
		if not folded[candidate] and not all_in[candidate]:
			return candidate
	return -1


func _contenders() -> int:
	var count := 0
	for seat: int in range(seat_count()):
		if not folded[seat]:
			count += 1
	return count


func _street_complete() -> bool:
	var able := 0
	var pending := 0
	var last_able := -1
	for seat: int in range(seat_count()):
		if folded[seat] or all_in[seat]:
			continue
		able += 1
		last_able = seat
		if not acted[seat] or street_bets[seat] < current_bet:
			pending += 1
	if pending == 0:
		return true
	# A lone player who can still act only has to answer an outstanding bet.
	return able == 1 and street_bets[last_able] >= current_bet


func _advance() -> RoundResult:
	while true:
		if _contenders() <= 1:
			return _finish_hand()
		if _street_complete():
			if street == Street.RIVER:
				street = Street.SHOWDOWN
				return _finish_hand()
			_deal_next_street()
			continue
		if to_act < 0 or folded[to_act] or all_in[to_act]:
			to_act = _next_seat(to_act if to_act >= 0 else button)
			continue
		if to_act == PLAYER_SEAT and not folded[PLAYER_SEAT]:
			(
				events
				. append(
					{
						"type": &"player_turn",
						"to_call": to_call(PLAYER_SEAT),
						"pot": pot_total(),
						"street": int(street),
					}
				)
			)
			return null
		var npc: PokerNpc = npcs[to_act - 1]
		_apply(to_act, npc.decide(npc_view(to_act), rng) as Action)
	return null


func _deal_next_street() -> void:
	for seat: int in range(seat_count()):
		street_bets[seat] = 0
		acted[seat] = false
	current_bet = 0
	bets_this_street = 0
	street = (street + 1) as Street
	deck.pop_back()  # burn card
	var fresh: Array[int] = []
	var count := 3 if street == Street.FLOP else 1
	for index: int in range(count):
		fresh.append(deck.pop_back())
	board.append_array(fresh)
	(
		events
		. append(
			{
				"type": &"board",
				"street": int(street),
				"cards": fresh,
				"board": board.duplicate(),
				"pot": pot_total(),
			}
		)
	)
	to_act = _next_seat(button)


## Main pot and side pots by contribution level; folded chips stay in the pots.
## Chips nobody matched (an uncalled bet) come back as a final one-seat pot.
func build_pots() -> Array[Dictionary]:
	var pots: Array[Dictionary] = []
	var remaining: Array[int] = committed.duplicate()
	var top_seat := 0
	for seat: int in range(seat_count()):
		if remaining[seat] > remaining[top_seat]:
			top_seat = seat
	var second := 0
	for seat: int in range(seat_count()):
		if seat != top_seat:
			second = maxi(second, remaining[seat])
	var uncalled := remaining[top_seat] - second
	remaining[top_seat] = second
	while true:
		var eligible: Array[int] = []
		var level := -1
		for seat: int in range(seat_count()):
			if not folded[seat] and remaining[seat] > 0:
				eligible.append(seat)
				level = remaining[seat] if level < 0 else mini(level, remaining[seat])
		if eligible.is_empty():
			var leftover := 0
			for seat: int in range(seat_count()):
				leftover += remaining[seat]
			if leftover > 0 and not pots.is_empty():
				pots[pots.size() - 1].amount = int(pots[pots.size() - 1].amount) + leftover
			break
		var amount := 0
		var contributors := 0
		for seat: int in range(seat_count()):
			var take := mini(remaining[seat], level)
			if take > 0:
				contributors += 1
			amount += take
			remaining[seat] -= take
		pots.append({"amount": amount, "eligible": eligible, "contributors": contributors})
	if uncalled > 0:
		var owner: Array[int] = [top_seat]
		pots.append({"amount": uncalled, "eligible": owner, "contributors": 1})
	return pots


func _finish_hand() -> RoundResult:
	var showdown := _contenders() > 1
	var scores: Dictionary = {}
	if showdown:
		# Run out any board still missing (everyone left is all in).
		while board.size() < 5:
			_deal_next_street()
		street = Street.SHOWDOWN
		var reveals: Array[Dictionary] = []
		for seat: int in range(seat_count()):
			if folded[seat]:
				continue
			var cards: Array[int] = []
			cards.assign(holes[seat])
			var seven: Array[int] = cards.duplicate()
			seven.append_array(board)
			scores[seat] = PokerHandEval.evaluate(seven)
			(
				reveals
				. append(
					{
						"seat": seat,
						"cards": cards,
						"score": scores[seat],
						"best": PokerHandEval.best_five(seven),
					}
				)
			)
		events.append({"type": &"showdown", "hands": reveals})
	var pots := build_pots()
	var winnings: Array[int] = []
	winnings.resize(seat_count())
	winnings.fill(0)
	var rakeable := 0
	for pot_index: int in range(pots.size()):
		var pot: Dictionary = pots[pot_index]
		var eligible: Array[int] = pot.eligible
		var winners: Array[int] = []
		var best := -1
		for seat: int in eligible:
			var score: int = scores.get(seat, 0)
			if score > best:
				best = score
				winners = [seat]
			elif score == best:
				winners.append(seat)
		# Odd chips go to the first winner clockwise from the button.
		winners.sort_custom(
			func(a: int, b: int) -> bool:
				return posmod(a - button - 1, seat_count()) < posmod(b - button - 1, seat_count())
		)
		var amount: int = pot.amount
		@warning_ignore("integer_division")
		var share := amount / winners.size()
		var odd := amount - share * winners.size()
		var shares: Dictionary = {}
		for index: int in range(winners.size()):
			var won := share + (odd if index == 0 else 0)
			winnings[winners[index]] += won
			shares[winners[index]] = won
			# A pot only the player paid into is an uncalled bet coming back.
			if winners[index] == PLAYER_SEAT and int(pot.contributors) > 1:
				rakeable += won
		(
			events
			. append(
				{
					"type": &"award",
					"pot_index": pot_index,
					"amount": amount,
					"winners": winners,
					"shares": shares,
					"uncontested": not showdown,
					"returned": int(pot.contributors) == 1,
				}
			)
		)
	for seat: int in range(seat_count()):
		stacks[seat] += winnings[seat]
	var rake := 0
	var dropped: bool = not rules.no_flop_no_drop or board.size() >= 3
	if dropped and rakeable > 0:
		@warning_ignore("integer_division")
		rake = mini(rakeable * rules.rake_percent / 100, rules.rake_cap_stakes * stake)
	stacks[PLAYER_SEAT] -= rake
	for seat: int in range(1, seat_count()):
		npcs[seat - 1].observe_hand(winnings[seat] - committed[seat], stake)
	var risked := committed[PLAYER_SEAT]
	var payout := winnings[PLAYER_SEAT] - rake
	var outcome := RoundResult.Outcome.LOSS
	if payout > risked:
		outcome = RoundResult.Outcome.WIN
	elif payout == risked and risked > 0:
		outcome = RoundResult.Outcome.PUSH
	var player_score: int = scores.get(PLAYER_SEAT, -1)
	(
		events
		. append(
			{
				"type": &"hand_end",
				"rake": rake,
				"payout": payout,
				"stake": risked,
				"stacks": stacks.duplicate(),
			}
		)
	)
	active = false
	to_act = -1
	last_result = (
		RoundResult
		. create(
			risked,
			payout,
			outcome,
			{
				"board": board.duplicate(),
				"player": player_hole(),
				"player_score": player_score,
				"folded": folded[PLAYER_SEAT],
				"showdown": showdown,
				"gross": winnings[PLAYER_SEAT],
				"rake": rake,
				"pots": pots.size(),
			}
		)
	)
	return last_result
