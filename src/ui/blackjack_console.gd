class_name BlackjackConsole
extends Control
## Blackjack's own HUD surface: a flat walnut rail plate with a brass edge and an
## inner brass hairline, optional felt-green insets and a small row of brass
## card-suit pips. Flat fills only: no gradients, glow or bloom. Presentation only.

const WALNUT := Color("2a1911")
const WALNUT_DEEP := Color("1d110b")
const BRASS := Color("c8a34b")
const BRASS_DIM := Color("7a5c2a")
const FELT := Color("123f30")
const FELT_EDGE := Color("5e4a24")

## Felt-green inset panels in local space (e.g. behind the wager chips).
var felt_insets: Array[Rect2] = []
## Left end of the suit-pip row in local space; negative x hides the row.
var suit_row_origin := Vector2(-1, -1)
var suit_pip_size: float = 9.0
var corner_radius: int = 7
var fill: Color = WALNUT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var body := StyleBoxFlat.new()
	body.bg_color = fill
	body.border_color = BRASS
	body.set_border_width_all(2)
	body.set_corner_radius_all(corner_radius)
	body.anti_aliasing = true
	body.shadow_color = Color("05040566")
	body.shadow_size = 6
	body.shadow_offset = Vector2(0, 3)
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var hairline := StyleBoxFlat.new()
	hairline.draw_center = false
	hairline.border_color = BRASS_DIM
	hairline.set_border_width_all(1)
	hairline.set_corner_radius_all(maxi(corner_radius - 3, 2))
	hairline.anti_aliasing = true
	draw_style_box(hairline, Rect2(Vector2(4, 4), size - Vector2(8, 8)))
	for inset: Rect2 in felt_insets:
		var felt := StyleBoxFlat.new()
		felt.bg_color = FELT
		felt.border_color = FELT_EDGE
		felt.set_border_width_all(1)
		felt.set_corner_radius_all(5)
		felt.anti_aliasing = true
		draw_style_box(felt, inset)
	if suit_row_origin.x >= 0.0:
		for index: int in range(4):
			var at := suit_row_origin + Vector2(index * suit_pip_size * 1.55, 0)
			PlayingCard.draw_suit(self, index, at, suit_pip_size, BRASS)
