class_name HouseLevelHud
extends Control
## The floor HUD's standing plate: rank medallion, tier initial and a slim
## fill toward the next rung, sitting beside the bank plate.
##
## It is deliberately the smallest reading of the ladder in the game - the
## number is short-form ("1.2M / 5M") and the detail lives at the Manager's
## desk and in the ledger. It shows only while the player is on a floor, and
## it is flat near-black and brass with no glow, because it sits over the room.
##
## A new rung raises a card under the plate for a few seconds. With reduced
## motion the card simply appears and leaves; nothing pulses or slides.

const PLATE_SIZE := Vector2(188, 40)
const CARD_SIZE := Vector2(268, 56)
const CARD_SECONDS: float = 3.4
const MEDALLION: float = 26.0

var plate: Panel
var meter: ProgressMeter
var card: Panel
var _medallion: TextureRect
var _initial: Label
var _numbers: Label
var _card_medallion: TextureRect
var _card_title: Label
var _card_note: Label
var _card_tween: Tween
var _card_serial: int = 0


func _init() -> void:
	name = "HouseLevelHud"
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _ready() -> void:
	Progression.standing_changed.connect(refresh)
	Progression.tier_reached.connect(celebrate)
	MotionPolicy.motion_preference_changed.connect(func(_reduced: bool) -> void: refresh())
	refresh()


## Re-reads the ladder. The bar animates on its own when the number moved.
func refresh() -> void:
	var index := Progression.tier_index()
	var tier: Dictionary = HouseLevel.TIERS[index]
	_medallion.texture = ProgressionArt.medallion(index)
	_initial.text = tr(String(tier.initial_key))
	_numbers.text = _numbers_text()
	meter.set_ratio(Progression.tier_ratio())
	tooltip_text = (
		tr("STANDING_TOOLTIP")
		% [tr(String(tier.name_key)), HouseLevel.short_chips(Progression.wagered())]
	)


## The short-form line: progress toward the next rung, or the finished ladder.
func _numbers_text() -> String:
	if Progression.is_max_tier():
		return tr("STANDING_LADDER_COMPLETE")
	return (
		"%s / %s"
		% [
			HouseLevel.short_chips(Progression.wagered()),
			HouseLevel.short_chips(Progression.next_target()),
		]
	)


## The moment a new rung is reached: the card names the tier and the one
## concrete thing it opened.
func celebrate(tier_index: int) -> void:
	refresh()
	var tier: Dictionary = HouseLevel.TIERS[clampi(tier_index, 0, HouseLevel.TIERS.size() - 1)]
	_card_medallion.texture = ProgressionArt.medallion(tier_index)
	_card_title.text = tr("STANDING_NEW_TIER") % tr(String(tier.name_key))
	_card_note.text = tr(String(tier.unlock_key))
	_card_serial += 1
	var serial := _card_serial
	if _card_tween != null:
		_card_tween.kill()
		_card_tween = null
	card.visible = true
	card.modulate = Color.WHITE
	card.position = Vector2(0, PLATE_SIZE.y + 6.0)
	if not MotionPolicy.is_reduced() and DisplayServer.get_name() != "headless":
		card.modulate.a = 0.0
		_card_tween = create_tween()
		_card_tween.tween_property(card, "modulate:a", 1.0, MotionPolicy.finite_duration(0.16))
	await get_tree().create_timer(CARD_SECONDS).timeout
	if serial == _card_serial:
		dismiss_card()


func dismiss_card() -> void:
	if _card_tween != null:
		_card_tween.kill()
		_card_tween = null
	card.visible = false


func card_visible() -> bool:
	return card != null and card.visible


# --- Construction ---------------------------------------------------------------


func _build() -> void:
	plate = _panel(Vector2.ZERO, PLATE_SIZE)
	plate.name = "StandingPlate"
	add_child(plate)
	_medallion = ProgressionArt.icon_rect(&"coin", Vector2(7, 7), MEDALLION)
	_medallion.name = "RankMedallion"
	plate.add_child(_medallion)
	_initial = _label(Vector2(38, 8), Vector2(18, 24), Typography.CONTROL, ProgressionArt.BRASS)
	_initial.name = "TierInitial"
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(_initial)
	_numbers = _label(
		Vector2(58, 5), Vector2(122, 16), Typography.CAPTION, ProgressionArt.MUTED, false
	)
	_numbers.name = "StandingNumbers"
	_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	plate.add_child(_numbers)
	meter = ProgressMeter.new()
	meter.name = "StandingMeter"
	meter.position = Vector2(58, 23)
	meter.size = Vector2(122, 11)
	plate.add_child(meter)
	_build_card()


func _build_card() -> void:
	card = _panel(Vector2(0, PLATE_SIZE.y + 6.0), CARD_SIZE)
	card.name = "TierCard"
	card.visible = false
	add_child(card)
	_card_medallion = ProgressionArt.icon_rect(&"coin", Vector2(9, 9), 38.0)
	_card_medallion.name = "CardMedallion"
	card.add_child(_card_medallion)
	_card_title = _label(Vector2(56, 8), Vector2(202, 22), Typography.CONTROL, ProgressionArt.IVORY)
	_card_title.name = "CardTitle"
	card.add_child(_card_title)
	_card_note = _label(
		Vector2(56, 29), Vector2(202, 20), Typography.CAPTION, ProgressionArt.MUTED, false
	)
	_card_note.name = "CardNote"
	_card_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(_card_note)


func _panel(at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17161a")
	style.border_color = ProgressionArt.BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(
	at: Vector2, dimensions: Vector2, font_size: int, colour: Color, display: bool = true
) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(
		"font", Typography.DISPLAY_FONT if display else Typography.UI_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
