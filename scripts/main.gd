extends Node2D
## Orquesta la escena principal: jugador, mundo, trivia, tienda, jefe y victoria.

const BossScene: PackedScene = preload("res://scenes/Boss.tscn")

const SKIES: Dictionary = {
	"city": "res://assets/uploaded/Wq89waY_rEI296y6WOdhp.png",
	"jungle": "res://assets/uploaded/5hVtKKt2v9DOFUJTALxq1.png",
	"volcano": "res://assets/uploaded/713zZZzS5QZqieubp_y3F.png",
}

@onready var world: Node2D = $World
@onready var player: Node2D = $Player
@onready var sky_texture: TextureRect = $Sky/SkyTexture
@onready var victory_ui: CanvasLayer = $VictoryUI
@onready var victory_button: Button = $VictoryUI/Root/Center/Panel/Margin/VBox/Button

var _current_biome: String = ""
var _boss: Node = null


func _ready() -> void:
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


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.BOSS_FIGHT:
			_spawn_boss()
		GameManager.GameState.VICTORY:
			victory_ui.show()


func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		return
	_boss = BossScene.instantiate()
	var gy: float = float(world.get("ground_y"))
	_boss.global_position = Vector2(GameManager.BOSS_TRIGGER_X + 700.0, gy)
	add_child(_boss)


func _on_victory_continue() -> void:
	GameManager.current_checkpoint_x = GameManager.CHECKPOINT_CITY
	GameManager.coins = 150
	get_tree().change_scene_to_file("res://scenes/IntroMenu.tscn")