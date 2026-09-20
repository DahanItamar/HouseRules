class_name CoreOverclockPaytable
extends Resource
## Core Overclock tuning. The crash point is a pure function of one uniform
## integer, so every number that shapes the distribution lives here.
##
## The survival function is P(crash >= m) = (rtp_numerator / rtp_denominator) / m
## for m >= 1. Cashing out at any multiplier m therefore returns
## m * (0.97 / m) = 0.97 of the stake, whatever the player's target, and the
## leftover 3% is the instant bust below 1.00x.
##
## Multipliers are integers in hundredths ("centi"): 100 = 1.00x, 235 = 2.35x.
## Every legal stake is a multiple of `stake_unit`, which is `multiplier_scale`,
## so `stake * centi / 100` is always an exact whole number of chips.

## Legal stakes are multiples of this, so payouts never round.
@export var stake_unit: int = 100
## Multipliers are stored in units of 1 / multiplier_scale.
@export var multiplier_scale: int = 100
## The lowest multiplier a run can be cashed out at (1.00x).
@export var min_cashout_centi: int = 100
## The highest crash point the cabinet reports (10000.00x). Capping is
## return-neutral: it only moves mass above the cap down onto it, and no legal
## target sits above it.
@export var cap_centi: int = 1_000_000
## Exact return as a fraction: 97 / 100 = 97.00%.
@export var rtp_numerator: int = 97
@export var rtp_denominator: int = 100
## The uniform draw is an integer in [1, curve_denominator]. Larger values make
## the quantised survival function closer to the continuous 0.97 / m.
@export var curve_denominator: int = 1_000_000_000
## The climb is multiplier = exp(growth_per_second * seconds); 2x at 1.73 s,
## 10x at 5.76 s, 100x at 11.5 s.
@export var growth_per_second: float = 0.40
## Locked-in bet, spooling core, no cash-out yet.
@export var countdown_seconds: float = 1.6
## How many crash points the recent-runs strip keeps.
@export var history_length: int = 10
## Auto cash-out presets in hundredths; 0 is "off" (cash out by hand).
@export var auto_targets: PackedInt32Array = PackedInt32Array([0, 120, 150, 200, 300, 500, 1000])
