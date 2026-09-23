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

var homing_strength := 0.0
var projectile_pierce := 0
var burst_count := 1
var room_heal_interval := 0
var floor_shield_enabled := false
var floor_shield_charges := 0
var _rooms_since_heal := 0

var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO
var health := 6
var movement_bounds := Rect2(54.0, 82.0, 1172.0, 584.0)
var is_dead := false
var _shoot_cooldown := 0.0
var _invulnerability := 0.0
var _knockback_velocity := Vector2.ZERO
var _last_aim := Vector2.RIGHT
var _shoot_pose := 0.0
var _visual_recoil := 0.0
var _anim_time := 0.0

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
	_anim_time += delta
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)
	_shoot_pose = maxf(0.0, _shoot_pose - delta)
	_visual_recoil = move_toward(_visual_recoil, 0.0, 70.0 * delta)
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
	_last_aim = direction.normalized()
	_visual_recoil = 4.0
	_shoot_pose = 0.13
	_spawn_projectile(direction)
	if burst_count > 1:
		_fire_burst_followups(direction.normalized(),burst_count-1)

func _spawn_projectile(direction: Vector2) -> void:
	if is_dead:
		return
	var projectile := IsmaelProjectile.new()
	projectile.position = global_position + direction.normalized()*28.0
	projectile.direction = direction.normalized()
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.homing_strength = homing_strength
	projectile.pierce_remaining = projectile_pierce
	get_tree().current_scene.add_child(projectile)

func _fire_burst_followups(direction: Vector2,count: int) -> void:
	for _i in count:
		await get_tree().create_timer(0.055).timeout
		if is_dead:
			return
		_spawn_projectile(direction)

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
	if floor_shield_charges > 0:
		floor_shield_charges -= 1
		_invulnerability = minf(invulnerability_time,0.40)
		queue_redraw()
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

func notify_room_cleared() -> void:
	if room_heal_interval <= 0 or is_dead:
		return
	_rooms_since_heal += 1
	if _rooms_since_heal >= room_heal_interval:
		_rooms_since_heal = 0
		heal(1)

func refill_floor_shield() -> void:
	if floor_shield_enabled:
		floor_shield_charges = 1
		queue_redraw()

func reset_health() -> void:
	is_dead = false
	health = max_health
	_invulnerability = 0.0
	_knockback_velocity = Vector2.ZERO
	health_changed.emit(health, max_health)

func _draw() -> void:
	var pose_strength := clampf(_shoot_pose / 0.13, 0.0, 1.0)
	var moving_strength := clampf(velocity.length() / maxf(move_speed,1.0),0.0,1.0)
	var bob := sin(_anim_time*10.0) * 1.8 * moving_strength
	var visual_offset := -_last_aim * _visual_recoil + Vector2(0,bob)
	var pose_scale := Vector2(1.0 + 0.025*pose_strength,1.0 - 0.035*pose_strength)
	draw_set_transform(visual_offset,_last_aim.x*0.018*pose_strength,pose_scale)
	var skin := Color(0.82,0.69,0.61)
	var skin_shadow := Color(0.60,0.44,0.38)
	var outline := Color(0.09,0.065,0.058)
	var shirt := Color(0.46,0.38,0.35)
	if _invulnerability > 0.0 and int(_invulnerability*12.0)%2==0:
		skin = Color(1.0,0.86,0.86)
	draw_ellipse(Vector2(0,24),Vector2(25,8),Color(0.02,0.018,0.016,0.38))
	# piernas y torso orgánicos
	draw_ellipse(Vector2(-8,15),Vector2(8,13),outline)
	draw_ellipse(Vector2(8,15),Vector2(8,13),outline)
	draw_ellipse(Vector2(-8,14),Vector2(5.5,10.5),skin_shadow)
	draw_ellipse(Vector2(8,14),Vector2(5.5,10.5),skin_shadow)
	draw_ellipse(Vector2(0,5),Vector2(18,18),outline)
	draw_ellipse(Vector2(0,4),Vector2(15.5,15.5),shirt)
	# cabeza
	draw_ellipse(Vector2(0,-14),Vector2(24,22),outline)
	draw_circle(Vector2(-22,-12),7.0,outline)
	draw_circle(Vector2(22,-12),7.0,outline)
	draw_circle(Vector2(-21,-12),5.2,skin_shadow)
	draw_circle(Vector2(21,-12),5.2,skin_shadow)
	draw_ellipse(Vector2(0,-15),Vector2(21,19.5),skin)
	# sombreado inferior de la cara
	draw_arc(Vector2(0,-13),18.0,0.18,PI-0.18,24,Color(0.47,0.32,0.29,0.22),3.0)
	var look := _last_aim.limit_length(1.0)*2.8
	var left_eye := Vector2(-8,-18)+look
	var right_eye := Vector2(8,-18)+look
	draw_ellipse(left_eye,Vector2(4.6,5.4),Color(0.025,0.025,0.026))
	draw_ellipse(right_eye,Vector2(4.6,5.4),Color(0.025,0.025,0.026))
	draw_circle(left_eye+Vector2(-1.2,-1.8),1.5,Color(0.74,0.83,0.88))
	draw_circle(right_eye+Vector2(-1.2,-1.8),1.5,Color(0.74,0.83,0.88))
	# lágrimas en la cara
	draw_ellipse(Vector2(-8,-9)+look*0.25,Vector2(2.0,5.5),Color(0.34,0.65,0.84,0.68))
	draw_ellipse(Vector2(8,-9)+look*0.25,Vector2(2.0,5.5),Color(0.34,0.65,0.84,0.68))
	var mouth_size := Vector2(5.5,3.2+pose_strength*2.4)
	draw_ellipse(Vector2(0,-3),mouth_size,Color(0.20,0.07,0.075))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if floor_shield_charges > 0:
		draw_arc(Vector2.ZERO,34.0,-PI*0.92,PI*0.92,34,Color(0.78,0.84,0.88,0.72),3.5)
		draw_circle(Vector2(25,-20),4.2,Color(0.88,0.78,0.48,0.90))
	if _shoot_pose > 0.0:
		var emission_progress := 1.0-pose_strength
		var tear_origin := Vector2(0,-12)+_last_aim*(10.0+emission_progress*16.0)
		draw_circle(tear_origin+Vector2(1.5,2.0),6.3,Color(0.02,0.08,0.13,0.40))
		draw_circle(tear_origin,5.4,Color(0.34,0.72,0.96,0.92))
		draw_circle(tear_origin+Vector2(-1.8,-1.8),1.7,Color(0.92,0.98,1.0,0.95))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
