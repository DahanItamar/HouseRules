class_name InfoPlate
extends Control
## One readable information card: a small caps caption over a big value.
##
## Used for the deck's balance and anywhere a total, result or status needs a clear
## hierarchy. One accent colour per meaning (win, loss, push, accent), consistent
## padding on the 8 px grid, Barlow Condensed throughout. An optional tag pill
## ("TEST") sits beside the caption instead of a separate plate.

enum Tone { NEUTRAL, WIN, LOSS, PUSH, ACCENT }

const PADDING := Vector2(12, 6)

var style: DeckStyle = DeckStyle.casino()
var caption: String = "":
	set = set_caption
var tag: String = "":
	set = set_tag
var tone: Tone = Tone.NEUTRAL:
	set = set_tone
var caption_size: int = Typography.MICRO
var value_size: int = 26
var value_label: AnimatedNumberLabel
var _plate: KitPlate


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label = AnimatedNumberLabel.new()
	value_label.name = "Value"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_override("font", Typography.DISPLAY_FONT)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	value_label.clip_text = true
	add_child(value_label)


func _ready() -> void:
	if UiKit.has_part(style.kit_theme, "panel"):
		# The game's painted plate; caption and value sit on its flat centre.
		_plate = KitPlate.new()
		_plate.name = "InfoPlateArt"
		_plate.configure(style.kit_theme, "panel", BetControl.PLATE_SCALE)
		add_child(_plate)
		move_child(_plate, 0)
	resized.connect(_layout)
	_layout()


func set_caption(value: String) -> void:
	caption = value
	queue_redraw()


func set_tag(value: String) -> void:
	tag = value
	queue_redraw()


func set_tone(value: Tone) -> void:
	tone = value
	_layout()


func set_value(amount: int, animate: bool = true) -> void:
	value_label.set_number(amount, "%d", animate)


func set_infinite() -> void:
	value_label.set_infinity()


func _layout() -> void:
	if value_label == null:
		return
	value_label.add_theme_font_size_override("font_size", value_size)
	value_label.add_theme_color_override(
		"font_color", style.accent if tone == Tone.NEUTRAL else style.tone_color(tone)
	)
	var top := PADDING.y + Typography.DISPLAY_FONT.get_height(caption_size)
	value_label.position = Vector2(PADDING.x, top - 2.0)
	value_label.size = Vector2(maxf(size.x - PADDING.x * 2.0, 0.0), size.y - top - PADDING.y + 4.0)
	if _plate != null:
		_plate.fit(Rect2(Vector2.ZERO, size))
	queue_redraw()


func _draw() -> void:
	if _plate == null:
		draw_style_box(style.panel_box(style.inset, style.inset_edge, 1), Rect2(Vector2.ZERO, size))
	var font := Typography.UI_FONT
	var baseline := PADDING.y + font.get_ascent(caption_size)
	draw_string(
		font,
		Vector2(PADDING.x, baseline),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		caption_size,
		style.caption
	)
	if tag.is_empty():
		return
	var caption_width := (
		font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	)
	var tag_width := (
		font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.MICRO - 1).x
	)
	var pill := Rect2(
		Vector2(PADDING.x + caption_width + 6.0, PADDING.y), Vector2(tag_width + 10.0, 13.0)
	)
	draw_style_box(style.panel_box(Color(0, 0, 0, 0), style.hairline, 1, 3), pill)
	draw_string(
		font,
		Vector2(pill.position.x, pill.position.y + 10.0),
		tag,
		HORIZONTAL_ALIGNMENT_CENTER,
		pill.size.x,
		Typography.MICRO - 1,
		style.caption
	)
