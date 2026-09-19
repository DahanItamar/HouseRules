class_name RouletteMath
extends RefCounted
## European single-zero roulette. Chips are placed on named layout spots before
## the spin; one uniform pocket draw from the cabinet stream settles every bet.
##
## A spot is {"id": String, "kind": BetKind, "numbers": Array[int]}. A spot that
## covers k numbers pays (36 / k) - 1 to one, so every legal bet returns exactly
## 36/37 of its stake over the 37 pockets.

enum BetKind {
	STRAIGHT,
	SPLIT,
	STREET,
	CORNER,
	SIX_LINE,
	DOZEN,
	COLUMN,
	RED,
	BLACK,
	ODD,
	EVEN,
	LOW,
	HIGH,
}

const DEFAULT_PAYTABLE: RoulettePaytable = preload("res://data/paytables/roulette.tres")
const KIND_PREFIXES: Array[String] = [
	"straight",
	"split",
	"street",
	"corner",
	"six",
	"dozen",
	"column",
	"red",
	"black",
	"odd",
	"even",
	"low",
	"high",
]

var paytable: RoulettePaytable = DEFAULT_PAYTABLE
## Spot id -> chips on that spot for the round being built.
var bets: Dictionary = {}
## The previous spin's bets, restored by rebet().
var last_bets: Dictionary = {}
var stake: int = 0
var pocket: int = -1
var _spots: Dictionary = {}


func _init(rules: RoulettePaytable = null) -> void:
	if rules != null:
		paytable = rules
	_spots = build_spots(paytable)


static func spot_id(kind: BetKind, numbers: Array[int] = []) -> String:
	if kind >= BetKind.RED:
		return KIND_PREFIXES[kind]
	var sorted := numbers.duplicate()
	sorted.sort()
	var parts: PackedStringArray = []
	for number: int in sorted:
		parts.append(str(number))
	return "%s:%s" % [KIND_PREFIXES[kind], ",".join(parts)]


## Every legal spot on a single-zero layout (157 spots), keyed by id.
static func build_spots(rules: RoulettePaytable) -> Dictionary:
	var spots: Dictionary = {}
	for number: int in range(0, 37):
		_add_spot(spots, BetKind.STRAIGHT, [number])
	for number: int in range(1, 34):
		_add_spot(spots, BetKind.SPLIT, [number, number + 3])
	for number: int in range(1, 36):
		if number % 3 != 0:
			_add_spot(spots, BetKind.SPLIT, [number, number + 1])
	for number: int in [1, 2, 3]:
		_add_spot(spots, BetKind.SPLIT, [0, number])
	for column: int in range(12):
		_add_spot(spots, BetKind.STREET, [column * 3 + 1, column * 3 + 2, column * 3 + 3])
	_add_spot(spots, BetKind.STREET, [0, 1, 2])
	_add_spot(spots, BetKind.STREET, [0, 2, 3])
	for number: int in range(1, 33):
		if number % 3 != 0:
			_add_spot(spots, BetKind.CORNER, [number, number + 1, number + 3, number + 4])
	_add_spot(spots, BetKind.CORNER, [0, 1, 2, 3])
	for column: int in range(11):
		var six: Array[int] = []
		for offset: int in range(1, 7):
			six.append(column * 3 + offset)
		_add_spot(spots, BetKind.SIX_LINE, six)
	for group: int in range(3):
		_add_numbers_spot(
			spots,
			BetKind.DOZEN,
			group,
			func(n: int) -> bool: return floori((n - 1) / 12.0) == group
		)
		_add_numbers_spot(
			spots, BetKind.COLUMN, group, func(n: int) -> bool: return (n - 1) % 3 == group
		)
	_add_numbers_spot(spots, BetKind.RED, -1, func(n: int) -> bool: return rules.red_numbers.has(n))
	_add_numbers_spot(
		spots, BetKind.BLACK, -1, func(n: int) -> bool: return not rules.red_numbers.has(n)
	)
	_add_numbers_spot(spots, BetKind.ODD, -1, func(n: int) -> bool: return n % 2 == 1)
	_add_numbers_spot(spots, BetKind.EVEN, -1, func(n: int) -> bool: return n % 2 == 0)
	_add_numbers_spot(spots, BetKind.LOW, -1, func(n: int) -> bool: return n <= 18)
	_add_numbers_spot(spots, BetKind.HIGH, -1, func(n: int) -> bool: return n >= 19)
	return spots


## Dozen and column ids carry their group (1-3); the other outside bets do not.
static func group_spot_id(kind: BetKind, group: int) -> String:
	return "%s:%d" % [KIND_PREFIXES[kind], group + 1]


static func _add_spot(spots: Dictionary, kind: BetKind, numbers: Array) -> void:
	var covered: Array[int] = []
	covered.assign(numbers)
	covered.sort()
	var id := spot_id(kind, covered)
	spots[id] = {"id": id, "kind": kind, "numbers": covered}


static func _add_numbers_spot(
	spots: Dictionary, kind: BetKind, group: int, covers: Callable
) -> void:
	var covered: Array[int] = []
	for number: int in range(1, 37):
		if covers.call(number):
			covered.append(number)
	var id := group_spot_id(kind, group) if group >= 0 else spot_id(kind)
	spots[id] = {"id": id, "kind": kind, "numbers": covered}


func spots() -> Dictionary:
	return _spots


func spot(id: String) -> Dictionary:
	return _spots.get(id, {})


func has_spot(id: String) -> bool:
	return _spots.has(id)


func pays_to_one(kind: BetKind) -> int:
	match kind:
		BetKind.STRAIGHT:
			return paytable.straight_pays
		BetKind.SPLIT:
			return paytable.split_pays
		BetKind.STREET:
			return paytable.street_pays
		BetKind.CORNER:
			return paytable.corner_pays
		BetKind.SIX_LINE:
			return paytable.six_line_pays
		BetKind.DOZEN:
			return paytable.dozen_pays
		BetKind.COLUMN:
			return paytable.column_pays
	return paytable.even_money_pays


## Chips returned for `amount` on a spot when the ball lands in `landed`,
## including the returned stake. Zero loses every outside bet.
func returned_for(id: String, amount: int, landed: int) -> int:
	var entry := spot(id)
	if entry.is_empty() or amount <= 0 or not (entry.numbers as Array).has(landed):
		return 0
	return amount * (pays_to_one(entry.kind) + 1)


func is_red(number: int) -> bool:
	return paytable.red_numbers.has(number)


func total_bet() -> int:
	var total: int = 0
	for amount: int in bets.values():
		total += amount
	return total


func chips_on(id: String) -> int:
	return int(bets.get(id, 0))


## `cap` is the table limit already reduced to what the player can cover.
func can_place(id: String, amount: int, cap: int) -> bool:
	return has_spot(id) and amount > 0 and total_bet() + amount <= cap


func place(id: String, amount: int, cap: int) -> bool:
	if not can_place(id, amount, cap):
		return false
	bets[id] = chips_on(id) + amount
	return true


## Takes up to `amount` chips back from a spot; returns how many came back.
func remove(id: String, amount: int) -> int:
	var present := chips_on(id)
	var taken := mini(present, maxi(amount, 0))
	if taken <= 0:
		return 0
	if taken == present:
		bets.erase(id)
	else:
		bets[id] = present - taken
	return taken


func clear() -> void:
	bets.clear()


func can_rebet(cap: int) -> bool:
	if last_bets.is_empty():
		return false
	var total: int = 0
	for amount: int in last_bets.values():
		total += amount
	return total <= cap


func rebet(cap: int) -> bool:
	if not can_rebet(cap):
		return false
	bets = last_bets.duplicate()
	return true


## One uniform draw settles every bet on the layout together.
func spin(rng: RandomNumberGenerator) -> RoundResult:
	assert(total_bet() > 0, "A spin needs at least one chip on the layout")
	stake = total_bet()
	pocket = rng.randi_range(0, paytable.pocket_count - 1)
	var payout: int = 0
	var winners: Dictionary = {}
	for id: String in bets:
		var back := returned_for(id, bets[id], pocket)
		if back > 0:
			winners[id] = back
			payout += back
	var placed := bets.duplicate()
	last_bets = placed.duplicate()
	bets.clear()
	var outcome := RoundResult.Outcome.LOSS
	if payout > stake:
		outcome = RoundResult.Outcome.WIN
	elif payout == stake:
		outcome = RoundResult.Outcome.PUSH
	return RoundResult.create(
		stake, payout, outcome, {"pocket": pocket, "bets": placed, "winners": winners}
	)


## Exact expected return of one chip on a spot, as a numerator over pocket_count.
func expected_return_numerator(id: String) -> int:
	var total: int = 0
	for landed: int in range(paytable.pocket_count):
		total += returned_for(id, 1, landed)
	return total
