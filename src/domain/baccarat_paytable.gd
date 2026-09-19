class_name BaccaratPaytable
extends Resource
## Punto Banco prices. "Pays" values are to one; the Banker commission is a
## whole-percent of the Banker win, rounded up to a whole chip (see BaccaratMath).

@export var decks: int = 8
@export var player_pays: int = 1
@export var banker_pays: int = 1
@export var banker_commission_percent: int = 5
@export var tie_pays: int = 8
@export var pair_pays: int = 11
