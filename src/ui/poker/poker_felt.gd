class_name PokerFelt
extends Node2D
## Everything that lies on the Hold'em felt: hole and board cards, bet piles,
## the pot pile and the dealer button, with their motion.
##
## Cards fly from the dealer's hand, bets slide in from the seats and into the pot,
## folded hands are mucked back to the dealer and the pot is pushed to the winner.
## Reduced motion places everything at once. Presentation only: PokerTablePanel
## tells the felt what the recorded hand did; nothing here reads game state.

const CHIPS_POT := preload("res://assets/production/poker/props/chips_pot.png")
const CHIPS_BET := preload("res://assets/production/poker/props/chips_black.png")

## Seat plates (index 0 is the player's own readout plate).
const PLATE_POSITIONS: Array[Vector2] = [
	Vector2(764, 330),
	Vector2(24, 330),
	Vector2(24, 214),
	Vector2(196, 112),
	Vector2(592, 112),
	Vector2(764, 214),
]
## Face-down hole cards sit flush against their own plate's table-facing edge,
## so each pair reads as that player's without covering the plate's text
## (index 0 unused: the player's are centred).
const HOLE_ORIGINS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(199, 336),
	Vector2(199, 220),
	Vector2(300, 175),
	Vector2(606, 175),
	Vector2(714, 220),
]
## Showdown cards grow away from the plate, clear of the board.
const SHOWDOWN_ORIGINS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(199, 332),
	Vector2(199, 216),
	Vector2(258, 174),
	Vector2(622, 174),
	Vector2(676, 216),
]
const BET_SPOTS: Array[Vector2] = [
	Vector2(382, 376),
	Vector2(292, 352),
	Vector2(292, 252),
	Vector2(320, 238),
	Vector2(640, 238),
	Vector2(690, 284),
]
const BUTTON_SPOTS: Array[Vector2] = [
	Vector2(556, 400),
	Vector2(254, 362),
	Vector2(254, 246),
	Vector2(274, 178),
	Vector2(664, 178),
	Vector2(686, 246),
]
const NPC_CARD_SMALL := Vector2(30, 42)
const NPC_CARD_SHOWDOWN := Vector2(38, 53)
const BOARD_ORIGIN := Vector2(339, 220)
const BOARD_CARD := Vector2(50, 70)
const BOARD_GAP: float = 8.0
const PLAYER_CARD := Vector2(58, 81)
const PLAYER_CARD_ORIGINS: Array[Vector2] = [Vector2(418, 340), Vector2(482, 340)]
const POT_CHIPS_RECT := Rect2(408, 295, 44, 39)
const DEAL_SECONDS: float = 0.24
const DEAL_STAGGER: float = 0.05
const SWEEP_SECONDS: float = 0.22
const DIMMED := Color(0.52, 0.54, 0.6)

## Current stake, used only to pick how many chip stacks a bet shows.
var stake: int = 1
var board_cards: Array[PlayingCard] = []
var seat_cards: Dictionary = {}
var pot_chips: Sprite2D
var puck: Control

var _bet_piles: Dictionary = {}
var _street_bets: Dictionary = {}
var _tweens: Array[Tween] = []


static func board_rect() -> Rect2:
	return Rect2(BOARD_ORIGIN, Vector2(5.0 * BOARD_CARD.x + 4.0 * BOARD_GAP, BOARD_CARD.y))


static func npc_card_origin(seat: int, index: int, showdown: bool) -> Vector2:
	if showdown:
		return SHOWDOWN_ORIGINS[seat] + Vector2(42.0 * index, 0)
	return HOLE_ORIGINS[seat] + Vector2(18.0 * index, 2.0 * index)


func _ready() -> void:
	pot_chips = Sprite2D.new()
	pot_chips.name = "PotChips"
	pot_chips.texture = CHIPS_POT
	pot_chips.centered = false
	pot_chips.position = POT_CHIPS_RECT.position
	pot_chips.scale = POT_CHIPS_RECT.size / Vector2(CHIPS_POT.get_width(), CHIPS_POT.get_height())
	pot_chips.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pot_chips.z_index = 2
	pot_chips.hide()
	add_child(pot_chips)
	puck = DealerPuck.new()
	puck.name = "DealerButton"
	puck.size = Vector2(20, 20)
	puck.z_index = 3
	puck.hide()
	add_child(puck)


func clear() -> void:
	settle()
	for card: PlayingCard in board_cards:
		card.queue_free()
	board_cards.clear()
	for seat: int in seat_cards:
		for card: PlayingCard in seat_cards[seat]:
			card.queue_free()
	seat_cards.clear()
	for seat: int in _bet_piles:
		(_bet_piles[seat] as Node).queue_free()
	_bet_piles.clear()
	_street_bets.clear()
	pot_chips.hide()
	puck.hide()


func place_puck(seat: int) -> void:
	puck.show()
	puck.position = BUTTON_SPOTS[seat]


func show_pot(amount: int) -> void:
	pot_chips.visible = amount > 0


## Deals two cards to every seat in `order`; the player's land face up.
## Returns the seconds until the last card has landed.
func deal_hole_cards(order: Array, player_cards: Array) -> float:
	var reduced := MotionPolicy.is_reduced()
	var index := 0
	for round_index: int in range(2):
		for seat_value: Variant in order:
			var seat: int = seat_value
			var card := PlayingCard.new()
			card.name = "Seat%dCard%d" % [seat, round_index]
			var target: Rect2
			if seat == PokerMath.PLAYER_SEAT:
				var dealt: int = player_cards[round_index]
				card.configure(
					PokerHandEval.display_rank(dealt), PokerHandEval.suit_of(dealt), true
				)
				card.z_index = 4
				target = Rect2(PLAYER_CARD_ORIGINS[round_index], PLAYER_CARD)
			else:
				card.configure(1, 0, true)
				# Above the plates: the pair sits against its owner's plate edge.
				card.z_index = 8
				target = Rect2(npc_card_origin(seat, round_index, false), NPC_CARD_SMALL)
			card.size = target.size
			card.pivot_offset = target.size * 0.5
			card.rotation = _card_tilt(seat, round_index)
			add_child(card)
			if not seat_cards.has(seat):
				seat_cards[seat] = []
			(seat_cards[seat] as Array).append(card)
			_fly_card(card, target, index * DEAL_STAGGER)
			index += 1
	var flight := 0.0 if reduced else (index - 1) * DEAL_STAGGER + DEAL_SECONDS
	# The player's own cards turn face up once they land in front of them.
	for card: PlayingCard in seat_cards.get(PokerMath.PLAYER_SEAT, []):
		if reduced:
			card.set_face_down(false, false)
		else:
			var turn := create_tween()
			turn.tween_interval(flight + 0.04)
			turn.tween_callback(card.set_face_down.bind(false, true))
			_track(turn)
	return flight


## Deals new board cards after the street's bets are swept; returns the duration.
func add_board_cards(fresh: Array) -> float:
	var reduced := MotionPolicy.is_reduced()
	var start := board_cards.size()
	var delay := 0.0 if reduced else SWEEP_SECONDS
	for offset: int in range(fresh.size()):
		var dealt: int = fresh[offset]
		var slot := start + offset
		var card := PlayingCard.new()
		card.name = "BoardCard%d" % slot
		card.z_index = 4
		card.configure(PokerHandEval.display_rank(dealt), PokerHandEval.suit_of(dealt), true)
		card.size = BOARD_CARD
		card.pivot_offset = BOARD_CARD * 0.5
		add_child(card)
		board_cards.append(card)
		var target := Rect2(
			BOARD_ORIGIN + Vector2(slot * (BOARD_CARD.x + BOARD_GAP), 0), BOARD_CARD
		)
		_fly_card(card, target, delay + offset * DEAL_STAGGER)
		if reduced:
			card.set_face_down(false, false)
		else:
			var turn := create_tween()
			turn.tween_interval(delay + offset * DEAL_STAGGER + DEAL_SECONDS + 0.02 + offset * 0.05)
			turn.tween_callback(card.set_face_down.bind(false, true))
			_track(turn)
	if reduced:
		return 0.0
	return delay + (fresh.size() - 1) * DEAL_STAGGER + DEAL_SECONDS + fresh.size() * 0.05


## Turns an NPC's hole cards face up at showdown size after `delay` seconds.
func reveal_seat(seat: int, holes: Array, delay: float) -> void:
	var cards: Array = seat_cards.get(seat, [])
	for index: int in range(mini(cards.size(), holes.size())):
		var card: PlayingCard = cards[index]
		var dealt: int = holes[index]
		card.rank = PokerHandEval.display_rank(dealt)
		card.suit = PokerHandEval.suit_of(dealt)
		var target := Rect2(npc_card_origin(seat, index, true), NPC_CARD_SHOWDOWN)
		if MotionPolicy.is_reduced():
			_place_card(card, target)
			card.rotation = 0.0
			card.set_face_down(false, false)
			continue
		var grow := create_tween().set_parallel(true)
		grow.tween_property(card, "position", target.position, 0.18).set_delay(delay)
		grow.tween_property(card, "size", target.size, 0.18).set_delay(delay)
		grow.tween_property(card, "rotation", 0.0, 0.18).set_delay(delay)
		grow.chain().tween_callback(card.set_face_down.bind(false, true))
		_track(grow)


## Shows a seat's chips for this street (the plate names the amount).
func set_street_bet(seat: int, amount: int) -> void:
	_street_bets[seat] = amount
	var pile: Node2D = _bet_piles.get(seat)
	if amount <= 0:
		if pile != null:
			pile.queue_free()
			_bet_piles.erase(seat)
		return
	var unit := maxi(1, stake)
	var stacks := 1 if amount <= unit else (2 if amount <= unit * 3 else 3)
	if pile == null:
		pile = Node2D.new()
		pile.name = "BetPile%d" % seat
		pile.z_index = 3
		add_child(pile)
		_bet_piles[seat] = pile
		pile.position = PLATE_POSITIONS[seat] + Vector2(86, 30)
		_move_node(pile, BET_SPOTS[seat], 0.18)
	for child: Node in pile.get_children():
		child.queue_free()
	for index: int in range(stacks):
		var sprite := Sprite2D.new()
		sprite.texture = CHIPS_BET
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.scale = Vector2.ONE * (22.0 / float(CHIPS_BET.get_width()))
		sprite.position = Vector2(index * 13.0 - 11.0, float(index % 2) * 3.0 - 14.0)
		pile.add_child(sprite)


func street_bet(seat: int) -> int:
	return int(_street_bets.get(seat, 0))


func bet_pile_count() -> int:
	return _bet_piles.size()


## Street end: every bet on the felt slides into the pot.
func sweep_bets() -> void:
	for seat: int in _bet_piles.keys():
		var pile: Node2D = _bet_piles[seat]
		_bet_piles.erase(seat)
		if MotionPolicy.is_reduced():
			pile.queue_free()
			continue
		var tween := create_tween().set_parallel(true)
		(
			tween
			. tween_property(pile, "position", POT_CHIPS_RECT.get_center(), SWEEP_SECONDS)
			. set_trans(Tween.TRANS_QUAD)
		)
		tween.tween_property(pile, "modulate:a", 0.0, SWEEP_SECONDS).set_delay(SWEEP_SECONDS * 0.4)
		tween.chain().tween_callback(pile.queue_free)
		_track(tween)
	_street_bets.clear()


## The pot pile slides to the winning seat.
func push_chips_to(seat: int) -> void:
	if MotionPolicy.is_reduced():
		return
	var ghost := Sprite2D.new()
	ghost.texture = CHIPS_POT
	ghost.centered = false
	ghost.z_index = 5
	ghost.scale = pot_chips.scale
	ghost.position = POT_CHIPS_RECT.position
	add_child(ghost)
	var target := (
		PLAYER_CARD_ORIGINS[0] + Vector2(40, 30)
		if seat == PokerMath.PLAYER_SEAT
		else PLATE_POSITIONS[seat] + Vector2(64, 10)
	)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "position", target, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2).set_delay(0.3)
	tween.chain().tween_callback(ghost.queue_free)
	_track(tween)


## Dims every face-up card outside the winning five.
func highlight(best: Array, board: Array[int], holes: Array) -> void:
	if best.is_empty():
		return
	for index: int in range(board_cards.size()):
		var in_best := index < board.size() and best.has(board[index])
		board_cards[index].modulate = Color.WHITE if in_best else DIMMED
	for seat: int in seat_cards:
		var seat_holes: Array = holes[seat]
		var cards: Array = seat_cards[seat]
		for index: int in range(mini(cards.size(), seat_holes.size())):
			var card: PlayingCard = cards[index]
			if card.face_down:
				continue
			card.modulate = Color.WHITE if best.has(seat_holes[index]) else DIMMED


## A folded NPC hand goes back to the dealer; the player's own cards dim.
func muck(seat: int) -> void:
	var cards: Array = seat_cards.get(seat, [])
	if seat == PokerMath.PLAYER_SEAT:
		for card: PlayingCard in cards:
			card.modulate = Color(0.55, 0.57, 0.62)
		return
	seat_cards.erase(seat)
	for card: PlayingCard in cards:
		if MotionPolicy.is_reduced():
			card.queue_free()
			continue
		var tween := create_tween().set_parallel(true)
		var target := PokerDealerPresenter.deck_point() + Vector2(0, 18)
		tween.tween_property(card, "position", target - card.size * 0.5, 0.24)
		tween.tween_property(card, "modulate:a", 0.0, 0.24)
		tween.tween_property(card, "scale", Vector2(0.6, 0.6), 0.24)
		tween.chain().tween_callback(card.queue_free)
		_track(tween)


func has_active_motion() -> bool:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			return true
	return false


## Completes every in-flight card and chip tween at its end state.
func settle() -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.custom_step(10.0)
			if tween.is_valid():
				tween.kill()
	_tweens.clear()


func _card_tilt(seat: int, index: int) -> float:
	if seat == PokerMath.PLAYER_SEAT:
		return -0.05 if index == 0 else 0.05
	return (-0.08 if index == 0 else 0.06) * (1.0 if seat <= 2 else -1.0)


## One deal: a short curved slide from the dealer's hand to the card's spot.
func _fly_card(card: PlayingCard, target: Rect2, delay: float) -> void:
	var release := PokerDealerPresenter.card_release_point()
	if MotionPolicy.is_reduced():
		_place_card(card, target)
		return
	card.position = release - target.size * 0.5
	card.scale = Vector2.ONE * 0.42
	card.modulate.a = 0.0
	var resting := card.rotation
	card.rotation = -0.3
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.04)
	var via := release.lerp(target.get_center(), 0.5) + Vector2(0, -26)
	(
		tween
		. parallel()
		. tween_method(
			_move_card_along.bind(card, release, via, target, resting), 0.0, 1.0, DEAL_SECONDS
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_track(tween)


func _move_card_along(
	progress: float,
	card: PlayingCard,
	release: Vector2,
	via: Vector2,
	target: Rect2,
	resting: float
) -> void:
	if not is_instance_valid(card):
		return
	var inverse := 1.0 - progress
	var centre := (
		release * inverse * inverse
		+ via * 2.0 * inverse * progress
		+ target.get_center() * progress * progress
	)
	card.position = centre - target.size * 0.5
	card.scale = Vector2.ONE * lerpf(0.42, 1.0, progress)
	card.rotation = lerpf(-0.3, resting, progress)


func _place_card(card: PlayingCard, target: Rect2) -> void:
	card.size = target.size
	card.pivot_offset = target.size * 0.5
	card.position = target.position
	card.scale = Vector2.ONE
	card.modulate.a = 1.0


func _move_node(node: Node2D, target: Vector2, duration: float) -> void:
	if MotionPolicy.is_reduced():
		node.position = target
		return
	var tween := create_tween()
	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	_track(tween)


func _track(tween: Tween) -> void:
	_tweens = _tweens.filter(
		func(existing: Tween) -> bool: return existing != null and existing.is_valid()
	)
	_tweens.append(tween)


## Flat white acrylic dealer button with a silver rim and a "D".
class DealerPuck:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		draw_circle(centre + Vector2(0.6, 1.4), radius, Color(0, 0, 0, 0.35))
		draw_circle(centre, radius, Color("eef1f4"))
		draw_arc(centre, radius - 0.5, 0.0, TAU, 32, Color("8d99a8"), 1.0, true)
		draw_arc(centre, radius - 3.0, 0.0, TAU, 32, Color("c2cad3"), 1.0, true)
		var glyph := tr("POKER_DEALER_GLYPH")
		var font := Typography.DISPLAY_FONT
		var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(
			font,
			centre + Vector2(-width * 0.5, 4.5),
			glyph,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("1b2230")
		)
