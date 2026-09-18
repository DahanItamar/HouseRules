class_name VaultTile
extends Control
## Physical deposit-box tile with a press-and-flip reveal.

enum Face { HIDDEN, SAFE, MINE }
var face: Face = Face.HIDDEN
var is_flipping: bool = false


func reveal(next_face: Face) -> void:
	if face == next_face and not is_flipping:
		return
	is_flipping = true
	pivot_offset = size * 0.5
	var flip := create_tween()
	flip.tween_property(self, "scale:x", 0.06, 0.10).set_trans(Tween.TRANS_QUAD)
	flip.tween_callback(
		func() -> void:
			face = next_face
			queue_redraw()
	)
	flip.tween_property(self, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_BACK)
	flip.tween_callback(func() -> void: is_flipping = false)


func set_face_immediate(next_face: Face) -> void:
	face = next_face
	scale.x = 1.0
	is_flipping = false
	queue_redraw()


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252126")
	style.border_color = Color("c8a34b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	if face == Face.HIDDEN:
		draw_circle(size * 0.5, 5.0, Color("6e5225"), true, -1.0, true)
		draw_line(size * 0.5 + Vector2(-8, 0), size * 0.5 + Vector2(8, 0), Color("b8ad9c"), 2.0)
	elif face == Face.SAFE:
		draw_circle(size * 0.5, 15.0, Color("073b31"), true, -1.0, true)
		draw_circle(size * 0.5, 11.0, Color("3fc276"), false, 3.0, true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(0, size.y * 0.5 + 6),
			"$",
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			18,
			Color("f1e8d8")
		)
	else:
		var center := size * 0.5
		draw_circle(center, 10.0, Color("d55353"), true, -1.0, true)
		for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(center + direction * 10.0, center + direction * 18.0, Color("d55353"), 3.0, true)
