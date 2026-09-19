class_name BaccaratOdds
extends RefCounted
## Exact Punto Banco odds for a full shoe, by enumeration.
##
## Cards are grouped into ten value classes (0 holds tens and courts). Every
## ordered deal of up to six cards is walked through the real tableau, and each
## leaf is weighted by the number of ordered six-card sequences that realise it,
## so the counts are exact integers over decks*52 P 6 sequences. Pair odds are
## combinatorial: the first two cards of a hand share one of 13 ranks.

static var _cache: Dictionary = {}


## {"player", "banker", "tie", "total"} as exact ordered-sequence counts.
static func outcome_counts(decks: int = 8) -> Dictionary:
	if _cache.has(decks):
		return _cache[decks]
	var shoe := decks * BaccaratRules.CARDS_PER_DECK
	var classes: Array[int] = [16 * decks]
	for value: int in range(1, 10):
		classes.append(4 * decks)
	# tails[k]: ways to fill the undrawn positions after k cards, up to six.
	var tails: Array[int] = []
	for used: int in range(7):
		var ways: int = 1
		for position: int in range(used, 6):
			ways *= shoe - position
		tails.append(ways)
	var counts: Array[int] = [0, 0, 0]
	for a: int in range(10):
		var wa := classes[a]
		classes[a] -= 1
		for b: int in range(10):
			var wb := classes[b]
			classes[b] -= 1
			for c: int in range(10):
				var wc := classes[c]
				classes[c] -= 1
				for d: int in range(10):
					var wd := classes[d]
					if wd <= 0:
						continue
					classes[d] -= 1
					_resolve(classes, wa * wb * wc * wd, (a + c) % 10, (b + d) % 10, counts, tails)
					classes[d] += 1
				classes[c] += 1
			classes[b] += 1
		classes[a] += 1
	var result := {
		"player": counts[BaccaratRules.Winner.PLAYER],
		"banker": counts[BaccaratRules.Winner.BANKER],
		"tie": counts[BaccaratRules.Winner.TIE],
		"total": tails[0],
	}
	_cache[decks] = result
	return result


static func _resolve(
	classes: Array[int],
	weight: int,
	player: int,
	banker: int,
	counts: Array[int],
	tails: Array[int]
) -> void:
	if BaccaratRules.is_natural(player) or BaccaratRules.is_natural(banker):
		counts[BaccaratRules.winner_of(player, banker)] += weight * tails[4]
		return
	if not BaccaratRules.player_draws(player):
		if BaccaratRules.banker_draws(banker, -1):
			for f: int in range(10):
				var wf := classes[f]
				if wf > 0:
					counts[BaccaratRules.winner_of(player, (banker + f) % 10)] += (
						weight * wf * tails[5]
					)
		else:
			counts[BaccaratRules.winner_of(player, banker)] += weight * tails[4]
		return
	for e: int in range(10):
		var we := classes[e]
		if we <= 0:
			continue
		classes[e] -= 1
		var player_final := (player + e) % 10
		if BaccaratRules.banker_draws(banker, e):
			for f: int in range(10):
				var wf := classes[f]
				if wf > 0:
					counts[BaccaratRules.winner_of(player_final, (banker + f) % 10)] += (
						weight * we * wf * tails[6]
					)
		else:
			counts[BaccaratRules.winner_of(player_final, banker)] += weight * we * tails[5]
		classes[e] += 1


## Probability that the first two cards of one hand pair, as [numerator, denominator].
static func pair_fraction(decks: int = 8) -> Array[int]:
	var shoe := decks * BaccaratRules.CARDS_PER_DECK
	var per_rank := 4 * decks
	return [BaccaratRules.RANKS * per_rank * (per_rank - 1), shoe * (shoe - 1)]


## Exact expected return of `amount` chips on a spot, as [numerator, denominator]
## (reduced by the common factor so large stakes cannot overflow 64 bits).
static func return_fraction(math: BaccaratMath, id: String, amount: int) -> Array[int]:
	var decks := math.paytable.decks
	if id == BaccaratMath.PLAYER_PAIR or id == BaccaratMath.BANKER_PAIR:
		var pair := pair_fraction(decks)
		var hit := {"winner": BaccaratRules.Winner.TIE, "player_pair": true, "banker_pair": true}
		return [pair[0] * math.returned_for(id, amount, hit), pair[1] * amount]
	var counts := outcome_counts(decks)
	var common := _gcd(_gcd(counts.player, counts.banker), _gcd(counts.tie, counts.total))
	var numerator: int = 0
	var keys: Array[String] = ["player", "banker", "tie"]
	for winner: int in [
		BaccaratRules.Winner.PLAYER, BaccaratRules.Winner.BANKER, BaccaratRules.Winner.TIE
	]:
		@warning_ignore("integer_division")
		var ways: int = int(counts[keys[winner]]) / common
		var coup := {"winner": winner, "player_pair": false, "banker_pair": false}
		numerator += ways * math.returned_for(id, amount, coup)
	@warning_ignore("integer_division")
	var sequences: int = int(counts.total) / common
	return [numerator, sequences * amount]


static func expected_return(math: BaccaratMath, id: String, amount: int) -> float:
	var fraction := return_fraction(math, id, amount)
	return float(fraction[0]) / float(fraction[1])


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a
