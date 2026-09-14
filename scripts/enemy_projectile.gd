extends Area2D
class_name IsmaelEnemyProjectile

var direction := Vector2.DOWN
var speed := 320.0
var lifetime := 4.0
var damage := 1
var variant := 0
var movement_bounds := Rect2()
var _age := 0.0

func configure(
	shot_direction: Vector2,
	shot_speed: float,
	shot_damage: int,
	bounds: Rect2,
	shot_variant: int = 0
) -> void:
	direction = shot_direction.normalized()
	speed = shot_speed
	damage = maxi(1, shot_damage)
	movement_bounds = bounds
	variant = shot_variant

func _ready() -> void:
	add_to_group("enemy_projectiles")
	collision_layer = 16
	collision_mask = 9
	monitoring = true
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0 if variant == 1 else 9.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	position += direction * speed * delta
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()
		return
	if movement_bounds.size.length_squared() > 1.0 and not movement_bounds.grow(72.0).has_point(global_position):
		queue_free()

func _draw() -> void:
	var pulse: float = 1.0 + sin(_age * 15.0) * 0.08
	var trail_direction: Vector2 = -direction
	if variant == 1:
		draw_circle(trail_direction * 12.0, 6.0 * pulse, Color(0.45, 0.025, 0.035, 0.20))
		draw_circle(Vector2(2.0, 3.0), 12.0 * pulse, Color(0.08, 0.01, 0.015, 0.55))
		draw_circle(Vector2.ZERO, 10.5 * pulse, Color(0.62, 0.035, 0.055))
		draw_circle(Vector2(-3.0, -3.0), 3.0, Color(1.0, 0.42, 0.28, 0.90))
		return
	draw_circle(trail_direction * 10.0, 5.5 * pulse, Color(0.22, 0.06, 0.38, 0.20))
	draw_circle(Vector2(1.5, 2.5), 10.0 * pulse, Color(0.04, 0.015, 0.07, 0.58))
	draw_circle(Vector2.ZERO, 8.8 * pulse, Color(0.48, 0.17, 0.68))
	draw_circle(Vector2(-2.5, -2.5), 2.5, Color(0.92, 0.63, 1.0, 0.90))

func _on_body_entered(body: Node) -> void:
	if body is IsmaelPlayer:
		body.take_contact_damage(damage, global_position - direction * 12.0)
	queue_free()
