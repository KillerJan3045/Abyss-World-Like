extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pass

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/test_area.tscn")

func _on_option_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/options_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

#============================DEV ONLY==========================================#
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
#============================DEV ONLY==========================================#
