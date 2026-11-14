extends CharacterBody2D
## James: jugador de lanzamiento y rebotes horizontales.

signal stopped
signal trivia_boost_applied(is_correct: bool)

const GRAVITY := 1500.0
const BASE_LAUNCH_VX := 700.0
const BASE_LAUNCH_VY := -950.0
const BASE_BOUNCE_VY := -760.0
const SLAM_SPEED := 1900.0
const MIN_SPEED_TO_CONTINUE := 50.0
const GROUNDED_COOLDOWN := 3.0
const MAX_FALL := 1700.0
const BOSS_CHARGE_RANGE := 150.0
## Si James cae más de esta distancia por debajo del suelo, se considera fuera del mapa.
const FALL_LIMIT_Y := 1500.0
## Tiempo máximo cayendo sin tocar el suelo antes de respawnear.
const MAX_FALL_TIME := 8.0

@export var launch_ground_y: float = 520.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var boost_fx: Sprite2D = $BoostFx
@onready var camera: Camera2D = $Camera2D

var boss_hits_taken: int = 0

var _slam_active: bool = false
var _charging_boss: bool = false
var _can_bounce: bool = false
var _boost_time: float = 0.0
var _run_start_x: float = 0.0
var _fall_time: float = 0.0
var _grounded_active: bool = false
var _grounded_timer: float = 0.0
var _max_reached_x: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	boost_fx.hide()
	launch_ground_y = global_position.y
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if _boost_time > 0.0:
		_boost_time -= delta
		if _boost_time <= 0.0:
			boost_fx.hide()

	match GameManager.current_state:
		GameManager.GameState.FLYING, GameManager.GameState.BOSS_FIGHT:
			_fly(delta)
		GameManager.GameState.WAITING_LAUNCH:
			velocity = Vector2.ZERO
			_play_anim("idle")
		_:
			pass


func _fly(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if _slam_active:
		velocity.y = SLAM_SPEED
	elif not is_on_floor() and Input.is_action_just_pressed("slam"):
		_start_slam()

	if _charging_boss:
		_try_charge_boss()

	move_and_slide()
	_update_fall_watch(delta)
	_check_boss_victory()
	
	## Trackear la posición máxima alcanzada para checkpoints
	if global_position.x > _max_reached_x:
		_max_reached_x = global_position.x
	
	_update_checkpoint()
	_update_anim()

	if not is_on_floor():
		## Si James está cayendo rápido o tiene velocidad vertical positiva,
		## permitir el bounce. Si está quieto cerca del suelo, bloquear el bounce.
		if velocity.y > 0.0 and _grounded_timer < 0.1:
			## James aún está recuperándose del bounce, permitir otro bounce suave
			_can_bounce = true
		else:
			_can_bounce = false
	elif velocity.y < -50.0 and _can_bounce:
		## James está cayendo fuerte, hacer bounce normal
		_bounce()
		_can_bounce = false

	if is_on_floor() and absf(velocity.x) < MIN_SPEED_TO_CONTINUE:
		_check_stopped()


func _start_slam() -> void:
	_slam_active = true
	velocity.y = SLAM_SPEED
	velocity.x *= 0.6
	_play_anim("attack")


func _bounce() -> void:
	_slam_active = false
	velocity.y = BASE_BOUNCE_VY * (1.0 + float(GameManager.elasticity_level - 1) * 0.03)
	velocity.x *= GameManager.elasticity_factor()
	_play_anim("jump")


func _check_stopped() -> void:
	var traveled: float = maxf(0.0, global_position.x - _run_start_x)
	GameManager.add_coins(int(traveled / 100.0))
	if GameManager.current_state == GameManager.GameState.BOSS_FIGHT:
		GameManager.boss_knockback_to_volcano()
	else:
		## Si James está quieto en el suelo con velocidad baja, activar estado "muerto"
		if is_on_floor() and absf(velocity.x) < MIN_SPEED_TO_CONTINUE:
			_is_dead = true
			_grounded_fallen()
		else:
			_grounded_active = false
			_is_dead = false
	stopped.emit()


func _grounded_fallen() -> void:
	## Cambiar a estado de James muerto/aplastado en el suelo
	_is_dead = true
	_grounded_timer = 0.0
	_grounded_active = true
	## Resetear velocidad horizontal para que parezca realmente muerto
	velocity.x = 0.0


func _update_anim() -> void:
	sprite.flip_h = velocity.x < -1.0
	if _is_dead:
		## Mostrar sprite de James muerto/aplastado en el suelo
		## El sprite permanecerá quieto (usamos idle pero el estado _is_dead indica que está muerto)
		_play_anim("idle")
	elif _slam_active:
		_play_anim("attack")
	elif not is_on_floor():
		# Subiendo: pose de salto; cayendo: planeo/floteo animado.
		_play_anim("jump" if velocity.y < 0.0 else "fly")
	elif absf(velocity.x) < 25.0:
		_play_anim("idle")
	else:
		_play_anim("run")


## Vigila caídas infinitas: si James lleva demasiado tiempo en el aire o se
## hunde por debajo del suelo, lo devuelve al mapa en el checkpoint actual.
func _update_fall_watch(delta: float) -> void:
	if is_on_floor():
		_fall_time = 0.0
		return
	_fall_time += delta
	var out_of_bounds: bool = global_position.y > launch_ground_y + FALL_LIMIT_Y
	var falling_too_long: bool = _fall_time > MAX_FALL_TIME and velocity.y > 0.0
	if out_of_bounds or falling_too_long:
		_respawn()


func _respawn() -> void:
	_fall_time = 0.0
	_slam_active = false
	_charging_boss = false
	_can_bounce = false
	_boost_time = 0.0
	_max_reached_x = 0.0  ## Reiniciar la posición máxima alcanzada
	boost_fx.hide()

	global_position = Vector2(GameManager.current_checkpoint_x + 80.0, launch_ground_y)
	velocity = Vector2.ZERO
	_run_start_x = global_position.x
	sprite.flip_h = false
	_play_anim("idle")
	# Vuelve al Campamento Táctico para poder relanzarse desde el checkpoint.
	GameManager.open_shop()


## Coloca a James en el Cañón del Checkpoint actual y lo dispara.
func launch_from_checkpoint() -> void:
	boss_hits_taken = 0
	_slam_active = false
	_charging_boss = false
	_can_bounce = false
	_boost_time = 0.0
	_fall_time = 0.0
	_max_reached_x = 0.0  ## Reiniciar la posición máxima alcanzada
	boost_fx.hide()

	global_position = Vector2(GameManager.current_checkpoint_x + 80.0, launch_ground_y)
	_run_start_x = global_position.x
	var power: float = GameManager.launch_power_multiplier()
	velocity = Vector2(BASE_LAUNCH_VX * power, BASE_LAUNCH_VY * power)
	sprite.flip_h = false
	_play_anim("run")
	GameManager.set_state(GameManager.GameState.FLYING)


## Resultado de la trivia: Rocket Boost o pérdida de velocidad.
func apply_trivia_boost(is_correct: bool) -> void:
	if is_correct:
		var boost: float = GameManager.trivia_boost_multiplier()
		velocity.x = maxf(velocity.x, 0.0) + 600.0 * boost
		velocity.y = -700.0 - 150.0 * boost
		_slam_active = false
		_boost_time = 1.0
		boost_fx.show()
		if GameManager.current_state == GameManager.GameState.BOSS_FIGHT:
			_charging_boss = true
		_play_anim("jump")
	else:
		velocity.x *= 0.5
		_play_anim("hit")
	trivia_boost_applied.emit(is_correct)


func _try_charge_boss() -> void:
	var targets: Array = get_tree().get_nodes_in_group("boss")
	if targets.is_empty():
		_charging_boss = false
		return
	for t in targets:
		if t.has_method("take_damage") \
				and global_position.distance_to(t.global_position) < BOSS_CHARGE_RANGE:
			t.take_damage(1)
			_charging_boss = false
			velocity.x *= 0.4
			return


## Llamado por los proyectiles del Jefe.
func take_boss_obstacle_hit() -> void:
	if GameManager.current_state != GameManager.GameState.BOSS_FIGHT:
		return
	boss_hits_taken += 1
	velocity.x *= 0.6
	velocity.y = -350.0
	_play_anim("hit")
	if boss_hits_taken >= 3:
		GameManager.boss_knockback_to_volcano()


func _update_checkpoint() -> void:
	## Usar la posición máxima alcanzada para registrar checkpoints
	## Esto evita que los checkpoints se pierdan cuando James rebota
	GameManager.update_checkpoint(_max_reached_x)
	if _max_reached_x >= GameManager.BOSS_TRIGGER_X:
		GameManager.start_boss_fight()


func _play_anim(anim: StringName) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## Variables para estado de victoria del boss
var _victory_screen: bool = false
var _defeated_by_boss: bool = false


## Función para verificar victoria del boss
func _check_boss_victory() -> void:
	if GameManager.boss_defeated and not _victory_screen and _defeated_by_boss:
		_victory_screen = true
		## Usar un timer simple y cambiar al menú después de 3 segundos
		get_tree().create_timer(3.0).timeout.connect(_on_victory_timeout)
		get_tree().create_timer(3.0).start()


## Controlador de timeout de victoria
func _on_victory_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/IntroMenu.tscn")


## En la función _physics_process, verificar victoria del boss cada frame
## (esta llamada se agregará en el processing)
