class_name PokerNpc
extends RefCounted
## One computer opponent at the Hold'em table: a personality over shared odds.
##
## Every decision reads only the public table view plus the NPC's own hole
## cards, and draws randomness only from the stream it is given, so a hand
## replays identically from the same seed. Personalities differ in how many
## hands they play (vpip), how often they raise (pfr, aggression), how often they
## bluff, how much pot odds matter to them, how sticky their calls are, how often
## they simply blunder, and how quickly a bad beat puts them on tilt.

enum Reason { FOLD_WEAK, CHECK, CALL_ODDS, CALL_STICKY, VALUE, BLUFF, MISTAKE, FORCED }

var id: StringName = &""
var name_key: String = ""
## Share of starting hands played voluntarily (0..1).
var vpip: float = 0.25
## Share of starting hands raised before the flop (0..1, at most vpip).
var pfr: float = 0.15
## Chance to bet or raise when the hand is strong enough to do so.
var aggression: float = 0.5
## Chance to bet or raise with a weak hand.
var bluff: float = 0.05
## Chance to take a random legal action instead of the reasoned one.
var mistake: float = 0.05
## 0 ignores pot odds (a fixed threshold), 1 calls exactly by pot odds.
var odds_skill: float = 0.5
## Equity bonus when deciding to call: the calling station's stickiness.
var call_bias: float = 0.0
## Monte-Carlo samples per street: better players think harder.
var samples: int = 32
## Tilt gained from a big loss; tilt loosens and speeds up play, then decays.
var tilt_gain: float = 0.1
var tilt: float = 0.0
## Presentation-only record of the last decision (never read by the rules).
var last_reason: Reason = Reason.CHECK
var last_equity: float = 0.0

var _equity_street: int = -1
var _equity: float = 0.0


static func create(npc_id: StringName, key: String, traits: Dictionary) -> PokerNpc:
	var npc := PokerNpc.new()
	npc.id = npc_id
	npc.name_key = key
	npc.vpip = float(traits.get("vpip", npc.vpip))
	npc.pfr = float(traits.get("pfr", npc.pfr))
	npc.aggression = float(traits.get("aggression", npc.aggression))
	npc.bluff = float(traits.get("bluff", npc.bluff))
	npc.mistake = float(traits.get("mistake", npc.mistake))
	npc.odds_skill = float(traits.get("odds_skill", npc.odds_skill))
	npc.call_bias = float(traits.get("call_bias", npc.call_bias))
	npc.samples = int(traits.get("samples", npc.samples))
	npc.tilt_gain = float(traits.get("tilt_gain", npc.tilt_gain))
	return npc


## The five regulars of the penthouse table, in seat order 1..5.
static func roster() -> Array[PokerNpc]:
	var npcs: Array[PokerNpc] = [
		# Tight-aggressive, pot-odds exact, thinks hardest, rarely errs.
		create(
			&"shark",
			"POKER_NPC_SHARK",
			{
				"vpip": 0.22,
				"pfr": 0.16,
				"aggression": 0.78,
				"bluff": 0.09,
				"mistake": 0.02,
				"odds_skill": 1.0,
				"call_bias": 0.0,
				"samples": 48,
				"tilt_gain": 0.05,
			}
		),
		# Very tight, passive: plays premiums, rarely raises, folds to pressure.
		create(
			&"rock",
			"POKER_NPC_ROCK",
			{
				"vpip": 0.12,
				"pfr": 0.05,
				"aggression": 0.25,
				"bluff": 0.01,
				"mistake": 0.03,
				"odds_skill": 0.6,
				"call_bias": -0.06,
				"samples": 32,
				"tilt_gain": 0.04,
			}
		),
		# Loose-aggressive: plays half the deck, raises and bluffs constantly.
		create(
			&"maniac",
			"POKER_NPC_MANIAC",
			{
				"vpip": 0.55,
				"pfr": 0.34,
				"aggression": 0.88,
				"bluff": 0.34,
				"mistake": 0.07,
				"odds_skill": 0.3,
				"call_bias": 0.05,
				"samples": 24,
				"tilt_gain": 0.3,
			}
		),
		# Calls nearly everything and almost never raises: the table's idiot.
		create(
			&"calling_station",
			"POKER_NPC_CALLING_STATION",
			{
				"vpip": 0.62,
				"pfr": 0.03,
				"aggression": 0.12,
				"bluff": 0.02,
				"mistake": 0.08,
				"odds_skill": 0.1,
				"call_bias": 0.2,
				"samples": 24,
				"tilt_gain": 0.15,
			}
		),
		# A novice on holiday: random mistakes, folds monsters, calls with air.
		create(
			&"tourist",
			"POKER_NPC_TOURIST",
			{
				"vpip": 0.42,
				"pfr": 0.08,
				"aggression": 0.3,
				"bluff": 0.1,
				"mistake": 0.17,
				"odds_skill": 0.0,
				"call_bias": 0.05,
				"samples": 16,
				"tilt_gain": 0.25,
			}
		),
	]
	return npcs


func reset_hand() -> void:
	_equity_street = -1
	_equity = 0.0


## Tilt rises after losing a big pot and decays after every other hand.
func observe_hand(net_chips: int, stake: int) -> void:
	if net_chips <= -6 * maxi(stake, 1):
		tilt = minf(1.0, tilt + tilt_gain)
	else:
		tilt *= 0.8


## Chooses an action for `view` (see PokerMath.npc_view). Returns PokerMath.Action.
func decide(view: Dictionary, rng: RandomNumberGenerator) -> int:
	var to_call: int = view.to_call
	var can_check := to_call == 0
	var can_raise: bool = view.can_raise
	if rng.randf() < mistake:
		last_reason = Reason.MISTAKE
		return _random_action(can_check, can_raise, rng)
	if int(view.street) == 0:
		return _decide_preflop(view, rng)
	return _decide_postflop(view, rng)


func _decide_preflop(view: Dictionary, rng: RandomNumberGenerator) -> int:
	var hole: Array[int] = view.hole
	var percentile := PokerOdds.preflop_percentile(hole[0], hole[1])
	last_equity = 1.0 - percentile
	var to_call: int = view.to_call
	var can_raise: bool = view.can_raise
	var bets: int = view.bets
	# Late position and tilt both widen the range a little.
	var loosen := float(view.position) * 0.06 + tilt * 0.22
	var play_range := clampf(vpip + loosen, 0.0, 1.0)
	var raise_range := clampf(pfr + loosen * 0.5, 0.0, play_range)
	if percentile > play_range:
		if to_call == 0:
			last_reason = Reason.CHECK
			return PokerMath.Action.CHECK
		# A cheap completion from the small blind is sometimes taken anyway.
		if to_call * 2 <= int(view.stake) and rng.randf() < vpip:
			last_reason = Reason.CALL_STICKY
			return PokerMath.Action.CALL
		last_reason = Reason.FOLD_WEAK
		return PokerMath.Action.FOLD
	# Each extra raise already in the pot tightens the re-raising range.
	var reraise_range := raise_range / float(maxi(1, bets))
	if can_raise and percentile <= reraise_range and rng.randf() < 0.5 + aggression * 0.5:
		last_reason = Reason.VALUE
		return PokerMath.Action.RAISE if to_call > 0 or bets > 0 else PokerMath.Action.BET
	if can_raise and rng.randf() < bluff * 0.35 and bets <= 1:
		last_reason = Reason.BLUFF
		return PokerMath.Action.RAISE
	if to_call == 0:
		last_reason = Reason.CHECK
		return PokerMath.Action.CHECK
	# Facing three bets or more, only the stronger half of the range continues.
	if bets >= 3 and percentile > play_range * (0.5 + call_bias):
		last_reason = Reason.FOLD_WEAK
		return PokerMath.Action.FOLD
	last_reason = Reason.CALL_ODDS
	return PokerMath.Action.CALL


func _decide_postflop(view: Dictionary, rng: RandomNumberGenerator) -> int:
	var street: int = view.street
	if _equity_street != street:
		_equity_street = street
		_equity = PokerOdds.equity(
			view.hole, view.board, mini(int(view.opponents), 4), samples, rng
		)
	var equity := _equity
	last_equity = equity
	var opponents := maxi(1, int(view.opponents))
	# Noise stands in for misreads; tilt makes every hand look better.
	var noise := (rng.randf() - 0.5) * (0.08 + mistake * 0.5)
	var felt := clampf(equity + noise + tilt * 0.08, 0.0, 1.0)
	# 1.0 means "an average share against this many opponents".
	var strength := felt * float(opponents + 1)
	var to_call: int = view.to_call
	var pot: int = view.pot
	var can_raise: bool = view.can_raise
	if to_call == 0:
		if strength >= 1.35 and rng.randf() < aggression:
			last_reason = Reason.VALUE
			return PokerMath.Action.BET if can_raise else PokerMath.Action.CHECK
		if equity < 0.3 and can_raise and rng.randf() < bluff:
			last_reason = Reason.BLUFF
			return PokerMath.Action.BET
		last_reason = Reason.CHECK
		return PokerMath.Action.CHECK
	if can_raise and strength >= 1.7 and felt >= 0.5 and rng.randf() < aggression:
		last_reason = Reason.VALUE
		return PokerMath.Action.RAISE
	var pot_odds := float(to_call) / float(pot + to_call)
	var needed := lerpf(0.34, pot_odds, odds_skill) - call_bias
	if felt >= needed:
		last_reason = Reason.CALL_STICKY if call_bias > 0.1 else Reason.CALL_ODDS
		return PokerMath.Action.CALL
	if can_raise and rng.randf() < bluff * 0.4:
		last_reason = Reason.BLUFF
		return PokerMath.Action.RAISE
	last_reason = Reason.FOLD_WEAK
	return PokerMath.Action.FOLD


func _random_action(can_check: bool, can_raise: bool, rng: RandomNumberGenerator) -> int:
	var options: Array[int] = []
	if can_check:
		options.append(PokerMath.Action.CHECK)
		if can_raise:
			options.append(PokerMath.Action.BET)
	else:
		options.append(PokerMath.Action.FOLD)
		options.append(PokerMath.Action.CALL)
		if can_raise:
			options.append(PokerMath.Action.RAISE)
	return options[rng.randi_range(0, options.size() - 1)]
