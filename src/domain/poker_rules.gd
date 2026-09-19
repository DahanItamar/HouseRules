class_name PokerRules
extends Resource
## Designer-editable table rules for Texas Hold'em (fixed limit).
##
## The small bet equals the selected stake and is also the big blind; the small
## blind is half of it. Turn and river bets are the big bet (twice the stake).

## Seats at the table: the player plus `seats - 1` NPCs.
@export var seats: int = 6
## One bet plus three raises per street (the big blind counts as the first bet).
@export var max_bets_per_street: int = 4
## House rake taken from pots the player wins, in whole percent.
@export var rake_percent: int = 10
## Rake never exceeds this many stakes in one hand.
@export var rake_cap_stakes: int = 3
## No rake is taken when a hand ends before the flop.
@export var no_flop_no_drop: bool = true
## NPC table stacks (never the player's wallet), in stakes.
@export var npc_buy_in_stakes: int = 40
## An NPC below this many stakes tops back up to the buy-in before a hand. It is
## at least the most one NPC can put in a single capped hand (24 stakes), so
## NPCs are never all in and only the player can create a side pot.
@export var npc_rebuy_below_stakes: int = 24
