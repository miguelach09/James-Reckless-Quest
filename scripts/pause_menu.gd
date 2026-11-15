extends Control
## Menú de pausa que detiene el juego y ofrece opciones.

func _ready() -> void:
	# Conectar botones
	get_node("ResumeButton").pressed.connect(_on_resume)
	get_node("MainMenuButton").pressed.connect(_on_main_menu)
	get_node("QuitButton").pressed.connect(_on_quit)

func _on_resume() -> void:
	get_tree().pause_mode = false
	queue_free()

func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/IntroMenu.tscn")
	get_tree().pause_mode = false

func _on_quit() -> void:
	get_tree().quit()