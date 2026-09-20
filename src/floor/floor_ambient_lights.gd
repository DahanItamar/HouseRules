class_name FloorAmbientLights
extends AmbientLayer
## Ambient life for the painted floor rooms, authored per room in
## `data/floors/<room>.json` next to the room's anchors and occluders:
##
## - "lights": every painted lamp, sconce and fan light breathes as a soft
##   additive pool (alpha at most POOL_ALPHA_CAP), each on its own 3-7 s period
##   and phase. Some pools carry a few dust motes rising through the light.
## - "ceiling_shadows": one or two soft lobed shapes (a fixture or fan above
##   the camera) drift and turn slowly over open carpet.
## - "glints": a slow light sweep crosses brass signage every 8-15 s, masked by
##   the painted brass so the streak stays on the metal.
## - "screen_sparkles": painted cabinet screens catch a rare tiny sparkle.
##
## A soft contact shadow follows the player's feet and gait. It only reads the
## floor's `avatar_position` and the avatar's public walk state; it never moves
## or changes the avatar.
##
## Depth: pools and motes draw above the depth layer (lamp light falls on
## people and furniture fronts alike) but under every prompt and HUD layer.
## Shade, contact shadow and screen sparkles lie on the room itself, under the
## depth layer, so object fronts and people cover them correctly.

const LIGHT_Z: int = 3
const SHADE_Z: int = 1
const SURFACE_Z: int = 1
## The floor draws a flat band of Color("0c0b0d9c") behind the top HUD. Light in
## that band is scaled by what the band lets through, as if drawn under it.
const HUD_BAND_HEIGHT: float = 72.0
const HUD_BAND_TRANSMISSION: float = 1.0 - 156.0 / 255.0
const GLINT_SECONDS: float = 1.9
const GLINT_TINT := Color("ffe7b3")
const SPARK_SECONDS: float = 0.75
const SPARK_TINT := Color("e8f4ff")
const MOTE_ALPHA_CAP: float = 0.22
const MOTE_TINT := Color("f6dfa8")
const CONTACT_ALPHA: float = 0.30
const CONTACT_RADII := Vector2(15.0, 5.0)
const CONTACT_TINT := Color("050406")
## Lamps farther than this many pool radii no longer push the contact shadow.
const CONTACT_LIGHT_REACH: float = 2.2
const DEFAULT_PERIOD: float = 4.8
const DEFAULT_FLICKER: float = 0.3

static var _room_data: Dictionary = {}

var room_id: StringName = &""
var surface_canvas: Node2D
var _floor: Node2D
var _background: Texture2D
var _light_at := PackedVector2Array()
var _light_radius := PackedFloat32Array()
var _light_squash := PackedFloat32Array()
var _light_color := PackedColorArray()
var _light_strength := PackedFloat32Array()
var _light_period := PackedFloat32Array()
var _light_phase := PackedFloat32Array()
var _light_flicker := PackedFloat32Array()
var _light_motes := PackedInt32Array()
var _shadow_at := PackedVector2Array()
var _shadow_radius := PackedFloat32Array()
var _shadow_squash := PackedFloat32Array()
var _shadow_lobes := PackedInt32Array()
var _shadow_spin := PackedFloat32Array()
var _shadow_sway := PackedVector2Array()
var _shadow_sway_period := PackedFloat32Array()
var _shadow_alpha := PackedFloat32Array()
var _glint_rect: Array[Rect2] = []
var _glint_interval := PackedFloat32Array()
var _glint_phase := PackedFloat32Array()
var _glints: Array[AmbientSweep] = []
var _spark_at := PackedVector2Array()
var _last_avatar := Vector2.INF


## Parsed ambience section of a room file, cached per room.
static func room_ambience(target_room: StringName) -> Dictionary:
	if not _room_data.has(target_room):
		var path := "res://data/floors/%s.json" % target_room
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var data: Dictionary = parsed if parsed is Dictionary else {}
		_room_data[target_room] = {
			"lights": data.get("lights", []),
			"ceiling_shadows": data.get("ceiling_shadows", []),
			"glints": data.get("glints", []),
			"screen_sparkles": data.get("screen_sparkles", []),
		}
	return _room_data[target_room]


func _setup() -> void:
	name = "FloorAmbience"
	light_canvas.z_index = LIGHT_Z
	shade_canvas.z_index = SHADE_Z
	surface_canvas = Node2D.new()
	surface_canvas.name = "AmbientSurfaceSparks"
	surface_canvas.z_index = SURFACE_Z
	surface_canvas.material = light_canvas.material
	surface_canvas.draw.connect(_draw_surface)
	add_child(surface_canvas)


## Follows `floor` (a FloorController) through every room change.
func bind(controller: Node2D) -> void:
	_floor = controller
	if controller.has_signal(&"room_changed"):
		controller.connect(&"room_changed", configure)


func _ready() -> void:
	super._ready()
	if _floor != null and _floor.get("room") != null:
		configure(StringName(_floor.get("room").get("id")))


func configure(target_room: StringName) -> void:
	room_id = target_room
	var data := room_ambience(target_room)
	_parse_lights(data["lights"])
	_parse_shadows(data["ceiling_shadows"])
	_spark_at = PackedVector2Array()
	for pair: Array in data["screen_sparkles"]:
		_spark_at.append(Vector2(float(pair[0]), float(pair[1])))
	_background = null
	if _floor != null and _floor.get("room") != null:
		_background = _floor.get("room").call("background")
	_build_glints(data["glints"])
	_advance()
	_redraw_all()


func _process(delta: float) -> void:
	if reduced_motion:
		# Everything is frozen except the contact shadow, which follows the feet.
		var feet := _avatar_feet()
		if not feet.is_equal_approx(_last_avatar):
			_last_avatar = feet
			shade_canvas.queue_redraw()
		return
	super._process(delta)
	surface_canvas.queue_redraw()


func apply_motion_preference(reduced: bool) -> void:
	super.apply_motion_preference(reduced)
	if surface_canvas != null:
		surface_canvas.queue_redraw()


func light_count() -> int:
	return _light_at.size()


func light_position(index: int) -> Vector2:
	return _light_at[index]


func light_radius(index: int) -> float:
	return _light_radius[index]


func light_alpha(index: int, at_time: float = elapsed) -> float:
	if reduced_motion:
		return clampf(_light_strength[index], 0.0, POOL_ALPHA_CAP)
	return pool_alpha(
		_light_strength[index],
		_light_flicker[index],
		at_time,
		_light_period[index],
		_light_phase[index]
	)


func glint_count() -> int:
	return _glints.size()


func glint_rect(index: int) -> Rect2:
	return _glint_rect[index]


## Streak strength of glint `index` at `at_time`: zero outside its sweep.
func glint_strength(index: int, at_time: float = elapsed) -> float:
	if reduced_motion:
		return 0.0
	var local := fposmod(at_time - _glint_phase[index], _glint_interval[index])
	if local >= GLINT_SECONDS:
		return 0.0
	return SWEEP_ALPHA_CAP * sin(PI * local / GLINT_SECONDS)


## Elapsed time of the next glint sweep start at or after `after`.
func next_glint_time(after: float = elapsed) -> float:
	var best := INF
	for index: int in range(_glints.size()):
		var interval := _glint_interval[index]
		var cycles := ceilf((after - _glint_phase[index]) / interval)
		best = minf(best, _glint_phase[index] + maxf(cycles, 0.0) * interval)
	return best if best < INF else after


func spark_alpha(index: int, at_time: float = elapsed) -> float:
	if reduced_motion:
		return 0.0
	var cycle := 3.4 + hash01(index * 7 + 3) * 4.6
	var local := fposmod(at_time + hash01(index * 13 + 11) * cycle, cycle)
	if local >= SPARK_SECONDS:
		return 0.0
	return SPARK_ALPHA_CAP * 0.8 * sin(PI * local / SPARK_SECONDS)


func shadow_count() -> int:
	return _shadow_at.size()


func shadow_center(index: int, at_time: float = elapsed) -> Vector2:
	if reduced_motion:
		return _shadow_at[index]
	var sway := sin(at_time / _shadow_sway_period[index] * TAU)
	var drift := cos(at_time / (_shadow_sway_period[index] * 1.618) * TAU)
	return _shadow_at[index] + Vector2(_shadow_sway[index].x * sway, _shadow_sway[index].y * drift)


func sample_alpha_peaks(at_time: float) -> Dictionary:
	var peaks := {"pool": 0.0, "shadow": 0.0, "sweep": 0.0, "spark": 0.0}
	for index: int in range(_light_at.size()):
		peaks["pool"] = maxf(peaks["pool"], light_alpha(index, at_time))
		for mote: int in range(_light_motes[index]):
			peaks["spark"] = maxf(peaks["spark"], _mote_state(index, mote, at_time).z)
	for index: int in range(_shadow_at.size()):
		peaks["shadow"] = maxf(peaks["shadow"], minf(_shadow_alpha[index], SHADOW_ALPHA_CAP))
	for index: int in range(_glints.size()):
		peaks["sweep"] = maxf(peaks["sweep"], glint_strength(index, at_time))
	for index: int in range(_spark_at.size()):
		peaks["spark"] = maxf(peaks["spark"], spark_alpha(index, at_time))
	return peaks


func pool_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for index: int in range(_light_at.size()):
		var half := Vector2(_light_radius[index], _light_radius[index] * _light_squash[index])
		bounds.append(Rect2(_light_at[index] - half, half * 2.0))
	return bounds


func moving_effect_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for index: int in range(_shadow_at.size()):
		var reach := _shadow_radius[index] * 1.1 + _shadow_sway[index].length()
		bounds.append(Rect2(_shadow_at[index] - Vector2(reach, reach), Vector2(reach, reach) * 2.0))
	bounds.append_array(_glint_rect)
	for point: Vector2 in _spark_at:
		bounds.append(Rect2(point - Vector2(4, 4), Vector2(8, 8)))
	return bounds


func _processes_when_reduced() -> bool:
	return true


func _advance() -> void:
	for index: int in range(_glints.size()):
		var strength := glint_strength(index)
		var local := fposmod(elapsed - _glint_phase[index], _glint_interval[index])
		_glints[index].show_progress(lerpf(-0.2, 1.2, local / GLINT_SECONDS), strength)


func _redraw_all() -> void:
	light_canvas.queue_redraw()
	shade_canvas.queue_redraw()
	surface_canvas.queue_redraw()


func _draw_light(canvas: Node2D) -> void:
	var texture := falloff_texture()
	for index: int in range(_light_at.size()):
		var alpha := light_alpha(index)
		var center := _light_at[index]
		var half := Vector2(_light_radius[index], _light_radius[index] * _light_squash[index])
		_draw_banded(canvas, texture, Rect2(center - half, half * 2.0), _light_color[index], alpha)
		if reduced_motion:
			continue
		for mote: int in range(_light_motes[index]):
			var state := _mote_state(index, mote, elapsed)
			var size := 1.2 + hash01(index * 97 + mote * 5) * 0.9
			var band := HUD_BAND_TRANSMISSION if state.y < HUD_BAND_HEIGHT else 1.0
			canvas.draw_texture_rect(
				texture,
				Rect2(Vector2(state.x, state.y) - Vector2(size, size) * 0.5, Vector2(size, size)),
				false,
				Color(MOTE_TINT, state.z * band)
			)


func _draw_surface() -> void:
	if reduced_motion:
		return
	for index: int in range(_spark_at.size()):
		var alpha := spark_alpha(index)
		if alpha <= 0.0:
			continue
		var point := _spark_at[index]
		if point.y < HUD_BAND_HEIGHT:
			alpha *= HUD_BAND_TRANSMISSION
		draw_spark(surface_canvas, point, 2.2, SPARK_TINT, alpha)


func _draw_shade(canvas: Node2D) -> void:
	var texture := falloff_texture()
	for index: int in range(_shadow_at.size()):
		_draw_ceiling_shadow(canvas, texture, index)
	_draw_contact_shadow(canvas, texture)


func _draw_ceiling_shadow(canvas: Node2D, texture: Texture2D, index: int) -> void:
	var center := shadow_center(index)
	var radius := _shadow_radius[index]
	var squash := _shadow_squash[index]
	var lobes := _shadow_lobes[index]
	var spin := 0.0
	if not reduced_motion and _shadow_spin[index] > 0.0:
		spin = elapsed / _shadow_spin[index] * TAU
	var tint := Color(0.0, 0.0, 0.0, minf(_shadow_alpha[index], SHADOW_ALPHA_CAP))
	var lobe_size := Vector2(radius * 0.95, radius * 0.34)
	for lobe: int in range(lobes):
		var angle := spin + float(lobe) * TAU / float(lobes)
		var direction := Vector2(cos(angle), sin(angle) * squash)
		var screen_angle := direction.angle()
		var lobe_center := center + direction * radius * 0.55
		var flatten := lerpf(1.0, squash, absf(sin(angle)))
		canvas.draw_set_transform(lobe_center, screen_angle, Vector2(1.0, flatten))
		canvas.draw_texture_rect(texture, Rect2(-lobe_size * 0.5, lobe_size), false, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_contact_shadow(canvas: Node2D, texture: Texture2D) -> void:
	var avatar := _avatar_node()
	if avatar == null or not avatar.visible:
		return
	var feet := avatar.position
	_last_avatar = feet
	var scale_factor := avatar.scale.x
	var radii := CONTACT_RADII * scale_factor
	var stretch := Vector2.ONE
	var facing := Vector2.RIGHT
	if not reduced_motion and bool(avatar.get("is_walking")):
		# Feet apart at each footfall lengthen the shadow along the stride.
		var phase := float(avatar.get("walk_phase"))
		var stride := absf(cos(phase))
		var heading: Variant = avatar.get("facing")
		if heading is Vector2 and not (heading as Vector2).is_zero_approx():
			facing = heading as Vector2
		stretch = Vector2(1.0 + 0.12 * stride, 1.0 - 0.06 * stride)
	# The nearest lamp pushes the shadow a little away from itself.
	var offset := Vector2.ZERO
	for index: int in range(_light_at.size()):
		var away := feet - _light_at[index]
		var reach := _light_radius[index] * CONTACT_LIGHT_REACH
		var distance := away.length()
		if distance < reach and distance > 0.01:
			var push := (1.0 - distance / reach) * 3.0 * scale_factor
			offset += away / distance * push
	offset = offset.limit_length(3.5 * scale_factor)
	var angle := facing.angle() if not stretch.is_equal_approx(Vector2.ONE) else 0.0
	var squash_angle := Vector2(cos(angle), sin(angle) * (radii.y / radii.x)).angle()
	canvas.draw_set_transform(feet + Vector2(offset.x, offset.y * 0.4), squash_angle, stretch)
	canvas.draw_texture_rect(
		texture, Rect2(-radii, radii * 2.0), false, Color(CONTACT_TINT, CONTACT_ALPHA)
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mote `mote` of light `index`: (x, y, alpha). Motes rise slowly through the
## pool and fade in and out, so the loop never pops.
func _mote_state(index: int, mote: int, at_time: float) -> Vector3:
	var key := index * 131 + mote * 17
	var radius := _light_radius[index]
	var travel := radius * 1.3
	var speed := 2.2 + hash01(key + 1) * 2.4
	var progress := fposmod(at_time * speed / travel + hash01(key + 2), 1.0)
	var sideways := (hash01(key + 3) * 2.0 - 1.0) * radius * 0.6
	var wander := sin(at_time * (0.4 + hash01(key + 4) * 0.5) + float(mote)) * 2.0
	var center := _light_at[index]
	var y := center.y + radius * _light_squash[index] * 0.7 - progress * travel
	var falloff := 1.0 - clampf(absf(sideways) / radius, 0.0, 1.0)
	# Reduced motion draws no motes at all, so the sampler reports none either.
	var alpha := 0.0
	if not reduced_motion:
		alpha = MOTE_ALPHA_CAP * sin(PI * progress) * (0.45 + 0.55 * falloff)
	return Vector3(center.x + sideways + wander, y, alpha)


## Draws a pool, splitting it at the HUD band edge so the part under the band
## is dimmed exactly as the band dims the painted room.
func _draw_banded(
	canvas: Node2D, texture: Texture2D, area: Rect2, color: Color, alpha: float
) -> void:
	if alpha <= 0.0005:
		return
	if area.position.y >= HUD_BAND_HEIGHT:
		canvas.draw_texture_rect(texture, area, false, Color(color, alpha))
		return
	var texture_size := Vector2(texture.get_size())
	var split := clampf((HUD_BAND_HEIGHT - area.position.y) / area.size.y, 0.0, 1.0)
	var upper := Rect2(area.position, Vector2(area.size.x, area.size.y * split))
	canvas.draw_texture_rect_region(
		texture,
		upper,
		Rect2(Vector2.ZERO, Vector2(texture_size.x, texture_size.y * split)),
		Color(color, alpha * HUD_BAND_TRANSMISSION)
	)
	if split < 1.0:
		var lower := Rect2(
			Vector2(area.position.x, upper.end.y), Vector2(area.size.x, area.size.y - upper.size.y)
		)
		canvas.draw_texture_rect_region(
			texture,
			lower,
			Rect2(
				Vector2(0.0, texture_size.y * split),
				Vector2(texture_size.x, texture_size.y * (1.0 - split))
			),
			Color(color, alpha)
		)


func _avatar_node() -> Node2D:
	if _floor == null:
		return null
	return _floor.get("_avatar_visual") as Node2D


func _avatar_feet() -> Vector2:
	var avatar := _avatar_node()
	return avatar.position if avatar != null else Vector2.INF


func _parse_lights(entries: Array) -> void:
	_light_at = PackedVector2Array()
	_light_radius = PackedFloat32Array()
	_light_squash = PackedFloat32Array()
	_light_color = PackedColorArray()
	_light_strength = PackedFloat32Array()
	_light_period = PackedFloat32Array()
	_light_phase = PackedFloat32Array()
	_light_flicker = PackedFloat32Array()
	_light_motes = PackedInt32Array()
	for entry: Dictionary in entries:
		var at: Array = entry["at"]
		_light_at.append(Vector2(float(at[0]), float(at[1])))
		_light_radius.append(float(entry.get("radius", 24.0)))
		_light_squash.append(float(entry.get("squash", 1.0)))
		_light_color.append(Color(String(entry.get("color", "ffd49a"))))
		_light_strength.append(float(entry.get("strength", 0.07)))
		_light_period.append(float(entry.get("period", DEFAULT_PERIOD)))
		_light_phase.append(float(entry.get("phase", 0.0)))
		_light_flicker.append(float(entry.get("flicker", DEFAULT_FLICKER)))
		_light_motes.append(int(entry.get("motes", 0)))


func _parse_shadows(entries: Array) -> void:
	_shadow_at = PackedVector2Array()
	_shadow_radius = PackedFloat32Array()
	_shadow_squash = PackedFloat32Array()
	_shadow_lobes = PackedInt32Array()
	_shadow_spin = PackedFloat32Array()
	_shadow_sway = PackedVector2Array()
	_shadow_sway_period = PackedFloat32Array()
	_shadow_alpha = PackedFloat32Array()
	for entry: Dictionary in entries:
		var at: Array = entry["at"]
		var sway: Array = entry.get("sway", [0, 0])
		_shadow_at.append(Vector2(float(at[0]), float(at[1])))
		_shadow_radius.append(float(entry.get("radius", 50.0)))
		_shadow_squash.append(float(entry.get("squash", 0.5)))
		_shadow_lobes.append(int(entry.get("lobes", 4)))
		_shadow_spin.append(float(entry.get("spin_period", 0.0)))
		_shadow_sway.append(Vector2(float(sway[0]), float(sway[1])))
		_shadow_sway_period.append(float(entry.get("sway_period", 13.0)))
		_shadow_alpha.append(float(entry.get("alpha", 0.05)))


func _build_glints(entries: Array) -> void:
	for sweep: AmbientSweep in _glints:
		remove_child(sweep)
		sweep.queue_free()
	_glints.clear()
	_glint_rect.clear()
	_glint_interval = PackedFloat32Array()
	_glint_phase = PackedFloat32Array()
	for entry: Dictionary in entries:
		var at: Array = entry["at"]
		var size: Array = entry["size"]
		var area := Rect2(float(at[0]), float(at[1]), float(size[0]), float(size[1]))
		var sweep := AmbientSweep.new()
		sweep.name = "Glint_%s" % String(entry.get("name", str(_glints.size())))
		# Signs cut into the foreground (a portal header) glint above the depth
		# layer; signs on open walls glint on the room surface under people.
		sweep.z_index = LIGHT_Z if bool(entry.get("front", false)) else SURFACE_Z
		(
			sweep
			. configure(
				area,
				_background,
				GLINT_TINT,
				{
					"band": 0.09,
					"slant": 0.45,
					"warm_bias": 1.0,
					"band_height": HUD_BAND_HEIGHT,
					"band_transmission": HUD_BAND_TRANSMISSION,
				}
			)
		)
		add_child(sweep)
		_glints.append(sweep)
		_glint_rect.append(area)
		_glint_interval.append(clampf(float(entry.get("interval", 11.0)), 8.0, 15.0))
		_glint_phase.append(float(entry.get("phase", 0.0)))
