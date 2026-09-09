extends CharacterBody2D
class_name IsmaelEnemy

signal defeated(enemy)

const BODY_RADIUS := 25.0
const SEPARATION_DISTANCE := 72.0

enum EnemyKind { CHASER, DASHER, ORBITER, BOSS }

@export var speed := 105.0
@export var health := 4
var kind: EnemyKind = EnemyKind.CHASER
var target: Node2D
var movement_bounds := Rect2(54.0, 82.0, 1172.0, 584.0)
var spawn_grace_time := 0.0
var _age := 0.0
var _dash_timer := 0.0
var _dash_direction := Vector2.ZERO
var _orbit_sign := 1.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 11
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0 if kind == EnemyKind.BOSS else 24.0
	shape.shape = circle
	add_child(shape)
	_orbit_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
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
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if spawn_grace_time > 0.0:
		spawn_grace_time = maxf(0.0, spawn_grace_time - delta)
		velocity = Vector2.ZERO
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
			collider.take_damage(1)
	clamp_to_bounds()

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds
	clamp_to_bounds()

func clamp_to_bounds() -> void:
	var radius := 36.0 if kind == EnemyKind.BOSS else BODY_RADIUS
	position.x = clampf(position.x, movement_bounds.position.x + radius, movement_bounds.position.x + movement_bounds.size.x - radius)
	position.y = clampf(position.y, movement_bounds.position.y + radius, movement_bounds.position.y + movement_bounds.size.y - radius)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		defeated.emit(self)
		queue_free()

func _draw() -> void:
	var radius := 36.0 if kind == EnemyKind.BOSS else BODY_RADIUS
	var body_color := Color(0.55, 0.16, 0.18)
	match kind:
		EnemyKind.DASHER:
			body_color = Color(0.72, 0.34, 0.12)
		EnemyKind.ORBITER:
			body_color = Color(0.35, 0.20, 0.62)
		EnemyKind.BOSS:
			body_color = Color(0.40, 0.07, 0.10)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_circle(Vector2(-radius * 0.32, -5), 4.0, Color.BLACK)
	draw_circle(Vector2(radius * 0.32, -5), 4.0, Color.BLACK)
	draw_line(Vector2(-8, 10), Vector2(8, 10), Color(0.15, 0.02, 0.02), 3.0)
	if kind == EnemyKind.BOSS:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 36, Color(0.75, 0.15, 0.12), 4.0)
