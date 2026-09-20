class_name HelpButton
extends Button
## The compact "How to play" control in every cabinet header: the game's painted
## medallion (UI kit) with a "?" drawn in code in warm ivory, a short label and the
## input that opens it (F1 keycap, Menu on Xbox, Options on PlayStation). Without a
## kit medallion it falls back to a flat brass ring. Crisp at any resolution.
##
## `text` keeps the plain label so panels that restyle the button keep working;
## the button draws its own content, so the native text stays transparent. Each
## game may restyle the plate (normal/hover/focus) through theme overrides.

const BRASS := Color("c8a34b")
const BRASS_BRIGHT := Color("f0cf73")
const IVORY := Color("f1e8d8")
const MEDALLION_FILL := Color("120e0f")
const CLEAR := Color(0, 0, 0, 0)
const SIZE := Vector2(176, 44)

var _applying: bool = false
## Theme id for the kit medallion; empty resolves it from the owning cabinet.
var theme_id: StringName = &""


func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	InputRouter.active_device_changed.connect(func(_device: int) -> void: queue_redraw())
	InputRouter.gamepad_family_changed.connect(func(_family: int) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_hide_native_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not _applying:
		_hide_native_text()


func _hide_native_text() -> void:
	_applying = true
	for state: String in [
		"font_color",
		"font_hover_color",
		"font_focus_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_outline_color",
	]:
		add_theme_color_override(state, CLEAR)
	_applying = false


## The label drawn next to the medallion (shortened on a narrow plate).
func label_text() -> String:
	return tr("HELP_BUTTON_LABEL") if size.x >= 150.0 else tr("HELP_BUTTON_SHORT")


func resolved_theme() -> StringName:
	if theme_id != &"":
		return theme_id
	var panel := get_parent() as CabinetPanel
	if panel != null and panel.cabinet != null and panel.cabinet.context != null:
		return panel.cabinet.context.definition.id
	return &""


func medallion_texture() -> Texture2D:
	return UiKit.texture(resolved_theme(), "medallion")


func _draw() -> void:
	var hovered := is_hovered() or has_focus()
	var mid := size.y * 0.5
	var radius := size.y * 0.5
	var medallion := Vector2(radius, mid)
	var painted := medallion_texture()
	var mark_ink := IVORY
	if painted != null:
		# The game's painted medallion; its empty centre carries the "?".
		var tint := Color(1.12, 1.1, 1.06) if hovered else Color.WHITE
		draw_texture_rect_region(
			painted,
			Rect2(medallion - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			UiKit.region(resolved_theme(), "medallion"),
			tint
		)
	else:
		# Flat fallback: a brass ring around a near-black coin.
		radius = minf(13.0, size.y * 0.5 - 6.0)
		medallion = Vector2(10.0 + radius, mid)
		draw_circle(medallion, radius, BRASS_BRIGHT if hovered else BRASS, true, -1.0, true)
		draw_circle(medallion, radius - 1.5, MEDALLION_FILL, true, -1.0, true)
		mark_ink = BRASS_BRIGHT if hovered else BRASS
	var display := Typography.DISPLAY_FONT
	var mark_size := int(round(radius * (0.9 if painted != null else 1.35)))
	draw_string(
		display,
		Vector2(
			medallion.x - radius,
			mid + (display.get_ascent(mark_size) - display.get_descent(mark_size)) * 0.5 - 0.5
		),
		"?",
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		mark_size,
		mark_ink
	)
	var spec := InputRouter.glyph_spec(&"help")
	var glyph_height := 18.0
	var glyph_width := InputGlyph.measure(spec, glyph_height)
	var glyph_x := size.x - 10.0 - glyph_width
	InputGlyph.draw_spec(
		self,
		spec,
		Rect2(Vector2(glyph_x, mid - glyph_height * 0.5), Vector2(glyph_width, glyph_height))
	)
	var font := Typography.UI_FONT
	var font_size := 14
	var label_x := medallion.x + radius + 10.0
	var label_width := glyph_x - 6.0 - label_x
	if label_width < 24.0:
		return
	draw_string(
		font,
		Vector2(label_x, mid + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
		label_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		label_width,
		font_size,
		IVORY
	)
