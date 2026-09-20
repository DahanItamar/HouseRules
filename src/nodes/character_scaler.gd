class_name CharacterScaler
extends RefCounted
## The one rule for how tall a person is drawn in a room.
##
## A room is a painting seen from a fixed camera, so a person's size is decided
## by how far down the screen their feet are: the room's depth ramp runs from
## `avatar_scale_far` at the top of its walk bounds to `avatar_scale_near` at the
## bottom, and is calibrated against the adults painted into that room.
##
## The ramp alone is not enough. A ramp is four numbers in a JSON file, and a
## wrong number there is invisible until someone looks at the screen: the
## Manager's Office once shipped a 2.6-3.2 ramp, which drew the player 148-183 px
## tall in a 540 px room -- a third of the screen height, towering over the
## painted furniture. Nothing failed, because nothing was checking.
##
## So this class does not only compute the scale, it states what a believable
## person may measure and clamps to it. `drawn_height_px()` converts a scale into
## the height the player actually occupies on the virtual canvas, and
## `BAND_MIN_PX`/`BAND_MAX_PX` are the range an adult may occupy anywhere in any
## room. `tests/test_character_scale.gd` walks every room at every depth and
## fails if a ramp leaves the band, so the office bug cannot come back quietly.

## The player's painted figure inside one atlas cell, head to sole, in source px.
const FIGURE_PX: float = 197.0
## The sprite's own scale; `FloorAvatar.GUEST_SCALE` is the same number.
const SPRITE_SCALE: float = 0.29

## What one adult may measure on the 960x540 virtual canvas, head to sole.
##
## The floor of the band is the far end of the Main Floor, where a guest stands
## against the back wall; the ceiling is the near end of the High Roller Salon,
## whose camera stands closest. Anything outside this is a mistake, not a style.
const BAND_MIN_PX: float = 50.0
const BAND_MAX_PX: float = 112.0

## The Manager is allowed to read as the biggest person in the room, but he is
## still a man standing on a floor. He gets a modest lift over a standard adult
## at the same depth, never a different order of size.
const BOSS_MODIFIER: float = 1.2
const BOSS_MODIFIER_MAX: float = 1.25


## The room's depth ramp at a foot height of `y`, before any clamping.
static func ramp_at(room: FloorRoomLayout, y: float) -> float:
	return room.avatar_scale_at(y)


## The height an adult drawn at `scale` occupies on the virtual canvas.
static func drawn_height_px(scale: float) -> float:
	return FIGURE_PX * SPRITE_SCALE * scale


## The scale that draws an adult exactly `height` px tall.
static func scale_for_height(height: float) -> float:
	return height / (FIGURE_PX * SPRITE_SCALE)


## True when `scale` draws an adult at a believable size for a room.
static func is_in_band(scale: float) -> bool:
	var height := drawn_height_px(scale)
	return height >= BAND_MIN_PX - 0.001 and height <= BAND_MAX_PX + 0.001


## The scale to draw a person at, given the room, their feet and who they are.
##
## `boss` lifts the Manager over a standard adult at the same depth; the lift is
## capped so "imposing" can never become "out of perspective".
static func scale_at(room: FloorRoomLayout, y: float, boss: bool = false) -> float:
	var scale := ramp_at(room, y)
	if boss:
		scale *= minf(BOSS_MODIFIER, BOSS_MODIFIER_MAX)
	return clampf(scale, scale_for_height(BAND_MIN_PX), scale_for_height(BAND_MAX_PX))
