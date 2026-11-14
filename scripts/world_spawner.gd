extends Node2D
## Genera suelo infinito, decoración de bioma, rebotadores y cañones.
## Mantiene el suelo generado alrededor del jugador, también hacia atrás, así
## que reaparecer en un checkpoint anterior siempre tiene suelo firme.

const BouncerScene: PackedScene = preload("res://scenes/Bouncer.tscn")

const SEG_WIDTH := 512.0
const GROUND_THICKNESS := 900.0
const VIEW_AHEAD := 2500.0
const CLEANUP_BEHIND := 1300.0
const BOUNCER_CHANCE := 1.0
const CRATE_RATIO := 0.5

const CHECKPOINTS: Array[float] = [0.0, 7000.0, 14000.0]

const FLOOR_COLORS: Dictionary = {
	"city": Color(0.28, 0.15, 0.26),
	"jungle": Color(0.11, 0.26, 0.14),
	"volcano": Color(0.32, 0.09, 0.06),
}
const FLOOR_TOP_COLORS: Dictionary = {
	"city": Color(0.55, 0.33, 0.49),
	"jungle": Color(0.29, 0.53, 0.28),
	"volcano": Color(0.72, 0.30, 0.10),
}

const CANNON_TEXTURE := "res://assets/generated/military_cannon.png"
const WALL_TEXTURE := "res://assets/generated/volcanic_wall.png"

@export var ground_y: float = 520.0

var player: CharacterBody2D
var active: bool = true

var _segments: Dictionary = {}   # index -> StaticBody2D
var _bouncers: Dictionary = {}   # index -> Node2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_spawn_cannons()
	_spawn_wall()


func _process(_delta: float) -> void:
	if not active:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var cam_x: float = player.global_position.x
	_ensure_ground(cam_x)


func biome_for_x(x: float) -> String:
	if x >= 14000.0:
		return "volcano"
	elif x >= 7000.0:
		return "jungle"
	return "city"


func _ensure_ground(cam_x: float) -> void:
	## Genera y mantiene segments de suelo alrededor de la posición de la cámara.
	## Asegura que siempre hay terreno tanto adelante como detrás del jugador.
	
	var start_index: int = int(cam_x / SEG_WIDTH) - 1
	var end_index: int = int((cam_x + VIEW_AHEAD) / SEG_WIDTH) + 1
	
	## Asegurar segments hacia adelante
	for i in range(start_index, end_index + 1):
		if not _segments.has(i):
			_spawn_segment(i)
	
	## Limpiar segments muy atrás (más atrás de CLEANUP_BEHIND)
	var cleanup_index: int = int(cam_x / SEG_WIDTH) - int(CLEANUP_BEHIND / SEG_WIDTH) - 1
	for i in _segments.keys():
		if i < cleanup_index:
			var s: Node = _segments[i]
			if is_instance_valid(s):
				s.queue_free()
			_segments.erase(i)


func _free_out_of_range(first_index: int, last_index: int) -> void:
	## Libera segmentos y bouncers que quedaron fuera de la ventana visible.
	## Solo elimina entries cuyo nodo sea inválido, manteniendo las instancias válidas.
	
	## Paso 1: Limpiar segmentos fuera de rango (solo los inválidos)
	var stale_segments: Array = []
	for i in _segments.keys():
		if i < first_index or i > last_index:
			stale_segments.append(i)
	for i in stale_segments:
		var s: Node = _segments[i]
		if not is_instance_valid(s):
			_segments.erase(i)
	
	## Paso 2: Limpiar bouncers fuera de rango (solo los inválidos)
	var stale_bouncers: Array = []
	for key in _bouncers.keys():
		## Keys son strings tipo "0_0", "1_1", etc. Extraemos el índice numérico.
		var parts: Array = str(key).split("_")
		var idx: int = -1
		if parts.size() >= 1:
			idx = int(parts[0])
		if idx < first_index or idx > last_index:
			stale_bouncers.append(key)
	
	## Solo borramos bouncers cuyo nodo ya no es válido (usando has() para evitar acceder a instancias freed)
	for key in stale_bouncers:
		if _bouncers.has(key):
			var b: Node = _bouncers[key]
			if not is_instance_valid(b):
				_bouncers.erase(key)


func _spawn_cannons() -> void:
	var tex: Texture2D = load(CANNON_TEXTURE)
	for cp in CHECKPOINTS:
		var cannon: Sprite2D = Sprite2D.new()
		cannon.texture = tex
		cannon.centered = false
		cannon.position = Vector2(cp - 10.0, ground_y - float(tex.get_height()) + 40.0)
		add_child(cannon)


func _spawn_wall() -> void:
	var tex: Texture2D = load(WALL_TEXTURE)
	var wall: Sprite2D = Sprite2D.new()
	wall.texture = tex
	wall.position = Vector2(GameManager.BOSS_TRIGGER_X, ground_y - float(tex.get_height()) * 0.5 + 20.0)
	add_child(wall)


func _spawn_segment(index: int) -> void:
	var x: float = float(index) * SEG_WIDTH
	var biome: String = biome_for_x(x)
	var seg: StaticBody2D = StaticBody2D.new()
	seg.position = Vector2(x + SEG_WIDTH * 0.5, ground_y + GROUND_THICKNESS * 0.5)
	seg.collision_layer = 1
	seg.collision_mask = 0

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(SEG_WIDTH, GROUND_THICKNESS)
	shape.shape = rect
	seg.add_child(shape)

	var fill: ColorRect = ColorRect.new()
	fill.color = FLOOR_COLORS[biome]
	fill.position = Vector2(-SEG_WIDTH * 0.5, -GROUND_THICKNESS * 0.5)
	fill.size = Vector2(SEG_WIDTH, GROUND_THICKNESS)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg.add_child(fill)

	var top: ColorRect = ColorRect.new()
	top.color = FLOOR_TOP_COLORS[biome]
	top.position = Vector2(-SEG_WIDTH * 0.5, -GROUND_THICKNESS * 0.5)
	top.size = Vector2(SEG_WIDTH, 10.0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg.add_child(top)

	add_child(seg)
	_segments[index] = seg

	## Spawnear 2 bouncers por segment con posiciones variables cerca del suelo
	_spawn_two_bouncers(index, x)


func _spawn_two_bouncers(index: int, seg_x: float) -> void:
	var bouncer_y_min: float = ground_y - 44.0
	var bouncer_y_max: float = ground_y - 120.0

	for i in range(2):
		var offset_x: float = randf_range(SEG_WIDTH * 0.15, SEG_WIDTH * 0.85)
		var offset_y: float = randf_range(bouncer_y_min - 20.0, bouncer_y_max)
		var bx: float = seg_x + offset_x
		var by: float = clamp(offset_y, bouncer_y_min, ground_y - 1.0)
		_spawn_bouncer_at_index(index, i, bx, by)


func _spawn_bouncer_at_index(index: int, bouncer_idx: int, x: float, y: float) -> void:
	var key: String = str(index) + "_" + str(bouncer_idx)
	if key in _bouncers:
		return
	var b: Node2D = BouncerScene.instantiate()
	b.position = Vector2(x, clamp(y, ground_y - 120, ground_y - 44))
	add_child(b)
	b.setup(Bouncer.Kind.CRATE if randf() < 0.5 else Bouncer.Kind.ENEMY)
	_bouncers[key] = b


func _is_bouncer_valid(key: String) -> bool:
	## Retorna true si el bouncer existe en el diccionario Y su instancia es válida
	if not _bouncers.has(key):
		return false
	var b: Node = _bouncers[key]
	return is_instance_valid(b)
