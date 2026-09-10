extends Area2D
class_name IsmaelProjectile

var direction := Vector2.RIGHT
var speed := 760.0
var lifetime := 1.8
var damage := 1
var _age := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 10
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	position += direction.normalized() * speed * delta
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	var pulse := 1.0 + sin(_age * 18.0) * 0.08
	var trail_dir := -direction.normalized()
	# Soft blue trail and shadow make tears read clearly against brown dungeon floors.
	draw_circle(trail_dir * 10.0, 5.5 * pulse, Color(0.20, 0.48, 0.72, 0.20))
	draw_circle(trail_dir * 5.0, 7.0 * pulse, Color(0.25, 0.58, 0.86, 0.28))
	# Dark outline, blue body and tiny highlight.
	draw_circle(Vector2(1.5, 2.5), 9.5 * pulse, Color(0.03, 0.08, 0.12, 0.45))
	draw_circle(Vector2.ZERO, 9.0 * pulse, Color(0.13, 0.42, 0.76))
	draw_circle(Vector2(-1.0, -1.0), 6.3 * pulse, Color(0.39, 0.72, 0.96))
	draw_circle(Vector2(-3.0, -3.0), 2.2, Color(0.88, 0.96, 1.0, 0.92))

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
