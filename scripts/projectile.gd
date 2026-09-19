extends Area2D
class_name IsmaelProjectile

var direction := Vector2.RIGHT
var speed := 760.0
var lifetime := 1.8
var damage := 1
var _age := 0.0

func _ready() -> void:
	z_index = 6
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
	var pulse := 1.0 + sin(_age * 18.0) * 0.06
	var tear_angle := direction.angle()
	draw_set_transform(Vector2.ZERO, tear_angle, Vector2.ONE)
	draw_circle(Vector2(-10.0,0.0), 5.5 * pulse, Color(0.22,0.52,0.78,0.18))
	draw_circle(Vector2(-5.0,0.0), 7.0 * pulse, Color(0.25,0.60,0.88,0.26))
	var outline := PackedVector2Array([Vector2(12,0),Vector2(3,-9),Vector2(-10,0),Vector2(3,9)])
	draw_colored_polygon(outline, Color(0.025,0.09,0.15,0.72))
	var body := PackedVector2Array([Vector2(10,0),Vector2(3,-7),Vector2(-7,0),Vector2(3,7)])
	draw_colored_polygon(body, Color(0.25,0.63,0.92))
	draw_circle(Vector2(2,-2), 3.3, Color(0.65,0.88,1.0,0.86))
	draw_circle(Vector2(4,-3), 1.5, Color(0.95,0.99,1.0,0.96))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
