class_name BaccaratTablePanel
extends CabinetPanel
## Velvet Baccarat table. Owns its whole presentation: the violet-and-walnut
## salon, the hostess behind the far rail, the shoe, the Player and Banker hand
## boxes with their cards, five betting spots, the bead road and the violet
## lacquer HUD. Game state is read from the cabinet; the panel never decides a
## coup. It only deals, squeezes and reveals the cards the math already drew,
## and holds settlement until every card is face up.

const BACKDROP := preload("res://assets/production/baccarat/baccarat_salon_backdrop.png")
const SHOE_TEXTURE := preload("res://assets/production/baccarat/baccarat_shoe.png")
const CHIP_TEXTURES := {
	20: preload("res://assets/production/baccarat/baccarat_chip_20.png"),
	40: preload("res://assets/production/baccarat/baccarat_chip_40.png"),
	100: preload("res://assets/production/baccarat/baccarat_chip_100.png"),
	200: preload("res://assets/production/baccarat/baccarat_chip_200.png"),
}
## Top of the far rail in the painted salon; the hostess is hidden below it.
const RAIL_Y: float = 222.0
const HOSTESS_LANE := Rect2(336, 0, 288, 222)
const TITLE_RECT := Rect2(48, 27, 276, 60)
const RESULT_RECT := Rect2(48, 95, 276, 118)
const HELP_RECT := Rect2(770, 27, 142, 44)
const ROAD_ORIGIN := Vector2(636, 79)
const PLAYER_ZONE := Rect2(96, 246, 330, 92)
const BANKER_ZONE := Rect2(534, 246, 330, 92)
const SHOE_RECT := Rect2(444, 252, 72, 60)
const SHOE_MOUTH := Vector2(456, 290)
const SPOT_RECTS := {
	"player_pair": Rect2(96, 346, 116, 82),
	"player": Rect2(220, 346, 176, 82),
	"tie": Rect2(404, 346, 152, 82),
	"banker": Rect2(564, 346, 176, 82),
	"banker_pair": Rect2(748, 346, 116, 82),
}
const DECK_ORIGIN := Vector2(48, 436)
## Unrotated top-left of each card, [hand][slot]; the third card lies sideways.
const CARD_SLOTS := [
	[Vector2(160, 256), Vector2(222, 256), Vector2(299, 256)],
	[Vector2(744, 256), Vector2(682, 256), Vector2(605, 256)],
]
const THIRD_ROTATION: float = PI * 0.5
const DEAL_SECONDS: float = 0.28
const DEAL_GAP: float = 0.07
const SQUEEZE_SECONDS: float = 0.85
const THIRD_SQUEEZE_SECONDS: float = 0.6
const STEP_BEAT: float = 0.25
const REVEAL_BEAT_SECONDS: float = 0.5
const NOTICE_SECONDS: float = 1.8
const HAND_PLAYER: int = 0
const HAND_BANKER: int = 1

var table_math: BaccaratMath
var hostess: BaccaratHostess
var deck: BaccaratDeck
var result_plaque: BaccaratResultPlaque
var bead_road: BaccaratBeadRoad
var zones: Array[BaccaratHandZone] = []
var spots: Dictionary = {}
var cards: Array[BaccaratCard] = []
var shoe: TextureRect
## Presentation phase: idle, dealing, squeeze_player, squeeze_banker,
## third_player, third_banker, revealed.
var phase: StringName = &"idle"
var _built: bool = false
var _card_layer: Control
var _coup: Dictionary = {}
var _coup_result: RoundResult
var _cards_revealed: bool = false
var _deal_tween: Tween
var _reveal_beat: Tween
var _notice: Tween
var _notice_key: String = ""
var _last_spot: String = BaccaratMath.PLAYER


func refresh() -> void:
	if _title == null or cabinet == null or cabinet.context == null:
		return
	if not _built:
		_build_table()
	_title.text = tr("BACCARAT_THEME_TITLE")
	_refresh_status()
	_refresh_deck()
	_refresh_spots()
	_refresh_help()


func _is_betting_open() -> bool:
	return not cabinet.is_round_active and not cabinet.is_result_pending and not help_open


func _build_table() -> void:
	_built = true
	table_math = cabinet.get("math")
	_art_id = cabinet.context.definition.id
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("0b0610")
	for hidden: CanvasItem in [_stake, _detail, _controls, _controls_backdrop, _stake_selector]:
		hidden.hide()
	_art_root.add_child(_texture("BaccaratSalonArt", BACKDROP, Vector2.ZERO, Vector2(960, 540)))
	_build_hostess()
	shoe = TextureRect.new()
	shoe.name = "BaccaratShoe"
	shoe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shoe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shoe.texture = SHOE_TEXTURE
	shoe.position = SHOE_RECT.position
	shoe.size = SHOE_RECT.size
	shoe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shoe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shoe.z_index = 3
	add_child(shoe)
	_build_zones()
	_card_layer = Control.new()
	_card_layer.name = "BaccaratCards"
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.z_index = 5
	add_child(_card_layer)
	_build_spots()
	_build_title_plaque()
	result_plaque = BaccaratResultPlaque.new()
	result_plaque.position = RESULT_RECT.position
	result_plaque.z_index = 4
	add_child(result_plaque)
	bead_road = BaccaratBeadRoad.new()
	bead_road.position = ROAD_ORIGIN
	bead_road.z_index = 4
	add_child(bead_road)
	deck = BaccaratDeck.new()
	deck.position = DECK_ORIGIN
	deck.z_index = 6
	add_child(deck)
	deck.build(CHIP_TEXTURES, cabinet.stake_options())
	deck.chip_chosen.connect(func(amount: int) -> void: cabinet.select_stake(amount))
	deck.clear_pressed.connect(func() -> void: cabinet.call("request_clear"))
	deck.rebet_pressed.connect(func() -> void: cabinet.call("request_rebet"))
	deck.deal_pressed.connect(func() -> void: cabinet.call("request_deal"))
	_style_help_button()
	_wire_focus()
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	_play_art_entrance()
	call_deferred("_focus_default_action")


func _build_hostess() -> void:
	var lane := Control.new()
	lane.name = "HostessLane"
	lane.position = HOSTESS_LANE.position
	lane.size = HOSTESS_LANE.size
	lane.clip_contents = true
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.add_child(lane)
	hostess = BaccaratHostess.new()
	hostess.place_on_rail(
		Vector2(480.0 - HOSTESS_LANE.position.x, HOSTESS_LANE.size.y), HOSTESS_LANE.size
	)
	lane.add_child(hostess)


func _build_zones() -> void:
	zones.append(
		BaccaratHandZone.new("BACCARAT_HAND_PLAYER", PLAYER_ZONE, BaccaratStyle.PLAYER_BLUE, -1)
	)
	zones.append(
		BaccaratHandZone.new("BACCARAT_HAND_BANKER", BANKER_ZONE, BaccaratStyle.BANKER_RED, 1)
	)
	for zone: BaccaratHandZone in zones:
		zone.z_index = 3
		add_child(zone)


func _build_spots() -> void:
	var tints := {
		BaccaratMath.PLAYER_PAIR: BaccaratStyle.PLAYER_BLUE,
		BaccaratMath.PLAYER: BaccaratStyle.PLAYER_BLUE,
		BaccaratMath.TIE: BaccaratStyle.TIE_JADE,
		BaccaratMath.BANKER: BaccaratStyle.BANKER_RED,
		BaccaratMath.BANKER_PAIR: BaccaratStyle.BANKER_RED,
	}
	for id: String in BaccaratMath.SPOTS:
		var spot := BaccaratBetSpot.new(id, SPOT_RECTS[id], tints[id])
		spot.chip_textures = CHIP_TEXTURES
		spot.chip_values = cabinet.stake_options()
		spot.z_index = 4
		spot.place_requested.connect(func(spot_id: String) -> void: _on_spot_pressed(spot_id))
		spot.remove_requested.connect(
			func(spot_id: String) -> void: cabinet.call("request_remove", spot_id)
		)
		spot.focus_entered.connect(_on_spot_focused.bind(id))
		add_child(spot)
		spots[id] = spot


func _build_title_plaque() -> void:
	var plaque := BaccaratPlate.new("BaccaratTitlePlaque", TITLE_RECT)
	plaque.fill = Color(BaccaratStyle.LACQUER, 0.94)
	add_child(plaque)
	move_child(plaque, _title.get_index())
	_title.position = TITLE_RECT.position + Vector2(14, 4)
	_title.size = Vector2(TITLE_RECT.size.x - 28, 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", BaccaratStyle.PEARL)
	_status.position = TITLE_RECT.position + Vector2(14, 34)
	_status.size = Vector2(TITLE_RECT.size.x - 28, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.add_theme_font_size_override("font_size", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.z_index = 1


func _style_help_button() -> void:
	if _help_button == null:
		return
	BaccaratStyle.style_button(_help_button)
	_help_button.position = HELP_RECT.position
	_help_button.size = HELP_RECT.size
	_help_button.add_theme_font_override("font", Typography.UI_FONT)
	_help_button.add_theme_font_size_override("font_size", 14)


## Explicit focus graph shared by D-pad/arrows (native) and WASD/stick
## (navigate()): the five spots form one row, the deck another.
func _wire_focus() -> void:
	var row: Array[Control] = []
	for id: String in BaccaratMath.SPOTS:
		row.append(spots[id])
	_link_row(row)
	_link_row(deck.focus_row())
	for spot: Control in row:
		spot.focus_neighbor_top = spot.get_path()
	for control: Control in deck.focus_row():
		control.focus_neighbor_bottom = control.get_path()
	_help_button.focus_neighbor_bottom = (spots[_last_spot] as Control).get_path()
	_retarget_vertical_links()


func _link_row(row: Array[Control]) -> void:
	for index: int in range(row.size()):
		var control := row[index]
		var left := row[maxi(index - 1, 0)]
		var right := row[mini(index + 1, row.size() - 1)]
		control.focus_neighbor_left = left.get_path()
		control.focus_neighbor_right = right.get_path()


## Down from a spot lands on the selected chip; up from the deck returns to the
## last spot the player used.
func _retarget_vertical_links() -> void:
	if deck == null or spots.is_empty():
		return
	var chip_target: Control = deck.deal_button
	for chip: BaccaratChipButton in deck.chip_buttons:
		if chip.amount == cabinet.selected_stake:
			chip_target = chip
	for id: String in spots:
		(spots[id] as Control).focus_neighbor_bottom = chip_target.get_path()
	var spot_path := (spots[_last_spot] as Control).get_path()
	for control: Control in deck.focus_row():
		control.focus_neighbor_top = spot_path
	_help_button.focus_neighbor_bottom = spot_path


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or spots.is_empty():
		return
	(spots[_last_spot] as Control).grab_focus()


func _on_spot_focused(id: String) -> void:
	_last_spot = id
	_retarget_vertical_links()
	_refresh_spot_text()


func _on_spot_pressed(id: String) -> void:
	_last_spot = id
	cabinet.call("request_place", id)


## WASD / left stick walk the same graph the D-pad uses natively.
func navigate(direction: Vector2i) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not (_owns_control(focused)):
		_focus_default_action()
		return true
	var side := SIDE_LEFT
	match direction:
		Vector2i.RIGHT:
			side = SIDE_RIGHT
		Vector2i.UP:
			side = SIDE_TOP
		Vector2i.DOWN:
			side = SIDE_BOTTOM
	var next := focused.find_valid_focus_neighbor(side)
	if next != null and next != focused:
		next.grab_focus()
		AudioService.play(&"move")
	return true


func _owns_control(control: Control) -> bool:
	return control == _help_button or deck.owns_focus(control) or spots.values().has(control)


## The spot X / right click takes chips back from (the focused one, or the last used).
func focused_spot_id() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	for id: String in spots:
		if spots[id] == focused:
			return id
	return _last_spot


func _refresh_help() -> void:
	if _help_title == null:
		return
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_BACCARAT_RULES")
	_help_controls.text = (
		tr("HELP_BACCARAT_CONTROLS")
		% [
			InputRouter.glyph("move"),
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("tertiary"),
			InputRouter.glyph("back"),
		]
	)


func _refresh_deck() -> void:
	var open := _is_betting_open()
	var total := table_math.total_bet() if open else cabinet.current_stake
	(
		deck
		. refresh_state(
			{
				"balance": cabinet.context.balance,
				"selected": cabinet.selected_stake,
				"total": total,
				"cap": cabinet.bet_cap(),
				"betting_open": open,
				"can_rebet": table_math.can_rebet(cabinet.bet_cap()),
				"test_bank": Wallet.test_mode_enabled,
			}
		)
	)
	_retarget_vertical_links()
	_refresh_spot_text()


func _refresh_spots() -> void:
	var open := _is_betting_open()
	var placed: Dictionary = table_math.bets
	if not open or _cards_revealed:
		placed = _coup.get("bets", table_math.bets) if not _coup.is_empty() else table_math.bets
	for id: String in spots:
		var spot: BaccaratBetSpot = spots[id]
		spot.title_text = tr(spot_name_key(id))
		spot.price_text = price_text(id)
		spot.set_state(int(placed.get(id, 0)), _settle_state_for(id, placed), open)
		spot.queue_redraw()


func _settle_state_for(id: String, placed: Dictionary) -> BaccaratBetSpot.Settle:
	if not _cards_revealed or _coup.is_empty():
		return BaccaratBetSpot.Settle.NONE
	var hit := {"winner": _coup.winner, "player_pair": _coup.player_pair}
	hit["banker_pair"] = _coup.banker_pair
	var back := table_math.returned_for(id, 2, hit)
	if back > 2:
		return BaccaratBetSpot.Settle.WIN
	if back == 2:
		return BaccaratBetSpot.Settle.PUSH
	return BaccaratBetSpot.Settle.LOSE if placed.has(id) else BaccaratBetSpot.Settle.NONE


static func spot_name_key(id: String) -> String:
	return "BACCARAT_SPOT_" + id.to_upper()


func price_text(id: String) -> String:
	if id == BaccaratMath.BANKER:
		return tr("BACCARAT_PRICE_BANKER") % table_math.paytable.banker_commission_percent
	return tr("BACCARAT_PRICE") % table_math.pays_to_one(id)


func _refresh_spot_text() -> void:
	if deck == null or spots.is_empty():
		return
	var id := focused_spot_id()
	deck.set_spot_text("%s · %s" % [tr(spot_name_key(id)), price_text(id)])


func _refresh_status() -> void:
	var text := ""
	if not _notice_key.is_empty():
		text = tr(_notice_key)
	elif cabinet.is_round_active or cabinet.is_result_pending:
		text = tr(_phase_status_key())
	elif _result != null:
		text = _result_status(_result)
	elif cabinet.selected_stake == 0:
		text = tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet
	else:
		text = tr("BACCARAT_STATUS_BETTING")
	_set_live_text(_status, text)


func _phase_status_key() -> String:
	match phase:
		&"squeeze_player":
			return "BACCARAT_STATUS_SQUEEZE_PLAYER"
		&"squeeze_banker":
			return "BACCARAT_STATUS_SQUEEZE_BANKER"
		&"third_player":
			return "BACCARAT_STATUS_THIRD_PLAYER"
		&"third_banker":
			return "BACCARAT_STATUS_THIRD_BANKER"
		&"revealed":
			return "BACCARAT_STATUS_REVEALED"
	return "BACCARAT_STATUS_DEALING"


func _result_status(result: RoundResult) -> String:
	var headline := result_plaque.headline_for(int(result.detail.get("winner", 2)))
	if result.payout > 0:
		return tr("BACCARAT_RESULT_RETURNED") % [headline, result.payout, result.stake]
	return tr("BACCARAT_RESULT_SWEPT") % [headline, result.stake]


## Transient table message (limit reached, nothing to rebet, no chips yet).
func show_notice(key: String) -> void:
	_notice_key = key
	if _notice != null and _notice.is_valid():
		_notice.kill()
	_notice = create_tween()
	_notice.tween_interval(NOTICE_SECONDS)
	_notice.tween_callback(
		func() -> void:
			_notice_key = ""
			refresh()
	)
	refresh()


## The cabinet changed the chips on the layout: last coup's cards leave.
func bets_changed() -> void:
	if _cards_revealed or not cards.is_empty():
		_sweep_table()
	refresh()


func _sweep_table() -> void:
	_clear_cards()
	_coup = {}
	_coup_result = null
	_cards_revealed = false
	_result = null
	phase = &"idle"
	for zone: BaccaratHandZone in zones:
		zone.reset()
	result_plaque.show_waiting()
	_status.add_theme_color_override("font_color", BaccaratStyle.PEARL_MUTED)
	if hostess != null:
		hostess.open_betting()


func _clear_cards() -> void:
	if _deal_tween != null and _deal_tween.is_valid():
		_deal_tween.kill()
	_deal_tween = null
	for card: BaccaratCard in cards:
		card.queue_free()
	cards.clear()


## The coup is already decided; this only deals, squeezes and reveals it.
func begin_deal(result: RoundResult) -> void:
	_sweep_table()
	_coup_result = result
	_coup = result.detail
	phase = &"dealing"
	result_plaque.show_dealing()
	_build_cards()
	AudioService.play(&"card_deal")
	if MotionPolicy.is_reduced():
		_snap_to_revealed()
		return
	_deal_tween = create_tween()
	_deal_tween.tween_callback(hostess.deal_cards)
	for index: int in range(4):
		_tween_deal(_deal_tween, cards[index])
	_deal_tween.tween_interval(STEP_BEAT)
	for hand: int in [HAND_PLAYER, HAND_BANKER]:
		_deal_tween.tween_callback(_begin_squeeze.bind(hand))
		(
			_deal_tween
			. tween_method(_set_peel_for.bind(_first_two(hand)), 0.0, 1.0, SQUEEZE_SECONDS)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
		_deal_tween.tween_callback(_show_total.bind(hand, 2))
		_deal_tween.tween_interval(STEP_BEAT)
	for hand: int in [HAND_PLAYER, HAND_BANKER]:
		var third := _card_at(hand, 2)
		if third == null:
			continue
		_deal_tween.tween_callback(_begin_third.bind(hand))
		_tween_deal(_deal_tween, third)
		_deal_tween.tween_callback(hostess.squeeze_cards)
		(
			_deal_tween
			. tween_method(_set_peel_for.bind([third]), 0.0, 1.0, THIRD_SQUEEZE_SECONDS)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
		_deal_tween.tween_callback(_show_total.bind(hand, 3))
		_deal_tween.tween_interval(STEP_BEAT)
	_deal_tween.tween_callback(_on_cards_revealed)
	refresh()


## Cards in the real dealing order: P1, B1, P2, B2, then any third cards.
func _build_cards() -> void:
	var player: Array = _coup.player_cards
	var banker: Array = _coup.banker_cards
	var order: Array = [
		[HAND_PLAYER, 0, player[0]],
		[HAND_BANKER, 0, banker[0]],
		[HAND_PLAYER, 1, player[1]],
		[HAND_BANKER, 1, banker[1]],
	]
	if player.size() > 2:
		order.append([HAND_PLAYER, 2, player[2]])
	if banker.size() > 2:
		order.append([HAND_BANKER, 2, banker[2]])
	for entry: Array in order:
		var card := BaccaratCard.new(entry[2], entry[0], entry[1])
		card.position = SHOE_MOUTH - BaccaratCard.SIZE * 0.5
		card.rotation = -0.35
		card.scale = Vector2(0.82, 0.82)
		card.visible = false
		_card_layer.add_child(card)
		cards.append(card)


func card_target(hand: int, slot: int) -> Vector2:
	return CARD_SLOTS[hand][slot]


func card_rotation(slot: int) -> float:
	return THIRD_ROTATION if slot == 2 else 0.0


## Screen rectangle a card covers once it has landed (sideways for a third card).
static func slot_rect(hand: int, slot: int) -> Rect2:
	var top_left: Vector2 = CARD_SLOTS[hand][slot]
	if slot < 2:
		return Rect2(top_left, BaccaratCard.SIZE)
	var center := top_left + BaccaratCard.SIZE * 0.5
	var turned := Vector2(BaccaratCard.SIZE.y, BaccaratCard.SIZE.x)
	return Rect2(center - turned * 0.5, turned)


func _tween_deal(tween: Tween, card: BaccaratCard) -> void:
	tween.tween_callback(_launch_card.bind(card))
	(
		tween
		. tween_property(card, "position", card_target(card.hand, card.slot), DEAL_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.parallel().tween_property(card, "rotation", card_rotation(card.slot), DEAL_SECONDS)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, DEAL_SECONDS)
	tween.tween_interval(DEAL_GAP)


func _launch_card(card: BaccaratCard) -> void:
	card.visible = true
	AudioService.play(&"card_deal")


func _begin_squeeze(hand: int) -> void:
	phase = &"squeeze_player" if hand == HAND_PLAYER else &"squeeze_banker"
	hostess.squeeze_cards()
	refresh()


func _begin_third(hand: int) -> void:
	phase = &"third_player" if hand == HAND_PLAYER else &"third_banker"
	hostess.deal_cards(0.5)
	refresh()


func _set_peel_for(value: float, peeled: Array) -> void:
	for card: BaccaratCard in peeled:
		card.set_peel(value)


func _first_two(hand: int) -> Array:
	return [_card_at(hand, 0), _card_at(hand, 1)]


func _card_at(hand: int, slot: int) -> BaccaratCard:
	for card: BaccaratCard in cards:
		if card.hand == hand and card.slot == slot:
			return card
	return null


func _show_total(hand: int, count: int) -> void:
	var key := "player_cards" if hand == HAND_PLAYER else "banker_cards"
	var shown: Array = (_coup[key] as Array).slice(0, count)
	zones[hand].set_total(BaccaratRules.hand_total(shown))
	AudioService.play(&"card_flip")


## Reduced motion or a skipped deal: every card lands face up at once.
func _snap_to_revealed() -> void:
	if _deal_tween != null and _deal_tween.is_valid():
		_deal_tween.kill()
	_deal_tween = null
	for card: BaccaratCard in cards:
		card.visible = true
		card.position = card_target(card.hand, card.slot)
		card.rotation = card_rotation(card.slot)
		card.scale = Vector2.ONE
		card.set_peel(1.0)
	_show_total(HAND_PLAYER, (_coup.player_cards as Array).size())
	_show_total(HAND_BANKER, (_coup.banker_cards as Array).size())
	_on_cards_revealed()
	var winner: int = _coup.winner
	if winner == BaccaratRules.Winner.TIE:
		for zone: BaccaratHandZone in zones:
			zone.play_cue()
	else:
		zones[HAND_PLAYER if winner == BaccaratRules.Winner.PLAYER else HAND_BANKER].play_cue()


## Test and reduced-motion hook: finish the presentation of the current coup now.
func settle_deal() -> void:
	if not _coup.is_empty() and not _cards_revealed:
		_snap_to_revealed()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		settle_deal()


func _on_cards_revealed() -> void:
	if _cards_revealed or _coup.is_empty():
		return
	_deal_tween = null
	_cards_revealed = true
	phase = &"revealed"
	var winner: int = _coup.winner
	for hand: int in [HAND_PLAYER, HAND_BANKER]:
		var hand_winner := (
			BaccaratRules.Winner.PLAYER if hand == HAND_PLAYER else BaccaratRules.Winner.BANKER
		)
		if winner == BaccaratRules.Winner.TIE:
			zones[hand].set_outcome(tr("BACCARAT_TAG_TIE"), false, false)
		elif winner == hand_winner:
			zones[hand].set_outcome(tr("BACCARAT_TAG_WINS"), true, false)
		else:
			zones[hand].set_outcome("", false, true)
	result_plaque.show_coup(_coup)
	bead_road.push(_coup)
	hostess.announce_result()
	AudioService.play(&"reveal")
	refresh()
	_try_finish_reveal()


func present_result_after_reveal(_result_to_show: RoundResult, on_ready: Callable) -> void:
	_result_reveal_active = true
	_result_reveal_callback = on_ready
	refresh()
	_try_finish_reveal()


func _try_finish_reveal() -> void:
	if not _result_reveal_active or not _cards_revealed:
		return
	if _reveal_beat != null and _reveal_beat.is_running():
		return
	_reveal_beat = create_tween()
	_reveal_beat.tween_interval(MotionPolicy.finite_duration(REVEAL_BEAT_SECONDS))
	_reveal_beat.tween_callback(_finish_reveal)


func _finish_reveal() -> void:
	if not _result_reveal_active:
		return
	_result_reveal_active = false
	var callback := _result_reveal_callback
	_result_reveal_callback = Callable()
	if callback.is_valid():
		callback.call()


func is_revealed() -> bool:
	return _cards_revealed


## Called by MiniGame after CabinetSession has settled the round.
func show_result(result: RoundResult) -> void:
	_result = result
	_status_key = "ROUND_READY"
	var won := result.payout > result.stake
	AudioService.play(&"win" if won else &"loss")
	_play_result_impact(result)
	_win_flash.play(
		_result_flash_tint(result), _last_result_impact_tier == ResultImpactTier.BIG_WIN
	)
	if won:
		var multiple := float(result.payout) / maxf(result.stake, 1.0)
		_celebration.burst(_win_origin(result), 24 if multiple >= 5.0 else 12)
	result_plaque.show_payout(payout_text(result), won)
	refresh()
	_status.add_theme_color_override(
		"font_color", BaccaratStyle.WIN_INK if result.payout > 0 else BaccaratStyle.LOSS_INK
	)


func payout_text(result: RoundResult) -> String:
	var commission: int = result.detail.get("commission", 0)
	var text := ""
	if result.payout == result.stake:
		text = tr("BACCARAT_PAYOUT_PUSH") % result.stake
	elif result.payout > 0:
		text = tr("BACCARAT_PAYOUT_RETURNED") % [result.payout, result.stake]
	else:
		text = tr("BACCARAT_PAYOUT_SWEPT") % result.stake
	if commission > 0:
		text += " · " + tr("BACCARAT_PAYOUT_COMMISSION") % commission
	return text


func _win_origin(result: RoundResult) -> Vector2:
	var winners: Dictionary = result.detail.get("winners", {})
	for id: String in BaccaratMath.SPOTS:
		if winners.has(id):
			return (SPOT_RECTS[id] as Rect2).get_center()
	return Vector2(480, 380)


func set_help_open(open: bool) -> void:
	super.set_help_open(open)
	if _built:
		refresh()
