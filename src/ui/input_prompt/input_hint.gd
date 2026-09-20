class_name InputHint
extends Control
## A glyph plus a short label, e.g. "(A) Deal". Follows the active device and pad
## family live. Presentation only; it never reads or changes game state.

@export var action: StringName = &"interact":
	set = set_action
@export var label: String = "":
	set = set_label
@export var font_size: int = Typography.SUPPORTING:
	set = set_font_size
@export var ink: Color = Color("f1e8d8"):
	set = set_ink
## Glyph height as a multiple of the font size.
var glyph_scale: float = 1.3
var gap: float = 6.0
var font: Font = Typography.UI_FONT


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	InputRouter.active_device_changed.connect(_on_prompts_changed)
	InputRouter.gamepad_family_changed.connect(_on_prompts_changed)
	_refresh()


func set_action(value: StringName) -> void:
	action = value
	_refresh()


func set_label(value: String) -> void:
	label = value
	_refresh()


func set_font_size(value: int) -> void:
	font_size = value
	_refresh()


func set_ink(value: Color) -> void:
	ink = value
	queue_redraw()


func glyph_height() -> float:
	return roundf(font_size * glyph_scale)


func glyph_spec() -> Dictionary:
	return InputRouter.glyph_spec(action)


## Plain-text form ("[Enter] Deal") for tests, logs and screen readers.
func plain_text() -> String:
	var prompt := "[%s]" % InputRouter.glyph(String(action))
	return prompt if label.is_empty() else "%s %s" % [prompt, label]


func _on_prompts_changed(_value: int) -> void:
	_refresh()


func _refresh() -> void:
	var glyph_width := InputGlyph.measure(glyph_spec(), glyph_height())
	var text_width := 0.0
	if not label.is_empty():
		text_width = gap + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(
		ceilf(glyph_width + text_width), maxf(glyph_height(), font.get_height(font_size))
	)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var spec := glyph_spec()
	var height := glyph_height()
	var glyph_width := InputGlyph.measure(spec, height)
	InputGlyph.draw_spec(
		self, spec, Rect2(Vector2(0, (size.y - height) * 0.5), Vector2(glyph_width, height))
	)
	if label.is_empty():
		return
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	draw_string(
		font,
		Vector2(glyph_width + gap, (size.y + ascent - descent) * 0.5),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ink
	)
