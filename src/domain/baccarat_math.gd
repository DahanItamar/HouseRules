class_name BaccaratMath
extends RefCounted
## Punto Banco from an eight-deck shoe. Chips go on five spots before the deal;
## one coup drawn from the cabinet stream settles every spot together.
##
## Every coup is dealt from a freshly shuffled shoe (a continuous shuffler), so
## each hand has exactly the enumerated odds in BaccaratOdds. Cards are drawn
## without replacement inside the coup by rejection: a uniform shoe index is
## redrawn when that physical card is already on the table.
##
## Banker commission: a winning Banker bet of S chips is paid
## S * banker_pays - ceil(S * banker_pays * commission% / 100), so the house
## never pays a fraction of a chip and the rounding always goes up. Every chip
## on this table is a multiple of 20, where 5% is exact (a 20-chip Banker win
## pays 19); other amounts pay slightly less than 19:20.

const DEFAULT_PAYTABLE: BaccaratPaytable = preload("res://data/paytables/baccarat.tres")
const PLAYER := "player"
const BANKER := "banker"
const TIE := "tie"
const PLAYER_PAIR := "player_pair"
const BANKER_PAIR := "banker_pair"
## Left-to-right order of the spots on the layout.
const SPOTS: Array[String] = [PLAYER_PAIR, PLAYER, TIE, BANKER, BANKER_PAIR]

var paytable: BaccaratPaytable = DEFAULT_PAYTABLE
## Spot id -> chips on that spot for the coup being built.
var bets: Dictionary = {}
## The previous coup's bets, restored by rebet().
var last_bets: Dictionary = {}
var stake: int = 0
## The last coup dealt (see BaccaratRules.play_coup).
var coup: Dictionary = {}


func _init(rules: BaccaratPaytable = null) -> void:
	if rules != null:
		paytable = rules


func shoe_size() -> int:
	return paytable.decks * BaccaratRules.CARDS_PER_DECK


func has_spot(id: String) -> bool:
	return SPOTS.has(id)


## Price of a spot, to one (the Banker price is before commission).
func pays_to_one(id: String) -> int:
	match id:
		PLAYER:
			return paytable.player_pays
		BANKER:
			return paytable.banker_pays
		TIE:
			return paytable.tie_pays
		PLAYER_PAIR, BANKER_PAIR:
			return paytable.pair_pays
	return 0


## Whole chips kept from a winning Banker bet of `amount`, rounded up.
func commission_for(amount: int) -> int:
	if amount <= 0:
		return 0
	@warning_ignore("integer_division")
	var kept: int = (amount * paytable.banker_pays * paytable.banker_commission_percent + 99) / 100
	return kept


## Chips won (excluding the returned stake) by a winning Banker bet.
func banker_win(amount: int) -> int:
	return maxi(0, amount * paytable.banker_pays - commission_for(amount))


## Chips returned for `amount` on a spot after `result_coup`, including the
## returned stake. Player and Banker bets push on a tie.
func returned_for(id: String, amount: int, result_coup: Dictionary) -> int:
	if amount <= 0 or result_coup.is_empty():
		return 0
	var winner: int = result_coup.winner
	match id:
		PLAYER:
			if winner == BaccaratRules.Winner.PLAYER:
				return amount * (paytable.player_pays + 1)
			return amount if winner == BaccaratRules.Winner.TIE else 0
		BANKER:
			if winner == BaccaratRules.Winner.BANKER:
				return amount + banker_win(amount)
			return amount if winner == BaccaratRules.Winner.TIE else 0
		TIE:
			return amount * (paytable.tie_pays + 1) if winner == BaccaratRules.Winner.TIE else 0
		PLAYER_PAIR:
			return amount * (paytable.pair_pays + 1) if result_coup.player_pair else 0
		BANKER_PAIR:
			return amount * (paytable.pair_pays + 1) if result_coup.banker_pair else 0
	return 0


func total_bet() -> int:
	var total: int = 0
	for amount: int in bets.values():
		total += amount
	return total


func chips_on(id: String) -> int:
	return int(bets.get(id, 0))


## `cap` is the table limit already reduced to what the player can cover.
func can_place(id: String, amount: int, cap: int) -> bool:
	return has_spot(id) and amount > 0 and total_bet() + amount <= cap


func place(id: String, amount: int, cap: int) -> bool:
	if not can_place(id, amount, cap):
		return false
	bets[id] = chips_on(id) + amount
	return true


## Takes up to `amount` chips back from a spot; returns how many came back.
func remove(id: String, amount: int) -> int:
	var present := chips_on(id)
	var taken := mini(present, maxi(amount, 0))
	if taken <= 0:
		return 0
	if taken == present:
		bets.erase(id)
	else:
		bets[id] = present - taken
	return taken


func clear() -> void:
	bets.clear()


func can_rebet(cap: int) -> bool:
	if last_bets.is_empty():
		return false
	var total: int = 0
	for amount: int in last_bets.values():
		total += amount
	return total <= cap


func rebet(cap: int) -> bool:
	if not can_rebet(cap):
		return false
	bets = last_bets.duplicate()
	return true


## Draws one coup from a freshly shuffled shoe using the cabinet stream.
func deal_coup(rng: RandomNumberGenerator) -> Dictionary:
	var used: Dictionary = {}
	var last_card := shoe_size() - 1
	var draw := func() -> int:
		var card := rng.randi_range(0, last_card)
		while used.has(card):
			card = rng.randi_range(0, last_card)
		used[card] = true
		return card
	return BaccaratRules.play_coup(draw)


## The whole coup is decided here, before any card is shown, and settles every
## chip on the layout together.
func deal(rng: RandomNumberGenerator) -> RoundResult:
	assert(total_bet() > 0, "A coup needs at least one chip on the layout")
	stake = total_bet()
	coup = deal_coup(rng)
	return settle(coup)


## Settles the current layout against a known coup (deal() and tests).
func settle(result_coup: Dictionary) -> RoundResult:
	stake = total_bet()
	coup = result_coup
	var payout: int = 0
	var winners: Dictionary = {}
	var commission: int = 0
	for id: String in bets:
		var back := returned_for(id, bets[id], result_coup)
		if back > 0:
			winners[id] = back
			payout += back
	if result_coup.winner == BaccaratRules.Winner.BANKER and bets.has(BANKER):
		commission = commission_for(bets[BANKER])
	var placed := bets.duplicate()
	last_bets = placed.duplicate()
	bets.clear()
	var outcome := RoundResult.Outcome.LOSS
	if payout > stake:
		outcome = RoundResult.Outcome.WIN
	elif payout == stake:
		outcome = RoundResult.Outcome.PUSH
	var detail := result_coup.duplicate(true)
	detail["bets"] = placed
	detail["winners"] = winners
	detail["commission"] = commission
	return RoundResult.create(stake, payout, outcome, detail)
