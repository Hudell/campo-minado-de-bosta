extends CanvasLayer

@export var game: MinesGrid

func _ready() -> void:
	if game != null:
		game.flag_changed.connect(on_flag_changed)
		game.mine_changed.connect(on_mine_changed)
		game.time_changed.connect(on_time_changed)
		game.game_state_changed.connect(on_game_state_changed)
		update_mines_left()
		update_timer()
		update_button()


func get_mines_left() -> int:
	if game == null:
		return 0

	return game.get_mines_left()

func get_time_elapsed() -> int:
	if game == null:
		return 0

	return game.time_elapsed

func is_game_lost() -> bool:
	if game == null:
		return true

	return game.game_lost

func on_flag_changed():
	update_mines_left()

func on_mine_changed():
	update_mines_left()

func on_time_changed():
	update_timer()

func on_game_state_changed():
	update_mines_left()
	update_timer()
	update_button()

func _on_game_button_pressed() -> void:
	if game != null:
		game.restart()

func update_mines_left():
	%MinesLabel.text = str(get_mines_left())

func update_timer():
	%TimerLabel.text = str(get_time_elapsed())

func update_button():
	var lost = is_game_lost()

	%GameButton.visible = not lost
	%GameLostButton.visible = lost
