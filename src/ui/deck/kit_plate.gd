class_name KitPlate
extends NinePatchRect
## One painted nine-slice plate from the UI kit, drawn at a fraction of its 1024 px
## master so it is crisp at FHD, QHD and 4K. Place it at a rectangle with `fit()`.
## The plate carries the key's reaction: hover lifts it, focus warms it so the
## selected key is lit and not merely circled, and a press darkens it and sinks it
## PRESS_SHIFT px. Each is a fixed tint and a fixed offset rather than a tween, so
## reduced motion keeps every state. The cyan ring around it is a FocusRing the
## owning control wears, never something the plate paints.

enum State { NORMAL, HOVER, PRESSED, DISABLED, FOCUSED }

const STATE_TINTS: Dictionary = {
	State.NORMAL: Color(1, 1, 1),
	State.HOVER: Color(1.14, 1.12, 1.08),
	State.PRESSED: Color(0.82, 0.82, 0.82),
	State.DISABLED: Color(0.55, 0.55, 0.55),
	# Warm rather than bright, so a focused key still brightens further on hover.
	State.FOCUSED: Color(1.12, 1.06, 0.94),
}
## Canvas pixels the plate drops while the key is held.
const PRESS_SHIFT: float = 1.0

## Canvas pixels per source pixel.
var kit_scale: float = 0.25
var base_tint := Color.WHITE
## The kit theme this plate was cut from; FocusRing reads it for the painted corner.
var theme_id: StringName = &""
var _rest := Vector2.ZERO
var _sink: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# A plate is a background: a node child draws after its parent's own _draw(),
	# so without this the plate would cover the captions and values drawn on it.
	show_behind_parent = true


## Configures the plate from the kit. Returns false when the theme has no such part.
func configure(kit_id: StringName, part: String, scale_factor: float) -> bool:
	var source := UiKit.texture(kit_id, part)
	if source == null:
		return false
	texture = source
	theme_id = kit_id
	region_rect = UiKit.region(kit_id, part)
	var slice := UiKit.margin(kit_id, part)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		set_patch_margin(side, slice)
	kit_scale = scale_factor
	scale = Vector2.ONE * kit_scale
	return true


## The painted border thickness on the canvas.
func border() -> float:
	return get_patch_margin(SIDE_LEFT) * kit_scale


## Covers `rect` (in the parent's space).
func fit(rect: Rect2) -> void:
	_rest = rect.position
	size = rect.size / kit_scale
	position = _rest + Vector2(0.0, _sink)


func set_state(state: State) -> void:
	modulate = base_tint * (STATE_TINTS[state] as Color)
	_sink = PRESS_SHIFT if state == State.PRESSED else 0.0
	position = _rest + Vector2(0.0, _sink)
