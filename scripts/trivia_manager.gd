extends CanvasLayer
## Sistema de Trivia militar: cámara lenta táctica + pregunta de opción múltiple.

signal question_answered(is_correct: bool)

const REWARD_COINS := 25
const ANSWER_TIME := 8.0
const SLOW_SCALE := 0.1

const QUESTIONS: Array[Dictionary] = [
	{"q": "¿Qué sentido está más desarrollado en los Seres Subterráneos?", "a": ["Visión en la oscuridad", "Vuelo", "Camuflaje ácido", "Telepatía"], "c": 0},
	{"q": "¿Cuántos hermanos tiene James?", "a": ["Uno: Pepito", "Dos", "Ninguno", "Tres"], "c": 0},
	{"q": "¿Qué arma usa James para aplastar enemigos desde el aire?", "a": ["El Slam", "Una espada", "Un látigo", "Una granada"], "c": 0},
	{"q": "¿Qué biome viene DESPUÉS de La Ciudad?", "a": ["La Selva", "El Desierto", "El Mar", "El Espacio"], "c": 0},
	{"q": "¿Dónde está cautivo Pepito?", "a": ["En un volcán activo", "En la luna", "En un castillo", "Bajo el mar"], "c": 0},
	{"q": "¿Qué conservan las Botas Tácticas al rebotar?", "a": ["La velocidad horizontal", "La munición", "La vida", "El tiempo"], "c": 0},
	{"q": "¿Qué obtiene James al acertar una trivia?", "a": ["Un Rocket Boost", "Un escudo", "Un mapa", "Un aliado"], "c": 0},
	{"q": "¿Qué pasa si James responde mal una trivia?", "a": ["Pierde la mitad de su velocidad", "Muere", "Vuelve al menú", "Se queda dormido"], "c": 0},
]

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var question_label: Label = $Root/Center/Panel/Margin/VBox/QuestionLabel
@onready var answers_box: VBoxContainer = $Root/Center/Panel/Margin/VBox/Answers
@onready var timer_bar: ProgressBar = $Root/Center/Panel/Margin/VBox/TimerBar

var _active: bool = false
var _time_left: float = 0.0
var _correct_index: int = 0
var _prev_state: int = GameManager.GameState.FLYING
var _buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("trivia_manager")
	root.hide()
	_build_buttons()


func _build_buttons() -> void:
	for i in 4:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(520, 50)
		b.pressed.connect(_on_answer.bind(i))
		answers_box.add_child(b)
		_buttons.append(b)


func activate() -> void:
	if _active:
		return
	_active = true
	_prev_state = GameManager.current_state
	GameManager.set_state(GameManager.GameState.TRIVIA_ACTIVE)

	var question: Dictionary = QUESTIONS[randi() % QUESTIONS.size()]
	_correct_index = int(question["c"])
	title_label.text = "¡CÓDIGO DE SUMINISTRO MILITAR!"
	question_label.text = str(question["q"])
	var answers: Array = question["a"]
	for i in _buttons.size():
		if i < answers.size():
			_buttons[i].text = "%d)  %s" % [i + 1, str(answers[i])]
			_buttons[i].disabled = false
		else:
			_buttons[i].text = ""
			_buttons[i].disabled = true

	_time_left = ANSWER_TIME
	timer_bar.max_value = ANSWER_TIME
	timer_bar.value = ANSWER_TIME
	Engine.time_scale = SLOW_SCALE
	root.show()


func _process(delta: float) -> void:
	if not _active:
		return
	var unscaled: float = delta / maxf(Engine.time_scale, 0.001)
	_time_left -= unscaled
	timer_bar.value = maxf(_time_left, 0.0)
	if _time_left <= 0.0:
		_resolve(-1)


func _on_answer(index: int) -> void:
	if not _active:
		return
	_resolve(index)


func _resolve(index: int) -> void:
	if not _active:
		return
	_active = false
	var is_correct: bool = index == _correct_index
	Engine.time_scale = 1.0
	root.hide()

	if is_correct:
		GameManager.add_coins(REWARD_COINS)

	GameManager.set_state(_prev_state)

	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_trivia_boost"):
		player.apply_trivia_boost(is_correct)

	question_answered.emit(is_correct)


func is_active() -> bool:
	return _active