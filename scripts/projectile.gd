extends Area2D
class_name IsmaelProjectile

var direction := Vector2.RIGHT
var speed := 760.0
var lifetime := 1.8
var damage := 1

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.85, 0.95, 1.0))
	draw_circle(Vector2.ZERO, 4.0, Color(0.35, 0.65, 0.95))

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
