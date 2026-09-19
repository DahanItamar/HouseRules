class_name MatchPointPaytable
extends Resource
## Match Point court multipliers. A ball crosses `rows` rows of posts and makes
## one fair left/right hop per row, so it lands in court k (0 = far left) with
## probability C(rows, k) / 2^rows. Multipliers are stored in tenths so every
## legal stake (a multiple of `stake_unit`) pays an exact integer.
##
## Each risk table is symmetric and tuned so its exact return is
## sum(C(12, k) * tenths[k]) / (10 * 4096) = 39320 / 40960 = 95.99609375%.

@export var rows: int = 12
## Every legal stake is a multiple of this, so tenths always settle exactly.
@export var stake_unit: int = 10
@export var low_tenths: PackedInt32Array = PackedInt32Array(
	[97, 27, 14, 12, 11, 10, 5, 10, 11, 12, 14, 27, 97]
)
@export var medium_tenths: PackedInt32Array = PackedInt32Array(
	[330, 80, 30, 16, 12, 7, 3, 7, 12, 16, 30, 80, 330]
)
@export var high_tenths: PackedInt32Array = PackedInt32Array(
	[1200, 200, 60, 22, 8, 3, 2, 3, 8, 22, 60, 200, 1200]
)
## Documented exact return per risk (numerator over 10 * 2^rows); tests check it.
@export var exact_return_numerator: int = 39320
