class_name PokerDealerPresenter
extends Node2D
## Presentation-only Hold'em dealer standing centred behind the table's far rail.
##
## Layers (cabinet space, 960x540, keep this node at the origin):
##   1. DealerFigure       the pose masters (rest / deal / reveal / push / player)
##   2. TableRailOccluder  the table's own texture below the far rail edge, so the
##                         padded rail and felt hide her from mid-thigh down
## Her hands stay above the rail line in every pose, so no separate hands layer is
## needed. PokerTablePanel names the beat; MotionPolicy decides how it is shown.
## The node never reads or writes game state.

const CABINET_HOST_SCRIPT := preload("res://src/ui/cabinet_host.gd")
const TABLE_TEXTURE := preload("res://assets/production/poker/poker_table_v1.png")
const POSE_REST := preload("res://assets/production/characters/hosts/poker_dealer.png")
const POSE_DEAL := preload("res://assets/production/characters/hosts/poker_dealer_deal.png")
const POSE_REVEAL := preload("res://assets/production/characters/hosts/poker_dealer_reveal.png")
const POSE_PUSH := preload("res://assets/production/characters/hosts/poker_dealer_push.png")
const POSE_PLAYER := preload("res://assets/production/characters/hosts/poker_dealer_player.png")

## Uniform scale of the 1392x2080 pose masters on the virtual canvas.
const DISPLAY_SCALE: float = 0.095
## Source point (body centre, upper thigh) that sits exactly on the far rail edge.
const SOURCE_RAIL_ANCHOR := Vector2(696, 1600)
## Top edge of the far padded rail, traced from poker_table_v1.png (4k y 760).
## It is level across x 325..650, wider than every pose.
const RAIL_Y: float = 190.0
const RAIL_ANCHOR := Vector2(480, RAIL_Y)
## Deep enough to cover the longest pose (hem ~46 px below the rail).
const OCCLUDER_RECT := Rect2(360, RAIL_Y, 240, 72)
## Painted alpha bounds of each pose master (source pixels).
const USED_REST := Rect2(251, 29, 888, 2035)
const USED_DEAL := Rect2(308, 29, 872, 2035)
const USED_REVEAL := Rect2(235, 29, 913, 2033)
const USED_PUSH := Rect2(291, 29, 804, 2032)
const USED_PLAYER := Rect2(249, 29, 916, 2030)
## Source-pixel hand positions painted in the poses.
const SOURCE_DECK_HAND := Vector2(696, 1393)
const SOURCE_DEAL_HAND := Vector2(570, 1530)
const POSE_FADE_SECONDS: float = 0.12
const SILVER := Color("c9d3de")
## The penthouse's cool night light on the painted figure.
const ROOM_GRADE := Color(0.95, 0.96, 1.0)

var last_gesture: StringName = &"idle"
var awaiting_player: bool = false

var _host: CabinetHost
var _occluder: Polygon2D


static func source_to_table(source_point: Vector2) -> Vector2:
	return RAIL_ANCHOR + (source_point - SOURCE_RAIL_ANCHOR) * DISPLAY_SCALE


## Where every dealt card leaves her hand.
static func card_release_point() -> Vector2:
	return source_to_table(SOURCE_DEAL_HAND)


static func deck_point() -> Vector2:
	return source_to_table(SOURCE_DECK_HAND)


func _ready() -> void:
	_host = CABINET_HOST_SCRIPT.new()
	_host.name = "DealerFigure"
	_host.display_scale = DISPLAY_SCALE
	_host.anchor_point = RAIL_ANCHOR
	_host.pivot_offset = RAIL_ANCHOR
	_host.fade_seconds = POSE_FADE_SECONDS
	_host.breath_period = 3.8
	_host.cue_color = SILVER
	_host.modulate = ROOM_GRADE
	for entry: Array in [
		[&"rest", POSE_REST, USED_REST],
		[&"deal", POSE_DEAL, USED_DEAL],
		[&"reveal", POSE_REVEAL, USED_REVEAL],
		[&"push", POSE_PUSH, USED_PUSH],
		[&"player", POSE_PLAYER, USED_PLAYER],
	]:
		_host.add_pose(CabinetHost.Pose.new(entry[0], entry[1], SOURCE_RAIL_ANCHOR, entry[2]))
	add_child(_host)
	_occluder = Polygon2D.new()
	_occluder.name = "TableRailOccluder"
	_occluder.texture = TABLE_TEXTURE
	_occluder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rect := OCCLUDER_RECT
	var corners := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)
	_occluder.polygon = corners
	# The table is drawn at 960x540 from a 3840x2160 master: UVs are 4x.
	var uvs := PackedVector2Array()
	for corner: Vector2 in corners:
		uvs.append(corner * 4.0)
	_occluder.uv = uvs
	add_child(_occluder)


func host() -> CabinetHost:
	return _host


func current_pose() -> StringName:
	return _host.current_pose if _host != null else &""


## Cards leaving the deck: the dealing pose is held for the deal, then rest.
func play_deal(hold_seconds: float) -> void:
	_play(&"deal", [[&"deal", maxf(hold_seconds, 0.2)]])


## Burn and turn: her own painted card turn over the board.
func play_reveal(hold_seconds: float) -> void:
	_play(&"reveal", [[&"reveal", maxf(hold_seconds, 0.24)]])


## Pushing the pot to the winner, then a look back to the table.
func play_push() -> void:
	_play(&"push", [[&"push", 0.9]])


## She looks up at the player while their decision is awaited.
func set_awaiting_player(waiting: bool) -> void:
	if awaiting_player == waiting:
		return
	awaiting_player = waiting
	if _host == null:
		return
	_host.set_rest_pose(&"player" if waiting else &"rest")


func reset_feedback() -> void:
	last_gesture = &"idle"
	awaiting_player = false
	if _host != null:
		_host.set_rest_pose(&"rest")
		_host.reset_feedback()


func has_active_gesture() -> bool:
	return _host != null and _host.has_active_gesture()


## Painted bounds of the whole figure (including the part the rail hides).
func visual_bounds() -> Rect2:
	return _host.visual_bounds() if _host != null else Rect2()


## The part of the figure visible above the rail.
func visible_bounds() -> Rect2:
	var bounds := visual_bounds()
	bounds.size.y = minf(bounds.size.y, RAIL_Y - bounds.position.y)
	return bounds


func occluder_rect() -> Rect2:
	return OCCLUDER_RECT


func _play(beat: StringName, steps: Array) -> void:
	last_gesture = beat
	if _host != null:
		_host.play_beat(beat, steps)
