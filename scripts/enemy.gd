extends CharacterBody2D
class_name IsmaelEnemy

signal defeated(enemy)
signal health_changed(current: int, maximum: int)

const BODY_RADIUS := 25.0
const SEPARATION_DISTANCE := 72.0

enum EnemyKind { CHASER, DASHER, ORBITER, BOSS }

@export var speed := 105.0
@export var health := 4
var max_health := 4
var kind: EnemyKind = EnemyKind.CHASER
var target: Node2D
var movement_bounds := Rect2(54.0, 82.0, 1172.0, 584.0)
var spawn_grace_time := 0.0
var _age := 0.0
var _dash_timer := 0.0
var _dash_direction := Vector2.ZERO
var _orbit_sign := 1.0
var _hit_flash := 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 11
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 38.0 if kind == EnemyKind.BOSS else 23.0
	shape.shape = circle
	add_child(shape)
	_orbit_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
	health_changed.emit(health, max_health)
	queue_redraw()

func configure(enemy_kind: EnemyKind, floor_index: int) -> void:
	kind = enemy_kind
	match kind:
		EnemyKind.CHASER:
			speed = 105.0 + floor_index * 8.0
			health = 3 + floor_index
		EnemyKind.DASHER:
			speed = 82.0 + floor_index * 6.0
			health = 3 + floor_index
		EnemyKind.ORBITER:
			speed = 118.0 + floor_index * 7.0
			health = 4 + floor_index
		EnemyKind.BOSS:
			speed = 92.0 + floor_index * 5.0
			health = 18 + floor_index * 5
	max_health = health
	health_changed.emit(health, max_health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if spawn_grace_time > 0.0:
		spawn_grace_time = maxf(0.0, spawn_grace_time - delta)
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = global_position.direction_to(target.global_position)
	var desired := to_player
	match kind:
		EnemyKind.CHASER:
			desired = to_player
		EnemyKind.DASHER:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_dash_timer = 1.55
				_dash_direction = to_player
			if _dash_timer > 1.15:
				desired = _dash_direction * 2.6
			elif _dash_timer < 0.35:
				desired = Vector2.ZERO
			else:
				desired = to_player * 0.35
		EnemyKind.ORBITER:
			var tangent := Vector2(-to_player.y, to_player.x) * _orbit_sign
			var distance := global_position.distance_to(target.global_position)
			var radial := to_player * clampf((distance - 240.0) / 120.0, -0.8, 0.8)
			desired = tangent + radial
		EnemyKind.BOSS:
			var wave := Vector2(-to_player.y, to_player.x) * sin(_age * 2.2) * 0.9
			desired = to_player + wave
	var separation := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()
		if distance > 0.0 and distance < SEPARATION_DISTANCE:
			separation += offset.normalized() * (1.0 - distance / SEPARATION_DISTANCE)
	var steering := desired + separation * 1.2
	var speed_multiplier := 1.0
	if kind == EnemyKind.DASHER and _dash_timer > 1.15:
		speed_multiplier = 2.4
	velocity = steering.normalized() * speed * speed_multiplier if steering.length() > 0.01 else Vector2.ZERO
	move_and_slide()
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is IsmaelPlayer:
			collider.take_contact_damage(1, global_position)
	clamp_to_bounds()
	queue_redraw()

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds
	clamp_to_bounds()

func clamp_to_bounds() -> void:
	var radius := 40.0 if kind == EnemyKind.BOSS else BODY_RADIUS
	position.x = clampf(position.x, movement_bounds.position.x + radius, movement_bounds.position.x + movement_bounds.size.x - radius)
	position.y = clampf(position.y, movement_bounds.position.y + radius, movement_bounds.position.y + movement_bounds.size.y - radius)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	_hit_flash = 0.11
	health_changed.emit(maxi(health, 0), max_health)
	queue_redraw()
	if health <= 0:
		defeated.emit(self)
		queue_free()

func _draw() -> void:
	var flash := _hit_flash > 0.0
	match kind:
		EnemyKind.CHASER:
			_draw_chaser(flash)
		EnemyKind.DASHER:
			_draw_dasher(flash)
		EnemyKind.ORBITER:
			_draw_orbiter(flash)
		EnemyKind.BOSS:
			_draw_boss(flash)

func _draw_chaser(flash: bool) -> void:
	var outline := Color(0.11, 0.035, 0.03)
	var flesh := Color(1.0, 0.86, 0.80) if flash else Color(0.56, 0.16, 0.18)
	var dark := Color(0.29, 0.07, 0.08)
	draw_ellipse(Vector2(0, 19), Vector2(22, 8), Color(0.03,0.02,0.02,0.28))
	draw_rect(Rect2(-23,-22,46,40), outline)
	draw_rect(Rect2(-19,-25,38,43), outline)
	draw_rect(Rect2(-17,-21,34,35), flesh)
	draw_rect(Rect2(-13,-25,26,5), flesh)
	draw_rect(Rect2(-22,-9,6,14), flesh)
	draw_rect(Rect2(16,-9,6,14), flesh)
	draw_rect(Rect2(-12,-12,7,8), Color.BLACK)
	draw_rect(Rect2(5,-12,7,8), Color.BLACK)
	draw_rect(Rect2(-6,2,12,5), dark)
	draw_rect(Rect2(-10,9,20,4), dark)
	draw_rect(Rect2(-14,14,9,12), dark)
	draw_rect(Rect2(5,14,9,12), dark)

func _draw_dasher(flash: bool) -> void:
	var outline := Color(0.13, 0.065, 0.025)
	var hide := Color(1.0, 0.88, 0.78) if flash else Color(0.73, 0.34, 0.12)
	var horn := Color(0.78, 0.69, 0.48)
	draw_ellipse(Vector2(0,19),Vector2(24,8),Color(0.03,0.02,0.01,0.28))
	draw_rect(Rect2(-25,-15,50,31),outline)
	draw_rect(Rect2(-21,-19,42,36),hide)
	draw_colored_polygon(PackedVector2Array([Vector2(-20,-17),Vector2(-31,-29),Vector2(-16,-25)]),horn)
	draw_colored_polygon(PackedVector2Array([Vector2(20,-17),Vector2(31,-29),Vector2(16,-25)]),horn)
	draw_rect(Rect2(-14,-10,9,7),Color.BLACK)
	draw_rect(Rect2(5,-10,9,7),Color.BLACK)
	draw_rect(Rect2(-5,-1,10,8),Color(0.27,0.08,0.03))
	draw_rect(Rect2(-18,13,12,10),outline)
	draw_rect(Rect2(6,13,12,10),outline)
	if _dash_timer > 1.15:
		draw_line(Vector2(-28,4),Vector2(-39,9),Color(0.86,0.50,0.16,0.75),4.0)
		draw_line(Vector2(28,4),Vector2(39,9),Color(0.86,0.50,0.16,0.75),4.0)

func _draw_orbiter(flash: bool) -> void:
	var outline := Color(0.075,0.045,0.12)
	var body := Color(1.0,0.9,0.84) if flash else Color(0.35,0.20,0.62)
	var inner := Color(0.18,0.09,0.31)
	draw_ellipse(Vector2(0,18),Vector2(22,7),Color(0.02,0.015,0.03,0.28))
	draw_rect(Rect2(-21,-21,42,42),outline)
	draw_rect(Rect2(-17,-24,34,46),outline)
	draw_rect(Rect2(-15,-20,30,38),body)
	draw_rect(Rect2(-11,-24,22,5),body)
	draw_rect(Rect2(-11,-13,22,17),Color(0.80,0.74,0.68))
	draw_rect(Rect2(-5,-10,10,12),Color.BLACK)
	draw_rect(Rect2(-2,-8,3,4),Color(0.70,0.58,0.88))
	draw_rect(Rect2(-8,8,16,6),inner)
	draw_line(Vector2(-19,-2),Vector2(-30,-8),body,5.0)
	draw_line(Vector2(19,-2),Vector2(30,8),body,5.0)

func _draw_boss(flash: bool) -> void:
	var outline := Color(0.08,0.02,0.025)
	var flesh := Color(1.0,0.86,0.80) if flash else Color(0.40,0.07,0.10)
	var flesh2 := Color(0.57,0.12,0.13)
	var wound := Color(0.20,0.015,0.02)
	draw_ellipse(Vector2(0,37),Vector2(43,12),Color(0.02,0.01,0.01,0.38))
	draw_rect(Rect2(-44,-18,88,56),outline)
	draw_rect(Rect2(-38,-24,76,65),outline)
	draw_rect(Rect2(-32,-30,64,71),flesh)
	draw_rect(Rect2(-23,-36,46,9),flesh2)
	draw_rect(Rect2(-42,-6,10,27),flesh2)
	draw_rect(Rect2(32,-6,10,27),flesh2)
	draw_rect(Rect2(-21,-16,15,13),Color.BLACK)
	draw_rect(Rect2(9,-13,12,10),Color.BLACK)
	draw_rect(Rect2(-17,-12,4,4),Color(0.78,0.18,0.17))
	draw_rect(Rect2(12,-10,3,3),Color(0.78,0.18,0.17))
	draw_rect(Rect2(-7,-1,14,8),wound)
	draw_rect(Rect2(-18,12,36,9),wound)
	draw_rect(Rect2(-13,15,5,7),Color(0.83,0.73,0.55))
	draw_rect(Rect2(5,15,5,7),Color(0.83,0.73,0.55))
	draw_rect(Rect2(-51,4,13,24),outline)
	draw_rect(Rect2(38,4,13,24),outline)
	draw_rect(Rect2(-49,7,10,18),flesh2)
	draw_rect(Rect2(39,7,10,18),flesh2)
	draw_arc(Vector2.ZERO,46.0+sin(_age*3.0)*2.0,0.0,TAU,40,Color(0.70,0.10,0.10,0.55),4.0)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
