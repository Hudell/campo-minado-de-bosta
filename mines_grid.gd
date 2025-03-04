extends Node2D
class_name MinesGrid

@export var columns := 40
@export var rows := 20
@export var number_of_mines := 130

signal flag_changed
signal time_changed
signal game_state_changed
signal mine_changed

const CELLS = {
	"1": Vector2i(0, 0),
	"2": Vector2i(1, 0),
	"3": Vector2i(2, 0),
	"4": Vector2i(3, 0),
	"5": Vector2i(4, 0),
	"6": Vector2i(0, 1),
	"7": Vector2i(1, 1),
	"8": Vector2i(2, 1),
	"CLEAR": Vector2i(3, 1),
	"BLOWN_MINE": Vector2i(4, 1),
	"FLAG": Vector2i(0, 2),
	"MINE": Vector2i(1, 2),
	"DEFAULT": Vector2i(2, 2),
	"HIGHLIGHT": Vector2i(3, 2),
}

var started = false
var time_elapsed = 0
var game_finished = false
var game_lost = false
var clicked_cell: Vector2i
var is_clicked := false
var clicked_mouse_button: MouseButton
var paused = false
var is_mouse_blocked = false

func _ready() -> void:
	clear_board()

func _input(event: InputEvent) -> void:
	if paused or is_mouse_blocked:
		clear_click_data()
		return

	var is_click = event is InputEventMouseButton
	var is_move = event is InputEventMouseMotion
	
	if not is_click and not is_move:
		return

	var local_event = %DefaultLayer.make_input_local(event)
	var cell = %DefaultLayer.local_to_map(local_event.position)

	if is_click:
		mouse_click_event(event, cell)
	else:
		mouse_move_event(event, cell)
	
func mouse_click_event(event: InputEventMouseButton, cell: Vector2i):
	if event.is_pressed():
		preview_click_cell(cell, event.button_index)
		return
	
	click_cell(cell, event.button_index)
	clear_click_data()

func mouse_move_event(event: InputEventMouseMotion, cell: Vector2i):
	if not is_clicked:
		return
	if event.relative.is_zero_approx():
		return
	if clicked_cell == null or not is_valid_pos(clicked_cell):
		return
	
	if clicked_cell != cell:
		clear_click_data()

func change_difficulty(new_columns: int, new_rows: int, new_mines: int):
	columns = new_columns
	rows = new_rows
	number_of_mines = new_mines
	restart()

func restart():
	clear_board()

func min_column() -> int:
	return 0

func max_column() -> int:
	return columns - 1

func min_row() -> int:
	return 0

func max_row() -> int:
	return rows - 1

func preview_click_cell(cell: Vector2i, mouse_button: MouseButton):
	clear_highlights()
	if not is_valid_pos(cell):
		return
	
	is_clicked = true
	clicked_cell = cell
	clicked_mouse_button = mouse_button
	
	if mouse_button == MOUSE_BUTTON_RIGHT:
		preview_right_click(cell)
		return
	
	if mouse_button == MOUSE_BUTTON_LEFT:
		preview_left_click(cell)
		return

func clear_click_data():
	is_clicked = false
	clear_highlights()

func click_cell(cell: Vector2i, mouse_button: MouseButton):
	if not is_valid_pos(cell) or not is_clicked or clicked_mouse_button != mouse_button:
		clear_click_data()
		return

	if mouse_button == MOUSE_BUTTON_RIGHT:
		right_click(cell)
		return

	if mouse_button == MOUSE_BUTTON_LEFT:
		left_click(cell)
		return

func preview_left_click(pos: Vector2i):
	if game_lost or game_finished:
		return
	
	if not started:
		return
	
	if is_flagged(pos):
		return
		
	if is_hidden(pos):
		highlight_cells([pos])
		return
	
	highlight_unflagged_cells_around(pos)

func left_click(pos: Vector2i):
	if game_lost or game_finished:
		return

	if not started:
		build_board(pos)
		started = true
		
	if is_flagged(pos):
		return

	if is_hidden(pos):
		reveal_cell(pos)
		return

	reveal_unflagged_cells_around(pos)
	if not game_lost and get_safe_hidden_cells_left() == 0:
		remove_all_flags()
		game_finished = true
		%Timer.stop()
		emit_signal('game_state_changed')

func reveal_cell(pos: Vector2i):
	if not is_hidden(pos):
		return

	%DefaultLayer.erase_cell(pos)
	if is_clear(pos):
		var area = get_area_around_tile(pos)
		for area_pos in area:
			reveal_cell(area_pos)

	if is_bomb(pos):
		lose_game()
		set_tile_cell(%MineLayer, pos, "BLOWN_MINE")

func highlight_unflagged_cells_around(pos: Vector2i):
	var cells = get_mines_to_flag(pos, false)
	highlight_cells(cells)

func reveal_unflagged_cells_around(pos: Vector2i):
	var cells = get_mines_to_flag(pos, true)
	for cell_pos in cells:
		reveal_cell(cell_pos)

func get_mines_to_flag(pos: Vector2i, validate_numbers: bool) -> Array[Vector2i]:
	if is_hidden(pos):
		return []

	var area = get_area_around_tile(pos, 1, true)
	if validate_numbers:
		var number_of_mines_here = get_number_of_mines_in_list(area)
		var number_of_known_mines = get_number_of_flags_and_revealed_mines_in_list(area)

		if number_of_known_mines < number_of_mines_here:
			return []
	
	return get_unflagged_hidden_cells_in_list(area)

func reveal_mines_in_tiles(tiles: Array[Vector2i]):
	for pos in tiles:
		if is_bomb(pos):
			%DefaultLayer.erase_cell(pos)

func lose_game():
	var cells = get_all_cells()
	reveal_mines_in_tiles(cells)
	game_lost = true
	game_finished = true
	%Timer.stop()
	emit_signal('game_state_changed')

func flag_cell(pos: Vector2i):
	set_tile_cell(%DefaultLayer, pos, "FLAG")
	emit_signal('flag_changed')

func unflag_cell(pos: Vector2i):
	set_tile_cell(%DefaultLayer, pos, "DEFAULT")
	emit_signal('flag_changed')

func highlight_hidden_cells_around(pos: Vector2i):
	var cells = get_cells_to_flag_around(pos, false)
	highlight_cells(cells)

func flag_hidden_cells_around(pos: Vector2i):
	var cells = get_cells_to_flag_around(pos, true)

	for cell_pos in cells:
		flag_cell(cell_pos)

func get_cells_to_flag_around(pos: Vector2i, validate_numbers: bool) -> Array[Vector2i]:
	if is_hidden(pos):
		return [pos]

	var area = get_area_around_tile(pos, 1, true)
	var cells = get_unflagged_hidden_cells_in_list(area)

	if validate_numbers:
		var number_of_mines_here = get_number_of_mines_in_list(area)
		var number_of_known_mines = get_number_of_flags_and_revealed_mines_in_list(area)

		if number_of_mines_here < number_of_known_mines + cells.size():
			return []
	
	return cells

func remove_all_flags():
	var cells = get_all_cells()
	for pos in cells:
		if is_flagged(pos):
			unflag_cell(pos)

func preview_right_click(pos: Vector2i):
	if game_lost or game_finished:
		return
	
	if is_flagged(pos):
		highlight_cells([pos])
		return
	
	highlight_hidden_cells_around(pos)

func right_click(pos: Vector2i):
	if game_lost or game_finished:
		return

	if is_flagged(pos):
		unflag_cell(pos)
		return

	flag_hidden_cells_around(pos)

func clear_board():
	%MineLayer.clear()
	%DefaultLayer.clear()
	started = false
	time_elapsed = 0
	game_finished = false
	game_lost = false
	emit_signal('game_state_changed')
	emit_signal('flag_changed')
	emit_signal('time_changed')
	emit_signal('mine_changed')

	if not %Timer.is_stopped():
		%Timer.stop()
		
	var cells = get_all_cells()
	for pos in cells:
		set_tile_cell(%DefaultLayer, pos, "DEFAULT")

func clear_highlights():
	%HighlightLayer.clear()

func highlight_cells(cells: Array[Vector2i]):
	for pos in cells:
		set_tile_cell(%HighlightLayer, pos, "HIGHLIGHT")

func build_board(safe_pos: Vector2i = Vector2.INF):
	clear_board()
	place_mines(safe_pos)

	var cells = get_all_cells()
	for pos in cells:
		if not is_bomb(pos):
			var qtt = get_number_of_mines_near_tile(pos)
			if qtt == 0:
				set_tile_cell(%MineLayer, pos, "CLEAR")
			else:
				set_tile_cell(%MineLayer, pos, str(qtt))

	if is_valid_pos(safe_pos):
		started = true
		time_elapsed = 0
		game_finished = false
		game_lost = false
		%Timer.start()
		emit_signal('game_state_changed')
		emit_signal('flag_changed')
		emit_signal('time_changed')


func place_mines(safe_pos: Vector2i):
	for i in number_of_mines:
		var cell_pos = get_random_empty_position(get_area_around_tile(safe_pos))

		set_tile_cell(%MineLayer, cell_pos, "MINE")
	emit_signal('mine_changed')

func is_bomb(pos: Vector2i) -> bool:
	if not is_valid_pos(pos):
		return false
	var variant = get_cell_custom_data(%MineLayer, pos, "has_mine")
	return true if variant else false

func is_hidden(pos: Vector2i) -> bool:
	if not is_valid_pos(pos):
		return false

	return get_tile_at_pos(%DefaultLayer, pos) != "NONE"

func is_clear(pos: Vector2i) -> bool:
	if not is_valid_pos(pos):
		return false

	return get_tile_at_pos(%MineLayer, pos) == "CLEAR"

func is_flagged(pos: Vector2i) -> bool:
	return get_tile_at_pos(%DefaultLayer, pos) == "FLAG"

func get_area_around_tile(pos: Vector2i, area_range:= 1, skip_center := false) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if not is_valid_pos(pos):
		return positions

	var total_range = area_range * 2 + 1
	for x in total_range:
		for y in total_range:
			var tile_pos = Vector2i(pos.x - area_range + x, pos.y - area_range + y)
			if skip_center and tile_pos == pos:
				continue
			if not is_valid_pos(tile_pos):
				continue
			positions.append(tile_pos)

	return positions

func get_unflagged_hidden_cells_in_list(area: Array[Vector2i]) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for area_pos in area:
		if not is_hidden(area_pos) or is_flagged(area_pos):
			continue
		positions.append(area_pos)
	return positions

func get_mines_in_list(area: Array[Vector2i]) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for area_pos in area:
		if not is_bomb(area_pos):
			continue
		positions.append(area_pos)

	return positions

func get_number_of_mines_near_tile(pos: Vector2i) -> int:
	var area = get_area_around_tile(pos, 1, true)
	return get_mines_in_list(area).size()

func get_number_of_mines_in_list(area: Array[Vector2i]) -> int:
	return get_mines_in_list(area).size()

func get_number_of_flags_and_revealed_mines_in_list(area: Array[Vector2i]) -> int:
	var qtt = 0

	for area_pos in area:
		if is_hidden(area_pos):
			if is_flagged(area_pos):
				qtt += 1
				continue
		elif is_bomb(area_pos):
			qtt += 1

	return qtt

func get_number_of_hidden_unflagged_cells_in_list(area: Array[Vector2i]) -> int:
	var qtt = 0

	for area_pos in area:
		if is_hidden(area_pos) and not is_flagged(area_pos):
			qtt += 1

	return qtt

func is_valid_pos(pos: Vector2i) -> bool:
	if pos.x < min_column() or pos.x > max_column():
		return false
	if pos.y < min_row() or pos.y > max_row():
		return false

	return true

func get_tile_at_pos(layer: TileMapLayer, pos: Vector2i) -> String:
	var tile = layer.get_cell_atlas_coords(pos)
	var key = CELLS.find_key(tile) if tile != null else null

	if key:
		return key
	return "NONE"

func get_cell_custom_data(layer: TileMapLayer, pos: Vector2i, layer_name: String) -> Variant:
	var tile = layer.get_cell_tile_data(pos)
	if tile == null:
		return null
	return tile.get_custom_data(layer_name)

func get_random_empty_position(positions_to_ignore: Array[Vector2i]) -> Vector2i:
	var pos = Vector2i(randi_range(min_column(), max_column()), randi_range(min_row(), max_row()))
	if positions_to_ignore.has(pos) or get_cell_custom_data(%MineLayer, pos, "has_mine"):
		return get_random_empty_position(positions_to_ignore)
	return pos

func set_tile_cell(layer: TileMapLayer, cell_coord: Vector2i, cell_type: String):
	layer.set_cell(cell_coord, 0, CELLS[cell_type])

func get_all_cells() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for x in columns:
		for y in rows:
			var pos = Vector2i(min_column() + x, min_row() + y)
			positions.append(pos)
	return positions

func count_mines_in_cells(cells: Array[Vector2i]) -> int:
	return cells.reduce(func (qtt, pos): return qtt + (1 if is_bomb(pos) else 0), 0)

func count_flags_in_cells(cells: Array[Vector2i]) -> int:
	return cells.reduce(func (qtt, pos): return qtt + (1 if is_flagged(pos) else 0), 0)

func count_safe_hidden_cells(cells: Array[Vector2i]) -> int:
	return cells.reduce(func (qtt, pos): return qtt + (1 if is_hidden(pos) and not is_bomb(pos) else 0), 0)

func get_mines_left() -> int:
	if game_finished and not game_lost:
		return 0
	var cells = get_all_cells()
	return max(0, count_mines_in_cells(cells) - count_flags_in_cells(cells))

func get_safe_hidden_cells_left() -> int:
	var cells = get_all_cells()
	return count_safe_hidden_cells(cells)

func _on_timer_timeout() -> void:
	if not started:
		return
	time_elapsed += 1
	emit_signal('time_changed')
