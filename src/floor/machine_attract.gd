class_name MachineAttract
extends Node2D
## Presentation-only ambient identity for a floor machine.
##
## Every machine uses a distinct loop, while reduced motion holds a clear,
## authored frame. This node never reads or changes gameplay/domain state.

enum Kind { SLOT, BLACKJACK, VAULT }

const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const INK := Color("100d11")
const SLOT_RED := Color("a91f3a")
const TABLE_GREEN := Color("16856f")
const VAULT_BLUE := Color("3157a8")
const REDUCED_PHASE: float = 0.22

var kind: Kind = Kind.SLOT
var phase_offset: float = 0.0
var elapsed: float = 0.0
var is_near: bool = false
var reduced_motion: bool = false


func configure(machine_kind: Kind, stagger_phase: float) -> void:
	kind = machine_kind
	phase_offset = fposmod(stagger_phase, 1.0)
	apply_motion_preference(MotionPolicy.is_reduced())
	queue_redraw()


func set_near(value: bool) -> void:
	if is_near == value:
		return
	is_near = value
	queue_redraw()


func apply_motion_preference(reduced: bool) -> void:
	reduced_motion = reduced
	if reduced:
		elapsed = 0.0
	set_process(not reduced)
	queue_redraw()


func visual_phase() -> float:
	if reduced_motion:
		return REDUCED_PHASE
	return fposmod(elapsed / _period() + phase_offset, 1.0)


func emphasis() -> float:
	return 1.0 if not is_near else 1.45


func _process(delta: float) -> void:
	if reduced_motion:
		return
	elapsed += delta
	queue_redraw()


func _period() -> float:
	match kind:
		Kind.SLOT:
			return 1.8
		Kind.BLACKJACK:
			return 2.4
		_:
			return 2.1


func _draw() -> void:
	match kind:
		Kind.SLOT:
			_draw_slot()
		Kind.BLACKJACK:
			_draw_blackjack()
		Kind.VAULT:
			_draw_vault()


func _draw_slot() -> void:
	var phase := visual_phase()
	var strength := emphasis()
	var face := Rect2(-40, -61, 80, 33)
	draw_rect(face, Color(INK, 0.84))
	draw_rect(face, Color(SLOT_RED, 0.64 * strength), false, 1.5)
	for reel: int in range(3):
		var reel_rect := Rect2(-34 + reel * 23, -56, 20, 22)
		draw_rect(reel_rect, Color("f1e8d8e8"))
		draw_rect(reel_rect, Color("4f1822"), false, 1.0)
		var reel_phase := fposmod(phase + float(reel) * 0.24, 1.0)
		var travel := sin(reel_phase * TAU) * (2.0 if not reduced_motion else 0.0)
		var symbol_center := reel_rect.get_center() + Vector2(0, travel)
		if reel == 0:
			draw_circle(symbol_center, 4.2, Color("c82f45"))
		elif reel == 1:
			draw_colored_polygon(
				PackedVector2Array([
					symbol_center + Vector2(0, -5), symbol_center + Vector2(5, 0),
					symbol_center + Vector2(0, 5), symbol_center + Vector2(-5, 0),
				]),
				BRASS
			)
		else:
			draw_rect(Rect2(symbol_center - Vector2(5, 3), Vector2(10, 6)), VAULT_BLUE)
	var active_bulb := int(floor(phase * 6.0)) % 6
	for bulb: int in range(6):
		var bulb_color := Color(BRASS, 0.96 if bulb == active_bulb else 0.32)
		draw_circle(Vector2(-31 + bulb * 12.4, -66), 1.8 * strength, bulb_color)


func _draw_blackjack() -> void:
	var phase := visual_phase()
	var strength := emphasis()
	var feed := sin(phase * TAU) * (4.0 if not reduced_motion else 0.0)
	var shoe := Rect2(-37, -58, 31, 22)
	draw_rect(shoe, Color(INK, 0.9))
	draw_rect(shoe, Color(TABLE_GREEN, 0.72 * strength), false, 1.5)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-9, -53), Vector2(2, -50), Vector2(-3, -36), Vector2(-14, -39),
		]),
		Color("202026")
	)
	_draw_attract_card(Vector2(-3 + feed, -56), -0.13, SLOT_RED, false)
	_draw_attract_card(Vector2(14, -54), 0.12, Color("17161a"), true)
	var edge_x := -1.0 + phase * 30.0
	draw_line(Vector2(edge_x, -57), Vector2(edge_x + 7, -56), Color(BRASS, 0.8 * strength), 1.5)


func _draw_attract_card(at: Vector2, angle: float, pip: Color, dark_suit: bool) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	draw_rect(Rect2(0, 0, 23, 30), Color("eee7db"))
	draw_rect(Rect2(0, 0, 23, 30), Color("6e5225"), false, 1.0)
	draw_circle(Vector2(7, 8), 2.5, Color("17161a") if dark_suit else pip)
	draw_line(Vector2(4, 24), Vector2(18, 24), pip, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vault() -> void:
	var phase := visual_phase()
	var strength := emphasis()
	var center := Vector2(0, -45)
	draw_circle(center, 22, Color(INK, 0.88))
	draw_arc(center, 21, 0.0, TAU, 40, Color(VAULT_BLUE, 0.75 * strength), 2.0, true)
	draw_arc(center, 14, 0.0, TAU, 32, Color("9da8bd90"), 1.5, true)
	var angle := phase * TAU - PI * 0.5
	var scanner_end := center + Vector2.from_angle(angle) * 17.0
	draw_line(center, scanner_end, Color(BRASS, 0.9 * strength), 2.0)
	draw_circle(center, 4.5, VAULT_BLUE)
	draw_circle(center, 1.8, IVORY)
	for index: int in range(3):
		var active := int(floor(phase * 3.0)) == index
		draw_circle(Vector2(-10 + index * 10, -18), 2.0, Color(BRASS, 0.9 if active else 0.3))
