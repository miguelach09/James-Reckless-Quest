extends Node2D
## Jefe final: Líder de los Seres Subterráneos (lanza obstáculos volcánicos).

signal defeated

const ProjectileScene: PackedScene = preload("res://scenes/BossProjectile.tscn")

@export var max_hp: int = 3
@export var throw_interval: float = 1.6

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var cage: Sprite2D = $Cage
@onready var throw_timer: Timer = $ThrowTimer
@onready var hp_bar: ProgressBar = $BossUI/HPBar

## Colisión con el jugador
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hp: int = 3

var _player: Node2D
var _defeated: bool = false
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("boss")
	hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	if hp_bar != null:
		hp_bar.max_value = float(max_hp)
		hp_bar.value = float(hp)
	throw_timer.wait_time = throw_interval
	throw_timer.timeout.connect(_throw_projectile)
	throw_timer.start()
	
	## Configurar colisión shape para detectar al jugador
	if collision_shape != null:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(120.0, 120.0)  # Tamaño aproximado del boss
		collision_shape.shape = shape
		collision_shape.collision_layer = 1
		collision_shape.collision_mask = 1  # Colisionar con capa de jugador


func _throw_projectile() -> void:
	if _defeated:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var p: Node2D = ProjectileScene.instantiate()
	p.global_position = global_position + Vector2(-70.0, -20.0)
	get_parent().add_child(p)
	if p.has_method("launch_at"):
		p.launch_at(_player.global_position + Vector2(0.0, -40.0))


func take_damage(amount: int) -> void:
	if _defeated:
		return
	hp = maxi(0, hp - amount)
	if hp_bar != null:
		hp_bar.value = float(hp)
	_flash()
	if hp <= 0:
		_defeat()


func _on_body_entered(body: Node2D) -> void:
	## Detectar colisión con el jugador - derrota instantánea
	if body.is_in_group("player") and not _defeated:
		_defeated = true
		throw_timer.stop()
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("hurt"):
			sprite.play("hurt")
		if cage != null:
			var tw: Tween = create_tween()
			tw.tween_property(cage, "modulate:a", 0.0, 0.6)
		GameManager.win()
		defeated.emit()
		queue_free()


func _flash() -> void:
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
	_flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)


func _defeat() -> void:
	_defeated = true
	throw_timer.stop()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
	if cage != null:
		var tw: Tween = create_tween()
		tw.tween_property(cage, "modulate:a", 0.0, 0.6)
	GameManager.win()
	defeated.emit()
	await get_tree().create_timer(1.4).timeout
	queue_free()


func is_defeated() -> bool:
	return _defeated