class_name MatchPointMath
extends RefCounted
## Match Point: a tennis-ball Plinko board with 12 rows of posts and 13 courts.
##
## The outcome is decided from the distribution, never from physics. One uniform
## draw in [0, 2^rows) from the cabinet stream picks one of the 4096 equally
## likely left/right paths. Draws are ordered court by court, so court k owns a
## block of exactly C(rows, k) draws (the binomial distribution), and the offset
## inside that block is unranked into the k-rights path the ball animates. The
## path is therefore a pure function of the draw and always ends in the court
## that was paid.

enum Risk { LOW, MEDIUM, HIGH }

const DEFAULT_PAYTABLE: MatchPointPaytable = preload("res://data/paytables/match_point.tres")
const RISK_KEYS: Array[String] = ["LOW", "MEDIUM", "HIGH"]

var paytable: MatchPointPaytable = DEFAULT_PAYTABLE
## The court and path of the most recent drop (presentation reads these).
var slot: int = -1
var path: Array[int] = []
var draw: int = -1


func _init(rules: MatchPointPaytable = null) -> void:
	if rules != null:
		paytable = rules


static func choose(n: int, k: int) -> int:
	if k < 0 or k > n:
		return 0
	var result: int = 1
	for index: int in range(mini(k, n - k)):
		result = result * (n - index) / (index + 1)
	return result


func rows() -> int:
	return paytable.rows


func slot_count() -> int:
	return paytable.rows + 1


func total_paths() -> int:
	return 1 << paytable.rows


## Number of the 2^rows equally likely paths that end in `court`.
func ways(court: int) -> int:
	return choose(paytable.rows, court)


func tenths_for(risk: Risk) -> PackedInt32Array:
	match risk:
		Risk.LOW:
			return paytable.low_tenths
		Risk.HIGH:
			return paytable.high_tenths
	return paytable.medium_tenths


func multiplier_tenths(risk: Risk, court: int) -> int:
	var table := tenths_for(risk)
	if court < 0 or court >= table.size():
		return 0
	return table[court]


func max_tenths(risk: Risk) -> int:
	var best: int = 0
	for value: int in tenths_for(risk):
		best = maxi(best, value)
	return best


## "33", "1.6", "0.2": a multiplier in tenths without a trailing ".0".
static func multiplier_text(tenths: int) -> String:
	if tenths % 10 == 0:
		return str(tenths / 10)
	return "%d.%d" % [tenths / 10, tenths % 10]


## Chips returned for `stake` landing in `court`, including the stake itself.
func payout_for(stake: int, risk: Risk, court: int) -> int:
	return stake * multiplier_tenths(risk, court) / 10


func is_legal_stake(stake: int) -> bool:
	return stake > 0 and stake % paytable.stake_unit == 0


## Court owning `value` in [0, 2^rows): blocks of C(rows, k) draws, k ascending.
func slot_for_draw(value: int) -> int:
	var remaining := value
	for court: int in range(slot_count()):
		var block := ways(court)
		if remaining < block:
			return court
		remaining -= block
	return slot_count() - 1


## First draw of a court's block.
func block_start(court: int) -> int:
	var start: int = 0
	for index: int in range(court):
		start += ways(index)
	return start


## The left(0)/right(1) hop at every row for `value`. The number of rights is
## exactly the court; different draws always give different paths.
func path_for_draw(value: int) -> Array[int]:
	var court := slot_for_draw(value)
	var rank := value - block_start(court)
	var hops: Array[int] = []
	var rights_left := court
	for row: int in range(paytable.rows):
		var rows_after := paytable.rows - row - 1
		# Paths that go left here and still fit the remaining rights.
		var left_paths := choose(rows_after, rights_left)
		if rank < left_paths:
			hops.append(0)
		else:
			rank -= left_paths
			hops.append(1)
			rights_left -= 1
	return hops


## One uniform draw from the cabinet stream decides the court and the path.
func drop(stake: int, risk: Risk, rng: RandomNumberGenerator) -> RoundResult:
	assert(is_legal_stake(stake), "Match Point stakes are multiples of the stake unit")
	draw = rng.randi_range(0, total_paths() - 1)
	slot = slot_for_draw(draw)
	path = path_for_draw(draw)
	var tenths := multiplier_tenths(risk, slot)
	var payout := stake * tenths / 10
	var outcome := RoundResult.Outcome.LOSS
	if payout > stake:
		outcome = RoundResult.Outcome.WIN
	elif payout == stake:
		outcome = RoundResult.Outcome.PUSH
	return (
		RoundResult
		. create(
			stake,
			payout,
			outcome,
			{
				"risk": risk,
				"slot": slot,
				"draw": draw,
				"path": path.duplicate(),
				"multiplier_tenths": tenths,
			}
		)
	)


## Exact return numerator: sum over courts of C(rows, k) * tenths[k].
func return_numerator(risk: Risk) -> int:
	var total: int = 0
	for court: int in range(slot_count()):
		total += ways(court) * multiplier_tenths(risk, court)
	return total


## Exact RTP as a fraction of the stake (numerator over 10 * 2^rows).
func exact_rtp(risk: Risk) -> float:
	return float(return_numerator(risk)) / float(10 * total_paths())
