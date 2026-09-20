class_name DeckStyle
extends Resource
## Per-game skin for the shared CabinetDeck, BetControl and InfoPlate.
##
## Every cabinet uses the same deck structure; only these colours and materials
## change. Surfaces are flat and opaque (no gradients, glow or bloom), text is warm
## off-white, structure is brass, and cyan is reserved for keyboard/controller
## focus. Result accents carry one meaning each: win, loss, push.

## Deck plate and instruction rail.
@export var surface := Color("17120f")
@export var edge := Color("c8a34b")
@export var hairline := Color("6e5428")
## Inset plates (balance, bet) sitting inside the deck.
@export var inset := Color("0f0c0b")
@export var inset_edge := Color("5a4626")
## Small caps captions and secondary copy.
@export var caption := Color("b8aa97")
## Big values and button labels.
@export var value := Color("f5ecd9")
## Balance numerals and brass accents.
@export var accent := Color("e7c35d")
@export var primary_face := Color("5a111c")
@export var primary_edge := Color("c8a34b")
@export var secondary_face := Color("211a1b")
@export var secondary_edge := Color("8a6d36")
@export var edge_bright := Color("f0cf73")
@export var text_disabled := Color("6f6558")
@export var win := Color("f2c84b")
@export var loss := Color("d27a6c")
@export var push := Color("f1e8d8")
@export var focus := Color("48c5d5")
@export var corner_radius: int = 6
## The painted chip stack the bet control shows beside the stake.
@export var chip_texture: Texture2D = preload("res://assets/production/ui/hud_chip_stack.png")
## UI kit theme id for painted plates (see UiKit); empty keeps flat plates.
@export var kit_theme: StringName = &""
## Canvas pixels per source pixel for the painted deck panel and button plates.
@export var panel_scale: float = 0.16
@export var button_scale: float = 0.18


## Blackjack salon: walnut deck, felt-green primary key, brass structure.
static func blackjack() -> DeckStyle:
	var style := DeckStyle.new()
	style.surface = Color("1d130d")
	style.edge = Color("c8a34b")
	style.hairline = Color("6b4f25")
	style.inset = Color("130c08")
	style.inset_edge = Color("5b4424")
	style.primary_face = Color("135a40")
	style.primary_edge = Color("d6b25a")
	style.secondary_face = Color("2a1a11")
	style.secondary_edge = Color("9a7535")
	style.kit_theme = &"blackjack"
	# The same painted stack the dealer places on the felt.
	style.chip_texture = BlackjackBetStack.CHIP_TEXTURE
	return style


## Neutral casino skin for cabinets without a themed deck yet.
static func casino() -> DeckStyle:
	return DeckStyle.new()


## The casino skin wearing one cabinet's painted kit, so every game shows the same
## controls in its own materials. An id with no kit falls back to flat plates.
static func for_theme(theme_id: StringName) -> DeckStyle:
	if theme_id == &"blackjack":
		return blackjack()
	var style := DeckStyle.new()
	if UiKit.THEMES.has(theme_id):
		style.kit_theme = theme_id
	return style


func panel_box(fill: Color, border: Color, border_width: int = 1, radius: int = -1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner_radius if radius < 0 else radius)
	box.anti_aliasing = true
	return box


## Applies the shared button states: hover brightens the brass edge, pressed
## darkens the face, focus is the only place cyan appears.
func style_button(button: Button, face: Color, border: Color, primary: bool) -> void:
	var width := 2 if primary else 1
	button.add_theme_stylebox_override("normal", panel_box(face, border, width))
	button.add_theme_stylebox_override(
		"hover", panel_box(face.lightened(0.06), edge_bright, width + (0 if primary else 1))
	)
	button.add_theme_stylebox_override(
		"pressed", panel_box(face.darkened(0.22), edge_bright, width)
	)
	button.add_theme_stylebox_override(
		"hover_pressed", panel_box(face.darkened(0.22), edge_bright, width)
	)
	button.add_theme_stylebox_override("focus", panel_box(Color(0, 0, 0, 0), focus, 3))
	button.add_theme_stylebox_override("disabled", panel_box(surface, hairline, 1))
	button.add_theme_color_override("font_color", value)
	button.add_theme_color_override("font_disabled_color", text_disabled)


## Skins a button: flat states, or the kit's painted plate behind it when the
## theme has one. The plate brightens on hover and darkens on press; the cyan
## focus ring stays the only focus cue and appears for keyboard/controller only.
func skin_button(
	button: Button, face: Color, border: Color, primary: bool, plate_scale: float = -1.0
) -> void:
	style_button(button, face, border, primary)
	if not UiKit.has_part(kit_theme, "button"):
		return
	var plate := KitPlate.new()
	plate.name = "KitPlate"
	if not plate.configure(kit_theme, "button", button_scale if plate_scale < 0.0 else plate_scale):
		return
	plate.show_behind_parent = true
	plate.base_tint = Color.WHITE if primary else Color(0.84, 0.84, 0.84)
	button.add_child(plate)
	button.move_child(plate, 0)
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	var sync := func() -> void:
		plate.fit(Rect2(Vector2.ZERO, button.size))
		plate.set_state(plate_state(button))
	button.resized.connect(sync)
	button.draw.connect(sync)
	sync.call()


static func plate_state(button: BaseButton) -> KitPlate.State:
	if button.disabled:
		return KitPlate.State.DISABLED
	match button.get_draw_mode():
		BaseButton.DRAW_PRESSED:
			return KitPlate.State.PRESSED
		BaseButton.DRAW_HOVER, BaseButton.DRAW_HOVER_PRESSED:
			return KitPlate.State.HOVER
	return KitPlate.State.NORMAL


func tone_color(tone: int) -> Color:
	match tone:
		InfoPlate.Tone.WIN:
			return win
		InfoPlate.Tone.LOSS:
			return loss
		InfoPlate.Tone.PUSH:
			return push
		InfoPlate.Tone.ACCENT:
			return accent
	return value
