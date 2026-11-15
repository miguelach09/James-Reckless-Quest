extends CanvasLayer
## Sistema de Trivia militar: cámara lenta táctica + pregunta de opción múltiple.

signal question_answered(is_correct: bool)

const REWARD_COINS := 25
const ANSWER_TIME := 8.0
const SLOW_SCALE := 0.1

const QUESTIONS := {
"1": {"q": "¿Cuál es la capital de Colombia?", "a": ["Cali", "Bogotá", "Medellín", "Cartagena"], "c": 1},
"2": {"q": "¿Cuántos días tiene una semana?", "a": ["Cinco", "Seis", "Ocho", "Siete"], "c": 3},
"3": {"q": "¿Qué planeta es conocido como el planeta rojo?", "a": ["Marte", "Venus", "Júpiter", "Saturno"], "c": 0},
"4": {"q": "¿Qué animal maúlla?", "a": ["Perro", "Vaca", "Gato", "Pato"], "c": 2},
"5": {"q": "¿Cuántos lados tiene un triángulo?", "a": ["Cuatro", "Tres", "Cinco", "Seis"], "c": 1},
"6": {"q": "¿Qué estrella ilumina la Tierra?", "a": ["La Luna", "Marte", "Venus", "El Sol"], "c": 3},
"7": {"q": "¿Qué órgano bombea la sangre?", "a": ["Corazón", "Pulmón", "Estómago", "Cerebro"], "c": 0},
"8": {"q": "¿Cuál es el océano más grande?", "a": ["Atlántico", "Índico", "Pacífico", "Ártico"], "c": 2},
"9": {"q": "¿Cuántos meses tiene un año?", "a": ["Diez", "Doce", "Once", "Trece"], "c": 1},
"10": {"q": "¿Qué producen las abejas?", "a": ["Leche", "Sal", "Harina", "Miel"], "c": 3},
"11": {"q": "¿En qué país está la Torre Eiffel?", "a": ["Francia", "Italia", "España", "Alemania"], "c": 0},
"12": {"q": "¿Cuál es el satélite natural de la Tierra?", "a": ["El Sol", "Marte", "La Luna", "Venus"], "c": 2},
"13": {"q": "¿Con qué órgano respiramos?", "a": ["Riñón", "Pulmones", "Estómago", "Corazón"], "c": 1},
"14": {"q": "¿Qué idioma se habla principalmente en Brasil?", "a": ["Español", "Inglés", "Francés", "Portugués"], "c": 3},
"15": {"q": "¿Qué animal tiene trompa?", "a": ["Elefante", "León", "Jirafa", "Cebra"], "c": 0},
"16": {"q": "¿Cuántas horas tiene un día?", "a": ["Doce", "Treinta", "Veinticuatro", "Sesenta"], "c": 2},
"17": {"q": "¿Qué instrumento tiene teclas blancas y negras?", "a": ["Guitarra", "Piano", "Tambor", "Flauta"], "c": 1},
"18": {"q": "¿Qué deporte se juega con una canasta?", "a": ["Fútbol", "Tenis", "Natación", "Baloncesto"], "c": 3},
"19": {"q": "¿Cómo se llama el agua en estado sólido?", "a": ["Hielo", "Vapor", "Lluvia", "Niebla"], "c": 0},
"20": {"q": "¿Qué usamos para medir la temperatura?", "a": ["Regla", "Balanza", "Termómetro", "Reloj"], "c": 2},
"21": {"q": "¿Cuál es el río más largo de América del Sur?", "a": ["El Amazonas", "El Orinoco", "El Paraná", "El Magdalena"], "c": 0},
"22": {"q": "¿Cuántos jugadores de un equipo de fútbol están en la cancha?", "a": ["Nueve", "Diez", "Once", "Doce"], "c": 2},
"23": {"q": "¿Qué animal es conocido como el rey de la selva?", "a": ["El tigre", "El león", "El elefante", "El oso"], "c": 1},
"24": {"q": "¿De qué color son la mayoría de las hojas de las plantas?", "a": ["Rojas", "Azules", "Verdes", "Amarillas"], "c": 2},
"25": {"q": "¿En qué país está la ciudad de Roma?", "a": ["Grecia", "Italia", "Portugal", "Francia"], "c": 1},
"26": {"q": "¿Cuántos colores tiene el arcoíris?", "a": ["Cinco", "Seis", "Siete", "Ocho"], "c": 2},
"27": {"q": "¿Qué instrumento se toca con baquetas?", "a": ["El tambor", "El violín", "El piano", "El arpa"], "c": 0},
"28": {"q": "¿Qué metal se usa mucho en los cables eléctricos?", "a": ["El hierro", "El oro", "El cobre", "El plomo"], "c": 2},
"29": {"q": "¿Qué animal tiene caparazón y camina muy lento?", "a": ["La tortuga", "El perro", "El gato", "El caballo"], "c": 0},
"30": {"q": "¿Cuál es el animal terrestre más grande?", "a": ["El elefante", "La jirafa", "El hipopótamo", "El rinoceronte"], "c": 0},
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


func activate(title_text: String = "¡CÓDIGO DE SUMINISTRO MILITAR!") -> void:
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
		title_label.text = title_text
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
		title_label.text = title_text
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
