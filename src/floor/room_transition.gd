class_name RoomTransition
extends Node
## Themed, presentation-only passage between floor rooms.
##
## Confirming an entry locks floor input and walks the avatar onto the threshold
## (up the Grand Staircase, into the lift, through the office door). A code-drawn
## overlay closes over the room, FloorController.enter_room switches the
## environment behind it, and the overlay opens while the avatar steps out of
## the entry into the new room. Input comes back when the step finishes.
##
## Wallet, save and the single avatar are never touched here: enter_room does
## the actual switch. Reduced motion replaces the whole passage with a short
## warm crossfade and no walking. Headless runs switch instantly unless a test
## turns `animations_enabled` on. A direct enter_room call (developer warps)
## cancels a passage in flight and wins.

signal started(room_id: StringName, kind: StringName)
signal finished(room_id: StringName)
## The room has switched behind the closed overlay and the avatar stands in the entry.
signal switched(room_id: StringName)
signal walk_settled

const OVERLAY_SCRIPT := preload("res://src/ui/transitions/room_transition_overlay.gd")
const LIFT := &"lift"
const STAIRS := &"stairs"
const DOOR := &"door"
const DIP := &"dip"
const CROSSFADE := &"crossfade"
const OVERLAY_LAYER: int = 90
## Which themed passage leads to each wing from the Main Floor.
const ENTRY_KINDS: Dictionary = {
	&"high_roller": STAIRS,
	&"vip": LIFT,
	&"manager_office": DOOR,
}
## The threshold of each wing's entry in virtual pixels: on the Main Floor (the
## avatar walks here from the approach anchor) and inside the wing (the avatar
## steps out from here to the wing's spawn). They sit on the painted stair base,
## lift doors and door leaves, so they are deliberately inside furniture.
const THRESHOLDS: Dictionary = {
	&"high_roller": {"floor": Vector2(136, 250), "room": Vector2(480, 482)},
	&"vip": {"floor": Vector2(864, 194), "room": Vector2(480, 394)},
	&"manager_office": {"floor": Vector2(896, 255), "room": Vector2(480, 494)},
}
## Seconds for each phase: the walk before the overlay starts, closing, the
## held cover while the room switches, and opening onto the new room.
const TIMINGS: Dictionary = {
	LIFT: {"lead": 0.14, "cover": 0.38, "hold": 0.14, "reveal": 0.4},
	STAIRS: {"lead": 0.12, "cover": 0.34, "hold": 0.04, "reveal": 0.4},
	DOOR: {"lead": 0.12, "cover": 0.36, "hold": 0.08, "reveal": 0.4},
	DIP: {"lead": 0.06, "cover": 0.24, "hold": 0.04, "reveal": 0.3},
	CROSSFADE: {"lead": 0.0, "cover": 0.1, "hold": 0.0, "reveal": 0.12},
}
## A brisk final approach; the step out of the entry is a normal walking pace.
const WALK_IN_PACE: float = 1.15
const STEP_OUT_PACE: float = 1.0
## The stair climb drifts the view a few pixels and zooms just enough that the
## drift never exposes the edge of the painted room.
const STAIR_DRIFT: float = 8.0
const STAIR_ZOOM: float = 0.035
## A slow disk can hold the switch behind the closed overlay, never for longer.
const PREFETCH_TIMEOUT: float = 1.5

## Off in headless runs so existing flows stay synchronous; tests may enable it.
var animations_enabled: bool = DisplayServer.get_name() != "headless"
## The visual in flight (CROSSFADE under reduced motion) and its theme, which
## also picks the sound: the lift still chimes when the doors are a crossfade.
var kind: StringName = &""
var theme: StringName = &""
var target_room: StringName = &""
var _floor: FloorController
var _layer: CanvasLayer
var _overlay: Control
var _active: bool = false
var _switching: bool = false
var _run: int = 0
var _tween: Tween
var _indicator_tween: Tween
var _walk_path := PackedVector2Array()
var _walk_speed: float = 0.0
var _arrival := Vector2.ZERO
var _camera: Camera2D
var _camera_offset := Vector2.ZERO
var _camera_zoom := Vector2.ONE
var _restore_physics: bool = true
var _restore_input: bool = true
var _restore_prompts: bool = true
var _held: Array[Resource] = []
var _pending_paths: Array[String] = []


func _init() -> void:
	name = "RoomTransition"


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "RoomTransitionLayer"
	_layer.layer = OVERLAY_LAYER
	_layer.visible = false
	add_child(_layer)
	_overlay = OVERLAY_SCRIPT.new() as Control
	_layer.add_child(_overlay)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


func bind(floor_controller: FloorController) -> void:
	_floor = floor_controller


func is_active() -> bool:
	return _active


## True only while this passage itself is calling FloorController.enter_room.
func is_switching() -> bool:
	return _switching


func overlay() -> Control:
	return _overlay


## The themed passage between two rooms; every wing connects to the Main Floor.
static func themed_kind(from_id: StringName, to_id: StringName) -> StringName:
	var wing := to_id if from_id == FloorController.MAIN_FLOOR else from_id
	return ENTRY_KINDS.get(wing, DIP)


## Starts a passage to `room_id`. Returns false (and does nothing) while one is
## already running, so a second confirm can never double-trigger.
func travel(room_id: StringName) -> bool:
	if _active or _floor == null or _floor.room == null or _floor.room.id == room_id:
		return false
	if not animations_enabled:
		_floor.enter_room(room_id)
		return true
	_run += 1
	_play(room_id, _run)
	return true


## Ends a passage at once: overlay gone, camera and input restored.
func cancel() -> void:
	if not _active:
		return
	_run += 1
	_kill_tweens()
	if not _walk_path.is_empty() and target_room == _floor.room.id:
		_place_avatar(_arrival)
	_walk_path.clear()
	_end()


func _play(room_id: StringName, run: int) -> void:
	var from_id := _floor.room.id
	var via_entry := _is_at_entry(from_id, room_id)
	theme = themed_kind(from_id, room_id) if via_entry else DIP
	kind = CROSSFADE if MotionPolicy.is_reduced() else theme
	target_room = room_id
	_active = true
	_lock()
	_request_textures(room_id)
	_overlay.call("begin", kind, from_id == FloorController.MAIN_FLOOR)
	_camera = _floor.get_node_or_null("FloorCamera") as Camera2D
	if _camera != null:
		_camera_offset = _camera.offset
		_camera_zoom = _camera.zoom
	started.emit(room_id, kind)
	if kind != CROSSFADE and via_entry:
		_start_walk(_walk_in_path(from_id, room_id), WALK_IN_PACE)
	if theme == STAIRS:
		AudioService.play(&"stair_steps")
	if not await _pause(_timing(&"lead"), run):
		return
	if kind == LIFT:
		_run_indicator()
	if not await _sweep(0.0, 1.0, _timing(&"cover"), run):
		return
	if not await _await_textures(run):
		return
	_switch(from_id, room_id)
	if not await _pause(_timing(&"hold"), run):
		return
	if kind != CROSSFADE and not MotionPolicy.is_reduced():
		_start_walk(PackedVector2Array([_arrival]), STEP_OUT_PACE)
	if theme == LIFT:
		AudioService.play(&"lift_chime")
	if not await _sweep(1.0, 2.0, _timing(&"reveal"), run):
		return
	if not _walk_path.is_empty():
		await walk_settled
		if run != _run:
			return
	_end()
	finished.emit(room_id)


func _switch(from_id: StringName, room_id: StringName) -> void:
	_walk_path.clear()
	_switching = true
	_floor.enter_room(room_id)
	_switching = false
	_held.clear()
	_arrival = _floor.avatar_position
	if theme == DOOR:
		AudioService.play(&"door_latch")
	if kind != CROSSFADE and not MotionPolicy.is_reduced():
		# Stand in the entry, already facing into the room, ready to step out.
		var start := _entry_point(room_id, from_id)
		_place_avatar(start)
		_face(_arrival - start)
	switched.emit(room_id)


func _timing(phase: StringName) -> float:
	var active_kind := CROSSFADE if MotionPolicy.is_reduced() else kind
	return float((TIMINGS[active_kind] as Dictionary)[phase])


func _pause(seconds: float, run: int) -> bool:
	if seconds > 0.0:
		_tween = create_tween()
		_tween.tween_interval(seconds)
		await _tween.finished
	return run == _run and _active


func _sweep(from: float, to: float, seconds: float, run: int) -> bool:
	_tween = create_tween()
	var closing := to <= 1.0
	var step := _tween.tween_method(_apply_progress, from, to, seconds)
	match kind:
		STAIRS:
			# Accelerate into the switch and decelerate out of it, so the flight
			# never pauses at full cover.
			step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN if closing else Tween.EASE_OUT)
		DOOR:
			step.set_trans(Tween.TRANS_QUAD if closing else Tween.TRANS_CUBIC).set_ease(
				Tween.EASE_IN if closing else Tween.EASE_OUT
			)
		LIFT:
			step.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_:
			step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	return run == _run and _active


func _apply_progress(value: float) -> void:
	_overlay.set("progress", value)
	if kind != STAIRS or _camera == null or MotionPolicy.is_reduced():
		return
	# Climbing, the view rises: the old room slides down and away, and the new
	# one arrives from slightly below. Descending mirrors it.
	var rise := -1.0 if target_room != FloorController.MAIN_FLOOR else 1.0
	var amount := value if value <= 1.0 else value - 2.0
	_camera.offset = _camera_offset + Vector2(0.0, rise * STAIR_DRIFT * amount)
	_camera.zoom = _camera_zoom * (1.0 + STAIR_ZOOM * absf(amount))


func _run_indicator() -> void:
	var cover := _timing(&"cover")
	_indicator_tween = create_tween()
	_indicator_tween.tween_interval(cover * 0.45)
	_indicator_tween.tween_property(
		_overlay, "indicator", 1.0, cover * 0.55 + _timing(&"hold") + _timing(&"reveal") * 0.25
	)


func _lock() -> void:
	_restore_physics = _floor.is_physics_processing()
	_restore_input = _floor.is_processing_unhandled_input()
	var prompts: Variant = _floor.get("_floor_prompts_visible")
	_restore_prompts = prompts if prompts is bool else true
	_floor.set_physics_process(false)
	_floor.set_process_unhandled_input(false)
	_floor.set_prompt_visible(false)
	_layer.visible = true


func _end() -> void:
	_active = false
	_held.clear()
	_pending_paths.clear()
	_kill_tweens()
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset
		_camera.zoom = _camera_zoom
	_camera = null
	_overlay.set("progress", 0.0)
	_layer.visible = false
	if is_instance_valid(_floor):
		_floor.set_physics_process(_restore_physics)
		_floor.set_process_unhandled_input(_restore_input)
		_floor.set_prompt_visible(_restore_prompts)
		_floor.refresh_proximity()


func _kill_tweens() -> void:
	for tween: Tween in [_tween, _indicator_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_tween = null
	_indicator_tween = null


## A themed passage only when the avatar is actually at the entry; the room
## Back control used from elsewhere in a wing takes the plain dip.
func _is_at_entry(from_id: StringName, to_id: StringName) -> bool:
	var anchor := _approach_anchor(from_id, to_id)
	return _floor.avatar_position.distance_to(anchor) <= FloorController.INTERACTION_RADIUS


func _approach_anchor(from_id: StringName, to_id: StringName) -> Vector2:
	if from_id != FloorController.MAIN_FLOOR:
		return _floor.room.anchor(FloorController.EXIT_ANCHOR)
	if to_id == FloorController.OFFICE:
		return _floor.room.anchor(FloorController.OFFICE_DOOR_ANCHOR)
	return FloorController.WING_POSITIONS.get(to_id, _floor.room.spawn)


func _walk_in_path(from_id: StringName, to_id: StringName) -> PackedVector2Array:
	var anchor := _approach_anchor(from_id, to_id)
	var path := PackedVector2Array()
	if _floor.avatar_position.distance_to(anchor) > 2.0:
		path.append(anchor)
	path.append(_entry_point(from_id, to_id))
	return path


## The threshold inside `room_id` for the passage between it and `other_id`.
func _entry_point(room_id: StringName, other_id: StringName) -> Vector2:
	if room_id == FloorController.MAIN_FLOOR:
		return (THRESHOLDS[other_id] as Dictionary)["floor"]
	return (THRESHOLDS[room_id] as Dictionary)["room"]


func _start_walk(path: PackedVector2Array, pace: float) -> void:
	_walk_path = path
	var scale := _floor.room.avatar_scale if _floor.room != null else 1.0
	_walk_speed = FloorController.SPEED * scale * pace


func _process(delta: float) -> void:
	if _walk_path.is_empty() or not is_instance_valid(_floor):
		return
	var budget := _walk_speed * minf(delta, FloorController.MAX_FRAME_DELTA)
	var point := _floor.avatar_position
	while budget > 0.0 and not _walk_path.is_empty():
		var target := _walk_path[0]
		var gap := point.distance_to(target)
		if gap <= budget:
			point = target
			budget -= gap
			_walk_path.remove_at(0)
		else:
			point = point.move_toward(target, budget)
			budget = 0.0
	_step_avatar(point)
	if _walk_path.is_empty():
		walk_settled.emit()


## Moves the avatar and plays its walk: the visual advances its gait and facing
## from the real displacement, exactly as FloorController.move_avatar does.
func _step_avatar(point: Vector2) -> void:
	var displacement := point - _floor.avatar_position
	_place_avatar(point)
	_face(displacement)


func _place_avatar(point: Vector2) -> void:
	_floor.avatar_position = point
	_floor.move_avatar(Vector2.ZERO, 0.0)


func _face(displacement: Vector2) -> void:
	var visual: Node = _floor.get("_avatar_visual")
	if visual != null and visual.has_method("set_motion") and not displacement.is_zero_approx():
		visual.call("set_motion", displacement)


## Loads the destination's 4K layers on a thread while the avatar walks in, and
## holds them until enter_room has taken its own references, so the switch
## behind the closed overlay never waits on disk.
func _request_textures(room_id: StringName) -> void:
	_held.clear()
	_pending_paths.clear()
	var layout := FloorRoomLayout.load_room(room_id)
	for path: String in [layout.background_path, layout.foreground_path]:
		if path.is_empty():
			continue
		if ResourceLoader.has_cached(path):
			_held.append(load(path))
		elif ResourceLoader.load_threaded_request(path) == OK:
			_pending_paths.append(path)


func _await_textures(run: int) -> bool:
	var waited := 0.0
	for path: String in _pending_paths:
		while (
			ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
			and waited < PREFETCH_TIMEOUT
		):
			await get_tree().process_frame
			waited += get_process_delta_time()
			if run != _run or not _active:
				return false
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_held.append(ResourceLoader.load_threaded_get(path))
	_pending_paths.clear()
	return run == _run and _active


## Turning reduced motion on mid-passage finishes the current phase at once and
## drops the walking; the rest runs on the crossfade timings.
func _on_motion_preference_changed(reduced: bool) -> void:
	if not reduced or not _active:
		return
	if _camera != null:
		_camera.offset = _camera_offset
		_camera.zoom = _camera_zoom
	if not _walk_path.is_empty():
		_place_avatar(_walk_path[_walk_path.size() - 1])
		_walk_path.clear()
		walk_settled.emit()
	if _tween != null and _tween.is_valid():
		_tween.custom_step(10.0)
