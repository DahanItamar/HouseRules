class_name ClusterGrid
extends Control
## The 7x7 board inside its painted harlequin frame. It owns one ClusterTile per
## cell and nothing else: it holds no game state, decides no outcome and never
## asks the domain anything. The panel drives it one phase at a time, and every
## method here finishes what it started before the next phase begins.

signal landed

var columns: int = 7
var tiles: Array[ClusterTile] = []
var _shatter_roots: Array[Node] = []
## Presentation-only scatter. Its own stream, never the cabinet's.
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "ClusterGrid"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# New symbols start above the board and fall in. Clipping to the board is what
	# makes them arrive from behind the painted frame instead of sliding down the
	# stage over the multiplier rail.
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rng.seed = 20260918


func build(size: int) -> void:
	columns = maxi(size, 1)
	position = ClusterTheme.GRID_ORIGIN
	self.size = Vector2.ONE * ClusterTheme.TILE_PITCH * float(columns)
	for tile: ClusterTile in tiles:
		tile.queue_free()
	tiles.clear()
	for index: int in range(columns * columns):
		var tile := ClusterTile.new()
		tile.name = "Tile_%d" % index
		tile.size = Vector2.ONE * ClusterTheme.TILE_SIZE
		tile.rest_position = _rest_position(index)
		tile.position = tile.rest_position
		add_child(tile)
		tiles.append(tile)


func _rest_position(index: int) -> Vector2:
	var column := index % columns
	var row := index / columns
	var inset := (ClusterTheme.TILE_PITCH - ClusterTheme.TILE_SIZE) * 0.5
	return Vector2(column, row) * ClusterTheme.TILE_PITCH + Vector2(inset, inset)


## Shows `grid` at rest, with no motion. Used for the idle board and for any
## state the replay has to snap to (reduced motion, a cancelled round).
func show_grid(grid: PackedByteArray) -> void:
	for index: int in range(mini(tiles.size(), grid.size())):
		var tile := tiles[index]
		tile.set_symbol(int(grid[index]))
		tile.settle()
		tile.position = tile.rest_position
		tile.visible = true


## Phase 1: the winning cells pulse. Nothing else on the board moves.
func pulse(cells: PackedInt32Array) -> void:
	for cell: int in cells:
		if cell >= 0 and cell < tiles.size():
			tiles[cell].pulse()


## Phase 3: the winning cells burst into painted gem shards and leave the board.
func shatter(cells: PackedInt32Array) -> void:
	for cell: int in cells:
		if cell < 0 or cell >= tiles.size():
			continue
		var tile := tiles[cell]
		if not MotionPolicy.is_reduced():
			_scatter(tile)
		tile.shatter()


## Phase 4: `grid` drops into place. Survivors fall to their new cells and new
## symbols arrive from above the board. Emits `landed` once everything is home.
func tumble_to(grid: PackedByteArray, cleared: PackedInt32Array) -> void:
	var was_cleared := PackedByteArray()
	was_cleared.resize(tiles.size())
	for cell: int in cleared:
		if cell >= 0 and cell < was_cleared.size():
			was_cleared[cell] = 1
	var drops := _column_drops(was_cleared)
	var duration := ClusterTheme.phase(ClusterTheme.TUMBLE_SECONDS)
	var tween: Tween = null
	for index: int in range(mini(tiles.size(), grid.size())):
		var tile := tiles[index]
		tile.settle()
		tile.set_symbol(int(grid[index]))
		tile.visible = true
		var drop: int = drops[index]
		if drop <= 0 or MotionPolicy.is_reduced():
			tile.position = tile.rest_position
			continue
		tile.position = tile.rest_position - Vector2(0, float(drop) * ClusterTheme.TILE_PITCH)
		if tween == null:
			tween = create_tween().set_parallel(true)
		(
			tween
			. tween_property(tile, "position", tile.rest_position, duration)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_OUT)
			. set_delay(0.02 * float(index % columns))
		)
	if tween == null:
		landed.emit.call_deferred()
		return
	tween.chain().tween_interval(ClusterTheme.phase(ClusterTheme.SETTLE_SECONDS))
	tween.chain().tween_callback(func() -> void: landed.emit())


## How many rows the tile now at each cell fell, keyed by its cell in the **new**
## grid. Survivors fall past the holes beneath them; the cells that opened at the
## top of a column are new symbols, and they enter from just above the board.
func _column_drops(cleared: PackedByteArray) -> PackedInt32Array:
	var drops := PackedInt32Array()
	drops.resize(tiles.size())
	for column: int in range(columns):
		var holes: int = 0
		var survivor_rows: Array[int] = []
		for row: int in range(columns):
			if cleared[row * columns + column] == 1:
				holes += 1
			else:
				survivor_rows.append(row)
		for slot: int in range(holes):
			drops[slot * columns + column] = holes
		for order: int in range(survivor_rows.size()):
			var landing := holes + order
			drops[landing * columns + column] = landing - survivor_rows[order]
	return drops


func _scatter(tile: ClusterTile) -> void:
	var shards := Control.new()
	shards.name = "Shards"
	shards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shards.position = tile.position + tile.size * 0.5
	add_child(shards)
	_shatter_roots.append(shards)
	var duration := ClusterTheme.phase(ClusterTheme.SHATTER_SECONDS)
	var tween := create_tween().set_parallel(true)
	for index: int in range(5):
		var atlas := AtlasTexture.new()
		atlas.atlas = ClusterTheme.SHARDS
		atlas.region = ClusterTheme.shard_region(_rng.randi_range(0, 15))
		var span := _rng.randf_range(11.0, 17.0)
		var shard := ClusterTheme.plate(
			atlas,
			Rect2(Vector2.ONE * span * -0.5, Vector2.ONE * span),
			"Shard_%d" % index,
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)
		shard.pivot_offset = shard.size * 0.5
		shards.add_child(shard)
		var angle := _rng.randf_range(0.0, TAU)
		var reach := _rng.randf_range(13.0, 28.0)
		var destination := Vector2(cos(angle), sin(angle)) * reach - shard.size * 0.5
		(
			tween
			. tween_property(shard, "position", destination, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		tween.tween_property(shard, "rotation", angle * 1.4, duration)
		tween.tween_property(shard, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(
		func() -> void:
			_shatter_roots.erase(shards)
			shards.queue_free()
	)


## Ends every shard and tile motion at once, leaving the board readable.
func settle() -> void:
	for shards: Node in _shatter_roots:
		if is_instance_valid(shards):
			shards.queue_free()
	_shatter_roots.clear()
	for tile: ClusterTile in tiles:
		tile.settle()
		tile.position = tile.rest_position
		tile.visible = true


func has_active_motion() -> bool:
	if not _shatter_roots.is_empty():
		return true
	for tile: ClusterTile in tiles:
		if tile.is_animating():
			return true
	return false


func _draw() -> void:
	# The stage well the tiles sit in. The painted frame is a sibling drawn by
	# the panel, so the board can never be stretched by it.
	draw_rect(Rect2(Vector2.ZERO, size), ClusterTheme.GRID_WELL)
	for step: int in range(1, columns):
		var offset := float(step) * ClusterTheme.TILE_PITCH
		draw_line(
			Vector2(offset, 2), Vector2(offset, size.y - 2), Color(ClusterTheme.EDGE, 0.16), 1.0
		)
		draw_line(
			Vector2(2, offset), Vector2(size.x - 2, offset), Color(ClusterTheme.EDGE, 0.16), 1.0
		)
