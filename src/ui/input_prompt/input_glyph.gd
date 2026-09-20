class_name InputGlyph
extends Control
## One input prompt, drawn from the painted GlyphKit art with its letter or symbol
## set in code, so a rebind always shows the key that is really bound.
##
## The glyph follows InputRouter: a keyboard shows the painted ivory keycap carrying
## the bound key; a gamepad shows its family's face buttons (the Xbox gems, the
## PlayStation button with cross/circle/square/triangle in their colours, Nintendo
## letters), shoulders, triggers, Menu and View on the graphite pill, and the painted
## D-pad with the arm a prompt means lit. It redraws itself when the device or the
## pad family changes.

const IVORY := Color("f1e8d8")
const IVORY_DIM := Color("8f867a")
## The legend on the painted ivory keycap is set in near-black, not ivory.
const KEY_INK := Color("241d18")
const PAD_FILL := Color("201d21")
const PAD_EDGE := Color("b7ab96")
const DARK_INK := Color("141112")

@export var action: StringName = &"interact":
	set = set_action
## Glyph height in virtual pixels; width follows the glyph's shape and label.
@export var glyph_height: float = 20.0:
	set = set_glyph_height
## A fixed description (tests and previews); empty follows InputRouter.
var forced_spec: Dictionary = {}:
	set = set_forced_spec


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	InputRouter.active_device_changed.connect(_on_prompts_changed)
	InputRouter.gamepad_family_changed.connect(_on_prompts_changed)
	_refresh()


func set_action(value: StringName) -> void:
	action = value
	_refresh()


func set_glyph_height(value: float) -> void:
	glyph_height = maxf(value, 8.0)
	_refresh()


func set_forced_spec(value: Dictionary) -> void:
	forced_spec = value
	_refresh()


func current_spec() -> Dictionary:
	if not forced_spec.is_empty():
		return forced_spec
	return InputRouter.glyph_spec(action)


func _on_prompts_changed(_value: int) -> void:
	_refresh()


func _refresh() -> void:
	var width := measure(current_spec(), glyph_height)
	custom_minimum_size = Vector2(width, glyph_height)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var spec := current_spec()
	draw_spec(self, spec, Rect2(Vector2.ZERO, Vector2(measure(spec, glyph_height), glyph_height)))


## Width of a glyph drawn at `height`.
static func measure(spec: Dictionary, height: float) -> float:
	var kind: int = spec.get("kind", InputRouter.GlyphKind.KEYCAP)
	match kind:
		InputRouter.GlyphKind.KEYCAP:
			return _keycap_width(String(spec.get("label", "")), height)
		InputRouter.GlyphKind.KEY_PAIR, InputRouter.GlyphKind.KEY_CLUSTER:
			var total := 0.0
			var labels: Array = spec.get("labels", [])
			for label: Variant in labels:
				total += _keycap_width(String(label), height)
			return total + maxf(labels.size() - 1, 0) * _key_gap(height)
		InputRouter.GlyphKind.SHOULDER, InputRouter.GlyphKind.TRIGGER:
			return _pill_width(String(spec.get("label", "")), height)
		InputRouter.GlyphKind.MENU, InputRouter.GlyphKind.VIEW:
			return _pill_width("", height)
	return height


## The painted keycap at its own aspect, widened when the legend needs more room.
static func _keycap_width(label: String, height: float) -> float:
	return maxf(height * GlyphKit.KEYCAP_ASPECT, _label_width(label, height) + height * 0.6)


## The painted pill at its own aspect, widened for a long legend ("ZL", "Options").
static func _pill_width(label: String, height: float) -> float:
	return maxf(height * GlyphKit.BUMPER_ASPECT, _label_width(label, height) + height * 0.9)


static func _key_gap(height: float) -> float:
	return maxf(2.0, height * 0.1)


static func _label_size(height: float) -> int:
	return maxi(8, int(round(height * 0.6)))


static func _label_width(label: String, height: float) -> float:
	return (
		Typography
		. DISPLAY_FONT
		. get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size(height))
		. x
	)


## Draws `spec` into `rect` on any canvas item (a Control, a Label, a Button).
static func draw_spec(canvas: CanvasItem, spec: Dictionary, rect: Rect2) -> void:
	var kind: int = spec.get("kind", InputRouter.GlyphKind.KEYCAP)
	match kind:
		InputRouter.GlyphKind.KEYCAP:
			_draw_keycap(canvas, String(spec.get("label", "")), rect)
		InputRouter.GlyphKind.KEY_PAIR, InputRouter.GlyphKind.KEY_CLUSTER:
			var x := rect.position.x
			for label: Variant in spec.get("labels", []):
				var width := _keycap_width(String(label), rect.size.y)
				_draw_keycap(
					canvas,
					String(label),
					Rect2(Vector2(x, rect.position.y), Vector2(width, rect.size.y))
				)
				x += width + _key_gap(rect.size.y)
		InputRouter.GlyphKind.FACE:
			_draw_face(canvas, spec, rect)
		InputRouter.GlyphKind.SHOULDER, InputRouter.GlyphKind.TRIGGER:
			_draw_pill(canvas, String(spec.get("label", "")), rect)
		InputRouter.GlyphKind.DPAD:
			_draw_dpad(canvas, StringName(spec.get("direction", &"all")), rect)
		InputRouter.GlyphKind.STICK:
			_draw_stick(canvas, spec, rect)
		InputRouter.GlyphKind.MENU:
			_draw_menu(canvas, int(spec.get("family", 0)), rect)
		InputRouter.GlyphKind.VIEW:
			_draw_view(canvas, int(spec.get("family", 0)), rect)


static func _draw_centered_text(
	canvas: CanvasItem, label: String, rect: Rect2, ink: Color, factor: float = 0.6
) -> void:
	var font_size := maxi(8, int(round(rect.size.y * factor)))
	var font := Typography.DISPLAY_FONT
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := rect.position.y + (rect.size.y + ascent - descent) * 0.5
	canvas.draw_string(
		font,
		Vector2(rect.position.x, baseline),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		font_size,
		ink
	)


## The painted ivory keycap with the bound key's legend set on it in dark ink.
static func _draw_keycap(canvas: CanvasItem, label: String, rect: Rect2) -> void:
	GlyphKit.draw_sliced(canvas, GlyphKit.KEYCAP, GlyphKit.KEYCAP_CAPS, rect, Color.WHITE)
	# The painted cap sits slightly above its brass under-edge; centre on the face.
	var face := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.94))
	_draw_centered_text(canvas, label, face, KEY_INK)


## The painted graphite pill: shoulders, triggers, Menu and View.
static func _draw_pill(canvas: CanvasItem, label: String, rect: Rect2) -> void:
	GlyphKit.draw_sliced(canvas, GlyphKit.BUMPER, GlyphKit.BUMPER_CAPS, rect, Color.WHITE)
	_draw_centered_text(canvas, label, rect, IVORY)


## A painted face button. The Xbox gems carry their letter; the blank black button
## carries a PlayStation symbol in its colour or a Nintendo letter.
static func _draw_face(canvas: CanvasItem, spec: Dictionary, rect: Rect2) -> void:
	var texture := GlyphKit.face_texture(spec)
	GlyphKit.draw_square(canvas, texture, rect, Color.WHITE)
	var extent := minf(rect.size.x, rect.size.y)
	var face := Rect2(
		rect.position + (rect.size - Vector2(extent, extent)) * 0.5, Vector2(extent, extent)
	)
	if spec.has("symbol"):
		var color: Color = spec.get("color", IVORY)
		_draw_face_symbol(canvas, StringName(spec.symbol), face.get_center(), extent * 0.30, color)
		return
	var gem: Color = spec.get("color", PAD_FILL)
	var ink := DARK_INK if texture != GlyphKit.PS_FACE and gem.get_luminance() > 0.55 else IVORY
	_draw_centered_text(canvas, String(spec.get("label", "")), face, ink, 0.46)


static func _draw_face_symbol(
	canvas: CanvasItem, symbol: StringName, center: Vector2, extent: float, color: Color
) -> void:
	var width := maxf(1.5, extent * 0.34)
	match symbol:
		&"cross":
			var e := extent * 0.82
			canvas.draw_line(center + Vector2(-e, -e), center + Vector2(e, e), color, width, true)
			canvas.draw_line(center + Vector2(-e, e), center + Vector2(e, -e), color, width, true)
		&"circle":
			canvas.draw_arc(center, extent * 0.86, 0.0, TAU, 32, color, width, true)
		&"square":
			var e := extent * 0.74
			var points := PackedVector2Array(
				[
					center + Vector2(-e, -e),
					center + Vector2(e, -e),
					center + Vector2(e, e),
					center + Vector2(-e, e),
					center + Vector2(-e, -e),
				]
			)
			canvas.draw_polyline(points, color, width, true)
		&"triangle":
			var e := extent * 0.95
			var points := PackedVector2Array(
				[
					center + Vector2(0, -e),
					center + Vector2(e * 0.9, e * 0.62),
					center + Vector2(-e * 0.9, e * 0.62),
					center + Vector2(0, -e),
				]
			)
			canvas.draw_polyline(points, color, width, true)


## The painted D-pad. The whole cross is drawn dim and the arms the prompt means are
## redrawn at full strength, so "left/right" reads without adding any invented art.
const DPAD_ARMS: Dictionary = {
	&"left": Rect2(0.0, 0.3, 0.34, 0.4),
	&"right": Rect2(0.66, 0.3, 0.34, 0.4),
	&"up": Rect2(0.3, 0.0, 0.4, 0.34),
	&"down": Rect2(0.3, 0.66, 0.4, 0.34),
}


static func _draw_dpad(canvas: CanvasItem, direction: StringName, rect: Rect2) -> void:
	var lit: Array[StringName] = []
	match direction:
		&"horizontal":
			lit = [&"left", &"right"]
		&"vertical":
			lit = [&"up", &"down"]
		&"all":
			lit = [&"left", &"right", &"up", &"down"]
		_:
			lit = [direction]
	var whole := lit.size() == DPAD_ARMS.size()
	GlyphKit.draw_square(
		canvas, GlyphKit.DPAD, rect, Color.WHITE if whole else Color(0.62, 0.6, 0.58)
	)
	if whole:
		return
	for id: StringName in lit:
		GlyphKit.draw_square_part(canvas, GlyphKit.DPAD, rect, DPAD_ARMS[id], Color(1.2, 1.18, 1.1))


static func _draw_stick(canvas: CanvasItem, spec: Dictionary, rect: Rect2) -> void:
	var center := rect.get_center()
	var extent := rect.size.y * 0.5
	canvas.draw_circle(center, extent, PAD_FILL, true, -1.0, true)
	canvas.draw_arc(center, extent - 0.5, 0.0, TAU, 32, PAD_EDGE, 1.0, true)
	canvas.draw_circle(center, extent * 0.56, Color("3a3438"), true, -1.0, true)
	canvas.draw_arc(center, extent * 0.56, 0.0, TAU, 32, IVORY, 1.0, true)
	var label := String(spec.get("label", ""))
	if label.is_empty():
		label = "L"
	_draw_centered_text(
		canvas, label, Rect2(center - Vector2(extent, extent), Vector2(extent, extent) * 2.0), IVORY
	)


## Menu / Options / + on the painted pill, with its icon set in code.
static func _draw_menu(canvas: CanvasItem, family: int, rect: Rect2) -> void:
	GlyphKit.draw_sliced(canvas, GlyphKit.BUMPER, GlyphKit.BUMPER_CAPS, rect, Color.WHITE)
	var center := rect.get_center()
	var extent := rect.size.y * 0.5
	var ink_width := maxf(1.0, extent * 0.14)
	if family == InputRouter.GamepadFamily.NINTENDO:
		var plus := extent * 0.46
		canvas.draw_line(
			center - Vector2(plus, 0), center + Vector2(plus, 0), IVORY, ink_width * 1.3, true
		)
		canvas.draw_line(
			center - Vector2(0, plus), center + Vector2(0, plus), IVORY, ink_width * 1.3, true
		)
		return
	var half := extent * (0.34 if family == InputRouter.GamepadFamily.PLAYSTATION else 0.44)
	for row: int in range(3):
		var y := center.y + (row - 1) * extent * 0.34
		canvas.draw_line(
			Vector2(center.x - half, y), Vector2(center.x + half, y), IVORY, ink_width, true
		)


## View / Share / − on the painted pill, with its icon set in code.
static func _draw_view(canvas: CanvasItem, family: int, rect: Rect2) -> void:
	GlyphKit.draw_sliced(canvas, GlyphKit.BUMPER, GlyphKit.BUMPER_CAPS, rect, Color.WHITE)
	var center := rect.get_center()
	var extent := rect.size.y * 0.5
	if family == InputRouter.GamepadFamily.NINTENDO:
		var minus := extent * 0.46
		canvas.draw_line(
			center - Vector2(minus, 0),
			center + Vector2(minus, 0),
			IVORY,
			maxf(1.0, extent * 0.18),
			true
		)
		return
	var box := extent * 0.42
	var back := Rect2(
		center + Vector2(-box, -box) + Vector2(-box * 0.35, -box * 0.35), Vector2(box, box) * 1.4
	)
	var front := Rect2(
		center + Vector2(-box, -box) + Vector2(box * 0.35, box * 0.35), Vector2(box, box) * 1.4
	)
	canvas.draw_rect(back, IVORY_DIM, false, 1.0)
	canvas.draw_rect(front, PAD_FILL)
	canvas.draw_rect(front, IVORY, false, 1.0)
