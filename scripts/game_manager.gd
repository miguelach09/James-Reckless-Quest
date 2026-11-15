extends Node
## Autoload "GameManager": estado global, monedas, mejoras y checkpoints.
## NOTA: no usa class_name porque un Autoload ocupa ese nombre global.

enum GameState {
	INTRO_MENU,
	WAITING_LAUNCH,
	FLYING,
	TRIVIA_ACTIVE,
	BOSS_FIGHT,
	SHOP_MENU,
	VICTORY,
}

signal state_changed(new_state: GameState)
signal coins_changed(amount: int)
signal checkpoint_changed(checkpoint_x: float)
signal upgrade_purchased(upgrade_id: String, new_level: int)

# --- Checkpoints (px) ---
const CHECKPOINT_CITY := 0.0
const CHECKPOINT_JUNGLE := 7000.0
const CHECKPOINT_VOLCANO := 14000.0
## Checkpoint avanzado dentro del volcán, para no repetir todo el tramo.
const CHECKPOINT_VOLCANO_DEEP := 20000.0
const BOSS_TRIGGER_X := 24000.0
## Reaparecer justo en la entrada de la guarida del Jefe.
const CHECKPOINT_BOSS := BOSS_TRIGGER_X
## Punto donde espera Pepito: la meta final, tras vencer al Jefe.
const PEPITO_X := BOSS_TRIGGER_X + 2400.0
## Hasta aquí puede avanzar James mientras el Jefe viva: el Jefe le corta el
## paso aquí, así Pepito queda claramente separado de la pelea.
const ARENA_END_X := PEPITO_X - 600.0
## Vida del Jefe final (más alta = pelea más larga).
const BOSS_MAX_HP := 5

# --- Mejoras ---
const MAX_UPGRADE_LEVEL := 10
const UPGRADE_BASE_COST := 50

var current_state: GameState = GameState.INTRO_MENU
var current_checkpoint_x: float = CHECKPOINT_CITY
var coins: int = 150
@export var boss_defeated: bool = false

var launch_power_level: int = 1
var elasticity_level: int = 1
var trivia_boost_level: int = 1

var last_distance: float = 0.0


func set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)


## Actualiza el checkpoint si James ha superado un umbral de bioma.
func update_checkpoint(player_x: float) -> void:
	var new_cp: float = current_checkpoint_x
	if player_x >= CHECKPOINT_BOSS:
		new_cp = CHECKPOINT_BOSS
	elif player_x >= CHECKPOINT_VOLCANO_DEEP:
		new_cp = CHECKPOINT_VOLCANO_DEEP
	elif player_x >= CHECKPOINT_VOLCANO:
		new_cp = CHECKPOINT_VOLCANO
	elif player_x >= CHECKPOINT_JUNGLE:
		new_cp = CHECKPOINT_JUNGLE
	if new_cp > current_checkpoint_x:
		current_checkpoint_x = new_cp
		checkpoint_changed.emit(current_checkpoint_x)


func checkpoint_biome_name() -> String:
	if current_checkpoint_x >= CHECKPOINT_BOSS:
		return "La Guarida del Jefe"
	elif current_checkpoint_x >= CHECKPOINT_VOLCANO_DEEP:
		return "El Corazón del Volcán"
	elif current_checkpoint_x >= CHECKPOINT_VOLCANO:
		return "El Volcán"
	elif current_checkpoint_x >= CHECKPOINT_JUNGLE:
		return "La Selva"
	return "La Ciudad"


# --- Multiplicadores de mejora ---
func launch_power_multiplier() -> float:
	return 1.0 + float(launch_power_level - 1) * 0.18


## Factor de velocidad horizontal conservada en cada rebote (0.0 - 0.95).
func elasticity_factor() -> float:
	return clampf(0.55 + float(elasticity_level - 1) * 0.04, 0.0, 0.95)


func trivia_boost_multiplier() -> float:
	return 1.0 + float(trivia_boost_level - 1) * 0.50


func upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"launch_power":
			return launch_power_level
		"elasticity":
			return elasticity_level
		"trivia_boost":
			return trivia_boost_level
	return 0


func upgrade_cost(upgrade_id: String) -> int:
	return UPGRADE_BASE_COST * (upgrade_level(upgrade_id) + 1)


func can_buy(upgrade_id: String) -> bool:
	return upgrade_level(upgrade_id) < MAX_UPGRADE_LEVEL and coins >= upgrade_cost(upgrade_id)


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy(upgrade_id):
		return false
	add_coins(-upgrade_cost(upgrade_id))
	match upgrade_id:
		"launch_power":
			launch_power_level += 1
		"elasticity":
			elasticity_level += 1
		"trivia_boost":
			trivia_boost_level += 1
	upgrade_purchased.emit(upgrade_id, upgrade_level(upgrade_id))
	return true


func reset_run() -> void:
	last_distance = 0.0
	boss_defeated = false


func open_shop() -> void:
	set_state(GameState.SHOP_MENU)


func start_boss_fight() -> void:
	set_state(GameState.BOSS_FIGHT)


## El Jefe golpea a James: vuelve al último checkpoint del Volcán y abre la tienda.
func boss_knockback_to_volcano() -> void:
	if current_checkpoint_x < CHECKPOINT_VOLCANO:
		current_checkpoint_x = CHECKPOINT_VOLCANO
		checkpoint_changed.emit(current_checkpoint_x)
	set_state(GameState.SHOP_MENU)


## El Jefe final ha caído: Pepito queda libre y la meta se desbloquea.
func defeat_boss() -> void:
	boss_defeated = true


func win() -> void:
	set_state(GameState.VICTORY)