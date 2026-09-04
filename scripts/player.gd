extends CharacterBody2D
class_name IsmaelPlayer

signal health_changed(current: int, maximum: int)
signal died

@export var move_speed := 280.0
@export var fire_rate := 0.18
@export var max_health := 6
@export var invulnerability_time := 0.75

var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO
var health := 6
var _shoot_cooldown := 0.0
var _invulnerability := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	health = max_health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	health_changed.emit(health, max_health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)

	velocity = move_input.limit_length(1.0) * move_speed
	move_and_slide()

	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is IsmaelEnemy:
			take_damage(1)

	position.x = clampf(position.x, 60.0, 1220.0)
	position.y = clampf(position.y, 72.0, 660.0)

	if aim_input.length() > 0.25 and _shoot_cooldown <= 0.0:
		shoot(aim_input.normalized())
		_shoot_cooldown = fire_rate

	queue_redraw()

func shoot(direction: Vector2) -> void:
	var projectile := IsmaelProjectile.new()
	projectile.position = global_position + direction * 38.0
	projectile.direction = direction
	get_tree().current_scene.add_child(projectile)

func take_damage(amount: int) -> void:
	if _invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	_invulnerability = invulnerability_time
	health_changed.emit(health, max_health)
	if health <= 0:
		died.emit()

func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func reset_health() -> void:
	health = max_health
	_invulnerability = 0.0
	health_changed.emit(health, max_health)

func _draw() -> void:
	var body_color := Color(0.82, 0.70, 0.62)
	if _invulnerability > 0.0 and int(_invulnerability * 12.0) % 2 == 0:
		body_color = Color(1.0, 0.85, 0.85)
	draw_circle(Vector2.ZERO, 28.0, body_color)
	draw_circle(Vector2(-9, -5), 4.5, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(9, -5), 4.5, Color(0.1, 0.1, 0.1))
	draw_arc(Vector2(0, 4), 9.0, 0.2, PI - 0.2, 20, Color(0.25, 0.12, 0.12), 2.5)
