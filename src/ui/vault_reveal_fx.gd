class_name VaultRevealFX
extends Node2D
## Presentation-only reveal stack for the vault. It never owns or mutates game state.

enum Kind { SAFE, MINE }

const SAFE_COLOR := Color("5de4d2")
const SAFE_HIGHLIGHT := Color("e9fff9")
const MINE_COLOR := Color("ef5350")
const DEBRIS_COLOR := Color("8d6257")
const SMOKE_COLOR := Color("39313d")

var kind: Kind = Kind.SAFE
var lifetime: float = 0.54
var elapsed: float = 0.0
var shard_particles: CPUParticles2D
var sparkle_particles: CPUParticles2D
var debris_particles: CPUParticles2D
var smoke_particles: CPUParticles2D


static func spawn(parent: Node, at: Vector2, effect_kind: Kind) -> Node2D:
	var effect := new()
	effect.name = "VaultSafeRevealFX" if effect_kind == Kind.SAFE else "VaultMineRevealFX"
	effect.position = at
	effect.z_index = 42
	effect.kind = effect_kind
	parent.add_child(effect)
	effect._configure()
	return effect


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)


func _configure() -> void:
	lifetime = MotionPolicy.finite_duration(0.54 if kind == Kind.SAFE else 0.78)
	if kind == Kind.SAFE:
		shard_particles = _particle_layer(
			"DiamondShards",
			_make_diamond_texture(),
			1 if MotionPolicy.is_reduced() else 14,
			0.44,
			SAFE_COLOR,
			34.0,
			92.0,
			Vector2(0.0, 92.0),
			0.7,
			1.25
		)
		if not MotionPolicy.is_reduced():
			sparkle_particles = _particle_layer(
				"DiamondSparkles",
				_make_sparkle_texture(),
				8,
				0.34,
				SAFE_HIGHLIGHT,
				24.0,
				64.0,
				Vector2.ZERO,
				0.65,
				1.0
			)
	else:
		debris_particles = _particle_layer(
			"MineDebris",
			_make_debris_texture(),
			1 if MotionPolicy.is_reduced() else 18,
			0.56,
			DEBRIS_COLOR,
			58.0,
			142.0,
			Vector2(0.0, 155.0),
			0.8,
			1.45
		)
		if not MotionPolicy.is_reduced():
			smoke_particles = _particle_layer(
				"MineSmoke",
				_make_smoke_texture(),
				7,
				0.72,
				SMOKE_COLOR,
				18.0,
				38.0,
				Vector2(0.0, -20.0),
				1.5,
				2.8
			)
	set_process(true)
	queue_redraw()
	get_tree().create_timer(lifetime + 0.12).timeout.connect(queue_free)


func _process(delta: float) -> void:
	elapsed = minf(elapsed + delta, lifetime)
	queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	if not reduced:
		return
	for particles: CPUParticles2D in [
		shard_particles, sparkle_particles, debris_particles, smoke_particles
	]:
		if particles != null:
			particles.emitting = false
	visible = false
	set_process(false)
	queue_free()


func _draw() -> void:
	var progress := clampf(elapsed / maxf(lifetime, 0.001), 0.0, 1.0)
	if kind == Kind.SAFE:
		var acknowledge := 1.0 - progress
		draw_arc(Vector2.ZERO, 8.0 + progress * 22.0, 0.0, TAU, 28, Color(SAFE_COLOR, acknowledge * 0.72), 2.0)
		draw_colored_polygon(
			PackedVector2Array([Vector2(0, -8), Vector2(7, 0), Vector2(0, 10), Vector2(-7, 0)]),
			Color(SAFE_HIGHLIGHT, acknowledge * 0.42)
		)
		var ray_length := 10.0 + progress * 12.0
		for ray_index: int in range(4):
			var ray_angle := PI * 0.25 + float(ray_index) * PI * 0.5
			var ray_direction := Vector2.from_angle(ray_angle)
			draw_line(
				ray_direction * (ray_length - 5.0),
				ray_direction * ray_length,
				Color(SAFE_HIGHLIGHT, acknowledge * 0.60),
				1.5
			)
		return
	# The tile owns the anticipation warning. This stack begins at impact: a hot core,
	# expanding shockwave, then physical debris and smoke particle layers.
	var shock_progress := clampf(progress / 0.52, 0.0, 1.0)
	var shock_alpha := pow(1.0 - shock_progress, 2.0)
	draw_circle(Vector2.ZERO, 12.0 * (1.0 - progress), Color(MINE_COLOR, shock_alpha * 0.44))
	draw_arc(
		Vector2.ZERO,
		10.0 + shock_progress * 54.0,
		0.0,
		TAU,
		36,
		Color(MINE_COLOR, shock_alpha * 0.82),
		3.0
	)


func _particle_layer(
	name_value: String,
	texture: Texture2D,
	count: int,
	duration: float,
	color: Color,
	velocity_min: float,
	velocity_max: float,
	gravity: Vector2,
	scale_minimum: float,
	scale_maximum: float
) -> CPUParticles2D:
	var layer := CPUParticles2D.new()
	layer.name = name_value
	layer.one_shot = true
	layer.explosiveness = 0.96
	layer.amount = count
	layer.lifetime = MotionPolicy.finite_duration(duration)
	layer.direction = Vector2.UP
	layer.spread = 180.0
	layer.initial_velocity_min = 0.0 if MotionPolicy.is_reduced() else velocity_min
	layer.initial_velocity_max = 0.0 if MotionPolicy.is_reduced() else velocity_max
	layer.gravity = Vector2.ZERO if MotionPolicy.is_reduced() else gravity
	layer.scale_amount_min = scale_minimum
	layer.scale_amount_max = scale_maximum
	layer.color = color
	layer.texture = texture
	add_child(layer)
	layer.emitting = true
	return layer


func _make_diamond_texture() -> Texture2D:
	var image := Image.create_empty(9, 11, false, Image.FORMAT_RGBA8)
	for y: int in range(11):
		var half_width: int = 4 - absi(y - 5)
		if half_width < 0:
			continue
		for x: int in range(4 - half_width, 5 + half_width):
			image.set_pixel(x, y, SAFE_HIGHLIGHT if x <= 4 else SAFE_COLOR)
	return ImageTexture.create_from_image(image)


func _make_debris_texture() -> Texture2D:
	var image := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	for y: int in range(1, 6):
		for x: int in range(1, 6):
			if x + y >= 3 and x + y <= 9:
				image.set_pixel(x, y, Color("b47b65") if y < 3 else DEBRIS_COLOR)
	return ImageTexture.create_from_image(image)


func _make_sparkle_texture() -> Texture2D:
	var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	for offset: int in range(-4, 5):
		var alpha := 1.0 - absf(float(offset)) / 5.0
		image.set_pixel(4 + offset, 4, Color(SAFE_HIGHLIGHT, alpha))
		image.set_pixel(4, 4 + offset, Color(SAFE_HIGHLIGHT, alpha))
	return ImageTexture.create_from_image(image)


func _make_smoke_texture() -> Texture2D:
	var image := Image.create_empty(13, 13, false, Image.FORMAT_RGBA8)
	var center := Vector2(6, 6)
	for y: int in range(13):
		for x: int in range(13):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= 6.0:
				image.set_pixel(x, y, Color(SMOKE_COLOR, clampf((6.0 - distance) / 6.0, 0.0, 0.62)))
	return ImageTexture.create_from_image(image)
