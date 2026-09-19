class_name BaccaratRules
extends RefCounted
## Punto Banco card values and the fixed third-card tableau. Pure functions:
## nothing here draws a card or touches a stake.
##
## A card is an index into the shoe (0 .. decks * 52 - 1): rank = card % 13 + 1
## (1 = ace .. 13 = king) and suit = (card / 13) % 4 (the PlayingCard suit order).
## Aces count 1, two to nine count face value, tens and courts count 0, and a
## hand is worth the last digit of its sum.

enum Winner { PLAYER, BANKER, TIE }

const CARDS_PER_DECK: int = 52
const RANKS: int = 13


static func card_rank(card: int) -> int:
	return card % RANKS + 1


static func card_suit(card: int) -> int:
	@warning_ignore("integer_division")
	var suit_block: int = card / RANKS
	return suit_block % 4


static func rank_value(rank: int) -> int:
	return rank if rank < 10 else 0


static func card_value(card: int) -> int:
	return rank_value(card_rank(card))


static func hand_total(cards: Array) -> int:
	var total: int = 0
	for card: int in cards:
		total += card_value(card)
	return total % 10


static func is_natural(two_card_total: int) -> bool:
	return two_card_total >= 8


## Player draws a third card on 0-5 and stands on 6-7 (8-9 is a natural).
static func player_draws(player_total: int) -> bool:
	return player_total <= 5


## The Banker tableau. `player_third` is the value (0-9) of the Player's third
## card, or -1 when the Player stood on two cards.
static func banker_draws(banker_total: int, player_third: int) -> bool:
	if player_third < 0:
		return banker_total <= 5
	match banker_total:
		0, 1, 2:
			return true
		3:
			return player_third != 8
		4:
			return player_third >= 2 and player_third <= 7
		5:
			return player_third >= 4 and player_third <= 7
		6:
			return player_third == 6 or player_third == 7
	return false


## The first two cards of a hand share a rank (K-K is a pair, 10-K is not).
static func is_pair(cards: Array) -> bool:
	return cards.size() >= 2 and card_rank(cards[0]) == card_rank(cards[1])


static func winner_of(player_total: int, banker_total: int) -> Winner:
	if player_total > banker_total:
		return Winner.PLAYER
	if banker_total > player_total:
		return Winner.BANKER
	return Winner.TIE


## Plays one coup with `draw` (a Callable returning the next card) in the real
## dealing order: Player, Banker, Player, Banker, then any third cards.
static func play_coup(draw: Callable) -> Dictionary:
	var player: Array[int] = [draw.call()]
	var banker: Array[int] = [draw.call()]
	player.append(draw.call())
	banker.append(draw.call())
	var player_total := hand_total(player)
	var banker_total := hand_total(banker)
	var natural := is_natural(player_total) or is_natural(banker_total)
	var player_third: int = -1
	if not natural:
		if player_draws(player_total):
			player.append(draw.call())
			player_third = card_value(player[2])
			player_total = hand_total(player)
		if banker_draws(banker_total, player_third):
			banker.append(draw.call())
			banker_total = hand_total(banker)
	return {
		"player_cards": player,
		"banker_cards": banker,
		"player_total": player_total,
		"banker_total": banker_total,
		"winner": winner_of(player_total, banker_total),
		"natural": natural,
		"player_pair": is_pair(player),
		"banker_pair": is_pair(banker),
	}
