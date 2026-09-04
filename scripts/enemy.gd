extends CharacterBody2D
class_name IsmaelEnemy

@export var speed := 105.0
@export var health := 4
var target: Node2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(target):
		velocity = global_position.direction_to(target.global_position) * speed
		move_and_slide()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 25.0, Color(0.55, 0.16, 0.18))
	draw_circle(Vector2(-8, -5), 4.0, Color.BLACK)
	draw_circle(Vector2(8, -5), 4.0, Color.BLACK)
	draw_line(Vector2(-8, 10), Vector2(8, 10), Color(0.15, 0.02, 0.02), 3.0)
