class_name ManagerStandingPanel
extends Control
## The Manager's reading of your standing, on his desk in the office.
##
## Two slim bars: the near one is the next rung, the far one is the whole arc
## toward owning the House. Both are labelled in short-form chips ("1.2M / 5M")
## so the panel stays small and legible on the 960x540 canvas.
##
## It reports; it never pays. The deed itself is bought through the Manager's
## own conversation, which spends the bank through the Wallet.

const RECT := Rect2(626, 84, 286, 132)
const MEDALLION: float = 34.0

var meter: ProgressMeter
var ownership_meter: ProgressMeter
var _panel: Panel
var _medallion: TextureRect
var _tier: Label
var _tier_numbers: Label
var _next: Label
var _ownership_numbers: Label
var _note: Label


func _init() -> void:
	name = "ManagerStandingPanel"
	position = Vector2.ZERO
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _ready() -> void:
	Progression.standing_changed.connect(refresh)
	Progression.house_purchased.connect(refresh)
	refresh()


func panel_rect() -> Rect2:
	return RECT


func show_standing() -> void:
	refresh()
	visible = true


func refresh() -> void:
	if _panel == null:
		return
	var index := Progression.tier_index()
	var tier: Dictionary = HouseLevel.TIERS[index]
	var wagered := Progression.wagered()
	_medallion.texture = ProgressionArt.medallion(index)
	_tier.text = tr(String(tier.name_key))
	if Progression.is_max_tier():
		_tier_numbers.text = tr("STANDING_LADDER_COMPLETE")
		_next.text = tr("STANDING_TOP_RUNG")
	else:
		var next_tier: Dictionary = HouseLevel.TIERS[index + 1]
		_tier_numbers.text = (
			"%s / %s"
			% [HouseLevel.short_chips(wagered), HouseLevel.short_chips(int(next_tier.target))]
		)
		_next.text = tr("STANDING_NEXT") % tr(String(next_tier.name_key))
	meter.set_ratio(Progression.tier_ratio())
	_ownership_numbers.text = (
		"%s / %s"
		% [
			HouseLevel.short_chips(wagered),
			HouseLevel.short_chips(HouseLevel.OWNERSHIP_TARGET),
		]
	)
	ownership_meter.set_ratio(Progression.ownership_ratio())
	_note.text = _note_text()
	_note.add_theme_color_override(
		"font_color", ProgressionArt.BRASS if Progression.house_owned else ProgressionArt.MUTED
	)


func _note_text() -> String:
	if Progression.house_owned:
		return tr("STANDING_HOUSE_OWNED")
	if Progression.is_max_tier():
		return tr("STANDING_DEED_PRICE") % HouseLevel.short_chips(HouseLevel.DEED_PRICE)
	return tr("STANDING_OWN_THE_HOUSE")


# --- Construction ---------------------------------------------------------------


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "StandingPanel"
	_panel.position = RECT.position
	_panel.size = RECT.size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = ProgressionArt.SURFACE
	style.border_color = Color(ProgressionArt.BRASS, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_medallion = ProgressionArt.icon_rect(&"coin", Vector2(14, 12), MEDALLION)
	_medallion.name = "StandingMedallion"
	_panel.add_child(_medallion)
	_tier = _label(Vector2(56, 10), Vector2(160, 24), 18, ProgressionArt.IVORY)
	_tier.name = "StandingTier"
	_tier_numbers = _label(
		Vector2(200, 13), Vector2(72, 20), Typography.CAPTION, ProgressionArt.BRASS
	)
	_tier_numbers.name = "StandingNumbers"
	_tier_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next = _label(
		Vector2(56, 32), Vector2(216, 18), Typography.CAPTION, ProgressionArt.MUTED, false
	)
	_next.name = "StandingNext"
	meter = ProgressMeter.new()
	meter.name = "StandingMeter"
	meter.position = Vector2(14, 54)
	meter.size = Vector2(258, 14)
	_panel.add_child(meter)
	_rule(Vector2(14, 78), RECT.size.x - 28.0)
	var ownership_title := _label(
		Vector2(14, 84), Vector2(180, 18), Typography.CAPTION, ProgressionArt.BRASS
	)
	ownership_title.name = "OwnershipTitle"
	ownership_title.text = tr("STANDING_OWNERSHIP")
	_ownership_numbers = _label(
		Vector2(190, 84), Vector2(82, 18), Typography.CAPTION, ProgressionArt.MUTED, false
	)
	_ownership_numbers.name = "OwnershipNumbers"
	_ownership_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ownership_meter = ProgressMeter.new()
	ownership_meter.name = "OwnershipMeter"
	ownership_meter.position = Vector2(14, 102)
	ownership_meter.size = Vector2(258, 10)
	_panel.add_child(ownership_meter)
	_note = _label(
		Vector2(14, 112), Vector2(258, 18), Typography.CAPTION, ProgressionArt.MUTED, false
	)
	_note.name = "OwnershipNote"
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _label(
	at: Vector2, dimensions: Vector2, font_size: int, colour: Color, display: bool = true
) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	_panel.add_child(label)
	return label


func _rule(at: Vector2, width: float) -> void:
	var rule := ColorRect.new()
	rule.name = "BrassRule"
	rule.color = Color(ProgressionArt.BRASS, 0.6)
	rule.position = at
	rule.size = Vector2(width, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rule)
