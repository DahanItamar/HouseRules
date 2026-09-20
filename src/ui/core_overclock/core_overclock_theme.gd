class_name CoreOverclockTheme
extends RefCounted
## Corsair's Reach: every art reference and every screen rectangle in one place.
##
## The cabinet id stays `core_overclock` (the crash mechanic); the fiction is a
## privateer's night sea. The multiplier is the climb: a parrot carries the line
## up an exponential curve over the water, and the longer she flies the more the
## run is worth. Haul her in and it pays; leave her out too long and the sea
## takes her.
##
## Swapping the skin is this file: the textures below, the palette, the sprite
## sheet grids and the geometry. No other Core Overclock file names a texture,
## a colour or a screen rectangle.
##
## The screen is laid out on the centre line: the chart and its climb in the
## middle with the multiplier read off it, the recent-runs strip and the
## auto-haul target in the top-left corner, the crew in lanes down either edge,
## and the shared deck across the foot. The two lanes keep equal margins, so
## nothing is crammed into a corner.
##
## Rebuild the production art with `python tools/art/prepare_corsair.py`;
## the generation log is in docs/art/GENERATION-REPORT.md.

const BACKDROP := preload("res://assets/production/corsair/corsair_sea.png")
const GAUGE := preload("res://assets/production/corsair/corsair_compass.png")
## The crest is the one icon on the recent-runs strip.
const ICONS := CREST
## Spray, spindrift and smoke for the bursts: the same four stages of the
## break-up the wreck plays, addressed one cell at a time.
const EMBERS := WRECK
## The small plates behind the title, the auto-haul target and the recent runs
## are cut from the same brass-and-rope chart frame as the crash box, so the
## whole cabinet is built out of one set of materials.
const FRAME := preload("res://assets/production/corsair/corsair_frame.png")
const CREST := preload("res://assets/production/corsair/corsair_crest.png")
const PARROT := preload("res://assets/production/corsair/corsair_parrot.png")
## The bird on the line: a four-frame flap cycle, body fixed, wings moving.
const PARROT_FLIGHT := preload("res://assets/production/corsair/corsair_parrot_flight.png")
const PARROT_GRID := Vector2i(2, 2)
const PARROT_CELL: float = 512.0
## The glowing beam she draws behind her.
const TRAIL := preload("res://assets/production/corsair/corsair_trail.png")
const TRAIL_TINT := Color(1.0, 0.86, 0.46, 0.95)
const DECK_TRIM := preload("res://assets/production/corsair/corsair_deck_trim.png")
## The chart frame the crash is drawn inside, so the graph is a thing on the
## wall and the room decorates up to its edge. It is the same painted frame the
## small HUD plates are cut from, at a different scale.
const FRAME_CHART := FRAME
## The painted border thickness in the 1536 px master.
const FRAME_CHART_MARGIN: int = 114
const WRECK := preload("res://assets/production/corsair/corsair_wreck.png")
const WRECK_GRID := Vector2i(2, 2)
const WRECK_CELL: float = 512.0
## The two of the crew, one painted frame per state of the run with both of them
## in it. They are generated together so their reaction is always shared; see
## `CoreOverclockHosts`. The middle of every frame is transparent, so the chart
## and the climb read between them.
const HOST_STATES: Dictionary = {
	&"ready": preload("res://assets/production/corsair/corsair_crew_ready.png"),
	&"tense": preload("res://assets/production/corsair/corsair_crew_tense.png"),
	&"cheer": preload("res://assets/production/corsair/corsair_crew_cheer.png"),
	&"wince": preload("res://assets/production/corsair/corsair_crew_wince.png"),
}

## Sprite sheet grids, as re-cut by tools/art/prepare_corsair.py.
const ICON_GRID := Vector2i(1, 1)
const ICON_CELL: float = 512.0
const EMBER_GRID := Vector2i(2, 2)
const EMBER_CELL: float = 512.0
## The one crest cell on the recent-runs strip.
const ICON_CREST: int = 0

## Which stage of the break-up each burst draws from. The sheet is 2x2 now, so
## these are the four cells: impact spray, timbers, debris and smoke, and the
## last of the foam.
const EMBER_SPARKS: Array[int] = [0, 1]
const EMBER_SPRAY: Array[int] = [0, 3]
const EMBER_SMOKE: Array[int] = [2, 3]

## The blank cream dial inside the brass compass case, in texture fractions.
const DIAL_CENTRE := Vector2(0.4971, 0.4873)
const DIAL_RADIUS: float = 0.315
## The brass-and-rope nine-slice plate: its margin in the 1024 px master, and
## the canvas pixels per source pixel it is drawn at (a 15 px painted border).
const FRAME_MARGIN: int = 114
const FRAME_SCALE: float = 0.13
## The chart the flight is drawn inside, in canvas pixels. It owns the middle of
## the screen, between the two character lanes and from under the title down to
## the deck; the climb is drawn inside this box and the multiplier is read off
## its centre.
const FLIGHT_AREA := Rect2(232, 116, 496, 274)
## She is seen head to foot now, so she is scaled to the lane's height
## (2011 painted pixels into 264) instead of to a hip cut line.
const HOSTESS_SCALE: float = 0.1313
## The source pixel that lands on the floor at the foot of her lane: the
## middle of her body columns, at the very bottom of her painted art.
const HOSTESS_ANCHOR := Vector2(670, 2044)

## Screen geometry on the 960x540 virtual canvas, all inside TV-safe. The left
## column and the right column are the same width and keep the same margin.
const AUTO_RECT := Rect2(48, 27, 176, 44)
const TITLE_RECT := Rect2(330, 27, 300, 70)
## The recent runs sit under the timer in the top-left corner, clear of the
## left-hand lane.
const HISTORY_RECT := Rect2(44, 78, 152, 34)
## The one multiplier, read in the middle of the chart, over the sea, the way
## every crash game reads it. An earlier screen showed the same number twice, on
## a brass dial and again on a drawn curve; there is no separate dial now, so
## nothing stands between the player and the water.
const GAUGE_CENTRE := Vector2(464, 226)
const GAUGE_SIZE: float = 300.0
## The two of them stand in narrow lanes hard against the left and right edges,
## clear of the crash area between them and clear of the deck below.
const HOST_LANE := Rect2(764, 118, 160, 300)
const HOST_LANE_LEFT := Rect2(36, 118, 160, 300)

const NIGHT := Color("1a0f09")
const ROPE := Color("d8a85a")
const SAILCLOTH := Color("e8d9b8")
const CREAM := Color("f2e6cc")
const INK := Color("3a2418")
const RUST := Color("b4552d")
const RUST_DEEP := Color("6d2f18")
const BRASS := Color("c89a3c")
const BRASS_BRIGHT := Color("f0cf73")
const BRASS_DIM := Color("6e5428")
const EMBER := Color("ff7a2a")
const FLAME := Color("ffb347")
const ENSIGN := Color("c4372c")
const IVORY := Color("f6ecd9")
const MUTED := Color("c3b39c")

## Pale sailcloth through to a warning red: the colour the number, the trace and
## the needle take as the climb goes on.
const CLIMB_STOPS: Array[Color] = [SAILCLOTH, ROPE, Color("e0a63c"), EMBER, ENSIGN]


## How far along the climb `centi` is: 0 at 1.00x, 1 at 100x and above.
static func climb_of(centi: int) -> float:
	if centi <= 100:
		return 0.0
	return clampf(log(float(centi) / 100.0) / log(100.0), 0.0, 1.0)


static func climb_color(climb: float) -> Color:
	return _ramp(CLIMB_STOPS, climb)


static func _ramp(stops: Array[Color], place: float) -> Color:
	var span := float(stops.size() - 1)
	var spot := clampf(place, 0.0, 1.0) * span
	var index := mini(int(spot), stops.size() - 2)
	return stops[index].lerp(stops[index + 1], spot - float(index))


## A brass-and-rope nine-slice plate. Like KitPlate, the node is scaled down
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


## The chart frame's painted border on the canvas, at the scale the panel draws
## it. The swell is inset by this much so the water never runs under the brass.
static func frame_chart_border(chart_scale: float = 0.22) -> float:
	return float(FRAME_CHART_MARGIN) * chart_scale


## The painted plate's border thickness on the canvas at `plate_scale`.
static func frame_border(plate_scale: float = FRAME_SCALE) -> float:
	return float(FRAME_MARGIN) * plate_scale


## One cell of a sprite sheet, in texture pixels.
static func sheet_region(index: int, grid: Vector2i, cell: float) -> Rect2:
	var column := index % grid.x
	var row := (index / grid.x) % grid.y
	return Rect2(float(column) * cell, float(row) * cell, cell, cell)


## The deck skin: dark oak plates, a rust-red primary key, brass structure.
## No painted kit: the shared kit only has a felt-green panel, which would fight
## the night sea, so the deck uses flat plates in this palette instead.
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
	# The cabinet's own painted kit. This was empty while it had no kit of its
	# own, which left every key on its deck a flat rounded rectangle.
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


## The colour a finished run is shown in on the recent-runs strip.
static func crash_color(centi: int) -> Color:
	if centi < 100:
		return ENSIGN
	if centi < 200:
		return ROPE
	if centi < 1000:
		return BRASS_BRIGHT
	return EMBER
