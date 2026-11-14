extends CanvasLayer
## Sistema de Trivia militar: cámara lenta táctica + pregunta de opción múltiple.

signal question_answered(is_correct: bool)

const REWARD_COINS := 25
const ANSWER_TIME := 8.0
const SLOW_SCALE := 0.1

const QUESTIONS := {
	"1": {"q": "¿Qué sentido está más desarrollado en los Seres Subterráneos?", "a": ["Visión en la oscuridad", "Vuelo", "Camuflaje ácido", "Telepatía"], "c": 0},
	"2": {"q": "¿Cuántos hermanos tiene James?", "a": ["Uno: Pepito", "Dos", "Ninguno", "Tres"], "c": 0},
	"3": {"q": "¿Qué arma usa James para aplastar enemigos desde el aire?", "a": ["El Slam", "Una espada", "Un látigo", "Una granada"], "c": 0},
	"4": {"q": "¿Qué biome viene DESPUÉS de La Ciudad?", "a": ["La Selva", "El Desierto", "El Mar", "El Espacio"], "c": 0},
	"5": {"q": "¿Dónde está cautivo Pepito?", "a": ["En un volcán activo", "En la luna", "En un castillo", "Bajo el mar"], "c": 0},
	"6": {"q": "¿Qué conservan las Botas Tácticas al rebotar?", "a": ["La velocidad horizontal", "La munición", "La vida", "El tiempo"], "c": 0},
	"7": {"q": "¿Qué obtiene James al acertar una trivia?", "a": ["Un Rocket Boost", "Un escudo", "Un mapa", "Un aliado"], "c": 0},
	"8": {"q": "¿Qué pasa si James responde mal una trivia?", "a": ["Pierde la mitad de su velocidad", "Muere", "Vuelve al menú", "Se queda dormido"], "c": 0},
	"9": {"q": "¿De dónde es originario James?", "a": ["Ciudad costera", "Región subterránea", "Isla volcánica", "Monte nevado"], "c": 1},
	"10": {"q": "¿Qué herramienta usa James para minería profunda?", "a": ["Pico", "Paleta", "Taladro", "Explosivos"], "c": 0},
	"11": {"q": "¿Qué tipo de vehículo usó James para cruzar la ciudad?", "a": ["Cañón táctico", "Helicóptero", "Globos", "Patines"], "c": 0},
	"12": {"q": "¿Cuál es el nombre del hermano de James?", "a": ["Pepito", "Pablo", "Pedro", "Ricardo"], "c": 0},
	"13": {"q": "¿Qué arma secundaria tiene James?", "a": ["Látigo", "Espada", "Granada", "Ninguna"], "c": 0},
	"14": {"q": "¿En qué bioma se encuentra el checkpoint inicial?", "a": ["Ciudad", "Selva", "Volcano", "Desierto"], "c": 0},
	"15": {"q": "¿Qué poder conservan las Botas Tácticas?", "a": ["Velocidad horizontal", "Salto más alto", "Respiración bajo agua", "Visión nocturna"], "c": 0},
	"16": {"q": "¿Qué accesorio lleva James en el cuello?", "a": ["Corbata", "Pañuelo", "Cadena", "Ninguno"], "c": 3},
	"17": {"q": "¿De qué material está hecha la cape de James?", "a": ["Cuero", "Nailon", "Seda", "Poliéster"], "c": 2},
	"18": {"q": "¿Qué tipo de gafas usa James?", "a": ["Solar", "De lectura", "Ninguna", "Protección"], "c": 3},
	"19": {"q": "¿Cuál es el alimento favorito de James?", "a": ["Pizza", "Sushi", "Hamburguesa", "Tacos"], "c": 0},
	"20": {"q": "¿De qué color es el coche de James?", "a": ["Rojo", "Azul", "Verde", "Negro"], "c": 2},
}

## Lista ordenada de preguntas (para evitar repeticiones)
var _used_questions: Array = []

func get_random_question() -> Dictionary:
	## Retorna una pregunta aleatoria que no haya sido usada recientemente
	## _used_questions almacena los keys (IDs) de preguntas ya usadas
	
	var available_keys: Array = []
	for key in QUESTIONS.keys():
		## Si el key no está en la lista de usados, está disponible
		if not _used_questions.has(key):
			available_keys.append(key)
	
	## Si no hay preguntas disponibles, reiniciar la lista de usadas
	if available_keys.size() == 0:
		_used_questions = []
		available_keys = QUESTIONS.keys()
	
	## Seleccionar un key aleatorio de los disponibles
	var random_key: String = available_keys.pick_random()
	## Obtener el diccionario de pregunta usando el key seleccionado
	var q: Dictionary = QUESTIONS[random_key]
	
	## Registrar que este key ha sido usado
	_used_questions.append(random_key)
	## Mantener solo las últimas 5 preguntas usadas (keys) para evitar memoria excesiva
	while _used_questions.size() > 5:
		_used_questions.remove_at(0)
	
	return q

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
	for i in range(4):
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

	var question: Dictionary = get_random_question()
	## Barajar respuestas manteniendo el índice correcto
	var answers: Array = question["a"]
	_correct_index = int(question["c"])
	
	## Crear array con respuestas barajadas
	var shuffled_answers: Array = answers.duplicate()
	shuffled_answers.shuffle()
	
	## Encontrar el nuevo índice de la respuesta correcta después de la barajada
	var new_correct_index: int = -1
	for i in range(shuffled_answers.size()):
		if shuffled_answers[i] == answers[_correct_index]:
			new_correct_index = i
			break
	
	## Actualizar el correct_index al nuevo índice barajado
	if new_correct_index != -1:
		_correct_index = new_correct_index
		title_label.text = "¡CÓDIGO DE SUMINISTRO MILITAR!"
		question_label.text = str(question["q"])
		
		for i in range(_buttons.size()):
			if i < shuffled_answers.size():
				_buttons[i].text = "%d)  %s" % [i + 1, str(shuffled_answers[i])]
				_buttons[i].disabled = false
			else:
				_buttons[i].text = ""
				_buttons[i].disabled = true
	else:
		## Fallback si no se encuentra la respuesta correcta
		title_label.text = "¡CÓDIGO DE SUMINISTRO MILITAR!"
		question_label.text = str(question["q"])
		for i in range(_buttons.size()):
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
