class_name VaultRuneFrame
extends Control
## Hexbound Vault HUD surface: a flat carved-slate plate with a silver outer rule,
## a faint inset "chisel" rule and four diamond rivets. Deliberately distinct
## from the Slot and Blackjack chrome: squared corners, silver and candle-amber,
## no gradients, no glow, no soft shadows. Presentation-only.

const STONE := Color("111115")
const STONE_RAISED := Color("1a1a20")
const SILVER := Color("aab3bf")
const SILVER_DIM := Color("5d636d")
const SILVER_TEXT := Color("e6e9ee")
const MUTED_TEXT := Color("a39d94")
const AMBER := Color("e3b062")
const UMBER := Color("2b1d12")
const CORNER_RADIUS: int = 2

var fill: Color = Color(STONE, 0.94)
var border: Color = SILVER_DIM
var rivet: Color = SILVER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_plate(self, Rect2(Vector2.ZERO, size), fill, border, rivet)


## Shared by the frame itself and by vault widgets that draw their own plate.
static func draw_plate(
	canvas: CanvasItem, rect: Rect2, plate_fill: Color, plate_border: Color, stud: Color
) -> void:
	canvas.draw_rect(rect, plate_fill, true)
	canvas.draw_rect(rect.grow(-0.5), plate_border, false, 1.0)
	canvas.draw_rect(rect.grow(-4.5), Color(plate_border, 0.42), false, 1.0)
	for corner: Vector2 in [
		rect.position + Vector2(4.5, 4.5),
		Vector2(rect.end.x - 4.5, rect.position.y + 4.5),
		Vector2(rect.position.x + 4.5, rect.end.y - 4.5),
		rect.end - Vector2(4.5, 4.5),
	]:
		_draw_diamond(canvas, corner, 3.0, stud)


## Flat squared button face (no shadow, no gradient) for vault-only controls.
static func button_style(face: Color, edge: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style


static func _draw_diamond(canvas: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	(
		canvas
		. draw_colored_polygon(
			PackedVector2Array(
				[
					at + Vector2(0, -radius),
					at + Vector2(radius, 0),
					at + Vector2(0, radius),
					at + Vector2(-radius, 0),
				]
			),
			color
		)
	)
