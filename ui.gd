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
	
	if game != null and game.game_finished and not game.game_lost:
		$AcceptDialog.title = "You've won!"
		$AcceptDialog.popup()

func _on_game_button_pressed() -> void:
	if game != null:
		game.paused = true
		
		$AcceptDialog.title = "New Game"
		$AcceptDialog.popup()

func update_mines_left():
	%MinesLabel.text = str(get_mines_left())

func update_timer():
	%TimerLabel.text = str(get_time_elapsed())

func update_button():
	var lost = is_game_lost()

	%GameButton.visible = not lost
	%GameLostButton.visible = lost
	
	if game != null and game.game_lost:
		$AcceptDialog.title = "You've lost!"
		$AcceptDialog.popup()

func _on_accept_dialog_confirmed() -> void:
	if game != null:
		game.paused = false
		
		if %Beginner.button_pressed:
			game.change_difficulty(10, 10, 20)
			return
		if %Easy.button_pressed:
			game.change_difficulty(20, 20, 70)
			return
		if %Normal.button_pressed:
			game.change_difficulty(40, 20, 130)
			return
		if %Hard.button_pressed:
			game.change_difficulty(40, 20, 200)
			return
			

func _on_accept_dialog_canceled() -> void:
	if game != null:
		game.paused = false

func prevent_game_input():
	if game != null:
		game.is_mouse_blocked = true

func allow_game_input():
	if game != null:
		game.is_mouse_blocked = false

func _on_panel_container_gui_input(_event: InputEvent) -> void:
	prevent_game_input()

func _on_control_gui_input(_event: InputEvent) -> void:
	allow_game_input()

func _on_game_button_gui_input(_event: InputEvent) -> void:
	prevent_game_input()

func _on_game_lost_button_gui_input(_event: InputEvent) -> void:
	prevent_game_input()
