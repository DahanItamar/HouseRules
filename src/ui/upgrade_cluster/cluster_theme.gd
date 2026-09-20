class_name ClusterTheme
extends RefCounted
## Harlequin Masquerade: the one place this cabinet records how it looks.
##
## Every art reference, colour, rectangle and motion duration the machine uses
## lives here. The panel, the grid, the tiles, the bar, the host and the
## celebration read from this script and name no texture of their own, so
## re-skinning the cabinet is a change to this file alone.
##
## The set is a carnival theatre: a masquerade stage with pink velvet curtains,
## an ornate harlequin-diamond frame around the board, a brass multiplier rail
## above it, gem and masquerade tiles in the cells, and the hostess in a blush
## satin jacket standing on the stage at the right with two jester sidekicks at
## the foot of the frame.

# -- Art ----------------------------------------------------------------------
const ART := "res://assets/production/harlequin/"
const HOSTS := "res://assets/production/characters/hosts/"

const BACKDROP: Texture2D = preload(ART + "harlequin_stage_backdrop.png")
const GRID_FRAME: Texture2D = preload(ART + "harlequin_grid_frame.png")
const MULTIPLIER_BAR: Texture2D = preload(ART + "harlequin_multiplier_bar.png")
const CREST: Texture2D = preload(ART + "harlequin_crest.png")
const SHARDS: Texture2D = preload(ART + "harlequin_shards.png")
const SIDEKICK_PINK: Texture2D = preload(ART + "harlequin_sidekick_pink.png")
const SIDEKICK_GREEN: Texture2D = preload(ART + "harlequin_sidekick_green.png")

## One painted tile per symbol, in UpgradeClusterMath.Symbol order: four
## harlequin-diamond gems (low) then four masquerade props (high). Each master is
## a 256 px square cell with the art centred at one visual weight.
const TILES: Array[Texture2D] = [
	preload(ART + "harlequin_tile_gem_green.png"),
	preload(ART + "harlequin_tile_gem_pink.png"),
	preload(ART + "harlequin_tile_gem_violet.png"),
	preload(ART + "harlequin_tile_gem_ivory.png"),
	preload(ART + "harlequin_tile_mask.png"),
	preload(ART + "harlequin_tile_jester_hat.png"),
	preload(ART + "harlequin_tile_bells.png"),
	preload(ART + "harlequin_tile_ticket.png"),
]

## The hostess's beats. Every pose is the same person on the same 1392x2080
## canvas, head-registered, so a cross-fade between them never jumps.
const HOST_IDLE: Texture2D = preload(HOSTS + "harlequin_hostess.png")
const HOST_MASK: Texture2D = preload(HOSTS + "harlequin_hostess_mask.png")
const HOST_PRESENT: Texture2D = preload(HOSTS + "harlequin_hostess_present.png")
const HOST_CHEER: Texture2D = preload(HOSTS + "harlequin_hostess_cheer.png")
const HOST_POUT: Texture2D = preload(HOSTS + "harlequin_hostess_pout.png")

## The painted frame's inner opening, as a fraction of the frame texture. The
## board is laid inside exactly this window, so the cells never sit on the paint.
const FRAME_WINDOW := Rect2(0.125, 0.1335, 0.75, 0.738)
## The frame's painted border measured from its own edge, used to place the
## board from the frame rectangle.
const FRAME_MARGIN := Vector2(0.125, 0.1335)
## The blank ribbon across the crest, where the tier word is drawn in code.
const CREST_RIBBON := Rect2(0.22, 0.784, 0.56, 0.100)
## The bar plate's painted end caps, in source pixels, for its nine-slice.
const BAR_PATCH: int = 70
## The shard sheet is a 4x4 grid of 256 px cells.
const SHARD_CELL := Vector2i(256, 256)
const SHARD_COLUMNS: int = 4

# -- Surfaces -----------------------------------------------------------------
## Theatre blacks and the masquerade's pink, green, ivory and brass.
const VOID := Color("0b0810")
const SURFACE := Color("1d1018")
const SURFACE_RAISED := Color("2b1a22")
const INSET := Color("140b11")
const EDGE := Color("c69a4e")
const EDGE_BRIGHT := Color("f0d27c")
const HAIRLINE := Color("6a4b2a")
const GRID_WELL := Color("0d0910")

# -- Ink ----------------------------------------------------------------------
const TEXT := Color("f6ece2")
const TEXT_MUTED := Color("c3ab9c")
const TEXT_DISABLED := Color("7c6a5f")
const ACCENT := Color("e7a7bd")
const HARLEQUIN_PINK := Color("e2a0b4")
const HARLEQUIN_GREEN := Color("1f6a45")
const WIN := Color("f2c84b")
const LOSS := Color("d27a6c")

# -- Symbols ------------------------------------------------------------------
## Name key and the accent each symbol lights with, in Symbol order.
const SYMBOLS: Array[Dictionary] = [
	{"key": "CLUSTER_SYMBOL_EMERALD", "tint": Color("3fae72")},
	{"key": "CLUSTER_SYMBOL_ROSE", "tint": Color("e494ad")},
	{"key": "CLUSTER_SYMBOL_AMETHYST", "tint": Color("9a6ad6")},
	{"key": "CLUSTER_SYMBOL_PEARL", "tint": Color("e8e0d4")},
	{"key": "CLUSTER_SYMBOL_MASK", "tint": Color("efe3c8")},
	{"key": "CLUSTER_SYMBOL_JESTER", "tint": Color("e7a0b6")},
	{"key": "CLUSTER_SYMBOL_BELLS", "tint": Color("e0b155")},
	{"key": "CLUSTER_SYMBOL_TICKET", "tint": Color("d35a52")},
]

# -- Layout (960x540 virtual canvas, TV-safe 48,27 864x486) --------------------
const TITLE_RECT := Rect2(48, 27, 240, 40)
const HELP_RECT := Rect2(48, 74, 176, 44)
const BAR_RECT := Rect2(296, 28, 368, 42)
const FRAME_RECT := Rect2(312, 72, 336, 342)
const GRID_ORIGIN := Vector2(354, 118)
const TILE_PITCH: float = 36.0
const TILE_SIZE: float = 32.0
const READOUT_RECT := Rect2(48, 130, 240, 132)
const LEGEND_RECT := Rect2(48, 270, 240, 144)
const HOSTESS_RECT := Rect2(700, 96, 212, 317)
const SIDEKICK_LEFT_RECT := Rect2(288, 320, 54, 96)
const SIDEKICK_RIGHT_RECT := Rect2(614, 324, 82, 92)
## The board, derived from the origin and pitch. Used by the tests and the popup.
const GRID_RECT := Rect2(354, 118, 252, 252)

## Rectangles the player has to keep reading while a round replays. No floating
## popup, sidekick, host or particle may cover one of them. The celebration is
## deliberately exempt: it is a modal, bounded moment that takes the screen and
## gives it back.
const PROTECTED_RECTS: Array[Rect2] = [BAR_RECT, READOUT_RECT, LEGEND_RECT, GRID_RECT]

# -- Motion -------------------------------------------------------------------
## Full-motion seconds for the phases of one cascade. They run strictly in order
## and never overlap. `phase()` bounds every one of them under reduced motion.
const PULSE_SECONDS: float = 0.34
const MATH_POP_SECONDS: float = 0.26
const MATH_HOLD_SECONDS: float = 0.42
const MATH_RISE_SECONDS: float = 0.34
const SHATTER_SECONDS: float = 0.30
const TUMBLE_SECONDS: float = 0.38
const SETTLE_SECONDS: float = 0.12
## Reduced motion collapses each phase to one short, bounded beat.
const REDUCED_PHASE: float = 0.09
const SHAKE_PIXELS: float = 3.0
const SHAKE_SECONDS: float = 0.18

# -- Celebration --------------------------------------------------------------
## Round win in bet multiples that opens each tier, ascending.
const BIG_WIN_MULTIPLE: float = 15.0
const SUPER_WIN_MULTIPLE: float = 50.0
const MEGA_WIN_MULTIPLE: float = 100.0
const CELEBRATION_RISE_SECONDS: float = 0.42
const CELEBRATION_COUNT_SECONDS: float = 0.9
const CELEBRATION_HOLD_SECONDS: float = 1.5
const CELEBRATION_FADE_SECONDS: float = 0.4


static func symbol_count() -> int:
	return SYMBOLS.size()


static func symbol(index: int) -> Dictionary:
	return SYMBOLS[clampi(index, 0, SYMBOLS.size() - 1)]


static func symbol_tint(index: int) -> Color:
	return symbol(index).tint as Color


static func symbol_texture(index: int) -> Texture2D:
	return TILES[clampi(index, 0, TILES.size() - 1)]


static func symbol_name(index: int) -> String:
	return TranslationServer.translate(String(symbol(index).key))


## Top-left of a cell in panel space.
static func cell_position(column: int, row: int) -> Vector2:
	var inset := (TILE_PITCH - TILE_SIZE) * 0.5
	return GRID_ORIGIN + Vector2(column, row) * TILE_PITCH + Vector2(inset, inset)


## Centre of a cell in panel space.
static func cell_center(column: int, row: int) -> Vector2:
	return GRID_ORIGIN + Vector2(column + 0.5, row + 0.5) * TILE_PITCH


## One cell of the painted shard sheet, as an AtlasTexture region.
static func shard_region(index: int) -> Rect2:
	var cell := index % (SHARD_COLUMNS * SHARD_COLUMNS)
	return Rect2(
		Vector2(cell % SHARD_COLUMNS, cell / SHARD_COLUMNS) * Vector2(SHARD_CELL),
		Vector2(SHARD_CELL)
	)


## Celebration tier for a round win, or an empty string below the first tier.
static func celebration_tier(multiple: float) -> String:
	if multiple >= MEGA_WIN_MULTIPLE:
		return "mega"
	if multiple >= SUPER_WIN_MULTIPLE:
		return "super"
	if multiple >= BIG_WIN_MULTIPLE:
		return "big"
	return ""


static func tier_key(tier: String) -> String:
	match tier:
		"mega":
			return "CLUSTER_MEGA_WIN"
		"super":
			return "CLUSTER_SUPER_WIN"
		"big":
			return "CLUSTER_BIG_WIN"
	return ""


## Seconds for one motion phase, bounded under the reduced-motion preference.
static func phase(full_motion_seconds: float) -> float:
	if MotionPolicy.is_reduced():
		return minf(REDUCED_PHASE, full_motion_seconds)
	return full_motion_seconds


## Milli-bet units as the machine prints them, to two decimals: 320 -> "0.32".
## The third decimal exists only so the paytable can be tuned exactly; it is
## never shown, and the rounding here is display-only.
static func bet_text(units: int) -> String:
	var hundredths := (absi(units) + 5) / 10
	return "%d.%02d" % [hundredths / 100, hundredths % 100]


static func box(fill: Color, border: Color, width: int = 1, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


## The shared deck skinned for this cabinet.
static func deck_style() -> DeckStyle:
	var style := DeckStyle.new()
	style.surface = SURFACE
	style.edge = EDGE
	style.hairline = HAIRLINE
	style.inset = INSET
	style.inset_edge = HAIRLINE
	style.caption = TEXT_MUTED
	style.value = TEXT
	style.accent = EDGE_BRIGHT
	style.primary_face = HARLEQUIN_GREEN
	style.primary_edge = EDGE_BRIGHT
	style.secondary_face = SURFACE_RAISED
	style.secondary_edge = EDGE
	style.edge_bright = EDGE_BRIGHT
	style.text_disabled = TEXT_DISABLED
	style.win = WIN
	style.loss = LOSS
	style.push = TEXT
	style.kit_theme = &"upgrade_cluster"
	return style


static func label(parent: Node, rect: Rect2, font_size: int, ink: Color = TEXT) -> Label:
	var text_label := Label.new()
	text_label.position = rect.position
	text_label.size = rect.size
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("font", Typography.UI_FONT)
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", ink)
	text_label.clip_text = true
	parent.add_child(text_label)
	return text_label


## A painted plate laid across `rect`.
##
## `expand_mode` is set **before** the texture: a TextureRect adopts its texture's
## size as its minimum the moment the texture is assigned, and a later mode change
## does not shrink a size that minimum has already clamped. Every painted control
## in this cabinet is built through here or through `fit()` for that reason.
static func plate(
	texture: Texture2D,
	rect: Rect2,
	node_name: String,
	mode: TextureRect.StretchMode = TextureRect.STRETCH_SCALE
) -> TextureRect:
	var art := TextureRect.new()
	art.name = node_name
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = mode
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = texture
	fit(art, rect)
	return art


## Places a painted control at `rect`, keeping its minimum size out of the way.
static func fit(art: Control, rect: Rect2) -> void:
	art.custom_minimum_size = Vector2.ZERO
	art.position = rect.position
	art.size = rect.size
