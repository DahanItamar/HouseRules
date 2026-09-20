class_name UpgradeClusterMath
extends RefCounted
## Upgrade Cluster: a 7x7 cluster-pays grid with tumbles and an upgrade bar.
##
## Pure domain. It never touches the scene tree, the wallet or a timer: one call to
## [method play] draws the whole round - the first grid, every tumble, the upgrade
## bar and the exact settlement - from one RandomNumberGenerator, and returns it as
## a RoundResult whose `detail` is a complete replay script for the cabinet screen.
##
## Connection rule: cells are connected only up, down, left and right. Diagonals
## never join a cluster. Five or more connected cells of the same symbol pay.
##
## Money: pays are milli-bet integers (320 = 0.32 x bet). One round sums its
## milli-bet wins, applies the ceiling, and converts once at settlement with
## round-half-up: `payout = (units * stake + 500) / 1000`. Nothing else rounds,
## and nothing rounds per cascade, so a long tumble chain cannot bleed chips.

enum Symbol { ORB, PRISM, SHARD, CUBE, CROWN, STAR, SIGIL, CORE }

const DEFAULT_PAYTABLE: UpgradeClusterPaytable = preload(
	"res://data/paytables/upgrade_cluster.tres"
)
## Milli-bet units in one bet.
const UNITS: int = 1000
## The four legal connections. Diagonals are deliberately absent.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)
]

var paytable: UpgradeClusterPaytable = DEFAULT_PAYTABLE


func _init(rules: UpgradeClusterPaytable = null) -> void:
	if rules != null:
		paytable = rules


func grid_size() -> int:
	return paytable.grid_size


func cell_count() -> int:
	return paytable.cell_count()


func index_of(column: int, row: int) -> int:
	return row * paytable.grid_size + column


func column_of(index: int) -> int:
	return index % paytable.grid_size


func row_of(index: int) -> int:
	return index / paytable.grid_size


## One weighted symbol draw from the fill stream.
func next_symbol(rng: RandomNumberGenerator) -> int:
	var roll := rng.randi_range(0, paytable.total_weight() - 1)
	for symbol: int in range(paytable.weights.size()):
		roll -= paytable.weights[symbol]
		if roll < 0:
			return symbol
	return paytable.weights.size() - 1


## A fresh grid, filled row by row from the top-left. Row 0 is the top row.
func fill_grid(rng: RandomNumberGenerator) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(cell_count())
	for index: int in range(cell_count()):
		grid[index] = next_symbol(rng)
	return grid


## Every paying cluster on `grid`, found with a 4-way flood fill.
##
## Returns an array of {"symbol": int, "cells": PackedInt32Array}, ordered by the
## lowest cell index in each cluster so the list is stable for replay and tests.
func find_clusters(grid: PackedByteArray) -> Array[Dictionary]:
	var size := paytable.grid_size
	var seen := PackedByteArray()
	seen.resize(grid.size())
	var clusters: Array[Dictionary] = []
	for start: int in range(grid.size()):
		if seen[start] == 1:
			continue
		var symbol := int(grid[start])
		var cells := PackedInt32Array()
		var frontier: Array[int] = [start]
		seen[start] = 1
		while not frontier.is_empty():
			var current: int = frontier.pop_back()
			cells.append(current)
			var column := current % size
			var row := current / size
			for step: Vector2i in NEIGHBOURS:
				var next_column := column + step.x
				var next_row := row + step.y
				if next_column < 0 or next_column >= size or next_row < 0 or next_row >= size:
					continue
				var next := next_row * size + next_column
				if seen[next] == 1 or int(grid[next]) != symbol:
					continue
				seen[next] = 1
				frontier.append(next)
		if cells.size() >= paytable.minimum_cluster:
			cells.sort()
			clusters.append({"symbol": symbol, "cells": cells})
	return clusters


## Removes `cells`, drops the survivors in each column and refills the gaps.
##
## Gravity is per column: what is left falls to the bottom keeping its order, and
## the holes that open at the top are filled from the stream column by column,
## left to right, top cell first. Returns the grid after the tumble.
func tumble(
	grid: PackedByteArray, cells: PackedInt32Array, rng: RandomNumberGenerator
) -> PackedByteArray:
	var size := paytable.grid_size
	var cleared := PackedByteArray()
	cleared.resize(grid.size())
	for cell: int in cells:
		cleared[cell] = 1
	var next := grid.duplicate()
	for column: int in range(size):
		var survivors: Array[int] = []
		for row: int in range(size):
			var index := row * size + column
			if cleared[index] == 0:
				survivors.append(int(grid[index]))
		var holes := size - survivors.size()
		for row: int in range(holes):
			next[row * size + column] = next_symbol(rng)
		for offset: int in range(survivors.size()):
			next[(holes + offset) * size + column] = survivors[offset]
	return next


## Plays one complete round: the first grid, every tumble, the upgrade bar and the
## settlement. Nothing is decided after this call returns.
func play(stake: int, rng: RandomNumberGenerator) -> RoundResult:
	assert(stake > 0, "A round needs a stake")
	var grid := fill_grid(rng)
	var opening := grid.duplicate()
	var cascades: Array = []
	var charge: int = 0
	var total_units: int = 0
	while cascades.size() < paytable.max_cascades:
		var clusters := find_clusters(grid)
		if clusters.is_empty():
			break
		var destroyed := PackedInt32Array()
		var base_units: int = 0
		var priced: Array = []
		for cluster: Dictionary in clusters:
			var cells: PackedInt32Array = cluster.cells
			var pay := paytable.pay_units(int(cluster.symbol), cells.size())
			base_units += pay
			destroyed.append_array(cells)
			priced.append({"symbol": int(cluster.symbol), "cells": cells, "base_units": pay})
		charge += destroyed.size()
		var multiplier := paytable.multiplier_for(charge)
		var win_units := base_units * multiplier
		total_units += win_units
		destroyed.sort()
		grid = tumble(grid, destroyed, rng)
		(
			cascades
			. append(
				{
					"clusters": priced,
					"destroyed": destroyed,
					"charge": charge,
					"multiplier": multiplier,
					"base_units": base_units,
					"win_units": win_units,
					"grid_after": grid.duplicate(),
				}
			)
		)
	var capped := mini(total_units, paytable.max_win_multiple * UNITS)
	var payout := settle(capped, stake)
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
				"grid": opening,
				"cascades": cascades,
				"charge": charge,
				"multiplier": paytable.multiplier_for(charge),
				"total_units": capped,
				"raw_units": total_units,
				"capped": capped != total_units,
			}
		)
	)


## Milli-bet units to whole chips, once per round, round-half-up.
static func settle(units: int, stake: int) -> int:
	if units <= 0 or stake <= 0:
		return 0
	return (units * stake + UNITS / 2) / UNITS


## Exact milli-bet value of one grid with no tumbles and no upgrade bar. Used by
## the tests to price a hand-built board without running a round.
func score_grid(grid: PackedByteArray) -> int:
	var total: int = 0
	for cluster: Dictionary in find_clusters(grid):
		total += paytable.pay_units(int(cluster.symbol), (cluster.cells as PackedInt32Array).size())
	return total
