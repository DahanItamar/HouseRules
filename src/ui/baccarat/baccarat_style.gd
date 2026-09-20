class_name BaccaratStyle
extends RefCounted
## Velvet Baccarat HUD language: flat violet lacquer plates with a brass rule,
## a fine pearl inlay line and four small pearl studs set in brass. Distinct from
## Ruby Roulette (mahogany, square brass studs), Blackjack (walnut and felt),
## the Elven Court slot (emerald, leaf-cut corners) and the Hexbound Vault
## (slate and silver). Cyan appears only as keyboard/controller focus.

const LACQUER := Color("27123a")
const LACQUER_DEEP := Color("170a24")
const LACQUER_RAISED := Color("3c1d55")
const PLUM := Color("5b2a70")
const BRASS := Color("c9a24e")
const BRASS_BRIGHT := Color("ecca72")
const BRASS_DIM := Color("7a5f2e")
const PEARL := Color("f1eaf3")
const PEARL_MUTED := Color("c2b5ca")
const PEARL_FAINT := Color("f1eaf340")
## Bead road and bet-spot identities; each also carries a letter, never colour alone.
const PLAYER_BLUE := Color("2f58b0")
const BANKER_RED := Color("b0293c")
const TIE_JADE := Color("1f8659")
const FOCUS := Color("48c5d5")
const WIN_INK := Color("f2cf6b")
const LOSS_INK := Color("c9bccf")
const TEXT_DISABLED := Color("6e5f78")
const INK := Color("1b1024")


## Flat lacquer plate: brass rule, pearl inlay line and four pearl studs.
static func draw_plate(canvas: CanvasItem, rect: Rect2, fill: Color = LACQUER) -> void:
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect.grow(-1.0), BRASS, false, 2.0)
	canvas.draw_rect(rect.grow(-5.0), Color(PEARL, 0.32), false, 1.0)
	for corner: Vector2 in [
		rect.position + Vector2(5, 5),
		Vector2(rect.end.x - 5.0, rect.position.y + 5.0),
		Vector2(rect.position.x + 5.0, rect.end.y - 5.0),
		rect.end - Vector2(5.0, 5.0),
	]:
		canvas.draw_circle(corner, 3.2, BRASS)
		canvas.draw_circle(corner, 2.0, PEARL)


static func box(fill: Color, border: Color, width: int = 2, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


## Lacquer key with a brass rim; the primary key is plum lacquer with pearl text.
static func style_button(button: Button, primary: bool = false) -> void:
	var face := PLUM if primary else LACQUER_RAISED
	button.add_theme_stylebox_override("normal", box(face, BRASS, 2))
	button.add_theme_stylebox_override("hover", box(face.lightened(0.08), BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("pressed", box(face.darkened(0.3), BRASS_BRIGHT, 2))
	button.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), FOCUS, 3))
	button.add_theme_stylebox_override("disabled", box(LACQUER_DEEP, BRASS_DIM.darkened(0.3), 1))
	for state: String in [
		"font_color", "font_hover_color", "font_focus_color", "font_pressed_color"
	]:
		button.add_theme_color_override(state, PEARL)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	# The table's own keys wear the same painted plate the shared deck uses, so
	# one cabinet does not mix painted keys with flat ones.
	UiKit.paint_button(button, &"baccarat", primary)


static func label(parent: Node, rect: Rect2, font_size: int, color: Color = PEARL) -> Label:
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


static func winner_color(winner: int) -> Color:
	match winner:
		BaccaratRules.Winner.PLAYER:
			return PLAYER_BLUE
		BaccaratRules.Winner.BANKER:
			return BANKER_RED
	return TIE_JADE


static func draw_centered(
	canvas: CanvasItem,
	text: String,
	center: Vector2,
	font_size: int,
	color: Color,
	font: Font = Typography.DISPLAY_FONT
) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Dresses an existing label (e.g. an InputPromptLabel that draws inline glyphs)
## in the same type as `label` builds, and parents it.
static func dress(
	text_label: Label, parent: Node, rect: Rect2, font_size: int, color: Color = PEARL
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
