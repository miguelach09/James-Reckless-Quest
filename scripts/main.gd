extends Node2D
## Orquesta la escena principal: jugador, mundo, trivia, tienda, jefe y victoria.

const BossScene: PackedScene = preload("res://scenes/Boss.tscn")

const SKIES: Dictionary = {
	"city": "res://assets/uploaded/city.png",
	"jungle": "res://assets/uploaded/jungle.png",
	"volcano": "res://assets/uploaded/volcano.png",
}

@onready var world: Node2D = $World
@onready var player: Node2D = $Player
@onready var sky_texture: TextureRect = $Sky/SkyTexture
@onready var victory_ui: CanvasLayer = $VictoryUI
@onready var victory_button: Button = $VictoryUI/Root/Center/Panel/Margin/VBox/Button
@onready var distance_label: Label = $CanvasLayer/DistanceLabel

var _current_biome: String = ""
var _boss: Node = null
var _distance: float = 0.0
var _high_score: float = 0.0
var _is_store_active: bool = false
var _previous_game_state: int = 0


func _ready() -> void:
	GameManager.reset_run()
	MusicManager.play("game")
	victory_ui.hide()
	victory_button.pressed.connect(_on_victory_continue)
	world.set("player", player)
	GameManager.state_changed.connect(_on_state_changed)
	_update_sky()
	# Al entrar, abre el Campamento Táctico para permitir el primer lanzamiento.
	GameManager.open_shop()


func _process(_delta: float) -> void:
	_update_sky()
	GameManager.last_distance = maxf(GameManager.last_distance, player.global_position.x)
	_check_goal()
	_update_distance()

	# Alternar menú de tienda al presionar R
	if Input.is_key_pressed(KEY_R):
		_toggle_store()


func _biome_for_x(x: float) -> String:
	if x >= 14000.0:
		return "volcano"
	elif x >= 7000.0:
		return "jungle"
	return "city"


func _update_sky() -> void:
	var biome: String = _biome_for_x(player.global_position.x)
	if biome != _current_biome:
		_current_biome = biome
		sky_texture.texture = load(SKIES[biome])
	_refresh_music()


## La música del Jefe suena durante TODO el tramo del volcán y toda la pelea,
## no solo al entrar: así no se corta al volver de la tienda ni tras un golpe.
func _refresh_music() -> void:
	# Boss fight always plays boss music, regardless of biome
	if GameManager.current_state == GameManager.GameState.BOSS_FIGHT:
		MusicManager.play("boss")
	else:
		if _current_biome == "volcano":
			MusicManager.play("boss")
		else:
			MusicManager.play("game")


## Meta final: James llega hasta Pepito. Solo se gana con el Jefe ya vencido;
## mientras siga en pie, el Jefe lo persigue y le corta el paso al rescate.
func _check_goal() -> void:
	if GameManager.current_state == GameManager.GameState.VICTORY:
		return
	if player.global_position.x < GameManager.PEPITO_X - 90.0:
		return
	if GameManager.boss_defeated:
		GameManager.win()


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.BOSS_FIGHT:
			_spawn_boss()
		GameManager.GameState.VICTORY:
			victory_ui.show()
	_refresh_music()


func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		return
	_boss = BossScene.instantiate()
	var gy: float = float(world.get("ground_y"))
	_boss.global_position = Vector2(GameManager.BOSS_TRIGGER_X + 600.0, gy)
	add_child(_boss)


func _on_victory_continue() -> void:
	GameManager.current_checkpoint_x = GameManager.CHECKPOINT_CITY
	GameManager.coins = 150
	get_tree().change_scene_to_file("res://scenes/IntroMenu.tscn")

func _game_restart() -> void:
	GameManager.reset_run()
	MusicManager.play("game")
	world.set("player", player)
	GameManager.open_shop()
	_current_biome = ""
	_distance = 0.0
	_high_score = 0.0
	player.position = Vector2(GameManager.CHECKPOINT_CITY + 80, 520)
	player.velocity = Vector2.ZERO
	player.show()

func _toggle_store() -> void:
	_is_store_active = not _is_store_active
	if _is_store_active:
		# Store the current game state before opening shop
		_previous_game_state = GameManager.current_state
		GameManager.open_shop()
	else:
		# Restore the game state that was active before the shop opened
		GameManager.set_state(_previous_game_state)
		get_tree().paused = false

func _update_distance() -> void:
	# Distancia desde checkpoint actual (mismos 80px que al morir)
	_distance = maxf(0.0, player.global_position.x - 80.0)
	
	# Mostrar distancia actual en label (números enteros, sin decimales)
	var dist_str = str(int(_distance))  # Sin decimales
	distance_label.text = "Dist: " + dist_str + " m"
	
	# Ya no trackeamos la distancia total de la partida aquí
	# Eso se mostrará cuando el jugador muera en la pantalla de la tienda
	# (player.gd se encarga de mostrar la distancia total al muerte)
