extends Node2D
## Genera suelo infinito, decoración de bioma, rebotadores y cañones.
## Elimina (queue_free) todo lo que queda detrás de la cámara.

const BouncerScene: PackedScene = preload("res://scenes/Bouncer.tscn")

const SEG_WIDTH := 512.0
const GROUND_THICKNESS := 900.0
const VIEW_AHEAD := 1700.0
const CLEANUP_BEHIND := 1100.0
const BOUNCER_CHANCE := 0.7
const CRATE_RATIO := 0.3

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
var next_spawn_x: float = -SEG_WIDTH


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
	while next_spawn_x < cam_x + VIEW_AHEAD:
		_spawn_segment(next_spawn_x)
		next_spawn_x += SEG_WIDTH
	_cleanup(cam_x)


func biome_for_x(x: float) -> String:
	if x >= 14000.0:
		return "volcano"
	elif x >= 7000.0:
		return "jungle"
	return "city"


func _spawn_segment(x: float) -> void:
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

	if x > 700.0 and randf() < BOUNCER_CHANCE:
		_spawn_bouncer(x + randf_range(120.0, SEG_WIDTH - 120.0))


func _spawn_bouncer(x: float) -> void:
	var b: Node2D = BouncerScene.instantiate()
	b.position = Vector2(x, ground_y - 44.0)
	add_child(b)
	b.setup(Bouncer.Kind.CRATE if randf() < CRATE_RATIO else Bouncer.Kind.ENEMY)


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


func _cleanup(cam_x: float) -> void:
	for c in get_children():
		if c is Node2D and not c.is_queued_for_deletion():
			if c.global_position.x < cam_x - CLEANUP_BEHIND:
				c.queue_free()