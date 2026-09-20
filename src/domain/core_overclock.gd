class_name CoreOverclockMath
extends RefCounted
## Core Overclock: a crash game, presented as Forno d'Oro, a pizza bake. A run
## climbs an exponential multiplier curve until it crashes; the player banks the
## multiplier before it does, or loses the stake. This file is the theme-free
## math: the presentation names the states.
##
## The outcome is decided before anything animates. One uniform integer `value`
## in [1, N] is taken from the cabinet stream at launch and the crash point is
##
##     crash_centi = floor(100 * p * N / value)     with p = 0.97
##
## so, for any target t in hundredths,
##
##     P(crash >= t) = P(value <= 100 * p * N / t) = floor(100 * p * N / t) / N
##
## which is 0.97 * 100 / t up to one part in N. Cashing out at t returns
## (t / 100) * 0.97 * 100 / t = 0.97 of the stake for **every** target: the
## return is 97.00% no matter how the player plays. The 3% the house keeps is
## exactly the instant bust, P(crash < 1.00x) = 1 - 0.97, which is exact on the
## integer lattice because 100 * 0.97 * N is divisible by 100.
##
## The climb only replays that decided crash point; it never rolls again.

enum State { IDLE, COUNTDOWN, OVERCLOCKING, CRASHED, CASHED_OUT }

const DEFAULT_PAYTABLE: CoreOverclockPaytable = preload("res://data/paytables/core_overclock.tres")

var paytable: CoreOverclockPaytable = DEFAULT_PAYTABLE
var state: State = State.IDLE
var stake: int = 0
## The uniform integer this run was decided from, in [1, curve_denominator].
var value: int = 0
## The decided crash point in hundredths. Below min_cashout_centi it is a bust.
var crash_centi: int = 0
## Auto cash-out target in hundredths; 0 is off.
var auto_centi: int = 0
## Seconds of climb replayed so far.
var elapsed: float = 0.0
var countdown_left: float = 0.0
## What the ticker reads right now, in hundredths.
var multiplier_centi: int = 0
## The multiplier the run settled at; 0 until it settles.
var settled_centi: int = 0
## Crash points of recent runs, newest first.
var history: Array[int] = []


func _init(rules: CoreOverclockPaytable = null) -> void:
	if rules != null:
		paytable = rules
	multiplier_centi = paytable.min_cashout_centi


## "1.00", "2.35", "10000.00": a multiplier in hundredths.
static func multiplier_text(centi: int) -> String:
	return "%d.%02d" % [centi / 100, centi % 100]


func is_legal_stake(wager: int) -> bool:
	return wager > 0 and wager % paytable.stake_unit == 0


## A legal auto cash-out target: off, or a multiplier the cabinet can reach.
func is_legal_target(centi: int) -> bool:
	return centi == 0 or (centi >= paytable.min_cashout_centi and centi <= paytable.cap_centi)


## The crash point decided by one uniform integer in [1, curve_denominator].
func crash_for(uniform: int) -> int:
	var numerator: int = (
		paytable.multiplier_scale * paytable.rtp_numerator * paytable.curve_denominator
	)
	var raw: int = numerator / (paytable.rtp_denominator * maxi(uniform, 1))
	return mini(raw, paytable.cap_centi)


## A crash below 1.00x: the core never gets a window, and nothing can be banked.
func is_bust(centi: int) -> bool:
	return centi < paytable.min_cashout_centi


## How many of the N uniform integers give a crash at or above `centi`. This is
## the exact win count for a player whose target is `centi`.
func winning_count(centi: int) -> int:
	var numerator: int = (
		paytable.multiplier_scale * paytable.rtp_numerator * paytable.curve_denominator
	)
	var count: int = numerator / (paytable.rtp_denominator * maxi(centi, 1))
	return mini(count, paytable.curve_denominator)


## Exact probability that a run reaches `centi`.
func reach_probability(centi: int) -> float:
	return float(winning_count(centi)) / float(paytable.curve_denominator)


## Exact expected return per chip staked for a player who always banks at
## `centi`. It is 0.97 minus the lattice remainder, which is below
## centi / (100 * N).
func expected_return(centi: int) -> float:
	return float(centi) / float(paytable.multiplier_scale) * reach_probability(centi)


## Exact probability of the instant bust: 1 - 0.97 = 0.03.
func bust_probability() -> float:
	return 1.0 - reach_probability(paytable.min_cashout_centi)


## The multiplier the climb reads `seconds` after the core opens.
func curve_centi(seconds: float) -> int:
	if seconds <= 0.0:
		return paytable.min_cashout_centi
	var scale := float(paytable.multiplier_scale)
	var reading := scale * exp(paytable.growth_per_second * seconds)
	if reading >= float(paytable.cap_centi):
		return paytable.cap_centi
	return maxi(paytable.min_cashout_centi, int(reading))


## When the climb reaches `centi`. The inverse of curve_centi.
func seconds_for(centi: int) -> float:
	if centi <= paytable.min_cashout_centi:
		return 0.0
	return log(float(centi) / float(paytable.multiplier_scale)) / paytable.growth_per_second


## Whole chips returned for banking `wager` at `centi`. Legal stakes are
## multiples of the scale, so this never rounds; other stakes round down.
func payout_for(wager: int, centi: int) -> int:
	return wager * centi / paytable.multiplier_scale


## What banking right now would return.
func current_payout() -> int:
	return payout_for(stake, multiplier_centi)


func can_cash_out() -> bool:
	return state == State.OVERCLOCKING


func is_running() -> bool:
	return state == State.COUNTDOWN or state == State.OVERCLOCKING


## Sets the auto cash-out target. Only between runs, so it is never a reaction
## to a multiplier the player can already see.
func set_auto_target(centi: int) -> bool:
	if is_running() or not is_legal_target(centi) or centi == auto_centi:
		return false
	auto_centi = centi
	return true


## Locks the stake and decides the crash point. Nothing has animated yet.
func begin(wager: int, rng: RandomNumberGenerator) -> void:
	begin_from(wager, rng.randi_range(1, paytable.curve_denominator))


## Starts a run from a recorded uniform instead of the stream. Replaying a run
## that already happened (a capture, a proof, a test) needs no seed search.
func begin_from(wager: int, uniform: int) -> void:
	assert(is_legal_stake(wager), "Core Overclock stakes are multiples of the stake unit")
	assert(not is_running(), "One run at a time")
	assert(uniform >= 1 and uniform <= paytable.curve_denominator, "The uniform is out of range")
	stake = wager
	value = uniform
	crash_centi = crash_for(value)
	multiplier_centi = paytable.min_cashout_centi
	settled_centi = 0
	elapsed = 0.0
	countdown_left = paytable.countdown_seconds
	state = State.COUNTDOWN


## Replays `delta` seconds of the decided run. Returns the settled result on the
## step that ends the run, and null on every other step.
func advance(delta: float) -> RoundResult:
	if delta <= 0.0:
		return null
	if state == State.COUNTDOWN:
		countdown_left -= delta
		if countdown_left > 0.0:
			return null
		var overflow := -countdown_left
		countdown_left = 0.0
		state = State.OVERCLOCKING
		elapsed = 0.0
		multiplier_centi = paytable.min_cashout_centi
		# An instant bust ends here, on the same step the window opens, so no
		# input can ever land inside a window that does not exist.
		return _step(overflow)
	if state == State.OVERCLOCKING:
		return _step(delta)
	return null


## Banks the run by hand at the multiplier now on the ticker.
func cash_out() -> RoundResult:
	if not can_cash_out():
		return null
	return _settle(multiplier_centi, true)


## Clears the settled run so the cabinet can take another stake.
func reset() -> void:
	if is_running():
		return
	state = State.IDLE
	stake = 0
	elapsed = 0.0
	countdown_left = 0.0
	settled_centi = 0
	multiplier_centi = paytable.min_cashout_centi


## Forfeits a live run. The stake is lost and the crash point is still recorded,
## so leaving mid-run can never be cheaper than losing.
func abandon() -> RoundResult:
	if not is_running():
		return null
	var wager := stake
	_record(crash_centi)
	state = State.CRASHED
	settled_centi = 0
	return RoundResult.create(wager, 0, RoundResult.Outcome.ABANDONED, _detail(0, false))


## One replay step. The auto target is checked first and settles at exactly the
## target, so a long frame can never cash out late or skip past a reached target.
func _step(delta: float) -> RoundResult:
	elapsed += delta
	var reading := curve_centi(elapsed)
	if auto_centi > 0 and auto_centi <= crash_centi and reading >= auto_centi:
		return _settle(auto_centi, true)
	if reading >= crash_centi:
		return _settle(crash_centi, false)
	multiplier_centi = reading
	return null


func _settle(centi: int, banked: bool) -> RoundResult:
	multiplier_centi = centi
	settled_centi = centi if banked else 0
	state = State.CASHED_OUT if banked else State.CRASHED
	_record(crash_centi)
	if not banked:
		return RoundResult.create(stake, 0, RoundResult.Outcome.LOSS, _detail(centi, false))
	var payout := payout_for(stake, centi)
	var outcome := RoundResult.Outcome.CASHED_OUT
	if payout == stake:
		outcome = RoundResult.Outcome.PUSH
	elif payout < stake:
		outcome = RoundResult.Outcome.LOSS
	return RoundResult.create(stake, payout, outcome, _detail(centi, true))


func _record(centi: int) -> void:
	history.push_front(centi)
	while history.size() > paytable.history_length:
		history.pop_back()


func _detail(centi: int, banked: bool) -> Dictionary:
	return {
		"crash_centi": crash_centi,
		"multiplier_centi": centi,
		"cashed_out": banked,
		"auto_centi": auto_centi,
		"uniform": value,
		"elapsed": elapsed,
		"bust": is_bust(crash_centi),
	}
