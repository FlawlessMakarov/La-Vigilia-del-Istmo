extends Control

func _ready() -> void:
	# Deja el botón de jugar listo para teclado/control.
	$MenuPanel/Buttons/PlayButton.grab_focus()

func _on_play_button_pressed() -> void:
	# Carga la escena principal.
	get_tree().change_scene_to_file("res://game.tscn")

func _on_exit_button_pressed() -> void:
	# Cierra el juego.
	get_tree().quit()
