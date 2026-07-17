class_name GridBoard
extends RefCounted

## Convierte entre el mundo y el tablero, y conoce qué celdas están ocupadas.

var lane_y: PackedFloat32Array
var columns: int
var x_start: float
var column_spacing: float
var click_width: float
var click_height: float
var occupied_cells: Dictionary = {}

func _init(
	board_lanes: PackedFloat32Array,
	board_columns: int,
	board_x_start: float,
	board_column_spacing: float,
	board_click_width: float,
	board_click_height: float
) -> void:
	lane_y = board_lanes
	columns = board_columns
	x_start = board_x_start
	column_spacing = board_column_spacing
	click_width = board_click_width
	click_height = board_click_height

func world_to_cell(world_position: Vector2) -> Vector2i:
	var lane_index: int = get_nearest_lane(world_position.y)
	if lane_index == -1:
		return Vector2i(-1, -1)

	var column: int = int(round((world_position.x - x_start) / column_spacing))
	if column < 0 or column >= columns:
		return Vector2i(-1, -1)
	if absf(world_position.x - cell_to_world(Vector2i(column, lane_index)).x) > click_width * 0.5:
		return Vector2i(-1, -1)
	return Vector2i(column, lane_index)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(x_start + cell.x * column_spacing, lane_y[cell.y])

func is_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(get_cell_key(cell))

func occupy(cell: Vector2i) -> void:
	occupied_cells[get_cell_key(cell)] = true

func release(cell: Vector2i) -> void:
	occupied_cells.erase(get_cell_key(cell))

func get_cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func get_nearest_lane(world_y: float) -> int:
	var nearest_lane: int = -1
	var nearest_distance: float = INF
	for i in range(lane_y.size()):
		var distance: float = absf(world_y - lane_y[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_lane = i
	return nearest_lane if nearest_distance <= click_height * 0.5 else -1
