extends CharacterBody2D
class_name IsmaelPlayer

@export var move_speed := 280.0
@export var fire_rate := 0.18

var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO
var _shoot_cooldown := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	velocity = move_input.limit_length(1.0) * move_speed
	move_and_slide()

	position.x = clampf(position.x, 76.0, 1204.0)
	position.y = clampf(position.y, 76.0, 644.0)

	if aim_input.length() > 0.25 and _shoot_cooldown <= 0.0:
		shoot(aim_input.normalized())
		_shoot_cooldown = fire_rate

func shoot(direction: Vector2) -> void:
	var projectile := IsmaelProjectile.new()
	projectile.position = global_position + direction * 38.0
	projectile.direction = direction
	get_tree().current_scene.add_child(projectile)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 28.0, Color(0.82, 0.70, 0.62))
	draw_circle(Vector2(-9, -5), 4.5, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(9, -5), 4.5, Color(0.1, 0.1, 0.1))
	draw_arc(Vector2(0, 4), 9.0, 0.2, PI - 0.2, 20, Color(0.25, 0.12, 0.12), 2.5)
