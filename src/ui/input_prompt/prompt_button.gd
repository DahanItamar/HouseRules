class_name PromptButton
extends Button
## A button that shows the input that presses it: "(A) DEAL", "MAIN FLOOR (B)".
##
## `text` keeps the plain label (tests, accessibility, `_set_live_text`); the button
## draws the glyph and label itself as one centred group, so the native text is
## kept transparent. The glyph follows the active device and pad family live.
## Micro-interactions come from ButtonFeedback (hover/focus lift, press squash).

enum GlyphSide { LEFT, RIGHT }

const CLEAR := Color(0, 0, 0, 0)

## The action whose glyph is shown; empty shows the label alone.
var action: StringName = &"":
	set = set_action
var glyph_side: GlyphSide = GlyphSide.LEFT
## Glyph height as a multiple of the label's font size.
var glyph_scale: float = 1.3
var gap: float = 8.0
var ink := Color("f1e8d8")
var ink_disabled := Color("756d62")
## Hides the glyph (e.g. while the pointer is the active device on a tiny button).
var show_glyph: bool = true:
	set = set_show_glyph
var _applying: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	InputRouter.active_device_changed.connect(_on_prompts_changed)
	InputRouter.gamepad_family_changed.connect(_on_prompts_changed)
	_hide_native_text()
	queue_redraw()


func set_action(value: StringName) -> void:
	action = value
	queue_redraw()


func set_show_glyph(value: bool) -> void:
	show_glyph = value
	queue_redraw()


func glyph_spec() -> Dictionary:
	return InputRouter.glyph_spec(action)


## "[Enter] DEAL": the plain-text form of what the button shows.
func plain_text() -> String:
	if action == &"" or not show_glyph:
		return text
	return "[%s] %s" % [InputRouter.glyph(String(action)), text]


func _on_prompts_changed(_value: int) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not _applying:
		var requested := get_theme_color("font_color")
		if requested.a > 0.0:
			ink = requested
		var requested_disabled := get_theme_color("font_disabled_color")
		if requested_disabled.a > 0.0:
			ink_disabled = requested_disabled
		_hide_native_text()


func _hide_native_text() -> void:
	if _applying:
		return
	_applying = true
	for state: String in [
		"font_color",
		"font_hover_color",
		"font_focus_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_disabled_color",
		"font_outline_color",
	]:
		add_theme_color_override(state, CLEAR)
	_applying = false


func _draw() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var color := ink_disabled if disabled else ink
	var label_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var has_glyph := action != &"" and show_glyph
	var glyph_height := roundf(font_size * glyph_scale)
	var spec := glyph_spec() if has_glyph else {}
	var glyph_width := InputGlyph.measure(spec, glyph_height) if has_glyph else 0.0
	var spacing := gap if has_glyph and not text.is_empty() else 0.0
	var group := glyph_width + spacing + label_width
	var available := size.x - 12.0
	if group > available and has_glyph:
		# Narrow button: keep the glyph and let the label trim.
		label_width = maxf(available - glyph_width - spacing, 0.0)
		group = available
	var x := (size.x - group) * 0.5
	# This button hides its native text and draws the group itself, so the content
	# margin that sinks an ordinary label cannot reach it: it follows the plate down.
	var sunk := KitPlate.PRESS_SHIFT if get_draw_mode() == DRAW_PRESSED else 0.0
	var mid := size.y * 0.5 + sunk
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := mid + (ascent - descent) * 0.5
	var label_x := x
	if has_glyph:
		var glyph_x := x if glyph_side == GlyphSide.LEFT else x + label_width + spacing
		label_x = x + glyph_width + spacing if glyph_side == GlyphSide.LEFT else x
		var glyph_rect := Rect2(
			Vector2(glyph_x, mid - glyph_height * 0.5), Vector2(glyph_width, glyph_height)
		)
		InputGlyph.draw_spec(self, spec, glyph_rect)
	if not text.is_empty():
		draw_string(
			font,
			Vector2(label_x, baseline),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			label_width + 1.0,
			font_size,
			color
		)
