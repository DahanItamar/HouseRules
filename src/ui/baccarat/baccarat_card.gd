class_name BaccaratCard
extends Control
## One baccarat card on the felt: the committed PlayingCard face underneath and
## its back on top. A squeeze peels the back away from the bottom edge, so the
## face (pips first, then the index) is uncovered a little at a time, the way a
## player bends a card up to read it. A pearl fold line marks the peel edge.
## Presentation only: the card's rank and suit come from the decided coup.

const SIZE := Vector2(56, 78)
const FOLD_LINE: float = 2.0

var card_id: int = -1
var hand: int = 0
var slot: int = 0
var peel: float = 0.0
var face: PlayingCard
var _cover: Control
var _back: PlayingCard
var _fold: ColorRect
var _fold_shadow: ColorRect


func _init(shoe_card: int = 0, hand_index: int = 0, slot_index: int = 0) -> void:
	card_id = shoe_card
	hand = hand_index
	slot = slot_index
	name = "BaccaratCard_%d_%d" % [hand_index, slot_index]
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = PlayingCard.new()
	face.name = "Face"
	face.size = SIZE
	face.configure(BaccaratRules.card_rank(shoe_card), BaccaratRules.card_suit(shoe_card), false)
	add_child(face)
	_cover = Control.new()
	_cover.name = "BackCover"
	_cover.clip_contents = true
	_cover.size = SIZE
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	_back = PlayingCard.new()
	_back.name = "Back"
	_back.size = SIZE
	_back.configure(1, 0, true)
	_cover.add_child(_back)
	_fold_shadow = _strip("FoldShadow", Color(BaccaratStyle.INK, 0.45))
	_fold = _strip("FoldLine", BaccaratStyle.PEARL)
	set_peel(0.0)


func _strip(node_name: String, colour: Color) -> ColorRect:
	var strip := ColorRect.new()
	strip.name = node_name
	strip.color = colour
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	return strip


## 0 = face down, 1 = face up; in between, the back is peeled from the bottom.
func set_peel(value: float) -> void:
	peel = clampf(value, 0.0, 1.0)
	var covered := SIZE.y * (1.0 - peel)
	_cover.size = Vector2(SIZE.x, covered)
	_cover.visible = peel < 1.0
	var folding := peel > 0.0 and peel < 1.0
	_fold.visible = folding
	_fold_shadow.visible = folding
	_fold.position = Vector2(1, covered - FOLD_LINE * 0.5)
	_fold.size = Vector2(SIZE.x - 2, FOLD_LINE)
	_fold_shadow.position = Vector2(1, covered + FOLD_LINE * 0.5)
	_fold_shadow.size = Vector2(SIZE.x - 2, 3.0)


func is_revealed() -> bool:
	return peel >= 1.0


func value() -> int:
	return BaccaratRules.card_value(card_id)
