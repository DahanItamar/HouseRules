class_name RouletteSeatPlate
extends Control
## One seated guest in the Ruby Salon HUD: painted portrait, name, betting
## style with their wheel-chip colour, and a short reaction line. Lives in the
## HUD row above the layout, never as a floating label over the art.

const PLATE_SIZE := Vector2(198, 88)
const PORTRAIT_RECT := Rect2(8, 8, 72, 72)

var guest: RouletteTableGuests.Guest
var _name: Label
var _tag: Label
var _line: Label
var _line_tween: Tween


func _init(seated: RouletteTableGuests.Guest) -> void:
	guest = seated
	name = "SeatPlate%s" % guest.name_key.trim_prefix("ROULETTE_GUEST_").capitalize()
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_name = RouletteStyle.label(self, Rect2(88, 7, 104, 20), 16, RouletteStyle.IVORY)
	_name.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_tag = RouletteStyle.label(self, Rect2(104, 27, 88, 16), 12, RouletteStyle.BRASS_BRIGHT)
	_line = RouletteStyle.label(self, Rect2(88, 44, 104, 40), 13, RouletteStyle.IVORY_MUTED)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.clip_text = false
	_line.max_lines_visible = 2
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	refresh(false)


func refresh(animate: bool = true) -> void:
	if _name == null:
		return
	_name.text = tr(guest.name_key)
	_tag.text = tr(guest.tag_key)
	var next := tr(guest.line_key) if not guest.line_key.is_empty() else ""
	if next.contains("%d"):
		next = next % guest.line_value
	if next == _line.text:
		return
	_line.text = next
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()
	_line.modulate.a = 1.0
	_line.position.y = 44.0
	if animate and not MotionPolicy.is_reduced() and is_inside_tree():
		_line.modulate.a = 0.0
		_line.position.y = 48.0
		_line_tween = create_tween().set_parallel(true)
		_line_tween.tween_property(_line, "modulate:a", 1.0, 0.2)
		_line_tween.tween_property(_line, "position:y", 44.0, 0.2).set_trans(Tween.TRANS_QUAD)
	var won := guest.last_net > 0
	_line.add_theme_color_override(
		"font_color", RouletteStyle.WIN_INK if won else RouletteStyle.IVORY_MUTED
	)


func _draw() -> void:
	RouletteStyle.draw_plate(self, Rect2(Vector2.ZERO, size), Color(RouletteStyle.MAHOGANY, 0.94))
	draw_rect(PORTRAIT_RECT.grow(2.0), RouletteStyle.BRASS)
	draw_texture_rect(guest.portrait, PORTRAIT_RECT, false)
	draw_rect(PORTRAIT_RECT, Color(RouletteStyle.IVORY, 0.35), false, 1.0)
	var swatch := Vector2(95, 35)
	draw_circle(swatch, 6.0, guest.chip_color)
	draw_arc(swatch, 6.0, 0.0, TAU, 18, RouletteStyle.IVORY, 1.5, true)
