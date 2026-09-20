class_name RouletteStyle
extends RefCounted
## Ruby Salon HUD language: flat mahogany plates, a brass rule and a fine ivory
## inlay line with small square brass studs. Distinct from the Elven Court
## (emerald, leaf-cut corners), Blackjack (walnut and felt) and Hexbound Vault
## (slate and silver) cabinets. Cyan appears only as keyboard/controller focus.

const MAHOGANY := Color("24100c")
const MAHOGANY_DEEP := Color("170907")
const MAHOGANY_RAISED := Color("3a1912")
const BRASS := Color("c9a24e")
const BRASS_BRIGHT := Color("ecca72")
const BRASS_DIM := Color("7a5f2e")
const IVORY := Color("f1e8d4")
const IVORY_MUTED := Color("bcae94")
const IVORY_FAINT := Color("f1e8d438")
const RUBY := Color("a8202c")
const RUBY_DEEP := Color("6d101b")
const EBONY := Color("15100e")
const ZERO_GREEN := Color("13704a")
const LAYOUT_CLOTH := Color("0a1638d9")
const FOCUS := Color("48c5d5")
const WIN_INK := Color("f2cf6b")
const LOSS_INK := Color("c9b9a6")
const TEXT_DISABLED := Color("6f6254")


## Flat plate with a brass rule, an ivory inlay line and four brass studs.
static func draw_plate(canvas: CanvasItem, rect: Rect2, fill: Color = MAHOGANY) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect.grow(-1.0), BRASS, false, 2.0)
	canvas.draw_rect(rect.grow(-5.0), Color(IVORY, 0.30), false, 1.0)
	for corner: Vector2 in [
		rect.position,
		Vector2(rect.end.x - 5.0, rect.position.y),
		Vector2(rect.position.x, rect.end.y - 5.0),
		rect.end - Vector2(5.0, 5.0),
	]:
		canvas.draw_rect(Rect2(corner, Vector2(5, 5)), BRASS_BRIGHT)


static func box(fill: Color, border: Color, width: int = 2, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


## Mahogany key with a brass rim; the primary key is ruby lacquer.
static func style_button(button: Button, primary: bool = false) -> void:
	var face := RUBY_DEEP if primary else MAHOGANY_RAISED
	button.add_theme_stylebox_override("normal", box(face, BRASS, 2))
	button.add_theme_stylebox_override("hover", box(face.lightened(0.08), BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", box(face.darkened(0.3), BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), FOCUS, 3))
	button.add_theme_stylebox_override("disabled", box(MAHOGANY_DEEP, BRASS_DIM.darkened(0.3), 1))
	for state: String in [
		"font_color", "font_hover_color", "font_focus_color", "font_pressed_color"
	]:
		button.add_theme_color_override(state, IVORY)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 18)


static func label(parent: Node, rect: Rect2, font_size: int, color: Color = IVORY) -> Label:
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


static func pocket_color(number: int, math: RouletteMath) -> Color:
	if number == 0:
		return ZERO_GREEN
	return RUBY if math.is_red(number) else EBONY


static func draw_centered(
	canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color
) -> void:
	var font: Font = Typography.DISPLAY_FONT
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Dresses an existing label (e.g. an InputPromptLabel that draws inline glyphs)
## in the same type as `label` builds, and parents it.
static func dress(
	text_label: Label, parent: Node, rect: Rect2, font_size: int, color: Color = IVORY
) -> Label:
	text_label.position = rect.position
	text_label.size = rect.size
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("font", Typography.UI_FONT)
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", color)
	text_label.clip_text = true
	parent.add_child(text_label)
	return text_label
