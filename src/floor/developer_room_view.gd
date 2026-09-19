class_name DeveloperRoomView
extends Control
## Distinct, dev-only wing view used until the locked wings receive playable games.

signal exit_requested

const IVORY := Color("f1e8d8")
const BRASS := Color("c8a34b")
const HIGH_ROLLER := &"high_roller"
const VIP := &"vip"
const HIGH_ROLLER_ART := preload(
	"res://assets/production/environments/high_roller_room.png"
)
const VIP_ART := preload("res://assets/production/environments/vip_room.png")

var room_id: StringName = HIGH_ROLLER
var _title: Label
var _status: Label
var _back: Button


func configure(id: StringName) -> void:
	assert(id == HIGH_ROLLER or id == VIP, "Developer room must be a known casino wing")
	room_id = id


func _ready() -> void:
	name = "DeveloperRoom_%s" % room_id
	position = Vector2.ZERO
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_header()
	_build_back_button()
	if DisplayServer.get_name() != "headless" and not MotionPolicy.is_reduced():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.20).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
	set_process(false)


func _build_background() -> void:
	var background := TextureRect.new()
	background.name = "RoomEnvironment"
	background.texture = HIGH_ROLLER_ART if room_id == HIGH_ROLLER else VIP_ART
	background.size = size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var frame := Panel.new()
	frame.name = "RoomFrame"
	frame.position = Vector2(18, 18)
	frame.size = Vector2(924, 504)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("00000000")
	frame_style.border_color = Color("c8a34b80")
	frame_style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)
	var header_scrim := ColorRect.new()
	header_scrim.name = "HeaderScrim"
	header_scrim.position = Vector2(18, 18)
	header_scrim.size = Vector2(924, 82)
	header_scrim.color = Color("120e10e6")
	header_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_scrim)


func _build_header() -> void:
	_title = Label.new()
	_title.name = "RoomTitle"
	_title.text = "HIGH ROLLER SALON" if room_id == HIGH_ROLLER else "VIP PENTHOUSE"
	_title.position = Vector2(260, 28)
	_title.size = Vector2(440, 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", Typography.DISPLAY)
	_title.add_theme_color_override("font_color", IVORY)
	add_child(_title)

	_status = Label.new()
	_status.name = "RoomStatus"
	_status.text = "DEVELOPMENT PREVIEW - TABLES ARE NOT PLAYABLE YET"
	_status.position = Vector2(280, 72)
	_status.size = Vector2(400, 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", Typography.UI_FONT)
	_status.add_theme_font_size_override("font_size", Typography.CAPTION)
	_status.add_theme_color_override("font_color", BRASS)
	add_child(_status)


func _build_back_button() -> void:
	_back = Button.new()
	_back.name = "BackToMainFloor"
	_back.text = "<  MAIN FLOOR"
	_back.position = Vector2(32, 28)
	_back.size = Vector2(172, 42)
	_back.focus_mode = Control.FOCUS_ALL
	_back.add_theme_font_override("font", Typography.UI_FONT)
	_back.add_theme_font_size_override("font_size", Typography.CONTROL)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("26161d") if state != "pressed" else Color("120d12")
		style.border_color = Color("48c5d5") if state == "focus" else BRASS
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(6)
		_back.add_theme_stylebox_override(state, style)
	_back.pressed.connect(func() -> void: exit_requested.emit())
	add_child(_back)
	ButtonFeedback.attach(_back)
	_back.call_deferred("grab_focus")
