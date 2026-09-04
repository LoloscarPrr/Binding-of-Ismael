extends CharacterBody2D
class_name IsmaelEnemy

signal defeated(enemy)

const BODY_RADIUS := 25.0
const SEPARATION_DISTANCE := 72.0

@export var speed := 105.0
@export var health := 4
var target: Node2D
var movement_bounds := Rect2(54.0, 82.0, 1172.0, 584.0)

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	var chase_direction := global_position.direction_to(target.global_position)
	var separation := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()
		if distance > 0.0 and distance < SEPARATION_DISTANCE:
			separation += offset.normalized() * (1.0 - distance / SEPARATION_DISTANCE)

	var steering := chase_direction + separation * 1.2
	velocity = steering.normalized() * speed if steering.length() > 0.01 else Vector2.ZERO
	move_and_slide()
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is IsmaelPlayer:
			collider.take_damage(1)
	clamp_to_bounds()

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds
	clamp_to_bounds()

func clamp_to_bounds() -> void:
	position.x = clampf(position.x, movement_bounds.position.x + BODY_RADIUS, movement_bounds.position.x + movement_bounds.size.x - BODY_RADIUS)
	position.y = clampf(position.y, movement_bounds.position.y + BODY_RADIUS, movement_bounds.position.y + movement_bounds.size.y - BODY_RADIUS)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		defeated.emit(self)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.55, 0.16, 0.18))
	draw_circle(Vector2(-8, -5), 4.0, Color.BLACK)
	draw_circle(Vector2(8, -5), 4.0, Color.BLACK)
	draw_line(Vector2(-8, 10), Vector2(8, 10), Color(0.15, 0.02, 0.02), 3.0)
