class_name RouletteTableGuests
extends RefCounted
## Three seated guests who bet every spin for table life. Their chips are pure
## presentation: they draw from their own fixed-seed generator (never the
## cabinet stream), never enter RouletteMath.bets, and never touch the wallet.
## They are settled here only to choose each guest's reaction line.

enum Personality { SYSTEM, DREAMER, REGULAR }

## Fixed presentation seed, so captures and tests stay reproducible.
const TABLE_LIFE_SEED: int = 17071923
const BIRTHDAY_NUMBERS: Array[int] = [7, 14, 23]
const DREAM_NUMBER: int = 17
const SYSTEM_BASE_UNIT: int = 5
const SYSTEM_CEILING: int = 80
const PORTRAITS := {
	Personality.SYSTEM: preload("res://assets/production/roulette/guest_system.png"),
	Personality.DREAMER: preload("res://assets/production/roulette/guest_dreamer.png"),
	Personality.REGULAR: preload("res://assets/production/roulette/guest_regular.png"),
}


class Guest:
	var personality: Personality
	var name_key: String
	var tag_key: String
	var chip_color: Color
	var portrait: Texture2D
	var bets: Dictionary = {}
	var line_key: String = ""
	var line_value: int = 0
	var last_net: int = 0
	var unit: int = SYSTEM_BASE_UNIT
	var backs_red: bool = true

	func _init(kind: Personality, key: String, tint: Color) -> void:
		personality = kind
		name_key = "ROULETTE_GUEST_%s" % key
		tag_key = "ROULETTE_TAG_%s" % key
		chip_color = tint
		portrait = PORTRAITS[kind]

	func staked() -> int:
		var total: int = 0
		for amount: int in bets.values():
			total += amount
		return total


var guests: Array[Guest] = []
var math: RouletteMath
var _rng := RandomNumberGenerator.new()


func _init(table_math: RouletteMath) -> void:
	math = table_math
	_rng.seed = TABLE_LIFE_SEED
	guests.append(Guest.new(Personality.SYSTEM, "SYSTEM", Color("3f8a8f")))
	guests.append(Guest.new(Personality.DREAMER, "DREAMER", Color("d08a2e")))
	guests.append(Guest.new(Personality.REGULAR, "REGULAR", Color("9a5bb0")))


## Every guest puts chips down for the coming spin.
func place_bets() -> void:
	for guest: Guest in guests:
		guest.bets.clear()
		guest.last_net = 0
		match guest.personality:
			Personality.SYSTEM:
				_place_system(guest)
			Personality.DREAMER:
				_place_dreamer(guest)
			Personality.REGULAR:
				_place_regular(guest)


func _place_system(guest: Guest) -> void:
	var kind := RouletteMath.BetKind.RED if guest.backs_red else RouletteMath.BetKind.BLACK
	guest.bets[RouletteMath.spot_id(kind)] = guest.unit
	guest.line_value = guest.unit
	guest.line_key = (
		"ROULETTE_LINE_SYSTEM_BASE"
		if guest.unit == SYSTEM_BASE_UNIT
		else "ROULETTE_LINE_SYSTEM_DOUBLE"
	)


func _place_dreamer(guest: Guest) -> void:
	guest.bets[RouletteMath.spot_id(RouletteMath.BetKind.STRAIGHT, [DREAM_NUMBER])] = 10
	if _rng.randf() < 0.5:
		var long_shot := DREAM_NUMBER
		while long_shot == DREAM_NUMBER:
			long_shot = _rng.randi_range(1, 36)
		guest.bets[RouletteMath.spot_id(RouletteMath.BetKind.STRAIGHT, [long_shot])] = 5
	guest.line_value = DREAM_NUMBER
	guest.line_key = (
		"ROULETTE_LINE_DREAMER_BET" if _rng.randf() < 0.6 else "ROULETTE_LINE_DREAMER_BET_ALT"
	)


func _place_regular(guest: Guest) -> void:
	for number: int in BIRTHDAY_NUMBERS:
		guest.bets[RouletteMath.spot_id(RouletteMath.BetKind.STRAIGHT, [number])] = 5
	guest.line_value = 0
	guest.line_key = "ROULETTE_LINE_REGULAR_BET"


## Settles the guests' own chips against the pocket to pick reaction lines.
func settle(pocket: int) -> void:
	for guest: Guest in guests:
		var returned: int = 0
		for id: String in guest.bets:
			returned += math.returned_for(id, guest.bets[id], pocket)
		guest.last_net = returned - guest.staked()
		guest.line_value = maxi(guest.last_net, 0)
		guest.line_key = _reaction_key(guest, pocket, returned > 0)
		if guest.personality == Personality.SYSTEM:
			_advance_martingale(guest, returned > 0)


func _reaction_key(guest: Guest, pocket: int, won: bool) -> String:
	match guest.personality:
		Personality.SYSTEM:
			if won:
				return "ROULETTE_LINE_SYSTEM_WIN"
			return "ROULETTE_LINE_SYSTEM_ZERO" if pocket == 0 else "ROULETTE_LINE_SYSTEM_LOSS"
		Personality.DREAMER:
			if won:
				return (
					"ROULETTE_LINE_DREAMER_WIN"
					if pocket == DREAM_NUMBER
					else "ROULETTE_LINE_DREAMER_LONGSHOT"
				)
			return "ROULETTE_LINE_DREAMER_LOSS"
	if won:
		return "ROULETTE_LINE_REGULAR_WIN"
	return "ROULETTE_LINE_REGULAR_ZERO" if pocket == 0 else "ROULETTE_LINE_REGULAR_LOSS"


## Martingale: double after a loss, back to one unit after a win or at the
## guest's own ceiling (where he also switches colour, "to reset the system").
func _advance_martingale(guest: Guest, won: bool) -> void:
	if won:
		guest.unit = SYSTEM_BASE_UNIT
		return
	guest.unit *= 2
	if guest.unit > SYSTEM_CEILING:
		guest.unit = SYSTEM_BASE_UNIT
		guest.backs_red = not guest.backs_red


func clear_bets() -> void:
	for guest: Guest in guests:
		guest.bets.clear()


## Chip layers for RouletteBoard: [{"color": Color, "bets": Dictionary}].
func board_entries() -> Array:
	var entries: Array = []
	for guest: Guest in guests:
		entries.append({"color": guest.chip_color, "bets": guest.bets})
	return entries
