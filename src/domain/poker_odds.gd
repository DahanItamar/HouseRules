class_name PokerOdds
extends RefCounted
## Hand-strength estimates shared by the NPCs and the baseline harness player.
##
## Preflop uses the Chen formula mapped to an exact percentile over all 1,326
## starting combinations. Postflop uses a short Monte-Carlo run against random
## opponent hands, drawing only from the caller's explicit RNG stream.

static var _percentile_by_score: Dictionary = {}


## Bill Chen's starting-hand score (about -1 for 72o up to 20 for AA).
static func chen_score(first: int, second: int) -> int:
	var high := maxi(first >> 2, second >> 2)
	var low := mini(first >> 2, second >> 2)
	var points := _chen_card_points(high)
	if high == low:
		return int(ceil(maxf(points * 2.0, 5.0)))
	if first & 3 == second & 3:
		points += 2.0
	var gap := high - low - 1
	match gap:
		0:
			pass
		1:
			points -= 1.0
		2:
			points -= 2.0
		3:
			points -= 4.0
		_:
			points -= 5.0
	# Connected or one-gap cards below a queen straighten more often.
	if gap <= 1 and high < 10:
		points += 1.0
	return int(ceil(points))


## Share of starting hands at least as strong as this one (0 = best, 1 = worst).
static func preflop_percentile(first: int, second: int) -> float:
	if _percentile_by_score.is_empty():
		_build_percentiles()
	return float(_percentile_by_score.get(chen_score(first, second), 1.0))


## Probability of winning (ties shared) against `opponents` random hands.
static func equity(
	hole: Array[int], board: Array[int], opponents: int, samples: int, rng: RandomNumberGenerator
) -> float:
	var foes := clampi(opponents, 1, 5)
	var known: Dictionary = {}
	for card: int in hole:
		known[card] = true
	for card: int in board:
		known[card] = true
	var stub: Array[int] = []
	for card: int in range(52):
		if not known.has(card):
			stub.append(card)
	var missing := 5 - board.size()
	var needed := missing + foes * 2
	var total := 0.0
	var runout: Array[int] = []
	var hand: Array[int] = []
	for _sample: int in range(samples):
		# Partial Fisher-Yates: only the cards this sample needs are shuffled.
		for index: int in range(needed):
			var other := rng.randi_range(index, stub.size() - 1)
			var swap := stub[index]
			stub[index] = stub[other]
			stub[other] = swap
		runout.assign(board)
		for index: int in range(missing):
			runout.append(stub[index])
		hand.assign(runout)
		hand.append(hole[0])
		hand.append(hole[1])
		var hero_score := PokerHandEval.evaluate(hand)
		var best_foe := -1
		var ties := 0
		for foe: int in range(foes):
			hand.assign(runout)
			hand.append(stub[missing + foe * 2])
			hand.append(stub[missing + foe * 2 + 1])
			var score := PokerHandEval.evaluate(hand)
			best_foe = maxi(best_foe, score)
			if score == hero_score:
				ties += 1
		if hero_score > best_foe:
			total += 1.0
		elif hero_score == best_foe:
			total += 1.0 / float(ties + 1)
	return total / float(maxi(samples, 1))


static func _chen_card_points(rank_index: int) -> float:
	match rank_index:
		12:
			return 10.0
		11:
			return 8.0
		10:
			return 7.0
		9:
			return 6.0
	return float(rank_index + 2) * 0.5


static func _build_percentiles() -> void:
	var tally: Dictionary = {}
	var total := 0
	for first: int in range(52):
		for second: int in range(first + 1, 52):
			var score := chen_score(first, second)
			tally[score] = int(tally.get(score, 0)) + 1
			total += 1
	var scores: Array = tally.keys()
	scores.sort()
	scores.reverse()
	var stronger := 0
	for score: int in scores:
		var count: int = tally[score]
		# Mid-rank percentile: half of the equal-score hands count as stronger.
		_percentile_by_score[score] = (float(stronger) + float(count) * 0.5) / float(total)
		stronger += count
