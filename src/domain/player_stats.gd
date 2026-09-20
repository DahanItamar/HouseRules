class_name PlayerStats
extends RefCounted
## Read-only records of what actually happened, aggregated from the save.
##
## Every number here is already written by the game's own settlement path:
## `CabinetSession.apply_result` records rounds, chips staked, chips returned
## and the best single payout per cabinet, and `Progression` records the win
## streak and the time played. Nothing is estimated, scaled or rounded up.

## Per-cabinet rows, richest first, plus the totals the overview reads.
var rows: Array[Dictionary] = []
var rounds: int = 0
var staked: int = 0
var returned: int = 0
var best_win: int = 0
var longest_streak: int = 0
var played_seconds: float = 0.0
var favourite_id: StringName = &""


## `state` is a SaveGame (or null before a profile is loaded).
static func from_save(state: SaveGame) -> PlayerStats:
	var stats := PlayerStats.new()
	if state == null:
		return stats
	stats.longest_streak = maxi(state.longest_win_streak, 0)
	stats.played_seconds = maxf(state.played_seconds, 0.0)
	var most_rounds: int = 0
	for key: Variant in state.cabinet_stats:
		var cabinet: CabinetStats = state.cabinet_stats[key]
		if cabinet == null or cabinet.rounds <= 0:
			continue
		stats.rounds += cabinet.rounds
		stats.staked += cabinet.wagered
		stats.returned += cabinet.returned
		stats.best_win = maxi(stats.best_win, cabinet.best_win)
		if cabinet.rounds > most_rounds:
			most_rounds = cabinet.rounds
			stats.favourite_id = StringName(key)
		(
			stats
			. rows
			. append(
				{
					"id": StringName(key),
					"rounds": cabinet.rounds,
					"staked": cabinet.wagered,
					"returned": cabinet.returned,
					"net": cabinet.returned - cabinet.wagered,
					"best_win": cabinet.best_win,
				}
			)
		)
	stats.rows.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.rounds) > int(right.rounds)
	)
	return stats


## Chips returned minus chips staked. Negative is the honest, common case.
func net() -> int:
	return returned - staked


func has_history() -> bool:
	return rounds > 0


## "3h 24m", or "12m" under an hour, or "48s" in a first session.
func played_text() -> String:
	var total := int(played_seconds)
	if total >= 3600:
		return "%dh %02dm" % [total / 3600, (total % 3600) / 60]
	if total >= 60:
		return "%dm" % (total / 60)
	return "%ds" % total
