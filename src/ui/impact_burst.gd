class_name ImpactBurst
extends Node2D
## GPU-first presentation-only spark burst with a compatibility-safe CPU path.

const BACKEND_GPU := "gpu"
const BACKEND_CPU := "cpu"

var backend_kind: String = BACKEND_CPU
var particles: Node2D
var lifetime: float = 0.42


static func spawn(parent: Node, at: Vector2, color: Color, strong: bool = false) -> ImpactBurst:
	var burst := ImpactBurst.new()
	burst.name = "ImpactBurst"
	burst.position = at
	burst.z_index = 40
	parent.add_child(burst)
	burst._configure(color, strong)
	return burst


static func gpu_backend_supported() -> bool:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return false
	# Compatibility has no RenderingDevice, so use Godot's CPU implementation there.
	# Forward+ and Mobile expose a RenderingDevice and can run GPU particles.
	return RenderingServer.get_rendering_device() != null


func _configure(color: Color, strong: bool) -> void:
	lifetime = MotionPolicy.finite_duration(0.62 if strong else 0.42)
	if gpu_backend_supported():
		_configure_gpu(color, strong)
	else:
		_configure_cpu(color, strong)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.2).timeout.connect(queue_free)


func _configure_gpu(color: Color, strong: bool) -> void:
	backend_kind = BACKEND_GPU
	var gpu := GPUParticles2D.new()
	gpu.name = "GPUParticles2D"
	gpu.one_shot = true
	gpu.explosiveness_ratio = 0.9
	gpu.amount = 1 if MotionPolicy.is_reduced() else (22 if strong else 12)
	gpu.lifetime = lifetime
	gpu.visibility_rect = Rect2(-180.0, -180.0, 360.0, 360.0)
	var process := ParticleProcessMaterial.new()
	process.particle_flag_disable_z = true
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = 0.0 if MotionPolicy.is_reduced() else (70.0 if strong else 42.0)
	process.initial_velocity_max = 0.0 if MotionPolicy.is_reduced() else (150.0 if strong else 92.0)
	process.gravity = Vector3.ZERO if MotionPolicy.is_reduced() else Vector3(0.0, 115.0, 0.0)
	process.scale_min = 1.5
	process.scale_max = 3.8 if strong else 2.8
	process.color = color
	gpu.process_material = process
	particles = gpu
	add_child(gpu)


func _configure_cpu(color: Color, strong: bool) -> void:
	backend_kind = BACKEND_CPU
	var cpu := CPUParticles2D.new()
	cpu.name = "CPUParticles2D"
	cpu.one_shot = true
	cpu.explosiveness = 0.9
	cpu.amount = 1 if MotionPolicy.is_reduced() else (22 if strong else 12)
	cpu.lifetime = lifetime
	cpu.direction = Vector2.UP
	cpu.spread = 180.0
	cpu.initial_velocity_min = 0.0 if MotionPolicy.is_reduced() else (70.0 if strong else 42.0)
	cpu.initial_velocity_max = 0.0 if MotionPolicy.is_reduced() else (150.0 if strong else 92.0)
	cpu.gravity = Vector2.ZERO if MotionPolicy.is_reduced() else Vector2(0.0, 115.0)
	cpu.scale_amount_min = 1.5
	cpu.scale_amount_max = 3.8 if strong else 2.8
	cpu.color = color
	particles = cpu
	add_child(cpu)
