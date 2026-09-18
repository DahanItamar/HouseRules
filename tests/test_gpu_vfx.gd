extends GutTest


func test_impact_burst_selects_a_supported_particle_backend() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var burst := ImpactBurst.spawn(host, Vector2(12.0, 18.0), Color.GOLD, true)
	assert_true(burst.backend_kind in [ImpactBurst.BACKEND_GPU, ImpactBurst.BACKEND_CPU])
	assert_not_null(burst.particles)
	assert_true(burst.particles is GPUParticles2D or burst.particles is CPUParticles2D)
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		assert_eq(burst.backend_kind, ImpactBurst.BACKEND_CPU)
		assert_true(burst.particles is CPUParticles2D)
	elif burst.backend_kind == ImpactBurst.BACKEND_GPU:
		assert_true(burst.particles is GPUParticles2D)
		assert_true((burst.particles as GPUParticles2D).process_material is ParticleProcessMaterial)


func test_slot_symbol_installs_canvas_shader_without_changing_symbol_state() -> void:
	var symbol := SlotSymbol.new()
	symbol.size = Vector2(120.0, 120.0)
	symbol.symbol_index = 5
	add_child_autofree(symbol)
	assert_true(symbol.shader_backend_active)
	assert_true(symbol.material is ShaderMaterial)
	assert_true((symbol.material as ShaderMaterial).shader.code.contains("shader_type canvas_item"))
	symbol.set_spin_strength(0.75)
	assert_eq(symbol.symbol_index, 5)
	assert_almost_eq(
		float((symbol.material as ShaderMaterial).get_shader_parameter("spin_strength")),
		0.75,
		0.001
	)


func test_slot_symbol_clamps_shader_velocity_parameter() -> void:
	var symbol := SlotSymbol.new()
	add_child_autofree(symbol)
	symbol.set_spin_strength(4.0)
	assert_eq(symbol.spin_strength, 1.0)
	assert_eq(float((symbol.material as ShaderMaterial).get_shader_parameter("spin_strength")), 1.0)
	symbol.set_spin_strength(-2.0)
	assert_eq(symbol.spin_strength, 0.0)
	assert_eq(float((symbol.material as ShaderMaterial).get_shader_parameter("spin_strength")), 0.0)
