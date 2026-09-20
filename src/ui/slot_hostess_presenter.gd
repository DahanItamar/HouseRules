extends CabinetHost
## Elven Court hostess: an adult blonde elf princess (jewelled circlet, emerald-and-
## gold gown) standing in the left lane, turned three-quarters toward the reel
## window on screen-right and presenting it with an open palm.
##
## Motion language: soft 0.18 s cross-fades with a hair of weight shift toward
## the reels. Beats: calm idle (presenting the reels), anticipatory watch while
## the reels spin, clasped-hands anticipation during the real third-reel beat, a
## raised-hand win reaction, a brief look to the player after any result, and a
## neutral reset. Presentation-only; CabinetPanel names every beat.

const POSE_IDLE := preload("res://assets/production/characters/hosts/slot_elf_princess.png")
const POSE_REELS := preload("res://assets/production/characters/hosts/slot_elf_princess_reels.png")
const POSE_ANTICIPATION := preload(
	"res://assets/production/characters/hosts/slot_elf_princess_anticipation.png"
)
const POSE_WIN := preload("res://assets/production/characters/hosts/slot_elf_princess_win.png")
const POSE_PLAYER := preload(
	"res://assets/production/characters/hosts/slot_elf_princess_player.png"
)

## Lane origin on the cabinet canvas; everything left of the reel window.
const LANE_POSITION := Vector2(0, 100)
const LANE_SIZE := Vector2(164, 330)
## Planted front-slipper anchor inside the lane (canvas y = 424).
const FOOT_POINT := Vector2(30, 324)
## Every pose is aligned to the master on one canvas, so one source anchor and
## one scale keep her stature identical across cross-fades (head-top to hem is
## ~1989 source px -> ~282 px on the 960x540 canvas).
const FIGURE_SCALE: float = 0.142
const SOURCE_FOOT := Vector2(400, 2030)
const WIN_HOLD_SECONDS: float = 1.1
const ACKNOWLEDGE_HOLD_SECONDS: float = 1.2


func _init() -> void:
	name = "SlotHostess"
	position = LANE_POSITION
	size = LANE_SIZE
	display_scale = FIGURE_SCALE
	anchor_point = FOOT_POINT
	fade_seconds = 0.18
	lean_radians = 0.006
	breath_period = 4.2
	cue_color = Color("d8b65a")
	add_pose(Pose.new(&"idle", POSE_IDLE, SOURCE_FOOT, Rect2(216, 48, 1117, 1987)))
	add_pose(Pose.new(&"reels", POSE_REELS, SOURCE_FOOT, Rect2(217, 48, 1120, 1989)))
	add_pose(Pose.new(&"anticipation", POSE_ANTICIPATION, SOURCE_FOOT, Rect2(225, 49, 1113, 1986)))
	add_pose(Pose.new(&"win", POSE_WIN, SOURCE_FOOT, Rect2(203, 48, 1138, 1989)))
	add_pose(Pose.new(&"player", POSE_PLAYER, SOURCE_FOOT, Rect2(214, 48, 1124, 1989)))


## Reels start: she turns her gaze to the reel window and holds it.
func watch_spin() -> void:
	play_beat(&"spin", [[&"reels", -1.0]])


## Real third-reel anticipation (first two reels matched): hands clasp.
func anticipate() -> void:
	if last_beat == &"anticipation":
		return
	play_beat(&"anticipation", [[&"anticipation", -1.0]])


## Result: a delighted win reaction, then a look to the player; losses get the
## acknowledgement only. Both settle back to the neutral idle presentation.
func react_to_result(win: bool) -> void:
	if win:
		play_beat(
			&"result_win", [[&"win", WIN_HOLD_SECONDS], [&"player", ACKNOWLEDGE_HOLD_SECONDS]]
		)
	else:
		play_beat(&"result_loss", [[&"player", ACKNOWLEDGE_HOLD_SECONDS]])
