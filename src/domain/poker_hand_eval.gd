class_name PokerHandEval
extends RefCounted
## Texas Hold'em hand ranking: the best five cards out of five to seven.
##
## A card is an int 0..51: `rank_index = card >> 2` (0 = deuce .. 12 = ace) and
## `suit = card & 3` (0 spade, 1 heart, 2 diamond, 3 club, the PlayingCard order).
## A score packs `category << 20` above five 4-bit rank indices in order of
## significance, so a larger score always wins and equal scores split the pot.
## Pure and allocation-light: NPC equity estimates call it thousands of times.

enum Category {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	TRIPS,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	QUADS,
	STRAIGHT_FLUSH,
}

const CATEGORY_SHIFT: int = 20
const ACE: int = 12
## Ace, deuce, trey, four and five: the wheel (five-high straight).
const WHEEL_MASK: int = (1 << 12) | 0b1111
const CATEGORY_KEYS: Array[String] = [
	"POKER_HAND_HIGH_CARD",
	"POKER_HAND_PAIR",
	"POKER_HAND_TWO_PAIR",
	"POKER_HAND_TRIPS",
	"POKER_HAND_STRAIGHT",
	"POKER_HAND_FLUSH",
	"POKER_HAND_FULL_HOUSE",
	"POKER_HAND_QUADS",
	"POKER_HAND_STRAIGHT_FLUSH",
]


static func make_card(rank_index: int, suit: int) -> int:
	return rank_index * 4 + suit


static func rank_of(card: int) -> int:
	return card >> 2


static func suit_of(card: int) -> int:
	return card & 3


## PlayingCard rank (1 = ace, 2..10, 11 J, 12 Q, 13 K) for a card int.
static func display_rank(card: int) -> int:
	var rank_index := card >> 2
	return 1 if rank_index == ACE else rank_index + 2


static func category_of(score: int) -> int:
	return score >> CATEGORY_SHIFT


static func category_key(score: int) -> String:
	return CATEGORY_KEYS[clampi(score >> CATEGORY_SHIFT, 0, CATEGORY_KEYS.size() - 1)]


## Score of the best five-card hand inside `cards` (5 to 7 distinct cards).
static func evaluate(cards: Array[int]) -> int:
	# Three bits per rank hold its count; four bits per suit hold its count.
	var counts: int = 0
	var suit_counts: int = 0
	var rank_mask: int = 0
	var spade_mask: int = 0
	var heart_mask: int = 0
	var diamond_mask: int = 0
	var club_mask: int = 0
	for card: int in cards:
		var rank_index := card >> 2
		var bit := 1 << rank_index
		counts += 1 << (rank_index * 3)
		rank_mask |= bit
		match card & 3:
			0:
				spade_mask |= bit
				suit_counts += 1
			1:
				heart_mask |= bit
				suit_counts += 1 << 4
			2:
				diamond_mask |= bit
				suit_counts += 1 << 8
			_:
				club_mask |= bit
				suit_counts += 1 << 12
	var flush_mask: int = 0
	if suit_counts & 0xF >= 5:
		flush_mask = spade_mask
	elif (suit_counts >> 4) & 0xF >= 5:
		flush_mask = heart_mask
	elif (suit_counts >> 8) & 0xF >= 5:
		flush_mask = diamond_mask
	elif (suit_counts >> 12) & 0xF >= 5:
		flush_mask = club_mask
	if flush_mask != 0:
		var straight_flush_high := straight_high(flush_mask)
		if straight_flush_high >= 0:
			return _pack(Category.STRAIGHT_FLUSH, straight_flush_high << 16)
	var quad := -1
	var trip_high := -1
	var trip_low := -1
	var pair_high := -1
	var pair_low := -1
	for rank_index: int in range(ACE, -1, -1):
		var count := (counts >> (rank_index * 3)) & 7
		if count == 4:
			quad = rank_index
		elif count == 3:
			if trip_high < 0:
				trip_high = rank_index
			elif trip_low < 0:
				trip_low = rank_index
		elif count == 2:
			if pair_high < 0:
				pair_high = rank_index
			elif pair_low < 0:
				pair_low = rank_index
	if quad >= 0:
		return _pack(Category.QUADS, (quad << 16) | _kickers(rank_mask & ~(1 << quad), 1, 12))
	if trip_high >= 0 and (trip_low >= 0 or pair_high >= 0):
		return _pack(Category.FULL_HOUSE, (trip_high << 16) | (maxi(trip_low, pair_high) << 12))
	if flush_mask != 0:
		return _pack(Category.FLUSH, _kickers(flush_mask, 5, 16))
	var straight := straight_high(rank_mask)
	if straight >= 0:
		return _pack(Category.STRAIGHT, straight << 16)
	if trip_high >= 0:
		return _pack(
			Category.TRIPS, (trip_high << 16) | _kickers(rank_mask & ~(1 << trip_high), 2, 12)
		)
	if pair_low >= 0:
		var rest := rank_mask & ~(1 << pair_high) & ~(1 << pair_low)
		return _pack(Category.TWO_PAIR, (pair_high << 16) | (pair_low << 12) | _kickers(rest, 1, 8))
	if pair_high >= 0:
		return _pack(
			Category.PAIR, (pair_high << 16) | _kickers(rank_mask & ~(1 << pair_high), 3, 12)
		)
	return _pack(Category.HIGH_CARD, _kickers(rank_mask, 5, 16))


## Highest rank index of a five-rank run inside `mask`, 3 for the wheel, else -1.
static func straight_high(mask: int) -> int:
	for high: int in range(ACE, 3, -1):
		var run := 0x1F << (high - 4)
		if mask & run == run:
			return high
	if mask & WHEEL_MASK == WHEEL_MASK:
		return 3
	return -1


## The five cards that make the best hand (for showdown highlighting).
static func best_five(cards: Array[int]) -> Array[int]:
	var best: Array[int] = []
	var best_score := -1
	var count := cards.size()
	if count <= 5:
		best.assign(cards)
		return best
	for a: int in range(count):
		for b: int in range(a + 1, count):
			for c: int in range(b + 1, count):
				for d: int in range(c + 1, count):
					for e: int in range(d + 1, count):
						var hand: Array[int] = [cards[a], cards[b], cards[c], cards[d], cards[e]]
						var score := evaluate(hand)
						if score > best_score:
							best_score = score
							best = hand
	return best


static func _pack(category: int, ranks: int) -> int:
	return (category << CATEGORY_SHIFT) | ranks


## Top `count` ranks of `mask`, packed from bit `shift` downward in 4-bit steps.
static func _kickers(mask: int, count: int, shift: int) -> int:
	var packed := 0
	var remaining := count
	var next_shift := shift
	var rank_index := ACE
	while remaining > 0 and rank_index >= 0:
		if mask & (1 << rank_index):
			packed |= rank_index << next_shift
			next_shift -= 4
			remaining -= 1
		rank_index -= 1
	return packed
