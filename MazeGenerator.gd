extends Node2D
class_name MazeGenerator

@export var tilemap: TileMapLayer
@export var width: int = 120
@export var height: int = 80
@export var floor_tile: Vector2i = Vector2i(10, 16)
@export var wall_tile: Vector2i = Vector2i(10, 15)
@export var ceiling_tile: Vector2i = Vector2i(9, 15)
@export var exit_tile: Vector2i = Vector2i(11, 16)
@export var seed_value: int = 12345
@export var tunnel_min_height: int = 5
@export var tunnel_min_width: int = 5
@export var room_chance: float = 0.3
@export var iterations: int = 90

# 0 = floor, 1 = wall, 2 = exit
var map: Array = []  # Array[Array[int]]

func _ready() -> void:
	generate_maze()
	_draw_map()

func generate_maze() -> void:
	seed(seed_value) # Deterministic; remove this if you want random each run.

	map.resize(height)
	for y: int in range(height):
		var row: Array = []
		row.resize(width)
		for x: int in range(width):
			row[x] = 1
		map[y] = row

	var start: Vector2i = Vector2i(width // 2, height // 2)
	map[start.y][start.x] = 0
	var prev_center: Vector2i = start

	for i: int in range(iterations):
		var room_w: int = randi_range(tunnel_min_width + 2, tunnel_min_width + 8)
		var room_h: int = randi_range(tunnel_min_height + 2, tunnel_min_height + 8)

		# Choose candidate top-left based on previous center with bounded random offset
		var base_x: int = prev_center.x + randi_range(-20, 20)
		var base_y: int = prev_center.y + randi_range(-10, 10)
		var room_x: int = clampi(base_x, 2, width - room_w - 2)
		var room_y: int = clampi(base_y, 2, height - room_h - 2)

		_dig_room(room_x, room_y, room_w, room_h)

		var new_center: Vector2i = Vector2i(room_x + room_w // 2, room_y + room_h // 2)
		_connect_rooms(prev_center, new_center)
		prev_center = new_center

	# Mark a random exit near the bottom
	var exit_x: int = randi_range(5, width - 5)
	var exit_y: int = height - 2
	map[exit_y][exit_x] = 2

func _dig_room(x: int, y: int, w: int, h: int) -> void:
	for j: int in range(y, y + h):
		if j < 0 or j >= height:
			continue
		for i: int in range(x, x + w):
			if i < 0 or i >= width:
				continue
			map[j][i] = 0

func _connect_rooms(a: Vector2i, b: Vector2i) -> void:
	var cx: int = a.x
	var cy: int = a.y
	while cx != b.x:
		map[cy][cx] = 0
		cx += signi(b.x - cx)
	while cy != b.y:
		map[cy][cx] = 0
		cy += signi(b.y - cy)

func _draw_map() -> void:
	if tilemap == null:
		push_error("TileMap not assigned!")
		return

	tilemap.clear()
	var source_id: int = 0

	for y: int in range(height):
		for x: int in range(width):
			var cell_type: int = map[y][x]
			var pos: Vector2i = Vector2i(x, y)
			match cell_type:
				1:
					tilemap.set_cell(pos, source_id, wall_tile)
				0:
					tilemap.set_cell(pos, source_id, floor_tile)
				2:
					tilemap.set_cell(pos, source_id, exit_tile)

	# Decorative edges
	for y: int in range(1, height - 1):
		for x: int in range(1, width - 1):
			if map[y][x] == 0:
				if map[y - 1][x] == 1:
					tilemap.set_cell(Vector2i(x, y - 1), source_id, ceiling_tile)
				if map[y][x - 1] == 1 and randf() < 0.1:
					tilemap.set_cell(Vector2i(x - 1, y), source_id, wall_tile)
				if map[y][x + 1] == 1 and randf() < 0.1:
					tilemap.set_cell(Vector2i(x + 1, y), source_id, wall_tile)
