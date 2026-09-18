class_name MinefieldMath
extends RefCounted

const DEFAULT_PAYTABLE: MinefieldPaytable = preload("res://data/paytables/minefield_vault.tres")

var paytable: MinefieldPaytable = DEFAULT_PAYTABLE
var mines: Array[int] = []
var revealed: Array[int] = []
var safe_reveals: int = 0
var stake: int = 0
var active: bool = false


func begin(risked: int, mine_count: int, rng: RandomNumberGenerator) -> void:
	assert(not active and risked > 0 and mine_count >= 1 and mine_count < paytable.tile_count)
	stake = risked
	safe_reveals = 0
	revealed.clear()
	mines.clear()
	var positions: Array[int] = []
	for index: int in range(paytable.tile_count):
		positions.append(index)
	# Partial Fisher-Yates: every mine subset has equal probability.
	for index: int in range(mine_count):
		var other: int = rng.randi_range(index, positions.size() - 1)
		var value: int = positions[index]
		positions[index] = positions[other]
		positions[other] = value
		mines.append(positions[index])
	active = true


static func combinations(n: int, k: int) -> int:
	if k < 0 or k > n:
		return 0
	var result: int = 1
	for i: int in range(1, mini(k, n - k) + 1):
		@warning_ignore("integer_division")
		var next: int = result * (n - i + 1) / i
		result = next
	return result


static func survival_probability(mine_count: int, k: int, rules: MinefieldPaytable = null) -> float:
	var config: MinefieldPaytable = rules if rules != null else DEFAULT_PAYTABLE
	return (
		float(combinations(config.tile_count - mine_count, k))
		/ float(combinations(config.tile_count, k))
	)


static func payout_for(
	risked: int, mine_count: int, k: int, rules: MinefieldPaytable = null
) -> int:
	var config: MinefieldPaytable = rules if rules != null else DEFAULT_PAYTABLE
	assert(k >= 1 and k <= config.tile_count - mine_count)
	# Exact integer rational evaluation: round down once, no float currency.
	@warning_ignore("integer_division")
	var payout: int = (
		risked
		* config.return_numerator
		* combinations(config.tile_count, k)
		/ (config.return_denominator * combinations(config.tile_count - mine_count, k))
	)
	return mini(payout, risked * config.max_win)


func multiplier() -> float:
	if safe_reveals == 0:
		return 0.0
	return minf(
		float(paytable.max_win),
		(
			float(paytable.return_numerator)
			/ float(paytable.return_denominator)
			/ survival_probability(mines.size(), safe_reveals, paytable)
		)
	)


func reveal(index: int) -> RoundResult:
	if not active or index < 0 or index >= paytable.tile_count or revealed.has(index):
		return null
	revealed.append(index)
	if mines.has(index):
		return _resolve(0, RoundResult.Outcome.LOSS)
	safe_reveals += 1
	if safe_reveals == paytable.tile_count - mines.size():
		return cash_out()
	return null


func cash_out() -> RoundResult:
	if not active or safe_reveals == 0:
		return null
	return _resolve(
		payout_for(stake, mines.size(), safe_reveals, paytable), RoundResult.Outcome.CASHED_OUT
	)


func abandon() -> RoundResult:
	if not active:
		return null
	return _resolve(0, RoundResult.Outcome.ABANDONED)


func _resolve(payout: int, outcome: RoundResult.Outcome) -> RoundResult:
	active = false
	return RoundResult.create(
		stake,
		payout,
		outcome,
		{"safe_reveals": safe_reveals, "mines": mines.duplicate(), "revealed": revealed.duplicate()}
	)
