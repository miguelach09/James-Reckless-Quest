extends Control
## Pantalla de Historia (efecto máquina de escribir) + Menú Principal.

const STORY_LINES: Array[String] = [
	"Los Seres Subterráneos han emergido de las profundidades con un solo objetivo: dominar la Tierra. En su ataque, secuestraron a Pepito y lo llevaron al corazón de un volcán activo.",
	"Para el ex-soldado James, ir a pie tomaría demasiado tiempo... Así que tomó una decisión temeraria: meterse en un cañón táctico de largo alcance para cruzar la Ciudad y la Selva volando a toda velocidad, aplastando monstruos y desbloqueando suministros militares en el aire.",
	"¡Prepárate! Aquí comienza... JAMES RECKLESS QUEST.",
]
const CHARS_PER_SECOND := 45.0
const MAIN_SCENE := "res://scenes/Main.tscn"

@onready var story_panel: Control = $StoryPanel
@onready var story_text: RichTextLabel = $StoryPanel/Margin/VBox/StoryText
@onready var continue_button: Button = $StoryPanel/Margin/VBox/ContinueButton
@onready var main_menu: Control = $MainMenu
@onready var play_button: Button = $MainMenu/Center/VBox/PlayButton
@onready var quit_button: Button = $MainMenu/Center/VBox/QuitButton

var _full_text: String = ""
var _revealed: float = 0.0
var _typing: bool = false


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.INTRO_MENU)
	main_menu.hide()
	story_panel.show()

	_full_text = "\n\n".join(STORY_LINES)
	story_text.text = _full_text
	story_text.visible_characters = 0
	_revealed = 0.0
	_typing = true
	continue_button.text = "Saltar"

	continue_button.pressed.connect(_on_continue_pressed)
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _process(delta: float) -> void:
	if not _typing:
		return
	_revealed += delta * CHARS_PER_SECOND
	story_text.visible_characters = int(_revealed)
	if _revealed >= float(_full_text.length()):
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_revealed = float(_full_text.length())
	story_text.visible_characters = -1
	continue_button.text = "Continuar"


func _on_continue_pressed() -> void:
	if _typing:
		_finish_typing()
	else:
		_show_main_menu()


func _show_main_menu() -> void:
	story_panel.hide()
	main_menu.show()
	continue_button.release_focus()


func _on_play_pressed() -> void:
	GameManager.set_state(GameManager.GameState.WAITING_LAUNCH)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()