class_name BaccaratHostess
extends CabinetHost
## Velvet Baccarat hostess: an adult woman with long dark-brunette hair in big
## honey-balayage waves, bronzed skin, brown eyes and gold hoops, in a violet
## satin ruched midi dress. She stands behind the far rail at the centre of the
## table; the rail hides her from the hip down, so her figure is registered to
## the rail line, not to her feet.
##
## Beats: calm watch of the shoe while bets go down, a dealing reach toward the
## card lane, a squeeze where she studies the cards, and a warm announcement to
## the player once the coup is known. Presentation-only.

const POSE_IDLE := preload("res://assets/production/characters/hosts/baccarat_hostess.png")
const POSE_DEAL := preload("res://assets/production/characters/hosts/baccarat_hostess_deal.png")
const POSE_SQUEEZE := preload(
	"res://assets/production/characters/hosts/baccarat_hostess_squeeze.png"
)
const POSE_ANNOUNCE := preload(
	"res://assets/production/characters/hosts/baccarat_hostess_announce.png"
)
## Head-registered masters share one 1392x2080 canvas; x=696 is her head centre.
const STANCE_X: float = 696.0
## Source row where the table's far rail crosses her hip.
const RAIL_SOURCE_Y: float = 1030.0
## Head-top (y=40) to rail is 990 source px -> 182 virtual px.
const FIGURE_SCALE: float = 182.0 / 990.0
const DEAL_HOLD_SECONDS: float = 0.9


func _init() -> void:
	name = "BaccaratHostess"
	display_scale = FIGURE_SCALE
	fade_seconds = 0.2
	lean_radians = 0.0
	breath_period = 4.8
	cue_color = BaccaratStyle.BRASS_BRIGHT
	add_pose(_pose(&"idle", POSE_IDLE, Rect2(495, 40, 522, 1989)))
	add_pose(_pose(&"deal", POSE_DEAL, Rect2(219, 40, 919, 1989)))
	add_pose(_pose(&"squeeze", POSE_SQUEEZE, Rect2(442, 40, 521, 1990)))
	add_pose(_pose(&"announce", POSE_ANNOUNCE, Rect2(203, 41, 919, 1988)))
	rest_pose = &"idle"


## Places the rail anchor at `rail_point` inside this control.
func place_on_rail(rail_point: Vector2, lane_size: Vector2) -> void:
	size = lane_size
	anchor_point = rail_point
	if is_node_ready():
		_layout_sprites()


func _layout_sprites() -> void:
	super._layout_sprites()
	# The shared cue bar sits under the anchor; the rail would hide it here, so
	# the reduced-motion cue rides just above the rail line instead.
	if _cue != null:
		_cue.position.y = anchor_point.y - 10.0


## Cards leave the shoe: reach toward the card lane, then hold while they land.
func deal_cards(hold_seconds: float = DEAL_HOLD_SECONDS) -> void:
	play_beat(&"deal", [[&"deal", hold_seconds], [&"idle", -1.0]])


## The cards are being squeezed: she studies them until the next beat.
func squeeze_cards() -> void:
	play_beat(&"squeeze", [[&"squeeze", -1.0]])


func announce_result() -> void:
	play_beat(&"announce", [[&"announce", -1.0]])


## Bets reopen: back to watching the shoe.
func open_betting() -> void:
	_stop_beat()
	last_beat = &"idle"
	show_pose(rest_pose)


static func _pose(id: StringName, texture: Texture2D, used: Rect2) -> Pose:
	return Pose.new(id, texture, Vector2(STANCE_X, RAIL_SOURCE_Y), used)
