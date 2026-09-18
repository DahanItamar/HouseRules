class_name PlayingCard
extends Control
## Sharp resolution-independent blackjack card with a real face/back state.

const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]
const RED := Color("a53243")
const BLACK := Color("17161a")
var rank: int = 1
var suit: int = 0
var face_down: bool = false


func configure(card_rank: int, card_suit: int, hidden: bool) -> void:
	rank = card_rank
	suit = posmod(card_suit, SUITS.size())
	face_down = hidden
	queue_redraw()


func reveal() -> void:
	face_down = false
	queue_redraw()


func _draw() -> void:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("5a111c") if face_down else Color("f1e8d8")
	card_style.border_color = Color("c8a34b") if face_down else Color("b8ad9c")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(7)
	draw_style_box(card_style, Rect2(Vector2.ZERO, size))
	if face_down:
		for inset: int in [8, 14, 20]:
			draw_rect(
				Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2)),
				Color("c8a34b"),
				false,
				1.0
			)
		return
	var rank_text := tr("CARD_" + str(rank)) if rank == 1 or rank > 10 else str(rank)
	var ink := RED if suit == 1 or suit == 2 else BLACK
	draw_string(ThemeDB.fallback_font, Vector2(8, 25), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(ThemeDB.fallback_font, Vector2(8, 48), SUITS[suit], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, 72),
		SUITS[suit],
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		34,
		ink
	)
