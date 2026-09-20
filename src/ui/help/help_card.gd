class_name HelpCard
extends Control
## The body of every cabinet's "How to play" card.
##
## One structure for every game: GOAL in one line, HOW TO PLAY as numbered steps,
## CONTROLS as glyph rows that follow the active device, PAYOUTS as a compact
## table, and a footer with the close hint and page controls. Long content pages
## instead of cramming; a page change slides (instant under reduced motion).
##
## Content is a Dictionary:
##   {"goal": String, "steps": Array[String], "controls": Array[String],
##    "payouts": Array[[label, value]], "payout_caption": String, "notes": Array[String]}
## Steps and controls may carry input tokens such as `{interact}`.

signal page_changed(page: int)

const BRASS := Color("c8a34b")
const BRASS_BRIGHT := Color("f0cf73")
const IVORY := Color("f1e8d8")
const MUTED := Color("b8ad9c")
const HAIRLINE := Color("4a3b22")
const DISC_INK := Color("17120f")
const BODY_HEIGHT: float = 284.0
const LEFT_X: float = 32.0
const LEFT_WIDTH: float = 318.0
const RIGHT_X: float = 378.0
const RIGHT_WIDTH: float = 210.0
const FOOTER_Y: float = 290.0
const GLYPH_COLUMN: float = 70.0
const CAPTION_HEIGHT: float = 26.0
const CONTROL_HEIGHT: float = 30.0
const PAYOUT_HEIGHT: float = 26.0

var page: int = 0
var _content: Dictionary = {}
var _pages: Array = []
var _page_root: Control
var _page_tween: Tween
var _footer_hint: InputPromptLabel
var _page_label: Label
var _previous: Button
var _next: Button


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2(620, 334)
	_page_root = Control.new()
	_page_root.name = "HelpPage"
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.size = Vector2(size.x, BODY_HEIGHT)
	add_child(_page_root)
	_footer_hint = InputPromptLabel.new()
	_footer_hint.name = "HelpFooterHint"
	_footer_hint.position = Vector2(LEFT_X, FOOTER_Y + 4.0)
	_footer_hint.size = Vector2(300, 40)
	_footer_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_hint.add_theme_font_override("font", Typography.UI_FONT)
	_footer_hint.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	_footer_hint.add_theme_color_override("font_color", MUTED)
	add_child(_footer_hint)
	_previous = _pager_button("HelpPagePrevious", String.chr(0x2039), -1)
	_previous.position = Vector2(470, FOOTER_Y)
	_next = _pager_button("HelpPageNext", String.chr(0x203A), 1)
	_next.position = Vector2(size.x - 32.0 - 44.0, FOOTER_Y)
	_page_label = Label.new()
	_page_label.name = "HelpPageLabel"
	_page_label.position = Vector2(514, FOOTER_Y)
	_page_label.size = Vector2(30, 44)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_page_label.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	_page_label.add_theme_color_override("font_color", IVORY)
	add_child(_page_label)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


func _pager_button(node_name: String, glyph: String, direction: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = glyph
	button.size = Vector2(44, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color("5c554d"))
	for entry: Array in [
		["normal", Color("1d191b"), Color("6e5225"), 1],
		["hover", Color("2a2225"), BRASS_BRIGHT, 1],
		["pressed", Color("120f10"), BRASS_BRIGHT, 1],
		["disabled", Color("151214"), Color("2e2821"), 1],
	]:
		var style := StyleBoxFlat.new()
		style.bg_color = entry[1]
		style.border_color = entry[2]
		style.set_border_width_all(entry[3])
		style.set_corner_radius_all(6)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(entry[0], style)
	button.add_theme_stylebox_override("focus", FocusRing.style(6.0))
	button.pressed.connect(func() -> void: step_page(direction))
	add_child(button)
	ButtonFeedback.attach(button)
	return button


## Replaces the content. The current page is kept when it still exists.
func set_content(content: Dictionary) -> void:
	_content = content
	_pages = _paginate(content)
	page = clampi(page, 0, maxi(_pages.size() - 1, 0))
	_render()


func page_count() -> int:
	return maxi(_pages.size(), 1)


func reset_page() -> void:
	if page != 0:
		page = 0
		_render()


## Moves one page; returns false at either end.
func step_page(direction: int) -> bool:
	var next := clampi(page + signi(direction), 0, page_count() - 1)
	if next == page:
		return false
	page = next
	_render()
	AudioService.play(&"move")
	page_changed.emit(page)
	if MotionPolicy.is_reduced() or not is_inside_tree():
		return true
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_root.position.x = 22.0 * signi(direction)
	_page_root.modulate.a = 0.0
	_page_tween = create_tween().set_parallel(true)
	(
		_page_tween
		. tween_property(_page_root, "position:x", 0.0, 0.18)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_page_tween.tween_property(_page_root, "modulate:a", 1.0, 0.14)
	return true


## Every glyph template on the visible page (tests and previews).
func visible_templates() -> Array[String]:
	var templates: Array[String] = []
	for node: Node in _page_root.find_children("*", "InputPromptLabel", true, false):
		templates.append((node as InputPromptLabel).template)
	return templates


func footer_hint() -> InputPromptLabel:
	return _footer_hint


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced and _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
		_page_tween = null
		_page_root.position = Vector2.ZERO
		_page_root.modulate.a = 1.0


func _render() -> void:
	if _page_root == null:
		return
	for child: Node in _page_root.get_children():
		_page_root.remove_child(child)
		child.queue_free()
	_page_root.position = Vector2.ZERO
	_page_root.modulate.a = 1.0
	if not _pages.is_empty():
		var current: Dictionary = _pages[page]
		_render_column(current.left, LEFT_X, LEFT_WIDTH)
		_render_column(current.right, RIGHT_X, RIGHT_WIDTH)
	var many := page_count() > 1
	_previous.visible = many
	_next.visible = many
	_page_label.visible = many
	_previous.disabled = page == 0
	_next.disabled = page >= page_count() - 1
	_page_label.text = tr("HELP_PAGE") % [page + 1, page_count()]
	_footer_hint.template = tr("HELP_FOOTER_PAGED") if many else tr("HELP_FOOTER")


func _render_column(blocks: Array, x: float, width: float) -> void:
	var y := 0.0
	for block: Dictionary in blocks:
		y += _render_block(block, Vector2(x, y), width)


func _render_block(block: Dictionary, at: Vector2, width: float) -> float:
	match String(block.type):
		"caption":
			var caption := _label(String(block.text), at, Vector2(width, 18), 12, BRASS, true)
			caption.name = "HelpCaption"
			var rule := ColorRect.new()
			rule.color = HAIRLINE
			rule.position = at + Vector2(0, 19)
			rule.size = Vector2(width, 1)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_page_root.add_child(rule)
			return CAPTION_HEIGHT
		"goal":
			var height := _text_height(String(block.text), width, 17)
			var goal := _prompt(String(block.text), at, Vector2(width, height), 17, IVORY)
			goal.name = "HelpGoal"
			return height + 12.0
		"step":
			var text_width := width - 30.0
			var height := maxf(20.0, _text_height(String(block.text), text_width, 15))
			var disc := StepDisc.new()
			disc.number = int(block.number)
			disc.position = at + Vector2(0, 1)
			disc.size = Vector2(20, 20)
			_page_root.add_child(disc)
			var step := _prompt(
				String(block.text), at + Vector2(30, 0), Vector2(text_width, height), 15, IVORY
			)
			step.name = "HelpStep%d" % int(block.number)
			return height + 8.0
		"control":
			var glyphs := GlyphRow.new()
			glyphs.name = "HelpControlGlyph"
			glyphs.template = String(block.glyphs)
			glyphs.position = at
			glyphs.size = Vector2(GLYPH_COLUMN - 10.0, CONTROL_HEIGHT)
			_page_root.add_child(glyphs)
			var label := _prompt(
				String(block.label),
				at + Vector2(GLYPH_COLUMN, 0),
				Vector2(width - GLYPH_COLUMN, CONTROL_HEIGHT),
				15,
				IVORY
			)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			return CONTROL_HEIGHT
		"payout":
			var value_width := minf(
				width * 0.5,
				(
					(
						Typography
						. DISPLAY_FONT
						. get_string_size(String(block.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
						. x
					)
					+ 8.0
				)
			)
			var name_label := _label(
				String(block.label),
				at,
				Vector2(width - value_width, PAYOUT_HEIGHT),
				15,
				IVORY,
				false
			)
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var value := _label(
				String(block.value),
				at + Vector2(width - value_width, 0),
				Vector2(value_width, PAYOUT_HEIGHT),
				15,
				BRASS_BRIGHT,
				true
			)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var rule := ColorRect.new()
			rule.color = Color(HAIRLINE, 0.7)
			rule.position = at + Vector2(0, PAYOUT_HEIGHT - 1.0)
			rule.size = Vector2(width, 1)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_page_root.add_child(rule)
			return PAYOUT_HEIGHT
		"note":
			var height := _text_height(String(block.text), width, 14)
			_prompt(String(block.text), at, Vector2(width, height), 14, MUTED)
			return height + 8.0
	return 0.0


func _label(
	value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, display: bool
) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(label)
	return label


func _prompt(
	template: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color
) -> InputPromptLabel:
	var label := InputPromptLabel.new()
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", Typography.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 1)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(label)
	label.template = template
	return label


static func _text_height(template: String, width: float, font_size: int) -> float:
	# Glyph tokens are measured as short words; the card leaves slack for them.
	var plain := template
	var pattern := RegEx.create_from_string("\\[?\\{[a-z_]+\\}\\]?")
	plain = pattern.sub(plain, "WWW", true)
	var size := Typography.UI_FONT.get_multiline_string_size(
		plain, HORIZONTAL_ALIGNMENT_LEFT, width, font_size
	)
	return ceilf(size.y + font_size * 0.15)


static func _block_height(block: Dictionary, width: float) -> float:
	match String(block.type):
		"caption":
			return CAPTION_HEIGHT
		"goal":
			return _text_height(String(block.text), width, 17) + 12.0
		"step":
			return maxf(20.0, _text_height(String(block.text), width - 30.0, 15)) + 8.0
		"control":
			return CONTROL_HEIGHT
		"payout":
			return PAYOUT_HEIGHT
		"note":
			return _text_height(String(block.text), width, 14) + 8.0
	return 0.0


## Splits the content into pages of two columns that never overflow.
func _paginate(content: Dictionary) -> Array:
	var left: Array = []
	if not String(content.get("goal", "")).is_empty():
		left.append({"type": "caption", "text": tr("HELP_GOAL")})
		left.append({"type": "goal", "text": content.goal})
	var steps: Array = content.get("steps", [])
	if not steps.is_empty():
		left.append({"type": "caption", "text": tr("HELP_STEPS")})
		for index: int in range(steps.size()):
			left.append({"type": "step", "number": index + 1, "text": steps[index]})
	var right: Array = []
	var controls: Array = content.get("controls", [])
	if not controls.is_empty():
		right.append({"type": "caption", "text": tr("HELP_CONTROLS")})
		for template: String in controls:
			right.append(_control_block(template))
	var extra: Array = []
	var payouts: Array = content.get("payouts", [])
	if not payouts.is_empty():
		extra.append({"type": "caption", "text": content.get("payout_caption", tr("HELP_PAYOUTS"))})
		for row: Array in payouts:
			extra.append({"type": "payout", "label": row[0], "value": row[1]})
	var notes: Array = content.get("notes", [])
	if not notes.is_empty():
		extra.append({"type": "caption", "text": tr("HELP_NOTES")})
		for note: String in notes:
			extra.append({"type": "note", "text": note})
	var left_columns := _fill_columns(left, LEFT_WIDTH, tr("HELP_STEPS"))
	var right_columns := _fill_columns(right, RIGHT_WIDTH, tr("HELP_CONTROLS"))
	var pages: Array = []
	var count := maxi(left_columns.size(), right_columns.size())
	for index: int in range(count):
		(
			pages
			. append(
				{
					"left": left_columns[index] if index < left_columns.size() else [],
					"right": right_columns[index] if index < right_columns.size() else [],
				}
			)
		)
	if not extra.is_empty():
		# Payouts take the first free column after the rules, else a new page.
		var placed := false
		for entry: Dictionary in pages:
			if (
				(entry.right as Array).is_empty()
				and _column_height(extra, RIGHT_WIDTH) <= BODY_HEIGHT
			):
				entry.right = extra
				placed = true
				break
		if not placed:
			for column: Array in _fill_columns(extra, LEFT_WIDTH, tr("HELP_PAYOUTS")):
				pages.append({"left": column, "right": []})
	if pages.is_empty():
		pages.append({"left": [], "right": []})
	return pages


func _control_block(template: String) -> Dictionary:
	# Leading tokens form the glyph column; the rest is the label.
	var pattern := RegEx.create_from_string("^(\\s*\\[?\\{[a-z_]+\\}\\]?\\s*)+")
	var found := pattern.search(template)
	if found == null:
		return {"type": "control", "glyphs": "", "label": template}
	return {
		"type": "control",
		"glyphs": found.get_string().strip_edges(),
		"label": template.substr(found.get_end()).strip_edges(),
	}


func _fill_columns(blocks: Array, width: float, continued_caption: String) -> Array:
	var columns: Array = []
	var column: Array = []
	var used := 0.0
	for block: Dictionary in blocks:
		var height := _block_height(block, width)
		var is_caption := String(block.type) == "caption"
		if not column.is_empty() and used + height > BODY_HEIGHT:
			columns.append(column)
			column = [{"type": "caption", "text": continued_caption}]
			used = CAPTION_HEIGHT
		if is_caption and not column.is_empty() and used + height + 30.0 > BODY_HEIGHT:
			# Never leave a caption alone at the foot of a column.
			columns.append(column)
			column = []
			used = 0.0
		column.append(block)
		used += height
	if not column.is_empty():
		columns.append(column)
	return columns


static func _column_height(blocks: Array, width: float) -> float:
	var total := 0.0
	for block: Dictionary in blocks:
		total += _block_height(block, width)
	return total


## Right-aligned input glyphs for one controls row, e.g. "{bet_down}{bet_up}".
class GlyphRow:
	extends Control

	const GLYPH_HEIGHT: float = 19.0
	const GAP: float = 3.0

	var template: String = ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		InputRouter.active_device_changed.connect(func(_device: int) -> void: queue_redraw())
		InputRouter.gamepad_family_changed.connect(func(_family: int) -> void: queue_redraw())

	func actions() -> Array[StringName]:
		var found: Array[StringName] = []
		var pattern := RegEx.create_from_string("\\{([a-z_]+)\\}")
		for match_result: RegExMatch in pattern.search_all(template):
			found.append(StringName(match_result.get_string(1)))
		return found

	func _draw() -> void:
		var x := size.x
		var specs: Array = []
		for action: StringName in actions():
			specs.append(InputRouter.glyph_spec(action))
		for index: int in range(specs.size() - 1, -1, -1):
			var width := InputGlyph.measure(specs[index], GLYPH_HEIGHT)
			x -= width
			InputGlyph.draw_spec(
				self,
				specs[index],
				Rect2(Vector2(x, (size.y - GLYPH_HEIGHT) * 0.5), Vector2(width, GLYPH_HEIGHT))
			)
			x -= GAP


## A brass disc carrying a step number.
class StepDisc:
	extends Control

	var number: int = 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, size.x * 0.5, HelpCard.BRASS, true, -1.0, true)
		var font := Typography.DISPLAY_FONT
		var font_size := 13
		draw_string(
			font,
			Vector2(0, center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
			str(number),
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			font_size,
			HelpCard.DISC_INK
		)
