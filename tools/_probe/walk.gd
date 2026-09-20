extends SceneTree

func _init() -> void:
	var room := FloorRoomLayout.load_room(&"main_floor")
	var line := ""
	for y: int in range(240, 520, 12):
		line = "%3d " % y
		for x: int in range(300, 680, 12):
			line += "." if room.is_walkable(Vector2(x, y)) else "#"
		print(line)
	for name: String in ["solids"]:
		for s: Dictionary in room.solids:
			var r := Rect2(s.points[0], Vector2.ZERO)
			for p: Vector2 in s.points:
				r = r.expand(p)
			print(s.name, " ", r)
	quit()
