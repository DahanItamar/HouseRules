class_name HouseLevel
extends RefCounted
## The House standing ladder: pure maths, no nodes, no wallet, no RNG.
##
## Standing is earned from chips **wagered**, never from chips won, so it can
## never be farmed by a lucky run and it can never feed back into a payout.
## The currency is `Economy.lifetime_wagered`, the same number the two wing
## transition points already gate on, so the shipped thresholds are preserved
## exactly: High Roller at 5,000 and VIP at 100,000 are tiers 3 and 4 here.
##
## The ladder ends at Owner: the Manager sells the House to a player who has
## turned over `TIERS[5].target` chips and can put `DEED_PRICE` on the desk.
## Both numbers are stated in `docs/PROGRESSION.md`.

## One rung each: `target` is lifetime chips wagered, `marker` the stipend the
## Manager will write at that standing, `unlock` the concrete thing it opens.
const TIERS: Array[Dictionary] = [
	{
		"name_key": "TIER_GUEST",
		"initial_key": "TIER_GUEST_INITIAL",
		"target": 0,
		"marker": 100,
		"unlock_key": "TIER_UNLOCK_GUEST",
	},
	{
		"name_key": "TIER_REGULAR",
		"initial_key": "TIER_REGULAR_INITIAL",
		"target": 1_500,
		"marker": 100,
		"unlock_key": "TIER_UNLOCK_REGULAR",
	},
	{
		"name_key": "TIER_HIGH_ROLLER",
		"initial_key": "TIER_HIGH_ROLLER_INITIAL",
		"target": 5_000,
		"marker": 100,
		"unlock_key": "TIER_UNLOCK_HIGH_ROLLER",
	},
	{
		"name_key": "TIER_WHALE",
		"initial_key": "TIER_WHALE_INITIAL",
		"target": 100_000,
		"marker": 250,
		"unlock_key": "TIER_UNLOCK_WHALE",
	},
	{
		"name_key": "TIER_PARTNER",
		"initial_key": "TIER_PARTNER_INITIAL",
		"target": 250_000,
		"marker": 500,
		"unlock_key": "TIER_UNLOCK_PARTNER",
	},
	{
		"name_key": "TIER_OWNER",
		"initial_key": "TIER_OWNER_INITIAL",
		"target": 1_000_000,
		"marker": 1_000,
		"unlock_key": "TIER_UNLOCK_OWNER",
	},
]
## Chips the Manager wants for the deed once the player stands at Owner.
const DEED_PRICE: int = 250_000
## The last rung's target: the bar toward owning the House fills against it.
const OWNERSHIP_TARGET: int = 1_000_000


## The rung index (0-based) a lifetime-wagered total stands on.
static func tier_index(wagered: int) -> int:
	var index: int = 0
	for step: int in range(TIERS.size()):
		if wagered >= int(TIERS[step].target):
			index = step
	return index


## The display level, 1-based, so the HUD never shows "level 0".
static func level(wagered: int) -> int:
	return tier_index(wagered) + 1


static func tier(wagered: int) -> Dictionary:
	return TIERS[tier_index(wagered)]


static func is_max_tier(wagered: int) -> bool:
	return tier_index(wagered) >= TIERS.size() - 1


## Chips the Manager writes on a marker at this standing. Guest through High
## Roller keep the shipped 100-chip stipend, so nothing about the existing
## marker rules changes until a player has turned over 100,000 chips.
static func marker_stipend(wagered: int) -> int:
	return int(tier(wagered).marker)


## Lifetime wagered at which the next rung starts, or this rung's own target
## once the ladder is finished.
static func next_target(wagered: int) -> int:
	var index := tier_index(wagered)
	if index >= TIERS.size() - 1:
		return int(TIERS[index].target)
	return int(TIERS[index + 1].target)


## Fill for the "next milestone" bar, always inside 0..1. A finished ladder
## reads full rather than empty.
static func tier_ratio(wagered: int) -> float:
	if is_max_tier(wagered):
		return 1.0
	var index := tier_index(wagered)
	var floor_target := float(TIERS[index].target)
	var span := float(TIERS[index + 1].target) - floor_target
	if span <= 0.0:
		return 1.0
	return clampf((float(wagered) - floor_target) / span, 0.0, 1.0)


## Fill for the secondary "buy the House" bar, measured from zero so it reads
## as one long arc rather than a rung.
static func ownership_ratio(wagered: int) -> float:
	return clampf(float(wagered) / float(OWNERSHIP_TARGET), 0.0, 1.0)


static func can_buy_house(wagered: int, chips: int, already_owned: bool) -> bool:
	return not already_owned and is_max_tier(wagered) and chips >= DEED_PRICE


## Chips in short form for a slim bar: 1_200_000 -> "1.2M", 5_000 -> "5K".
## Values under a thousand stay exact, because a small bank is read precisely.
static func short_chips(amount: int) -> String:
	var size := absi(amount)
	var sign_text := "-" if amount < 0 else ""
	if size >= 1_000_000:
		return "%s%sM" % [sign_text, _trim(float(size) / 1_000_000.0)]
	if size >= 1_000:
		return "%s%sK" % [sign_text, _trim(float(size) / 1_000.0)]
	return str(amount)


## One decimal place, and none at all when it would only add a zero.
static func _trim(value: float) -> String:
	var text := "%.1f" % value
	return text.trim_suffix(".0")


## Chips in full, grouped in threes: 250000 -> "250,000". Used wherever the
## exact figure is the point - a receipt, or a row of the ledger.
static func grouped(amount: int) -> String:
	var digits := str(absi(amount))
	var text := ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			text += ","
		text += digits[index]
	return ("-" + text) if amount < 0 else text
