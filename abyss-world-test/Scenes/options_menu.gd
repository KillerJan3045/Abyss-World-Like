extends Control

func _on_return_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_sens_slider_value_changed(Value: float) -> void:
	Global.sens = Value/10
