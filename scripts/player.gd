extends CharacterBody2D
class_name IsmaelPlayer

signal health_changed(current: int, maximum: int)
signal died

const BODY_RADIUS := 28.0

@export var move_speed := 280.0
@export var fire_rate := 0.18
@export var max_health := 6
@export var invulnerability_time := 0.75
@export var projectile_speed := 760.0
@export var projectile_damage := 1
@export var contact_knockback := 430.0

var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO
var health := 6
var movement_bounds := Rect2(54.0, 82.0, 1172.0, 584.0)
var is_dead := false
var _shoot_cooldown := 0.0
var _invulnerability := 0.0
var _knockback_velocity := Vector2.ZERO

func _ready() -> void:
	collision_layer = 1
	collision_mask = 10
	health = max_health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	health_changed.emit(health, max_health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 1250.0 * delta)
	velocity = move_input.limit_length(1.0) * move_speed + _knockback_velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is IsmaelEnemy:
			take_contact_damage(1, collider.global_position)
	clamp_to_bounds()
	if aim_input.length() > 0.25 and _shoot_cooldown <= 0.0:
		shoot(aim_input.normalized())
		_shoot_cooldown = fire_rate
	queue_redraw()

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds
	clamp_to_bounds()

func clamp_to_bounds() -> void:
	position.x = clampf(position.x, movement_bounds.position.x + BODY_RADIUS, movement_bounds.position.x + movement_bounds.size.x - BODY_RADIUS)
	position.y = clampf(position.y, movement_bounds.position.y + BODY_RADIUS, movement_bounds.position.y + movement_bounds.size.y - BODY_RADIUS)

func shoot(direction: Vector2) -> void:
	var projectile := IsmaelProjectile.new()
	projectile.position = global_position + direction * 38.0
	projectile.direction = direction
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	get_tree().current_scene.add_child(projectile)

func take_contact_damage(amount: int, source_position: Vector2) -> void:
	if is_dead or _invulnerability > 0.0:
		return
	var away := source_position.direction_to(global_position)
	if away.length_squared() < 0.01:
		away = Vector2.DOWN
	_knockback_velocity = away.normalized() * contact_knockback
	take_damage(amount)

func take_damage(amount: int) -> void:
	if is_dead or _invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	_invulnerability = invulnerability_time
	health_changed.emit(health, max_health)
	if health <= 0:
		is_dead = true
		move_input = Vector2.ZERO
		aim_input = Vector2.ZERO
		velocity = Vector2.ZERO
		_knockback_velocity = Vector2.ZERO
		died.emit()

func heal(amount: int) -> void:
	if is_dead:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func add_max_health(amount: int) -> void:
	max_health += amount
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func reset_health() -> void:
	is_dead = false
	health = max_health
	_invulnerability = 0.0
	_knockback_velocity = Vector2.ZERO
	health_changed.emit(health, max_health)

func _draw() -> void:
	var skin := Color(0.83, 0.70, 0.62)
	var skin_shadow := Color(0.62, 0.46, 0.40)
	var outline := Color(0.12, 0.085, 0.075)
	var shirt := Color(0.54, 0.45, 0.40)
	if _invulnerability > 0.0 and int(_invulnerability * 12.0) % 2 == 0:
		skin = Color(1.0, 0.86, 0.86)
	# shadow
	draw_ellipse(Vector2(0, 22), Vector2(24, 9), Color(0.03, 0.025, 0.02, 0.35))
	# legs
	draw_rect(Rect2(-15, 12, 11, 16), outline)
	draw_rect(Rect2(4, 12, 11, 16), outline)
	draw_rect(Rect2(-13, 12, 8, 13), skin_shadow)
	draw_rect(Rect2(5, 12, 8, 13), skin_shadow)
	# torso
	draw_rect(Rect2(-19, -2, 38, 25), outline)
	draw_rect(Rect2(-16, 0, 32, 20), shirt)
	# head silhouette
	draw_rect(Rect2(-24, -29, 48, 36), outline)
	draw_rect(Rect2(-21, -32, 42, 39), outline)
	draw_rect(Rect2(-19, -29, 38, 33), skin)
	draw_rect(Rect2(-15, -32, 30, 4), skin)
	# ears
	draw_rect(Rect2(-25, -18, 6, 12), outline)
	draw_rect(Rect2(19, -18, 6, 12), outline)
	draw_rect(Rect2(-23, -16, 4, 8), skin_shadow)
	draw_rect(Rect2(19, -16, 4, 8), skin_shadow)
	# eyes
	draw_rect(Rect2(-13, -17, 8, 9), Color(0.035, 0.03, 0.03))
	draw_rect(Rect2(5, -17, 8, 9), Color(0.035, 0.03, 0.03))
	draw_rect(Rect2(-11, -15, 2, 3), Color(0.75, 0.80, 0.84))
	draw_rect(Rect2(9, -15, 2, 3), Color(0.75, 0.80, 0.84))
	# nose and mouth
	draw_rect(Rect2(-2, -8, 4, 5), skin_shadow)
	draw_rect(Rect2(-7, -1, 14, 3), Color(0.24, 0.10, 0.10))
	# tiny tear streaks
	draw_rect(Rect2(-11, -7, 3, 5), Color(0.42, 0.61, 0.72, 0.75))
	draw_rect(Rect2(8, -7, 3, 5), Color(0.42, 0.61, 0.72, 0.75))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
