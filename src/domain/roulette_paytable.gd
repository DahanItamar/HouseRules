class_name RoulettePaytable
extends Resource
## Single-zero wheel and the "to one" price of every bet kind. A bet covering
## k numbers pays (36 / k) - 1 to one, so each kind returns 36/37 of its stake.

@export var pocket_count: int = 37
@export var straight_pays: int = 35
@export var split_pays: int = 17
@export var street_pays: int = 11
@export var corner_pays: int = 8
@export var six_line_pays: int = 5
@export var dozen_pays: int = 2
@export var column_pays: int = 2
@export var even_money_pays: int = 1
@export var red_numbers: PackedInt32Array = PackedInt32Array(
	[1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
)
## Physical European wheel order, clockwise from zero. Presentation only reads it.
@export var wheel_order: PackedInt32Array = PackedInt32Array(
	[
		0,
		32,
		15,
		19,
		4,
		21,
		2,
		25,
		17,
		34,
		6,
		27,
		13,
		36,
		11,
		30,
		8,
		23,
		10,
		5,
		24,
		16,
		33,
		1,
		20,
		14,
		31,
		9,
		22,
		18,
		29,
		7,
		28,
		12,
		35,
		3,
		26
	]
)
