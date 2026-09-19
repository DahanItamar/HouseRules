class_name BlackjackDealerPresenter
extends Node2D
## Presentation-only Blackjack dealer standing centred behind the table's far rail.
##
## Layer order (all in cabinet space, 960x540, keep this node at the origin):
##   1. DealerFigure    full pose master (cards / deal / reveal / player)
##   2. TableRailOccluder  a patch of the real table texture below the rail edge,
##                      so the walnut rail and felt hide her from the belt down
##   3. CardShoe        painted shoe on the felt at her left (screen right)
##   4. DealerHands     the same pose's hands, forearms and held cards, cut below
##                      the rail line, so her hands rest in front of the rail on
##                      the felt instead of vanishing behind it
## CabinetPanel names the beat (deal, reveal, decision wait, result, reset) and
## MotionPolicy decides how it is shown. The node never reads or changes game state.

const CABINET_HOST_SCRIPT := preload("res://src/ui/cabinet_host.gd")
const TABLE_TEXTURE := preload("res://assets/production/blackjack/blackjack_table_v2.png")
const SHOE_TEXTURE := preload("res://assets/production/blackjack/props/card_shoe_v2.png")
const POSE_CARDS := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_cards.png"
)
const POSE_DEAL := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_deal.png"
)
const POSE_REVEAL := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_reveal.png"
)
const POSE_PLAYER := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_player.png"
)
const HANDS_CARDS := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_hands_cards.png"
)
const HANDS_DEAL := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_hands_deal.png"
)
const HANDS_REVEAL := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_hands_reveal.png"
)
const HANDS_PLAYER := preload(
	"res://assets/production/blackjack/dealer/blackjack_dealer_v2_salon_hands_player.png"
)

## Uniform scale of the 1360x2048 salon masters on the virtual canvas.
const DISPLAY_SCALE: float = 0.135
## Source point (skirt waistband, body centre) that sits exactly on the far rail edge.
const SOURCE_RAIL_ANCHOR := Vector2(674, 1215)
## Visible top edge of the far walnut rail, traced from blackjack_table_v2.png
## (3840x2160 drawn at 960x540); it is straight across the dealer's lane.
const RAIL_Y: float = 175.25
const RAIL_ANCHOR := Vector2(480, RAIL_Y)
## Table patch redrawn over everything the figure paints below the rail edge.
const OCCLUDER_RECT := Rect2(412, RAIL_Y, 146, 116)
## Painted shoe resting on the felt at the dealer's left (screen right).
const SHOE_RECT := Rect2(546, 178, 84, 63)
## Brass finger slot of the shoe, where every dealt card leaves the shoe.
const SHOE_MOUTH := Vector2(562, 226)
## Painted alpha bounds of each pose master (source pixels).
const USED_CARDS := Rect2(243, 8, 863, 2040)
const USED_DEAL := Rect2(269, 10, 929, 2038)
const USED_REVEAL := Rect2(248, 10, 860, 2038)
const USED_PLAYER := Rect2(244, 15, 866, 2033)
## Source-pixel hand positions painted in each pose master.
const SOURCE_DEAL_HAND := Vector2(1110, 1645)
const SOURCE_REST_HAND := Vector2(734, 1300)
const SOURCE_REVEAL_HAND := Vector2(550, 700)
const POSE_SNAP_SECONDS: float = 0.12
const DEAL_CARD_STAGGER: float = 0.08
const RESULT_HOLD_SECONDS: float = 1.0
const REVEAL_HOLD_SECONDS: float = 0.34
## Result nod: the upper body dips toward the rail by this fraction (~1.3 px at the head).
const NOD_DEPTH: float = 0.008
const REST_CUE_ALPHA: float = 0.0
const BRASS := Color("d9b44a")
## Reduced-motion cue bar, on the felt to the right of the shoe's base.
const CUE_START := Vector2(600, 243)
const CUE_END := Vector2(640, 243)
## A touch of the salon's warm sconce light on the painted figure.
const ROOM_GRADE := Color(0.98, 0.96, 0.93)

var last_gesture: StringName = &"idle"
var awaiting_decision: bool = false

var _host: CabinetHost
var _hands: CabinetHost
var _occluder: Polygon2D
var _shoe: Sprite2D
var _cue: Line2D
var _gesture_tween: Tween
var _nod_tween: Tween
var _gesture_active: bool = false


static func source_to_table(source_point: Vector2) -> Vector2:
	return RAIL_ANCHOR + (source_point - SOURCE_RAIL_ANCHOR) * DISPLAY_SCALE


static func deal_hand_point() -> Vector2:
	return source_to_table(SOURCE_DEAL_HAND)


static func rest_hand_point() -> Vector2:
	return source_to_table(SOURCE_REST_HAND)


static func reveal_hand_point() -> Vector2:
	return source_to_table(SOURCE_REVEAL_HAND)


## Rail height at an x inside the dealer lane (the traced edge is level).
static func rail_y_at(_x: float) -> float:
	return RAIL_Y


## Seconds the dealing pose is held for `card_count` cards leaving the shoe.
static func deal_hold_seconds(card_count: int) -> float:
	return 0.30 + float(clampi(card_count, 1, 8) - 1) * DEAL_CARD_STAGGER


func _ready() -> void:
	_host = _build_host(
		"DealerFigure",
		[
			[&"cards", POSE_CARDS, USED_CARDS],
			[&"deal", POSE_DEAL, USED_DEAL],
			[&"reveal", POSE_REVEAL, USED_REVEAL],
			[&"player", POSE_PLAYER, USED_PLAYER],
		]
	)

	_occluder = Polygon2D.new()
	_occluder.name = "TableRailOccluder"
	_occluder.texture = TABLE_TEXTURE
	_occluder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_occluder)
	_rebuild_occluder()

	# Flat contact shadow where the shoe's walnut base meets the felt.
	var shoe_shadow := Polygon2D.new()
	shoe_shadow.name = "CardShoeShadow"
	var shadow_points := PackedVector2Array()
	var shadow_centre := SHOE_RECT.position + Vector2(SHOE_RECT.size.x * 0.46, SHOE_RECT.size.y - 9)
	for step: int in range(24):
		var angle := TAU * float(step) / 24.0
		shadow_points.append(
			shadow_centre + Vector2(cos(angle) * 38.0, sin(angle) * 5.0).rotated(-0.32)
		)
	shoe_shadow.polygon = shadow_points
	shoe_shadow.color = Color(0.0, 0.02, 0.01, 0.30)
	add_child(shoe_shadow)
	_shoe = Sprite2D.new()
	_shoe.name = "CardShoe"
	_shoe.texture = SHOE_TEXTURE
	_shoe.centered = false
	_shoe.position = SHOE_RECT.position
	_shoe.scale = SHOE_RECT.size / Vector2(SHOE_TEXTURE.get_width(), SHOE_TEXTURE.get_height())
	_shoe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_shoe)

	_hands = _build_host(
		"DealerHands",
		[
			[&"cards", HANDS_CARDS, USED_CARDS],
			[&"deal", HANDS_DEAL, USED_DEAL],
			[&"reveal", HANDS_REVEAL, USED_REVEAL],
			[&"player", HANDS_PLAYER, USED_PLAYER],
		]
	)

	# Reduced motion only: one short brass bar on the felt beside the shoe
	# acknowledges a beat while the dealer holds her static master pose. It never
	# crosses her, the rail or a card lane, and is invisible in full motion.
	_cue = Line2D.new()
	_cue.name = "DealerGestureCue"
	_cue.points = PackedVector2Array([CUE_START, CUE_END])
	_cue.width = 1.5
	_cue.default_color = BRASS
	_cue.modulate.a = REST_CUE_ALPHA
	_cue.antialiased = true
	add_child(_cue)

	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


## Deal (and dealer draw): the dealing pose is held while every new card slides
## out of the shoe mouth past her dealing hand; then she returns to rest.
func play_deal(card_count: int = 1) -> void:
	last_gesture = &"deal"
	_begin_gesture(BRASS)
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	_show_pose(&"deal")
	_gesture_tween = create_tween()
	_gesture_tween.tween_interval(deal_hold_seconds(card_count))
	_gesture_tween.finished.connect(_finish_gesture)


## Hole-card reveal: her own painted card turn, synced to the table flip.
func play_reveal() -> void:
	last_gesture = &"reveal"
	_begin_gesture(BRASS)
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	_show_pose(&"reveal")
	_gesture_tween = create_tween()
	_gesture_tween.tween_interval(REVEAL_HOLD_SECONDS)
	_gesture_tween.tween_callback(_show_pose.bind(&"cards"))
	_gesture_tween.finished.connect(_finish_gesture)


## Win/loss/push acknowledgement: she looks up at the player with one small nod.
func play_result(color: Color, positive: bool) -> void:
	last_gesture = &"result_win" if positive else &"result_loss"
	awaiting_decision = false
	_begin_gesture(color)
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	_show_pose(&"player")
	_play_nod()
	_gesture_tween = create_tween()
	_gesture_tween.tween_interval(RESULT_HOLD_SECONDS)
	_gesture_tween.tween_callback(_show_pose.bind(&"cards"))
	_gesture_tween.finished.connect(_finish_gesture)


## Player decision wait: the dealer looks up at the player between beats.
func set_awaiting_decision(waiting: bool) -> void:
	if awaiting_decision == waiting:
		return
	awaiting_decision = waiting
	if _host == null or _gesture_active or MotionPolicy.is_reduced():
		return
	_show_pose(_rest_pose())


func reset_feedback() -> void:
	_stop_gesture()
	_stop_nod()
	last_gesture = &"idle"
	awaiting_decision = false
	_set_rest_pose()
	if _cue != null:
		_cue.default_color = BRASS
		_cue.modulate.a = REST_CUE_ALPHA


func has_active_gesture() -> bool:
	return _gesture_tween != null and _gesture_tween.is_running()


func current_pose() -> StringName:
	return _host.current_pose if _host != null else &""


func hands_pose() -> StringName:
	return _hands.current_pose if _hands != null else &""


func cue_color() -> Color:
	return _cue.default_color


## Point where each real table card appears: the shoe's brass finger slot.
func card_release_point() -> Vector2:
	return position + SHOE_MOUTH


## The dealing hand the card slides past on its way to the felt.
func card_via_point() -> Vector2:
	return position + deal_hand_point()


func shoe_bounds() -> Rect2:
	return Rect2(position + SHOE_RECT.position, SHOE_RECT.size)


func host() -> CabinetHost:
	return _host


func hands_host() -> CabinetHost:
	return _hands


## Painted bounds of the current pose (full figure, including the part the
## table hides) in cabinet space.
func visual_bounds() -> Rect2:
	var bounds: Rect2 = _host.visual_bounds() if _host != null else Rect2()
	bounds.position += position
	return bounds


## Portion of the dealer that is actually visible above the rail.
func visible_bounds() -> Rect2:
	var bounds := visual_bounds()
	var rail_bottom := RAIL_Y + position.y
	bounds.size.y = minf(bounds.size.y, rail_bottom - bounds.position.y)
	return bounds


func _build_host(node_name: String, poses: Array) -> CabinetHost:
	var figure: CabinetHost = CABINET_HOST_SCRIPT.new()
	figure.name = node_name
	figure.display_scale = DISPLAY_SCALE
	figure.anchor_point = RAIL_ANCHOR
	figure.pivot_offset = RAIL_ANCHOR
	figure.fade_seconds = POSE_SNAP_SECONDS
	figure.breath_period = 3.6
	figure.cue_color = BRASS
	figure.modulate = ROOM_GRADE
	for entry: Array in poses:
		figure.add_pose(CabinetHost.Pose.new(entry[0], entry[1], SOURCE_RAIL_ANCHOR, entry[2]))
	add_child(figure)
	return figure


func _show_pose(id: StringName) -> void:
	_host.show_pose(id)
	_hands.show_pose(id)


func _rest_pose() -> StringName:
	return &"player" if awaiting_decision else &"cards"


func _rebuild_occluder() -> void:
	var points := PackedVector2Array(
		[
			OCCLUDER_RECT.position,
			Vector2(OCCLUDER_RECT.end.x, OCCLUDER_RECT.position.y),
			OCCLUDER_RECT.end,
			Vector2(OCCLUDER_RECT.position.x, OCCLUDER_RECT.end.y),
		]
	)
	var table_scale := (
		Vector2(TABLE_TEXTURE.get_width(), TABLE_TEXTURE.get_height()) / Vector2(960, 540)
	)
	var uvs := PackedVector2Array()
	for point: Vector2 in points:
		uvs.append((point + position) * table_scale)
	_occluder.polygon = points
	_occluder.uv = uvs


func _begin_gesture(color: Color) -> void:
	_stop_gesture()
	_cue.default_color = color
	_cue.modulate.a = REST_CUE_ALPHA


func _play_nod() -> void:
	_stop_nod()
	_nod_tween = create_tween()
	for figure: CabinetHost in [_host, _hands]:
		(
			_nod_tween
			. parallel()
			. tween_property(figure, "scale", Vector2(1.0, 1.0 - NOD_DEPTH), 0.16)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
	for figure: CabinetHost in [_host, _hands]:
		(
			_nod_tween
			. parallel()
			. tween_property(figure, "scale", Vector2.ONE, 0.26)
			. set_delay(0.16)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)


func _stop_nod() -> void:
	if _nod_tween != null and _nod_tween.is_valid():
		_nod_tween.kill()
	_nod_tween = null
	for figure: CabinetHost in [_host, _hands]:
		if figure != null:
			figure.scale = Vector2.ONE


func _play_reduced_cue() -> void:
	# A fixed colour cue acknowledges the event while the dealer pose stays still.
	_gesture_active = false
	_cue.modulate.a = 1.0
	_gesture_tween = create_tween()
	_gesture_tween.tween_interval(MotionPolicy.finite_duration(0.16))
	_gesture_tween.tween_property(
		_cue, "modulate:a", REST_CUE_ALPHA, MotionPolicy.finite_duration(0.12)
	)
	_gesture_tween.finished.connect(_finish_gesture)


func _finish_gesture() -> void:
	_gesture_active = false
	_gesture_tween = null
	if _host != null and not MotionPolicy.is_reduced():
		_show_pose(_rest_pose())


func _stop_gesture() -> void:
	if _gesture_tween != null and _gesture_tween.is_valid():
		_gesture_tween.kill()
	_gesture_tween = null
	_gesture_active = false


func _set_rest_pose() -> void:
	for figure: CabinetHost in [_host, _hands]:
		if figure != null:
			figure.reset_feedback()


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		_stop_gesture()
		_stop_nod()
		_set_rest_pose()
		if _cue != null:
			_cue.modulate.a = REST_CUE_ALPHA
