class_name BlackjackDealerCardProp
extends Control
## Small, resolution-independent card used only inside the dealer's hand gesture.
## The table cards remain authoritative; this is a transient presentation prop.

const BACK := Color("6d1824")
const BACK_INK := Color("d9b44a")
const FACE := Color("f1e8d8")
const FACE_INK := Color("48c5d5")

var face_down: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	queue_redraw()


func set_face_down(hidden: bool) -> void:
	face_down = hidden
	queue_redraw()


func _draw() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = BACK if face_down else FACE
	card.border_color = BACK_INK if face_down else Color("b8ad9c")
	card.set_border_width_all(1)
	card.set_corner_radius_all(2)
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	if face_down:
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), BACK_INK, false, 1.0)
		draw_line(Vector2(4, size.y - 4), Vector2(size.x - 4, 4), BACK_INK, 1.0, true)
	else:
		var center := size * 0.5
		var diamond := PackedVector2Array([
			center + Vector2(0, -4), center + Vector2(3, 0),
			center + Vector2(0, 4), center + Vector2(-3, 0)
		])
		draw_colored_polygon(diamond, FACE_INK)
