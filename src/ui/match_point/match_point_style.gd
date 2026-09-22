class_name MatchPointStyle
extends RefCounted
## Match Point HUD language: a country-club scoreboard. Flat racing-green plates
## with double brass piping and cream enamel score strips with dark green ink.
## Distinct from Ruby Roulette (mahogany, studs), Blackjack (walnut and felt),
## the Elven Court slot (emerald, leaf-cut corners) and Hexbound Vault (slate).
## No gradients or glow; cyan appears only as keyboard/controller focus.

const RACING_GREEN := Color("123524")
const RACING_DEEP := Color("0b2418")
const RACING_RAISED := Color("1c4a33")
const CREAM := Color("efe6cf")
const CREAM_SHADE := Color("d9ceb0")
const CREAM_INK := Color("163a28")
const CREAM_MUTED := Color("bdb39a")
const BRASS := Color("c9a24e")
const BRASS_BRIGHT := Color("ecca72")
const BRASS_DIM := Color("7a6330")
const WIN_INK := Color("f2cf6b")
const LOSS_INK := Color("c9c0a6")
const TEXT_DISABLED := Color("5f6d62")


## Racing-green plate with double brass piping (outer rule and a fine inner line).
static func draw_plate(canvas: CanvasItem, rect: Rect2, fill: Color = RACING_GREEN) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect.grow(-1.0), BRASS, false, 2.0)
	canvas.draw_rect(rect.grow(-5.0), Color(BRASS, 0.55), false, 1.0)


## Cream enamel score strip inset into a plate, with a thin brass edge.
static func draw_strip(canvas: CanvasItem, rect: Rect2, fill: Color = CREAM) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, BRASS_DIM, false, 1.0)


## A held key: the same plate with its label dropped the distance a painted plate
## sinks, so a flat fallback presses the way the painted keys do.
static func held_box(fill: Color) -> StyleBoxFlat:
	var style := box(fill, BRASS_BRIGHT, 2)
	style.content_margin_top = KitPlate.PRESS_SHIFT * 2.0
	return style


static func box(fill: Color, border: Color, width: int = 2, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	return style


## Scoreboard key: racing green with brass piping. The primary key (Serve) is a
## cream enamel face with green ink; a selected toggle is cream as well.
static func style_button(button: Button, primary: bool = false) -> void:
	var face := CREAM if primary else RACING_RAISED
	var ink := CREAM_INK if primary else CREAM
	button.add_theme_stylebox_override("normal", box(face, BRASS, 2))
	button.add_theme_stylebox_override("hover", box(face.lightened(0.07), BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", held_box(face.darkened(0.18)))
	button.add_theme_stylebox_override("disabled", box(RACING_DEEP, BRASS_DIM.darkened(0.3), 1))
	for state: String in [
		"font_color", "font_hover_color", "font_focus_color", "font_pressed_color"
	]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	# Stake and risk keys wear the clubhouse's painted plate.  The large primary
	# key deliberately keeps its cream enamel face: the painted plate has a dark
	# green centre, which would leave the primary's green ink unreadable and make
	# an enabled Serve key look disabled.
	if not primary:
		UiKit.paint_button(button, &"match_point")
	# Ringed last, so the ring takes its corner from whichever face won.
	FocusRing.apply(button, 2.0)


## A toggle key shows its selected state as a cream enamel face.
static func style_toggle(button: Button, selected: bool) -> void:
	style_button(button, false)
	if not selected:
		return
	button.add_theme_stylebox_override("normal", box(CREAM, BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("hover", box(CREAM.lightened(0.05), BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", held_box(CREAM_SHADE))
	button.add_theme_stylebox_override("disabled", box(CREAM_SHADE.darkened(0.25), BRASS_DIM, 1))
	for state: String in [
		"font_color", "font_hover_color", "font_focus_color", "font_pressed_color"
	]:
		button.add_theme_color_override(state, CREAM_INK)
	button.add_theme_color_override("font_disabled_color", CREAM_INK.lightened(0.25))


static func label(parent: Node, rect: Rect2, font_size: int, color: Color = CREAM) -> Label:
	var text_label := Label.new()
	text_label.position = rect.position
	text_label.size = rect.size
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("font", Typography.UI_FONT)
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", color)
	text_label.clip_text = true
	parent.add_child(text_label)
	return text_label


static func draw_centered(
	canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color
) -> void:
	var font: Font = Typography.DISPLAY_FONT
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Court colour by multiplier: brass for the big edges, cream for a return of the
## stake or better, racing green for courts that return less than the stake.
## The painted troughs the thirteen courts are drawn with. Three faces rather
## than one plate tinted three ways: a brass edge and a green centre are
## different materials, and tinting a single plate reads as one object standing
## under coloured light instead of three different things.
const COURT_HOT := preload("res://assets/production/match_point/court_hot.png")
const COURT_MID := preload("res://assets/production/match_point/court_mid.png")
const COURT_COLD := preload("res://assets/production/match_point/court_cold.png")
## The brass-framed recess the next ball waits in.
const HATCH := preload("res://assets/production/match_point/hatch.png")


## The trough for a court paying `tenths`, on the same bands as `court_fill`.
static func court_plate(tenths: int) -> Texture2D:
	if tenths >= 50:
		return COURT_HOT
	if tenths >= 10:
		return COURT_MID
	return COURT_COLD


## The flat colour the result plaque still reads, where the cells are too small
## for a painted plate to show anything but its rim.
static func court_fill(tenths: int) -> Color:
	if tenths >= 50:
		return BRASS
	if tenths >= 10:
		return CREAM
	return RACING_RAISED


static func court_ink(tenths: int) -> Color:
	return CREAM_INK if tenths >= 10 else CREAM
