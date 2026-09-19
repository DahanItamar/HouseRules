extends Node
## Renders the full 52-card deck plus the back at in-game Blackjack card size and a
## 2x close-up row, for visual QA of the reusable PlayingCard deck.
## Usage (windowed, not headless):
##   godot --path . res://tools/capture_card_deck.tscn --resolution 1920x1080 -- --out=<dir>

const CARD_SIZE := Vector2(58, 81)


func _ready() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0f3a2c")
	backdrop.size = Vector2(960, 540)
	add_child(backdrop)
	for suit: int in range(4):
		for rank: int in range(1, 14):
			_add_card(rank, suit, false, Vector2(12 + (rank - 1) * 64, 12 + suit * 88), CARD_SIZE)
	_add_card(1, 0, true, Vector2(790, 364), CARD_SIZE)
	var close_up := [[1, 0], [10, 1], [7, 3], [11, 2], [12, 0], [13, 1]]
	for index: int in range(close_up.size()):
		var entry: Array = close_up[index]
		_add_card(entry[0], entry[1], false, Vector2(12 + index * 124, 364), CARD_SIZE * 2.0)
	_capture.call_deferred()


func _add_card(rank: int, suit: int, hidden: bool, at: Vector2, card_size: Vector2) -> void:
	var card := PlayingCard.new()
	card.size = card_size
	card.position = at
	add_child(card)
	card.configure(rank, suit, hidden)


func _capture() -> void:
	for _frame: int in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_dir := "res://tests/results/screenshots/card_deck"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(
		out_dir.path_join("deck_%dx%d.png" % [image.get_width(), image.get_height()])
	)
	image.save_png(path)
	print("DECK ", path)
	get_tree().quit()
