class_name SlotMachineMath
extends RefCounted

enum Symbol { CHERRY, LEMON, BELL, BAR, SEVEN, DIAMOND }

var paytable: SlotPaytable = preload("res://data/paytables/slot_classic.tres")


func spin(stake: int, rng: RandomNumberGenerator) -> RoundResult:
	assert(stake > 0)
	var symbols: Array[int] = []
	var total: int = 0
	for weight: int in paytable.weights:
		total += weight
	for reel: int in range(3):
		var stop: int = rng.randi_range(0, total - 1)
		for symbol: int in range(paytable.weights.size()):
			stop -= paytable.weights[symbol]
			if stop < 0:
				symbols.append(symbol)
				break
	return evaluate(symbols, stake)


func evaluate(symbols: Array[int], stake: int) -> RoundResult:
	assert(symbols.size() == 3 and stake > 0)
	var multiplier: int = 0
	if symbols[0] == symbols[1] and symbols[1] == symbols[2]:
		multiplier = paytable.multipliers[symbols[0]]
	elif symbols.count(Symbol.CHERRY) == 2:
		multiplier = paytable.two_cherry_multiplier
	multiplier = mini(multiplier, paytable.max_win)
	var outcome: RoundResult.Outcome = RoundResult.Outcome.LOSS
	if multiplier == 1:
		outcome = RoundResult.Outcome.PUSH
	elif multiplier > 1:
		outcome = RoundResult.Outcome.WIN
	return RoundResult.create(stake, stake * multiplier, outcome, {"symbols": symbols})
