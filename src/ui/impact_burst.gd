class_name ImpactBurst
extends CPUParticles2D
## Short presentation-only spark burst used by reveals and result impacts.


static func spawn(parent: Node, at: Vector2, color: Color, strong: bool = false) -> ImpactBurst:
	var burst := ImpactBurst.new()
	burst.name = "ImpactBurst"
	burst.position = at
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 22 if strong else 12
	burst.lifetime = 0.62 if strong else 0.42
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 70.0 if strong else 42.0
	burst.initial_velocity_max = 150.0 if strong else 92.0
	burst.gravity = Vector2(0, 115.0)
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.8 if strong else 2.8
	burst.color = color
	burst.z_index = 40
	parent.add_child(burst)
	burst.emitting = true
	burst.get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(burst.queue_free)
	return burst
