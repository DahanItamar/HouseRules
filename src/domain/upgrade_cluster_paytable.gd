class_name UpgradeClusterPaytable
extends Resource
## Prices and reel weights for the Upgrade Cluster cabinet.
##
## Pays are quoted in **milli-bet** units: 320 means 0.32 x the total bet, which
## is how a cluster game states its prices ("0.32 x256"). A cluster is priced by
## its symbol and by the band its size falls in, so the resource stays small while
## the curve keeps rising for huge clusters.
##
## The third decimal place is not shown to the player; it exists so that tuning
## the table to an exact RTP does not lose a fifth of a percent to rounding, which
## is what happens when the most common price on the board is a two-digit integer.
##
## The round's return is linear in every entry of `pays`, so the whole cabinet can
## be retuned to a new RTP by scaling this one array (see docs/cabinets/upgrade_cluster.md).

## Square grid edge. 7x7 = 49 cells.
@export var grid_size: int = 7
## Smallest connected group that pays. Connections are 4-way only.
@export var minimum_cluster: int = 5
## Relative frequency of each symbol on the fill stream, indexed by symbol.
## Four low symbols (0-3) are common, four high symbols (4-7) are rare.
@export var weights: PackedInt32Array = PackedInt32Array([18, 18, 18, 18, 7, 7, 7, 7])
## Inclusive lower bound of each pay band, ascending. A cluster uses the last band
## whose minimum it reaches.
@export var band_minimums: PackedInt32Array = PackedInt32Array([5, 6, 7, 8, 10, 12, 15, 20])
## Milli-bet price per symbol per band, row-major: `pays[symbol * bands + band]`.
@export var pays: PackedInt32Array = PackedInt32Array(
	[
		# ORB
		252,
		378,
		504,
		756,
		1260,
		2519,
		5039,
		12597,
		# PRISM
		302,
		453,
		605,
		907,
		1512,
		3023,
		6047,
		15116,
		# SHARD
		353,
		529,
		705,
		1058,
		1764,
		3527,
		7054,
		17636,
		# CUBE
		403,
		605,
		806,
		1209,
		2016,
		4031,
		8062,
		20155,
		# CROWN
		630,
		945,
		1260,
		1890,
		3149,
		6299,
		12597,
		31493,
		# STAR
		882,
		1323,
		1764,
		2645,
		4409,
		8818,
		17636,
		44090,
		# SIGIL
		1260,
		1890,
		2519,
		3779,
		6299,
		12597,
		25194,
		62985,
		# CORE
		1890,
		2834,
		3779,
		5669,
		9448,
		18896,
		37791,
		94478,
	]
)
## Destroyed-symbol counts that light each rung of the upgrade bar, ascending.
@export var charge_thresholds: PackedInt32Array = PackedInt32Array([4, 9, 14, 20, 27, 35, 44, 55])
## Global multiplier granted by each rung. The bar starts at `base_multiplier`.
@export var multipliers: PackedInt32Array = PackedInt32Array([2, 4, 8, 16, 32, 64, 128, 256])
@export var base_multiplier: int = 1
## Hard ceiling on one round, in bet multiples. High enough that it effectively
## never binds; it exists so a settlement can never be unbounded.
@export var max_win_multiple: int = 10000
## Guard against a pathological tumble chain. Never reached in practice.
@export var max_cascades: int = 64


func cell_count() -> int:
	return grid_size * grid_size


func symbol_count() -> int:
	return weights.size()


func band_count() -> int:
	return band_minimums.size()


## The band index a cluster of `size` falls in, or -1 when it does not pay.
func band_for(size: int) -> int:
	var band: int = -1
	for index: int in range(band_minimums.size()):
		if size >= band_minimums[index]:
			band = index
	return band


## Milli-bet price of one cluster, before any upgrade multiplier.
func pay_units(symbol: int, size: int) -> int:
	if size < minimum_cluster or symbol < 0 or symbol >= symbol_count():
		return 0
	var band := band_for(size)
	if band < 0:
		return 0
	return pays[symbol * band_count() + band]


## The global multiplier once `charge` symbols have been destroyed this round.
func multiplier_for(charge: int) -> int:
	var multiplier := base_multiplier
	for index: int in range(charge_thresholds.size()):
		if charge >= charge_thresholds[index]:
			multiplier = multipliers[index]
	return multiplier


func total_weight() -> int:
	var total: int = 0
	for weight: int in weights:
		total += weight
	return total
