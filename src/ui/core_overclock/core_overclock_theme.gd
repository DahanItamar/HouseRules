class_name CoreOverclockTheme
extends RefCounted
## Forno d'Oro: every art reference and every screen rectangle in one place.
##
## The cabinet id stays `core_overclock` (the crash mechanic); the fiction is an
## Italian pizzeria. The multiplier is the bake: the pizza goes into the
## wood-fired oven, and the longer it bakes the more it is worth. Pull it out
## with the peel and it is served; leave it too long and it burns.
##
## Swapping the skin is this file: the textures below, the palette, the sprite
## sheet grids and the geometry. No other Core Overclock file names a texture,
## a colour or a screen rectangle.
##
## The screen is laid out on the centre line: the oven gauge at 480, the bake
## curve and the recent-bakes board in the left column, the pizzaiola in the
## right column at the same width, and the shared deck across the foot. The two
## columns keep equal margins, so nothing is crammed into a corner.
##
## Rebuild the production art with `python tools/art/prepare_forno.py`;
## provenance is in docs/art/GENERATION-REPORT.md under "Forno d'Oro".

const BACKDROP := preload("res://assets/production/forno/forno_backdrop_v2.png")
const GAUGE := preload("res://assets/production/forno/forno_oven_gauge.png")
const PIZZA := preload("res://assets/production/forno/forno_pizza.png")
## The bake, in order, all on one 512 px cell and all at one shared scale so the
## dough ball stays small and the finished pizza stays large. This is the
## cabinet's real multiplier readout: the player reads how far the bake has gone
## from the food in the oven, not only from the number under it.
const BAKE_STAGES: Array[Texture2D] = [
	preload("res://assets/production/forno/forno_bake_0.png"),
	preload("res://assets/production/forno/forno_bake_1.png"),
	preload("res://assets/production/forno/forno_bake_2.png"),
	preload("res://assets/production/forno/forno_bake_3.png"),
	preload("res://assets/production/forno/forno_bake_4.png"),
	preload("res://assets/production/forno/forno_bake_5.png"),
	preload("res://assets/production/forno/forno_bake_6.png"),
	preload("res://assets/production/forno/forno_bake_7.png"),
	preload("res://assets/production/forno/forno_bake_8.png"),
]
## The stage the pizza is at before the oven is lit: made, topped, still raw.
const BAKE_STAGE_RAW: int = 3
## The stage a bake that ran too long settles on: the last one in the set.
const BAKE_STAGE_BURNT: int = 8
const BURNT := preload("res://assets/production/forno/forno_burnt_pizza.png")
const ICONS := preload("res://assets/production/forno/forno_icons.png")
const EMBERS := preload("res://assets/production/forno/forno_embers.png")
const FRAME := preload("res://assets/production/forno/forno_frame.png")
## The host is a placeholder until her final art lands; one constant swaps her.
const HOSTESS := preload("res://assets/production/characters/hosts/forno_hostess.png")

## Sprite sheet grids, as re-cut by tools/art/prepare_forno.py.
const ICON_GRID := Vector2i(3, 2)
const ICON_CELL: float = 256.0
const EMBER_GRID := Vector2i(4, 4)
const EMBER_CELL: float = 256.0
## Icon cells by what they are, in sheet order.
const ICON_SLICE: int = 0
const ICON_DOUGH: int = 1
const ICON_TOMATO: int = 2
const ICON_BASIL: int = 3
const ICON_MOZZARELLA: int = 4
const ICON_CHILLI: int = 5
## Ember sheet cells: sparks, flour swirls and smoke puffs.
const EMBER_SPARKS: Array[int] = [0, 5, 10, 14]
const EMBER_FLOUR: Array[int] = [1, 4, 9, 12]
const EMBER_SMOKE: Array[int] = [3, 6, 11, 15]

## The blank cream dial inside the oven gauge, in texture fractions.
const DIAL_CENTRE := Vector2(0.4946, 0.4902)
const DIAL_RADIUS: float = 0.29
## The terracotta nine-slice plate: its margin in the 1024 px master, and the
## canvas pixels per source pixel it is drawn at (a 15 px painted border).
const FRAME_MARGIN: int = 140
const FRAME_SCALE: float = 0.11
## Where the oven mouth burns on the painted backdrop, in canvas pixels.
const OVEN_MOUTH := Rect2(420, 180, 126, 62)
const HOSTESS_SCALE: float = 0.24
## The source pixel that lands on the cut line at the foot of her lane.
const HOSTESS_ANCHOR := Vector2(650, 1341)

## Screen geometry on the 960x540 virtual canvas, all inside TV-safe. The left
## column and the right column are the same width and keep the same margin.
const AUTO_RECT := Rect2(48, 27, 176, 44)
const TITLE_RECT := Rect2(330, 27, 300, 70)
const HISTORY_RECT := Rect2(48, 88, 236, 152)
## The one multiplier: the brass oven dial, standing on the counter front on the
## centre line directly below the oven mouth. An earlier screen showed the same
## number twice, on this dial and again on a drawn bake curve; the curve is gone.
## It is sized to the gap between the counter top and the deck so it covers
## neither.
const GAUGE_CENTRE := Vector2(480, 347)
const GAUGE_SIZE: float = 148.0
## The pizza sits on the oven floor inside the painted arch, so it is part of the
## oven instead of floating over the counter attached to nothing.
const BAKE_CENTRE := Vector2(483, 232)
const BAKE_HEIGHT: float = 88.0
const HOST_LANE := Rect2(676, 88, 236, 322)

const NIGHT := Color("1a0f09")
const CRUST := Color("d8a85a")
const DOUGH := Color("e8d9b8")
const CREAM := Color("f2e6cc")
const INK := Color("3a2418")
const TERRACOTTA := Color("b4552d")
const TERRACOTTA_DEEP := Color("6d2f18")
const BRASS := Color("c89a3c")
const BRASS_BRIGHT := Color("f0cf73")
const BRASS_DIM := Color("6e5428")
const EMBER := Color("ff7a2a")
const FLAME := Color("ffb347")
const CHAR := Color("2a1b14")
const BASIL := Color("3f7a3a")
const TOMATO := Color("c4372c")
const IVORY := Color("f6ecd9")
const MUTED := Color("c3b39c")
const FOCUS := Color("48c5d5")

## Pale dough to the edge of burning: the colour the dial, the trace and the
## needle take as the bake goes on.
const HEAT_STOPS: Array[Color] = [DOUGH, CRUST, Color("e0a63c"), EMBER, TOMATO]


## 0 at 1.00x (raw dough), 1 at 100x and above (as dark as a crust gets).
static func heat_of(centi: int) -> float:
	if centi <= 100:
		return 0.0
	return clampf(log(float(centi) / 100.0) / log(100.0), 0.0, 1.0)


static func heat_color(heat: float) -> Color:
	return _ramp(HEAT_STOPS, heat)


## Which painted bake stage the pizza shows at this point in the bake.
##
## The stages before `BAKE_STAGE_RAW` are the pizza being made and are stepped
## through during the countdown; from there the heat walks it to the last stage
## before burnt. A burn settles on `BAKE_STAGE_BURNT` outright.
static func bake_stage(heat: float) -> int:
	var first := BAKE_STAGE_RAW
	var last := BAKE_STAGE_BURNT - 1
	return clampi(first + int(round(clampf(heat, 0.0, 1.0) * float(last - first))), first, last)


## The stage the pizza is at while it is being made, `progress` running 0 to 1
## across the countdown: a dough ball, stretched, sauced, then topped and raw.
static func prep_stage(progress: float) -> int:
	var steps := BAKE_STAGE_RAW
	return clampi(int(clampf(progress, 0.0, 1.0) * float(steps + 1)), 0, steps)


static func _ramp(stops: Array[Color], place: float) -> Color:
	var span := float(stops.size() - 1)
	var spot := clampf(place, 0.0, 1.0) * span
	var index := mini(int(spot), stops.size() - 2)
	return stops[index].lerp(stops[index + 1], spot - float(index))


## A terracotta nine-slice plate. Like KitPlate, the whole node is scaled down
## from the 1024 px master so the painted tiles stay in proportion and stay
## crisp at 4K. The plate holds no children: content is drawn by a sibling
## control on top of it.
static func frame_plate(
	node_name: String, rect: Rect2, plate_scale: float = FRAME_SCALE
) -> NinePatchRect:
	var plate := NinePatchRect.new()
	plate.name = node_name
	plate.texture = FRAME
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_patch_margin(side, FRAME_MARGIN)
	plate.scale = Vector2.ONE * plate_scale
	plate.position = rect.position
	plate.size = rect.size / plate_scale
	return plate


## The painted plate's border thickness on the canvas at `plate_scale`.
static func frame_border(plate_scale: float = FRAME_SCALE) -> float:
	return float(FRAME_MARGIN) * plate_scale


## One cell of a sprite sheet, in texture pixels.
static func sheet_region(index: int, grid: Vector2i, cell: float) -> Rect2:
	var column := index % grid.x
	var row := (index / grid.x) % grid.y
	return Rect2(float(column) * cell, float(row) * cell, cell, cell)


## The deck skin: charred-oak plates, a terracotta primary key, brass structure.
## No painted kit: the shared kit only has a felt-green panel, which would fight
## the pizzeria, so the deck uses flat plates in this palette instead.
static func deck_style() -> DeckStyle:
	var style := DeckStyle.new()
	style.surface = Color("241209")
	style.edge = BRASS
	style.hairline = BRASS_DIM
	style.inset = Color("170b05")
	style.inset_edge = Color("50361d")
	style.caption = MUTED
	style.value = IVORY
	style.accent = BRASS_BRIGHT
	style.primary_face = Color("8a3418")
	style.primary_edge = BRASS_BRIGHT
	style.secondary_face = Color("2c1a10")
	style.secondary_edge = BRASS_DIM
	# The painted terracotta kit. This was empty while the cabinet had no kit of
	# its own, which left every key on its deck a flat rounded rectangle.
	style.kit_theme = &"core_overclock"
	return style


static func label(parent: Node, rect: Rect2, font_size: int, color: Color = IVORY) -> Label:
	var text_label := Label.new()
	text_label.position = rect.position
	text_label.size = rect.size
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("font", Typography.UI_FONT)
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", color)
	text_label.clip_text = true
	parent.add_child(text_label)
	return text_label


static func draw_centered(
	canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color
) -> void:
	var font: Font = Typography.DISPLAY_FONT
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## The colour a finished bake is shown in on the recent-bakes board.
static func crash_color(centi: int) -> Color:
	if centi < 100:
		return TOMATO
	if centi < 200:
		return CRUST
	if centi < 1000:
		return BRASS_BRIGHT
	return EMBER
