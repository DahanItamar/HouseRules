class_name BlackjackMath
extends RefCounted

var paytable: BlackjackPaytable = preload("res://data/paytables/blackjack.tres")
var player: Array[int] = []
var dealer: Array[int] = []
var shoe: Array[int] = []
var rng: RandomNumberGenerator
var stake: int = 0
var active: bool = false
var doubled: bool = false


static func hand_value(cards: Array[int]) -> int:
	var total: int = 0
	var aces: int = 0
	for rank: int in cards:
		if rank == 1:
			aces += 1
			total += 11
		else:
			total += mini(rank, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


static func is_soft(cards: Array[int]) -> bool:
	var low: int = 0
	for rank: int in cards:
		low += mini(rank, 10)
	return cards.has(1) and low + 10 <= 21


func remaining_cards() -> int:
	return shoe.size()


func _shuffle() -> void:
	shoe.clear()
	for deck: int in range(paytable.decks):
		for suit: int in range(4):
			for rank: int in range(1, 14):
				shoe.append(rank)
	for index: int in range(shoe.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var card: int = shoe[index]
		shoe[index] = shoe[other]
		shoe[other] = card


func _draw() -> int:
	assert(not shoe.is_empty(), "Shoe must only be replenished between hands")
	return shoe.pop_back()


func begin(risked: int, stream: RandomNumberGenerator) -> RoundResult:
	assert(not active and risked > 0)
	rng = stream
	stake = risked
	doubled = false
	if remaining_cards() < paytable.reshuffle_below:
		_shuffle()
	player.clear()
	dealer.clear()
	player.append(_draw())
	dealer.append(_draw())
	player.append(_draw())
	dealer.append(_draw())
	active = true
	var player_natural: bool = hand_value(player) == 21
	var dealer_natural: bool = hand_value(dealer) == 21
	if player_natural and dealer_natural:
		return _resolve(stake, RoundResult.Outcome.PUSH)
	if player_natural:
		@warning_ignore("integer_division")
		var natural_payout: int = stake * paytable.natural_numerator / paytable.natural_denominator
		return _resolve(natural_payout, RoundResult.Outcome.WIN)
	if dealer_natural:
		return _resolve(0, RoundResult.Outcome.LOSS)
	return null


func can_double(balance: int) -> bool:
	return active and player.size() == 2 and balance >= stake * 2


func hit() -> RoundResult:
	if not active:
		return null
	player.append(_draw())
	if hand_value(player) > 21:
		return _resolve(0, RoundResult.Outcome.LOSS)
	if hand_value(player) == 21:
		return stand()
	return null


func stand() -> RoundResult:
	if not active:
		return null
	while hand_value(dealer) < 17:
		dealer.append(_draw())
	var player_total: int = hand_value(player)
	var dealer_total: int = hand_value(dealer)
	if dealer_total > 21 or player_total > dealer_total:
		return _resolve(stake * 2, RoundResult.Outcome.WIN)
	if player_total == dealer_total:
		return _resolve(stake, RoundResult.Outcome.PUSH)
	return _resolve(0, RoundResult.Outcome.LOSS)


func double_down(balance: int) -> RoundResult:
	if not can_double(balance):
		return null
	doubled = true
	stake *= 2
	player.append(_draw())
	if hand_value(player) > 21:
		return _resolve(0, RoundResult.Outcome.LOSS)
	return stand()


func abandon() -> RoundResult:
	if not active:
		return null
	return _resolve(0, RoundResult.Outcome.ABANDONED)


func _resolve(payout: int, outcome: RoundResult.Outcome) -> RoundResult:
	active = false
	return RoundResult.create(
		stake,
		mini(payout, stake * paytable.max_win),
		outcome,
		{"player": player.duplicate(), "dealer": dealer.duplicate(), "doubled": doubled}
	)


func basic_strategy(balance: int) -> StringName:
	var total: int = hand_value(player)
	var up: int = mini(dealer[0], 10)
	if up == 1:
		up = 11
	var double: bool = false
	var fallback: StringName = &"hit"
	if is_soft(player):
		if total >= 19:
			return &"stand"
		if total == 18:
			double = up >= 3 and up <= 6
			if up <= 8:
				fallback = &"stand"
		elif total == 17:
			double = up >= 3 and up <= 6
		elif total >= 15:
			double = up >= 4 and up <= 6
		else:
			double = up >= 5 and up <= 6
	else:
		if total >= 17 or (total >= 13 and up <= 6) or (total == 12 and up >= 4 and up <= 6):
			return &"stand"
		double = (
			(total == 9 and up >= 3 and up <= 6)
			or (total == 10 and up <= 9)
			or (total == 11 and up <= 10)
		)
	if double and can_double(balance):
		return &"double"
	return fallback


func play_basic_strategy(risked: int, stream: RandomNumberGenerator) -> RoundResult:
	var result: RoundResult = begin(risked, stream)
	while result == null:
		match basic_strategy(risked * 2):
			&"double":
				result = double_down(risked * 2)
			&"stand":
				result = stand()
			_:
				result = hit()
	return result
