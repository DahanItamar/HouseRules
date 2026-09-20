class_name GlyphKit
extends RefCounted
## The painted input glyphs (assets/production/ui/glyphs, see glyphs.json).
##
## Higgsfield masters, processed by tools/art/build_glyph_kit.py: round face buttons
## with a blank centre, a graphite bumper pill and an ivory keycap whose faces are
## flat so they stretch cleanly, and a D-pad icon. Every letter and symbol on them is
## drawn in code with the bundled font, so a rebind shows the key that is really
## bound and nothing is baked into the art.
##
## Masters are 456-889 px tall and drawn at 18-28 px, so they are imported with
## mipmaps; a canvas that draws them must use TEXTURE_FILTER_LINEAR_WITH_MIPMAPS.

## Xbox gems, keyed by the letter printed on them.
const XBOX_FACES: Dictionary = {
	"A": preload("res://assets/production/ui/glyphs/xbox_a.png"),
	"B": preload("res://assets/production/ui/glyphs/xbox_b.png"),
	"X": preload("res://assets/production/ui/glyphs/xbox_x.png"),
	"Y": preload("res://assets/production/ui/glyphs/xbox_y.png"),
}
## The blank glossy black button: PlayStation symbols and Nintendo letters sit on it.
const PS_FACE: Texture2D = preload("res://assets/production/ui/glyphs/ps_face.png")
const DPAD: Texture2D = preload("res://assets/production/ui/glyphs/dpad.png")
const BUMPER: Texture2D = preload("res://assets/production/ui/glyphs/bumper.png")
const KEYCAP: Texture2D = preload("res://assets/production/ui/glyphs/keycap.png")

## Painted cap widths in source pixels (left, right): the part that must not stretch.
const BUMPER_CAPS := Vector2(148, 147)
const KEYCAP_CAPS := Vector2(82, 81)
## Natural width as a multiple of the drawn height, from the master's aspect.
const BUMPER_ASPECT: float = 917.0 / 456.0
const KEYCAP_ASPECT: float = 881.0 / 889.0
## The flat face inside the bezel, as a fraction of half the drawn size.
const XBOX_FACE_RADIUS: float = 0.78
const PS_FACE_RADIUS: float = 0.88


## The round art for a face-button spec, or the blank black button when the family
## prints its own symbol (PlayStation) or letter (Nintendo).
static func face_texture(spec: Dictionary) -> Texture2D:
	if spec.has("symbol") or bool(spec.get("outlined", false)):
		return PS_FACE
	return XBOX_FACES.get(String(spec.get("label", "")), PS_FACE) as Texture2D


## Half-extent of the flat centre a letter or symbol may use, for `spec` at `height`.
static func face_extent(spec: Dictionary, height: float) -> float:
	var fraction := PS_FACE_RADIUS if face_texture(spec) == PS_FACE else XBOX_FACE_RADIUS
	return height * 0.5 * fraction


## Draws a horizontally sliced piece: the painted caps keep their shape and only the
## flat middle stretches, so the pill and the keycap stay true at any label width.
static func draw_sliced(
	canvas: CanvasItem, texture: Texture2D, caps: Vector2, rect: Rect2, tint: Color
) -> void:
	var source := texture.get_size()
	var factor := rect.size.y / source.y
	var left := minf(caps.x * factor, rect.size.x * 0.5)
	var right := minf(caps.y * factor, rect.size.x * 0.5)
	var middle := maxf(rect.size.x - left - right, 0.0)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(rect.position, Vector2(left, rect.size.y)),
		Rect2(0, 0, caps.x, source.y),
		tint
	)
	if middle > 0.0:
		canvas.draw_texture_rect_region(
			texture,
			Rect2(rect.position + Vector2(left, 0), Vector2(middle, rect.size.y)),
			Rect2(caps.x, 0, source.x - caps.x - caps.y, source.y),
			tint
		)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(rect.position + Vector2(left + middle, 0), Vector2(right, rect.size.y)),
		Rect2(source.x - caps.y, 0, caps.y, source.y),
		tint
	)


## Draws a square glyph centred in `rect`, keeping it round.
static func draw_square(canvas: CanvasItem, texture: Texture2D, rect: Rect2, tint: Color) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var at := rect.position + (rect.size - Vector2(extent, extent)) * 0.5
	canvas.draw_texture_rect(texture, Rect2(at, Vector2(extent, extent)), false, tint)


## Draws one quadrant/arm of a square glyph at its own tint, by taking the matching
## slice of the master. Used to light the D-pad arm a prompt means.
static func draw_square_part(
	canvas: CanvasItem, texture: Texture2D, rect: Rect2, part: Rect2, tint: Color
) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var at := rect.position + (rect.size - Vector2(extent, extent)) * 0.5
	var source := texture.get_size()
	canvas.draw_texture_rect_region(
		texture,
		Rect2(at + part.position * extent, part.size * extent),
		Rect2(part.position * source, part.size * source),
		tint
	)
