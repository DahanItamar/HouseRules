class_name KitPlate
extends NinePatchRect
## One painted nine-slice plate from the UI kit, drawn at a fraction of its 1024 px
## master so it is crisp at FHD, QHD and 4K. Place it at a rectangle with `fit()`.
## Hover, focus and press only modulate it slightly brighter or darker; the cyan
## focus ring is drawn by the owning control, never by the plate.

enum State { NORMAL, HOVER, PRESSED, DISABLED }

const STATE_TINTS: Dictionary = {
	State.NORMAL: Color(1, 1, 1),
	State.HOVER: Color(1.14, 1.12, 1.08),
	State.PRESSED: Color(0.82, 0.82, 0.82),
	State.DISABLED: Color(0.55, 0.55, 0.55),
}

## Canvas pixels per source pixel.
var kit_scale: float = 0.25
var base_tint := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# A plate is a background: a node child draws after its parent's own _draw(),
	# so without this the plate would cover the captions and values drawn on it.
	show_behind_parent = true


## Configures the plate from the kit. Returns false when the theme has no such part.
func configure(theme_id: StringName, part: String, scale_factor: float) -> bool:
	var source := UiKit.texture(theme_id, part)
	if source == null:
		return false
	texture = source
	region_rect = UiKit.region(theme_id, part)
	var slice := UiKit.margin(theme_id, part)
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
	position = rect.position
	size = rect.size / kit_scale


func set_state(state: State) -> void:
	modulate = base_tint * (STATE_TINTS[state] as Color)
