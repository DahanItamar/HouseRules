class_name ProgressionArt
extends RefCounted
## The painted progression kit, looked up by name.
##
## Built by `tools/art/prepare_progression.py` from the Higgsfield masters and
## described in `assets/production/ui/progression/progression.json`. Five rank
## medallions were painted for six ranks: Partner reuses the Owner key tinted
## to aged bronze, so the pure gold key stays the last rung's own.

const RANK_MEDALLIONS: Array[Texture2D] = [
	preload("res://assets/production/ui/progression/rank_guest.png"),
	preload("res://assets/production/ui/progression/rank_regular.png"),
	preload("res://assets/production/ui/progression/rank_high_roller.png"),
	preload("res://assets/production/ui/progression/rank_whale.png"),
	preload("res://assets/production/ui/progression/rank_partner.png"),
	preload("res://assets/production/ui/progression/rank_owner.png"),
]
const PANEL: Texture2D = preload("res://assets/production/ui/progression/stats_panel.png")
const PANEL_MARGIN: int = 83
const PANEL_CENTRE := Color("080808")
const DEED: Texture2D = preload("res://assets/production/ui/progression/deed_keys.png")
const ICONS: Dictionary = {
	&"chips": preload("res://assets/production/ui/progression/icon_chips.png"),
	&"coin": preload("res://assets/production/ui/progression/icon_coin.png"),
	&"up": preload("res://assets/production/ui/progression/icon_up.png"),
	&"down": preload("res://assets/production/ui/progression/icon_down.png"),
	&"clock": preload("res://assets/production/ui/progression/icon_clock.png"),
	&"cabinet": preload("res://assets/production/ui/progression/icon_cabinet.png"),
	&"laurel": preload("res://assets/production/ui/progression/icon_laurel.png"),
	&"flame": preload("res://assets/production/ui/progression/icon_flame.png"),
}
## Shared surface colours, matching the floor and cabinet decks.
const SURFACE := Color("0e0b0df5")
const BRASS := Color("c8a34b")
const BRASS_DIM := Color("6e5225")
const IVORY := Color("f1e8d8")
const MUTED := Color("b8ad9c")
## Losses are stated in a muted red, never a warning red and never celebrated.
const DOWN := Color("b9636a")


static func medallion(tier_index: int) -> Texture2D:
	return RANK_MEDALLIONS[clampi(tier_index, 0, RANK_MEDALLIONS.size() - 1)]


static func icon(icon_id: StringName) -> Texture2D:
	return ICONS.get(icon_id, ICONS[&"coin"]) as Texture2D


## A square, mipmapped icon that never eats mouse events.
static func icon_rect(icon_id: StringName, at: Vector2, edge: float) -> TextureRect:
	var rect := TextureRect.new()
	# `expand_mode` is set before the texture: assigning a texture first would
	# raise the minimum size to the master's 256 px and clamp the size below.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = icon(icon_id)
	rect.custom_minimum_size = Vector2.ZERO
	rect.position = at
	rect.size = Vector2(edge, edge)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## The painted ledger frame as a nine-slice, drawn at the scale its brass rule
## needs to stay one crisp line at the virtual canvas.
static func panel_frame(at: Vector2, dimensions: Vector2, art_scale: float = 0.25) -> NinePatchRect:
	var frame := NinePatchRect.new()
	frame.name = "LedgerFrame"
	frame.texture = PANEL
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(side, PANEL_MARGIN)
	frame.position = at
	frame.scale = Vector2(art_scale, art_scale)
	frame.size = dimensions / art_scale
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame
