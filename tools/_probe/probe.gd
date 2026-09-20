extends SceneTree

func _init() -> void:
	for column: int in [2, 4, 0, 3]:
		var travel := CharacterWalkAtlas.direction_vector(column)
		var max_reach := 0.0
		var min_toe := 999.0
		var passing_flex := 0.0
		var max_slide := 0.0
		var prev := {}
		var steps := 200
		for i: int in range(steps + 1):
			var screen := float(i) * 1.5
			var world := AvatarLegs.world_distance(screen, travel)
			var pose := AvatarLegs.solve(world, travel, column, 1.0, false)
			var body := travel * screen
			for leg: Dictionary in pose["legs"]:
				var d: float = (leg["ankle_3d"] - leg["hip_3d"]).length()
				max_reach = maxf(max_reach, d)
				var lp: float = leg["leg_phase"]
				if lp >= AvatarLegs.STANCE:
					min_toe = minf(min_toe, (leg["toe_3d"] as Vector3).z)
					min_toe = minf(min_toe, (leg["heel_3d"] as Vector3).z)
				if absf(lp - 0.8) < 0.02:
					passing_flex = maxf(passing_flex, rad_to_deg(leg["knee_flex"]))
				var toe_pivot := float(leg["pitch"]) < -0.001
				var pivot: Vector2 = leg["toe"] if toe_pivot else leg["heel"]
				var world_pt := body + pivot
				var key: int = leg["side"]
				if leg["stance"] and prev.has(key) and prev[key][1] and prev[key][2] == toe_pivot:
					max_slide = maxf(max_slide, world_pt.distance_to(prev[key][0]))
				prev[key] = [world_pt, leg["stance"], toe_pivot]
		print("col=%d reach=%.2f/%.2f min_swing_clear=%.2f passing_flex=%.1f slide=%.4f" % [column, max_reach, AvatarLegs.THIGH + AvatarLegs.SHIN, min_toe, passing_flex, max_slide])
	quit()
