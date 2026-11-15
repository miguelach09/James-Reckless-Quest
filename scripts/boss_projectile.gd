extends Area2D
## Obstáculo volcánico lanzado por el Jefe.

var velocity: Vector2 = Vector2(-360.0, 0.0)

var _life: float = 5.0
## Breve retardo antes de poder golpear: da a James una oportunidad de esquivar.
var _arm_time: float = 0.35

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("spin"):
		sprite.play("spin")


func launch_at(target: Vector2) -> void:
	var dir: Vector2 = (target - global_position)
	if dir.length() < 0.01:
		dir = Vector2(-1.0, 0.0)
	velocity = dir.normalized() * 360.0


func _physics_process(delta: float) -> void:
	if _arm_time > 0.0:
		_arm_time -= delta
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _arm_time > 0.0:
		return
	if body.has_method("take_boss_obstacle_hit"):
		body.take_boss_obstacle_hit()
	queue_free()