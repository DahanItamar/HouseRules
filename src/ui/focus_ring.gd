class_name FocusRing
extends RefCounted
## The one selected-key cue in House Rules: a cyan ring contained by the key's
## painted edge.
##
## Keyboard and controller focus is the only place cyan is allowed, so this ring
## carries the whole "this is the key you are about to press" message. It does that
## by ringing a key instead of covering it. The box draws no centre, so the painted
## plate under it, its hover brightening and a toggle's selected face all stay
## visible. The stroke stays within the component bounds so focus never looks like
## a second panel floating outside the key.
##
## The ring is a plain stylebox with no tween, pulse or shadow behind it, so reduced
## motion keeps the whole cue and nothing here can turn into glow.

const COLOR := Color("48c5d5")
const WIDTH: int = 2
## Kept as a public layout constant for round keys. Zero guarantees that no focus
## background or stroke escapes the component it describes.
const OUTSET: float = 0.0

## The outer corner radius of each painted key, in master pixels. Measured from the
## alpha silhouette of assets/production/ui/kit/button_*.png by walking the diagonal
## in from a corner: a rounded rectangle of radius R first turns opaque at
## R * (1 - 1 / sqrt(2)) along that diagonal.
const PAINTED_RADIUS: Dictionary = {
	&"baccarat": 99.0,
	&"blackjack": 106.0,
	&"core_overclock": 96.0,
	&"match_point": 79.0,
	&"minefield_vault": 82.0,
	&"poker": 109.0,
	&"roulette": 102.0,
	&"slot_classic": 92.0,
	&"upgrade_cluster": 137.0,
}


## A ring around a key whose corner measures `radius` canvas pixels.
static func style(radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = COLOR
	box.set_border_width_all(WIDTH)
	box.set_corner_radius_all(int(roundf(maxf(radius, 0.0))))
	box.set_expand_margin_all(OUTSET)
	box.anti_aliasing = true
	return box


## The ring for a painted key: its corner comes from the plate's own art.
static func for_plate(plate: KitPlate) -> StyleBoxFlat:
	return style(plate_radius(plate))


## Rings `button`. Call it once the key is dressed: a painted key takes its corner
## from the plate behind it, a flat one from `radius`.
static func apply(button: Button, radius: float) -> void:
	var plate := button.get_node_or_null("KitPlate") as KitPlate
	button.add_theme_stylebox_override(
		"focus", style(radius) if plate == null else for_plate(plate)
	)


## What a plate's painted corner measures on the canvas. A nine-slice can never show
## an arc wider than its patch margin - past that the art is stretched straight - so
## the margin caps the radius measured off the master.
static func plate_radius(plate: KitPlate) -> float:
	var corner := plate.border()
	var painted := float(PAINTED_RADIUS.get(plate.theme_id, 0.0)) * plate.kit_scale
	return corner if painted <= 0.0 else minf(painted, corner)
