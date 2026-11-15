extends CanvasLayer
## Tienda de mejoras: Campamento Táctico Militar.

const UPGRADES: Array[Dictionary] = [
	{"id": "launch_power", "name": "Pólvora del Cañón", "icon": "res://assets/generated/icon_cannon.png", "desc": "Fuerza de lanzamiento inicial"},
	{"id": "elasticity", "name": "Botas Tácticas", "icon": "res://assets/generated/icon_boots.png", "desc": "Velocidad conservada al rebotar"},
	{"id": "trivia_boost", "name": "Combustible del Jetpack", "icon": "res://assets/generated/icon_jetpack.png", "desc": "Potencia del cohete al acertar"},
]

@onready var root: Control = $Root
@onready var checkpoint_label: Label = $Root/Center/Panel/Margin/VBox/CheckpointLabel
@onready var coins_label: Label = $Root/Center/Panel/Margin/VBox/CoinsLabel
@onready var rows_box: VBoxContainer = $Root/Center/Panel/Margin/VBox/Rows
@onready var launch_button: Button = $Root/Center/Panel/Margin/VBox/LaunchButton

var _row_refs: Dictionary = {}


func _ready() -> void:
	root.hide()
	_build_rows()
	launch_button.pressed.connect(_on_launch_pressed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.checkpoint_changed.connect(_on_checkpoint_changed)
	_on_state_changed(GameManager.current_state)
	# Check if this is a death shop opening
	if GameManager.current_state == GameManager.GameState.SHOP_MENU and GameManager._is_dead:
		show_death_screen()


func _build_rows() -> void:
	for up in UPGRADES:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)

		var icon: TextureRect = TextureRect.new()
		icon.texture = load(str(up["icon"]))
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = Label.new()
		name_label.text = str(up["name"])
		var level_label: Label = Label.new()
		var desc: Label = Label.new()
		desc.text = str(up["desc"])
		desc.modulate = Color(0.75, 0.75, 0.8, 1.0)
		info.add_child(name_label)
		info.add_child(level_label)
		info.add_child(desc)
		row.add_child(info)

		var cost_label: Label = Label.new()
		cost_label.custom_minimum_size = Vector2(96, 0)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cost_label)

		var buy: Button = Button.new()
		buy.text = "Mejorar"
		buy.custom_minimum_size = Vector2(120, 44)
		buy.pressed.connect(_on_buy_pressed.bind(str(up["id"])))
		row.add_child(buy)

		rows_box.add_child(row)
		_row_refs[str(up["id"])] = {"level": level_label, "cost": cost_label, "buy": buy}


func _refresh() -> void:
	checkpoint_label.text = "Checkpoint desbloqueado: %s  (x = %d)" % [
		GameManager.checkpoint_biome_name(), int(GameManager.current_checkpoint_x)
	]
	coins_label.text = "Puntos Tácticos: %d" % GameManager.coins

	for id in _row_refs.keys():
		var refs: Dictionary = _row_refs[id]
		var lvl: int = GameManager.upgrade_level(id)
		var level_label: Label = refs["level"]
		var cost_label: Label = refs["cost"]
		var buy: Button = refs["buy"]
		level_label.text = "Nivel %d / %d" % [lvl, GameManager.MAX_UPGRADE_LEVEL]
		if lvl >= GameManager.MAX_UPGRADE_LEVEL:
			cost_label.text = "MÁX"
			buy.disabled = true
		else:
			cost_label.text = "%d pts" % GameManager.upgrade_cost(id)
			buy.disabled = not GameManager.can_buy(id)

	launch_button.text = "LANZAR DESDE CHECKPOINT · %s" % GameManager.checkpoint_biome_name()


func _on_buy_pressed(id: String) -> void:
	if GameManager.buy_upgrade(id):
		_refresh()


func show_death_screen() -> void:
	# Hide the upgrade rows
	rows_box.hide()
	# Get root dimensions
	var r_size: Vector2 = root.size
	# Create death label
	var death_label: Label = Label.new()
	death_label.text = "Has muerto"
	death_label.font_size = 48
	death_label.color = Color(1.0, 0.0, 0.0, 1.0)
	death_label.anchor_shrink = Vector2(0.5, 0.5)
	death_label.position = Vector2(r_size.x / 2, 100)
	root.add_child(death_label)
	
	# Add James muerto sprite placeholder
	var james_sprite: Sprite2D = Sprite2D.new()
	# Use a gray color rect as placeholder for the dead james sprite
	james_sprite.color = Color(0.5, 0.5, 0.5, 1.0)
	james_sprite.custom_minimum_size = Vector2(100, 100)
	james_sprite.position = Vector2(r_size.x / 2, 200)
	root.add_child(james_sprite)
	
	# Add restart button
	var restart_button: Button = Button.new()
	restart_button.text = "Reintentar"
	restart_button.position = Vector2(r_size.x / 2 - 60, 350)
	restart_button.pressed.connect(_on_restart_pressed)
	root.add_child(restart_button)


func _on_restart_pressed() -> void:
	root.hide()
	rows_box.show()
	# Reset death state
	GameManager._is_dead = false
	_on_state_changed(GameManager.GameState.SHOP_MENU)


func _on_launch_pressed() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("launch_from_checkpoint"):
		root.hide()
		player.launch_from_checkpoint()


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.SHOP_MENU:
		_refresh()
		root.show()
	else:
		root.hide()


func _on_coins_changed(_amount: int) -> void:
	_refresh()


func _on_checkpoint_changed(_x: float) -> void:
	_refresh()