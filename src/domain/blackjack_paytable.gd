class_name BlackjackPaytable
extends Resource

@export var decks: int = 6
@export var reshuffle_below: int = 52
@export var natural_numerator: int = 5
@export var natural_denominator: int = 2
# Cap is relative to the final, possibly doubled, risked stake.
@export var max_win: int = 3
