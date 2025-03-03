extends Camera2D

@export var game: MinesGrid

var screen_width = 1280
var screen_height = 720
var default_margin := 100
var speed = 150.0

func _ready():
	update_limits()
	if game != null:
		game.game_state_changed.connect(on_game_state_changed)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	if event.button_index != MOUSE_BUTTON_WHEEL_DOWN and event.button_index != MOUSE_BUTTON_WHEEL_UP:
		return
	
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		change_zoom_level(0.1 if event.factor == 0 else event.factor / 10)
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		change_zoom_level(-(0.1 if event.factor == 0 else event.factor / 10))
		return

func get_game_width() -> int:
	if game == null:
		return 1280
	
	return game.columns * 32

func get_game_height() -> int:
	if game == null:
		return 720
	
	return game.rows * 32

func _process(delta: float) -> void:
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction == Vector2.ZERO:
		return
	
	var position_delta = direction * delta * speed
	var new_position = normalize_position(position + position_delta)
	
	if position != new_position:
		position = new_position
	
func normalize_position(pos: Vector2) -> Vector2:
	var zoomed_screen_width = int(screen_width / zoom.x)
	var zoomed_screen_height = int(screen_height / zoom.y)

	return Vector2(max(limit_left, min(limit_right - zoomed_screen_width, pos.x)), max(limit_top, min(limit_bottom - zoomed_screen_height, pos.y)))
	
func change_zoom_level(diff: float):
	var intended_zoom = zoom.x + diff
	var new_zoom = min(3, max(1, intended_zoom))
	
	if new_zoom == zoom.x:
		return
		
	zoom = Vector2(new_zoom, new_zoom)
	update_limits()

func update_limits():
	limit_left = 0 - int(default_margin / zoom.x)
	limit_top = 0 - int(default_margin / zoom.y)
	
	var right_pos = get_game_width()
	var bottom_pos = get_game_height()
	
	limit_right = right_pos + int(default_margin / zoom.x)
	limit_bottom = bottom_pos + int(default_margin / zoom.y)
	
	var new_position = normalize_position(position)
	if new_position != position:
		position = new_position
	
func on_game_state_changed():
	update_limits()
