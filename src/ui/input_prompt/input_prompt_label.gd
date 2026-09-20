class_name InputPromptLabel
extends Label
## A Label whose text carries input prompts drawn as glyphs inline with the words.
##
## Set `template` instead of `text`. `{interact}` draws that action's glyph for the
## active device; `[{interact}]` does the same, so a legacy "[%s] Join" string can be
## formatted with a token and still read cleanly. `text` always holds the plain
## fallback ("[Enter] Join") for tests, logs and accessibility; the native text is
## hidden only while glyphs are drawn. Supports alignment, word wrap and the
## Label's `visible_characters` reveal (a glyph counts as its fallback's length).

const TOKEN_PATTERN := "\\[\\{([a-z_]+)\\}\\]|\\{([a-z_]+)\\}"
const CLEAR := Color(0, 0, 0, 0)
## Horizontal breathing room either side of an inline glyph.
const GLYPH_PAD: float = 2.0

var template: String = "":
	set = set_template
## Glyph height as a multiple of the font size.
var glyph_scale: float = 1.25
var _regex := RegEx.new()
var _paragraphs: Array = []
var _has_glyphs: bool = false
var _hiding_native: bool = false
var _applying: bool = false
var _ink := Color("f1e8d8")


func _init() -> void:
	_regex.compile(TOKEN_PATTERN)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	InputRouter.active_device_changed.connect(_on_prompts_changed)
	InputRouter.gamepad_family_changed.connect(_on_prompts_changed)
	resized.connect(queue_redraw)
	_rebuild()


## A token for `action`, for building templates in code.
static func token(action: StringName) -> String:
	return "{%s}" % action


## Formats a legacy "[%s]" key with tokens instead of glyph text.
static func tokens(actions: Array) -> Array:
	return actions.map(func(action: Variant) -> String: return "{%s}" % action)


func set_template(value: String) -> void:
	template = value
	_rebuild()


func has_glyphs() -> bool:
	return _has_glyphs


## The glyph actions in reading order (tests and previews).
func glyph_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for runs: Array in _paragraphs:
		for run: Dictionary in runs:
			if run.glyph:
				actions.append(run.action)
	return actions


func ink() -> Color:
	return _ink if _hiding_native else get_theme_color("font_color")


func _on_prompts_changed(_value: int) -> void:
	_rebuild()


func _rebuild() -> void:
	_paragraphs.clear()
	var fallback_lines: PackedStringArray = []
	var any_glyph := false
	for paragraph: String in template.split("\n"):
		var runs: Array = []
		var fallback := ""
		var cursor := 0
		for found: RegExMatch in _regex.search_all(paragraph):
			var bracketed := not found.get_string(1).is_empty()
			var action := StringName(found.get_string(1) if bracketed else found.get_string(2))
			if action == &"":
				continue
			if not InputRouter.has_prompt(action):
				continue
			if found.get_start() > cursor:
				var before := paragraph.substr(cursor, found.get_start() - cursor)
				runs.append({"glyph": false, "text": before})
				fallback += before
			# The plain fallback always brackets the input, e.g. "[Enter] Deal".
			var plain := "[%s]" % InputRouter.glyph(String(action))
			runs.append({"glyph": true, "action": action, "fallback": plain})
			fallback += plain
			any_glyph = true
			cursor = found.get_end()
		if cursor < paragraph.length():
			runs.append({"glyph": false, "text": paragraph.substr(cursor)})
			fallback += paragraph.substr(cursor)
		_paragraphs.append(runs)
		fallback_lines.append(fallback)
	_has_glyphs = any_glyph
	text = "\n".join(fallback_lines)
	_sync_native_text()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _hiding_native and not _applying:
		# A caller restyled the label: adopt its colour, keep the native text hidden.
		var requested := get_theme_color("font_color")
		if requested.a > 0.0:
			_ink = requested
			_sync_native_text()


func _sync_native_text() -> void:
	if _applying:
		return
	_applying = true
	if _has_glyphs:
		if not _hiding_native:
			_ink = get_theme_color("font_color")
		add_theme_color_override("font_color", CLEAR)
		add_theme_color_override("font_shadow_color", CLEAR)
		add_theme_color_override("font_outline_color", CLEAR)
		_hiding_native = true
	elif _hiding_native:
		add_theme_color_override("font_color", _ink)
		remove_theme_color_override("font_shadow_color")
		remove_theme_color_override("font_outline_color")
		_hiding_native = false
	_applying = false


func _draw() -> void:
	if not _has_glyphs:
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var spacing := float(get_theme_constant("line_spacing"))
	var text_height := font.get_height(font_size)
	var line_height := text_height + spacing
	var glyph_height := roundf(font_size * glyph_scale)
	var lines := _layout(font, font_size, glyph_height)
	var total := lines.size() * line_height - spacing
	var top := 0.0
	match vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			top = (size.y - total) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			top = size.y - total
	var budget := INF if visible_characters < 0 else float(visible_characters)
	var ascent := font.get_ascent(font_size)
	for line: Dictionary in lines:
		var x := 0.0
		match horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x = (size.x - float(line.width)) * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:
				x = size.x - float(line.width)
		var mid := top + text_height * 0.5
		for item: Dictionary in line.items:
			if budget <= 0.0:
				return
			if item.glyph:
				var fallback_length := String(item.fallback).length()
				if budget < fallback_length:
					return
				budget -= fallback_length
				var spec: Dictionary = item.spec
				InputGlyph.draw_spec(
					self,
					spec,
					Rect2(
						Vector2(x + GLYPH_PAD, mid - glyph_height * 0.5),
						Vector2(InputGlyph.measure(spec, glyph_height), glyph_height)
					)
				)
			else:
				var shown: String = item.text
				if budget < shown.length():
					shown = shown.substr(0, int(budget))
				budget -= shown.length()
				draw_string(
					font,
					Vector2(x, top + ascent),
					shown,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					_ink
				)
			x += float(item.width)
		budget -= 1.0
		top += line_height


## Lays the runs out into lines of measured items, wrapping on spaces when the
## label autowraps.
func _layout(font: Font, font_size: int, glyph_height: float) -> Array:
	var wrap := autowrap_mode != TextServer.AUTOWRAP_OFF and size.x > 1.0
	var lines: Array = []
	for runs: Array in _paragraphs:
		var items: Array = []
		for run: Dictionary in runs:
			if run.glyph:
				var spec: Dictionary = InputRouter.glyph_spec(run.action)
				(
					items
					. append(
						{
							"glyph": true,
							"spec": spec,
							"fallback": run.fallback,
							"width": InputGlyph.measure(spec, glyph_height) + GLYPH_PAD * 2.0,
						}
					)
				)
				continue
			var words: Array = [run.text] if not wrap else _split_words(String(run.text))
			for word: String in words:
				(
					items
					. append(
						{
							"glyph": false,
							"text": word,
							"width":
							font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
						}
					)
				)
		var line: Dictionary = {"items": [], "width": 0.0}
		for item: Dictionary in items:
			var starts_word: bool = item.glyph or not String(item.text).begins_with(" ")
			if (
				wrap
				and starts_word
				and not (line.items as Array).is_empty()
				and float(line.width) + float(item.width) > size.x
			):
				lines.append(_trim_line(line, font, font_size))
				line = {"items": [], "width": 0.0}
			(line.items as Array).append(item)
			line.width = float(line.width) + float(item.width)
		lines.append(_trim_line(line, font, font_size))
	return lines


static func _split_words(value: String) -> Array:
	var words: Array = []
	var current := ""
	for character: String in value:
		current += character
		if character == " ":
			words.append(current)
			current = ""
	if not current.is_empty():
		words.append(current)
	return words


## Drops the trailing space width so centred and right-aligned lines sit true.
static func _trim_line(line: Dictionary, font: Font, font_size: int) -> Dictionary:
	var items: Array = line.items
	if items.is_empty() or items[-1].glyph:
		return line
	var last: String = items[-1].text
	var trimmed := last.rstrip(" ")
	if trimmed.length() != last.length():
		var removed := (
			font
			. get_string_size(
				last.substr(trimmed.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			)
			. x
		)
		line.width = float(line.width) - removed
	return line
