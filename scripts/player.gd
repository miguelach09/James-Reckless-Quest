extends CharacterBody2D
signal stopped
signal trivia_boost_applied(is_correct: bool)

const GRAVITY := 1500.0
## Impulso de la trivia (limitado: encadenar aciertos ya no dispara a James
## directo al final del recorrido).
const TRIVIA_BOOST_VX := 480.0
const TRIVIA_MAX_VX := 1150.0
const BASE_LAUNCH_VX := 700.0
const BASE_LAUNCH_VY := -950.0
const BASE_BOUNCE_VY := -760.0
const SLAM_SPEED := 1900.0
const MIN_SPEED_TO_CONTINUE := 50.0
const GROUNDED_COOLDOWN := 3.0
const MAX_FALL := 1700.0
const BOSS_CHARGE_RANGE := 150.0
## Avance mínimo durante la pelea del Jefe: James nunca se queda quieto.
const BOSS_MIN_VX := 200.0
const FALL_LIMIT_Y := 1500.0
const MAX_FALL_TIME := 8.0

@export var launch_ground_y: float = 520.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var boost_fx: Sprite2D = $BoostFx
@onready var camera: Camera2D = $Camera2D

var boss_hits_taken: int = 0

var _slam_active: bool = false
## Pequeña ventana tras el Slam para que el golpe cuente al aterrizar.
var _slam_grace: float = 0.0
var _charging_boss: bool = false
var _charge_time: float = 0.0
var _can_bounce: bool = false
var _boost_time: float = 0.0
var _run_start_x: float = 0.0
var _fall_time: float = 0.0
var _grounded_active: bool = false
var _grounded_timer: float = 0.0
var _max_reached_x: float = 0.0
var _distance_traveled: float = 0.0
var _distance_at_death: float = 0.0
var _is_dead: bool = false
var _time_on_ground: float = 0.0


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

	if _charge_time > 0.0:
		_charge_time -= delta
		if _charge_time <= 0.0:
			_charging_boss = false

	if _slam_grace > 0.0:
		_slam_grace -= delta

	if GameManager.current_state == GameManager.GameState.BOSS_FIGHT and velocity.x >= 0.0 and velocity.x < BOSS_MIN_VX:
		velocity.x = BOSS_MIN_VX

	if _slam_active:
		velocity.y = SLAM_SPEED
	elif not is_on_floor() and Input.is_action_just_pressed("slam"):
		_start_slam()

	move_and_slide()

	## Mientras el Jefe viva, James no pasa del final del arena: el Jefe le corta
	## el paso y Pepito queda más allá, fuera del alcance.
	if GameManager.current_state == GameManager.GameState.BOSS_FIGHT and not GameManager.boss_defeated and global_position.x > GameManager.ARENA_END_X:
		global_position.x = GameManager.ARENA_END_X

	_update_fall_watch(delta)
	
	if global_position.x > _max_reached_x:
		_max_reached_x = global_position.x
	
	_distance_traveled = max(0.0, _max_reached_x - _run_start_x)
	

	_update_checkpoint()
	_update_anim()


	if not is_on_floor():
		_can_bounce = true
		_time_on_ground = _time_on_ground
	elif velocity.y >= 0.0 and _can_bounce:
		_bounce()


	if is_on_floor() and not _slam_active:
		if absf(velocity.x) < 50:
			velocity.x = 0
		_time_on_ground += delta
	else:
		_time_on_ground = _time_on_ground


	if is_on_floor() and absf(velocity.x) < MIN_SPEED_TO_CONTINUE:
		_check_stopped();


func _start_slam() -> void:
	_slam_active = true
	_slam_grace = 0.25
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
		if _time_on_ground > 0.05:
			_is_dead = true
			_grounded_fallen()
			_can_bounce = false
			# Set death flag in GameManager so shop knows to show death screen
			GameManager._is_dead = true
			GameManager.open_shop()
		else:
			_grounded_active = false


func _grounded_fallen() -> void:
	_is_dead = true
	_grounded_timer = 0.0
	_grounded_active = true
	velocity.x = 0
	_distance_at_death = _distance_traveled
	_show_distance_label()
	_play_anim("dead")
	_can_bounce = false
	GameManager.open_shop()


func _show_distance_label() -> void:
	# Access DistanceLabel from Main scene via tree root
	var main_node = get_tree().root.get_node("Main")
	var distance_label = main_node.get_node("CanvasLayer/DistanceLabel")
	if distance_label and _distance_at_death > 0:
		distance_label.text = "Dist: " + str(int(_distance_at_death)) + " m (muerto)"

func _update_anim() -> void:
	sprite.flip_h = velocity.x < -1.0
	if _is_dead:
		_play_anim("dead")
	elif not is_on_floor():
		_play_anim("jump" if velocity.y < 0.0 else "fly")
	elif absf(velocity.x) < 25.0:
		_play_anim("idle")
	else:
		_play_anim("run")


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
	_max_reached_x = 0.0
	boost_fx.hide()

	_distance_at_death = _distance_traveled

	_show_distance_label()

	global_position = Vector2(GameManager.current_checkpoint_x + 80.0, launch_ground_y)
	velocity = Vector2.ZERO
	_run_start_x = global_position.x
	sprite.flip_h = false
	_play_anim("idle")
	GameManager.open_shop()


func launch_from_checkpoint() -> void:
	boss_hits_taken = 0
	_slam_active = false
	_charging_boss = false
	_can_bounce = false
	_boost_time = 0.0
	_fall_time = 0.0
	_max_reached_x = 0.0
	boost_fx.hide()

	global_position = Vector2(GameManager.current_checkpoint_x + 80.0, launch_ground_y)
	_run_start_x = global_position.x
	var power: float = GameManager.launch_power_multiplier()
	velocity = Vector2(BASE_LAUNCH_VX * power, BASE_LAUNCH_VY * power)
	sprite.flip_h = false
	_play_anim("run")
	_is_dead = false  # Reset death state
	GameManager._is_dead = false  # Reset game manager death state
	GameManager.set_state(GameManager.GameState.FLYING)


func apply_trivia_boost(is_correct: bool) -> void:
	if is_correct:
		var boost: float = GameManager.trivia_boost_multiplier()
		var max_vx: float = TRIVIA_MAX_VX + 200.0 * (boost - 1.0)
		velocity.x = clampf(maxf(velocity.x, 0.0) + TRIVIA_BOOST_VX * boost, 0.0, max_vx)
		velocity.y = -700.0 - 150.0 * boost
		_slam_active = false
		_boost_time = 1.0
		boost_fx.show()
		if GameManager.current_state == GameManager.GameState.BOSS_FIGHT:
			_charging_boss = true
			_charge_time = 2.5
		_play_anim("jump")
	else:
		velocity.x *= 0.5
		_play_anim("hit")
	trivia_boost_applied.emit(is_correct)


## ¿James está aplastando (Slam) en este momento?
func is_slamming() -> bool:
	return _slam_active or _slam_grace > 0.0


## ¿James embiste al Jefe tras acertar una trivia?
func is_charging_boss() -> bool:
	return _charging_boss


## Impulso al aplastar (Slam) a un Ser Subterráneo: James rebota hacia arriba.
func bounce_from_bouncer(from_enemy: bool) -> void:
	if not from_enemy:
		return
	_slam_active = false
	_slam_grace = 0.0
	var bounce: float = BASE_BOUNCE_VY * (1.0 + float(GameManager.elasticity_level - 1) * 0.03)
	velocity.y = minf(bounce, -900.0)
	velocity.x = maxf(velocity.x, 320.0)
	_play_anim("jump")


## Rebote al golpear al Jefe: sube y se queda cerca para repetir el golpe.
func bounce_from_boss() -> void:
	_slam_active = false
	_slam_grace = 0.0
	_charging_boss = false
	_charge_time = 0.0
	velocity.y = -900.0
	velocity.x = maxf(velocity.x * 0.5, 260.0)
	_play_anim("jump")


## Al caer el Jefe, James sale disparado hacia Pepito para el rescate.
func launch_toward_pepito() -> void:
	_slam_active = false
	_charging_boss = false
	_charge_time = 0.0
	velocity = Vector2(760.0, -880.0)
	_play_anim("jump")


func take_boss_obstacle_hit() -> void:
	if GameManager.current_state != GameManager.GameState.BOSS_FIGHT:
		return
	boss_hits_taken += 1
	velocity.x *= 0.6
	velocity.y = -350.0
	_play_anim("hit")
	if boss_hits_taken >= 6:
		GameManager.boss_knockback_to_volcano()


func _update_checkpoint() -> void:
	GameManager.update_checkpoint(_max_reached_x)
	if _max_reached_x >= GameManager.BOSS_TRIGGER_X:
		GameManager.start_boss_fight()


func _play_anim(anim: StringName) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
