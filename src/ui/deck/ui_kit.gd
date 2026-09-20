class_name UiKit
extends RefCounted
## The painted, per-game UI kit (assets/production/ui/kit, see ui_kit.json).
##
## Every cabinet theme has a nine-slice deck panel, a nine-slice button plate and a
## round medallion with an empty centre. Textures are preloaded here (the JSON
## manifest is design documentation and is not exported). Each plate records the
## opaque bounds of its art in source pixels and a patch margin that keeps the
## painted corners out of the stretched edges; masters are 1024 px and are drawn
## at a fraction of that so they stay crisp at 4K (mipmapped).

## The theme id for plates every game shares: the art-deco result banner and the
## brass-rimmed score badge. Their whole texture is the nine-patch (they carry their
## own transparent pad), so they record no region.
const SHARED := &"shared"

const THEMES: Dictionary = {
	SHARED:
	{
		"result_banner": preload("res://assets/production/ui/kit/plaque_result_banner.png"),
		"result_banner_margin": 103,
		"score_badge": preload("res://assets/production/ui/kit/plaque_score_badge.png"),
		"score_badge_margin": 90,
	},
	&"blackjack":
	{
		"panel": preload("res://assets/production/ui/kit/panel_blackjack.png"),
		"panel_region": Rect2(35, 35, 955, 936),
		"panel_margin": 118,
		"button": preload("res://assets/production/ui/kit/button_blackjack.png"),
		"button_region": Rect2(53, 54, 918, 903),
		"button_margin": 92,
		"medallion": preload("res://assets/production/ui/kit/medallion_blackjack.png"),
		"medallion_region": Rect2(32, 19, 955, 971),
	},
	&"slot_classic":
	{
		"button": preload("res://assets/production/ui/kit/button_elven.png"),
		"button_region": Rect2(93, 83, 837, 845),
		"button_margin": 129,
		"medallion": preload("res://assets/production/ui/kit/medallion_elven.png"),
		"medallion_region": Rect2(48, 33, 914, 936),
	},
	&"minefield_vault":
	{
		"button": preload("res://assets/production/ui/kit/button_vault.png"),
		"button_region": Rect2(55, 51, 915, 922),
		"button_margin": 124,
		"medallion": preload("res://assets/production/ui/kit/medallion_vault.png"),
		"medallion_region": Rect2(24, 12, 969, 984),
	},
	&"roulette":
	{
		"button": preload("res://assets/production/ui/kit/button_roulette.png"),
		"button_region": Rect2(68, 58, 888, 896),
		"button_margin": 115,
		"medallion": preload("res://assets/production/ui/kit/medallion_roulette.png"),
		"medallion_region": Rect2(44, 32, 925, 943),
	},
	&"upgrade_cluster":
	{
		"panel": preload("res://assets/production/ui/kit/panel_harlequin.png"),
		"panel_region": Rect2(3, 8, 1019, 992),
		"panel_margin": 121,
		"button": preload("res://assets/production/ui/kit/button_harlequin.png"),
		"button_region": Rect2(24, 26, 976, 958),
		"button_margin": 111,
		"medallion": preload("res://assets/production/ui/kit/medallion_harlequin.png"),
		"medallion_region": Rect2(14, 4, 995, 969),
	},
	&"core_overclock":
	{
		"panel": preload("res://assets/production/ui/kit/panel_forno.png"),
		"panel_region": Rect2(10, 18, 1004, 970),
		"panel_margin": 80,
		"button": preload("res://assets/production/ui/kit/button_forno.png"),
		"button_region": Rect2(20, 27, 983, 967),
		"button_margin": 61,
		"medallion": preload("res://assets/production/ui/kit/medallion_forno.png"),
		"medallion_region": Rect2(18, 14, 985, 985),
	},
	&"poker":
	{
		"button": preload("res://assets/production/ui/kit/button_poker.png"),
		"button_region": Rect2(65, 62, 893, 894),
		"button_margin": 128,
		"medallion": preload("res://assets/production/ui/kit/medallion_poker.png"),
		"medallion_region": Rect2(44, 36, 920, 930),
	},
	&"baccarat":
	{
		"button": preload("res://assets/production/ui/kit/button_baccarat.png"),
		"button_region": Rect2(63, 54, 898, 905),
		"button_margin": 130,
		"medallion": preload("res://assets/production/ui/kit/medallion_baccarat.png"),
		"medallion_region": Rect2(45, 31, 922, 940),
	},
	&"match_point":
	{
		"button": preload("res://assets/production/ui/kit/button_match_point.png"),
		"button_region": Rect2(45, 38, 934, 942),
		"button_margin": 120,
		"medallion": preload("res://assets/production/ui/kit/medallion_match_point.png"),
		"medallion_region": Rect2(35, 25, 939, 950),
	},
}


static func has_part(theme_id: StringName, part: String) -> bool:
	return THEMES.has(theme_id) and (THEMES[theme_id] as Dictionary).has(part)


static func texture(theme_id: StringName, part: String) -> Texture2D:
	if not has_part(theme_id, part):
		return null
	return THEMES[theme_id][part] as Texture2D


static func region(theme_id: StringName, part: String) -> Rect2:
	if not has_part(theme_id, part):
		return Rect2()
	return THEMES[theme_id].get(part + "_region", Rect2()) as Rect2


static func margin(theme_id: StringName, part: String) -> int:
	if not has_part(theme_id, part):
		return 0
	return int(THEMES[theme_id].get(part + "_margin", 0))


## The scale that draws this part's painted corner at `corner_px` on the canvas.
## Kits differ in how much of their master the corner ornament takes, so a small
## key made from any theme still shows a frame of the same visual weight.
static func scale_for_corner(theme_id: StringName, part: String, corner_px: float) -> float:
	var slice := margin(theme_id, part)
	if slice <= 0:
		return 0.11
	return corner_px / float(slice)
