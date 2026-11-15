class_name Bouncer
extends Area2D
## Rebotador: Ser Subterráneo (enemigo) o Caja de Suministros (trivia).

enum Kind { ENEMY, CRATE }

const ENEMY_TEXTURE := "res://assets/generated/enemy_ser.png"
const CRATE_TEXTURE := "res://assets/generated/supply_crate.png"

@onready var sprite: Sprite2D = $Sprite

var kind: Kind = Kind.ENEMY

var _used: bool = false
var _bob_phase: float = 0.0


func setup(p_kind: Kind) -> void:
	kind = p_kind
	if is_node_ready():
		_apply_visual()


func _ready() -> void:
	_apply_visual()
	body_entered.connect(_on_body_entered)
	_bob_phase = randf() * TAU


func _apply_visual() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	if kind == Kind.CRATE:
		sprite.texture = load(CRATE_TEXTURE)
		sprite.scale = Vector2(0.85, 0.85)
	else:
		sprite.texture = load(ENEMY_TEXTURE)
		sprite.scale = Vector2.ONE


func _process(delta: float) -> void:
	_bob_phase += delta * 3.0
	if sprite != null and not _used:
		sprite.position.y = sin(_bob_phase) * 6.0


func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return

	if kind == Kind.CRATE:
		_used = true
		if body.has_method("bounce_from_bouncer"):
			body.bounce_from_bouncer(false)
		_trigger_trivia()
		_fade_out()
	else:
		if body.has_method("is_slamming") and body.is_slamming():
			if body.has_method("bounce_from_bouncer"):
				body.bounce_from_bouncer(true)
			GameManager.add_coins(5)
			_fade_out()
		else:
			if body.has_method("bounce_from_bouncer"):
				body.bounce_from_bouncer(false)


func _trigger_trivia() -> void:
	var tm: Node = get_tree().get_first_node_in_group("trivia_manager")
	if tm != null and tm.has_method("activate"):
		tm.activate()


func _fade_out() -> void:
	_used = true
	set_deferred("monitoring", false)
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
