extends Node2D
## Jefe final: Líder de los Seres Subterráneos.
## Custodia la jaula de Pepito y lanza obstáculos volcánicos. Al tocarlo lanza
## una pregunta: solo si James acierta se le quita vida.

signal defeated

const ProjectileScene: PackedScene = preload("res://scenes/BossProjectile.tscn")

@export var max_hp: int = 8
@export var throw_interval: float = 1.6
## Espera entre una pregunta y la siguiente al tocar al Jefe.
@export var question_cooldown: float = 0.9
## El Jefe persigue a James para no dejarle pasar hacia Pepito.
@export var move_speed: float = 780.0
@export var follow_offset: float = 200.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var throw_timer: Timer = $ThrowTimer
@onready var hp_bar: ProgressBar = $BossUI/HPBar
@onready var hitbox: Area2D = $Hitbox

var hp: int = 8

var _player: Node2D
var _defeated: bool = false
var _flash_tween: Tween
var _contact_cooldown: float = 0.0
var _question_lock: float = 0.0
var _question_pending: bool = false


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
	
func _physics_process(delta: float) -> void:
	if _defeated:
		return
	if _question_lock > 0.0:
		_question_lock -= delta
	_follow_player(delta)
	if hitbox == null:
		return
	## Mientras hay una pregunta en pantalla, el Jefe no pide otra.
	if GameManager.current_state == GameManager.GameState.TRIVIA_ACTIVE:
		return
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta
		return
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player"):
			_handle_player_contact(body)
			break


## Persigue a James en horizontal, sin salirse del tramo del volcán.
func _follow_player(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var min_x: float = GameManager.BOSS_TRIGGER_X + 200.0
	## El Jefe se queda entre James y Pepito: nunca encima de Pepito.
	var max_x: float = GameManager.ARENA_END_X + follow_offset
	var target_x: float = clampf(_player.global_position.x + follow_offset, min_x, max_x)
	global_position.x = move_toward(global_position.x, target_x, move_speed * delta)


func _throw_projectile() -> void:
	if _defeated:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var p: Node2D = ProjectileScene.instantiate()
	p.global_position = global_position + Vector2(-90.0, -220.0)
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
	elif hp * 2 <= max_hp:
		## Fase de furia: lanza obstáculos más seguido.
		throw_timer.wait_time = maxf(0.6, throw_interval * 0.55)


## Choque con James: si llega atacando (Slam o embestida) recibe daño;
## si solo lo toca, el Jefe lo rechaza.
func _handle_player_contact(body: Node) -> void:
	if _defeated:
		return
	var attacking: bool = false
	if body.has_method("is_slamming") and body.is_slamming():
		attacking = true
	elif body.has_method("is_charging_boss") and body.is_charging_boss():
		attacking = true

	if attacking:
		if body.has_method("bounce_from_boss"):
			body.bounce_from_boss()
		_contact_cooldown = 0.3
	else:
		_contact_cooldown = 0.5

	## El daño no es automático: al tocar al Jefe hay que acertar una pregunta.
	if _question_lock <= 0.0 and not _question_pending:
		_ask_damage_question()


## Lanza una pregunta de trivia: solo un acierto le quita vida al Jefe.
func _ask_damage_question() -> void:
	var tm: Node = get_tree().get_first_node_in_group("trivia_manager")
	if tm == null or not tm.has_method("activate") or not tm.has_method("is_active"):
		return
	if tm.is_active():
		return
	if not tm.is_connected("question_answered", _on_question_answered):
		tm.connect("question_answered", _on_question_answered)
	_question_pending = true
	tm.activate("¡ACIERTA PARA GOLPEARLO!")


func _on_question_answered(is_correct: bool) -> void:
	if not _question_pending:
		return
	_question_pending = false
	_question_lock = question_cooldown
	if _defeated:
		return
	if is_correct:
		take_damage(1)


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
	GameManager.defeat_boss()
	defeated.emit()
	## James sale disparado hacia Pepito para el rescate.
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("launch_toward_pepito"):
		player.launch_toward_pepito()
	await get_tree().create_timer(1.6).timeout
	queue_free()


func is_defeated() -> bool:
	return _defeated