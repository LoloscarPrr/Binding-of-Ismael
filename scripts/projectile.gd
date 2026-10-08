extends Area2D
class_name IsmaelProjectile

var direction := Vector2.RIGHT
var speed := 760.0
var lifetime := 1.8
var damage := 1
var homing_strength := 0.0
var pierce_remaining := 0
var visual_style := "tear"
var size_scale := 1.0
var void_synergy := false
var split_count := 0
var split_spread := 0.0
var split_homing := false
var _split_triggered := false
var _age := 0.0
var _hit_ids: Dictionary = {}

func _ready() -> void:
	z_index = 6
	collision_layer = 4
	collision_mask = 10
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0*size_scale
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if homing_strength > 0.0:
		_steer_toward_enemy(delta)
	position += direction.normalized() * speed * delta
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	var pulse := 1.0 + sin(_age * 18.0) * 0.06
	var tear_angle := direction.angle()
	draw_set_transform(Vector2.ZERO,tear_angle,Vector2.ONE*size_scale)
	if void_synergy:
		draw_circle(Vector2(-12,0),7.5*pulse,Color(0.42,0.08,0.62,0.20))
		draw_circle(Vector2.ZERO,10.0*pulse,Color(0.04,0.01,0.08,0.90))
		draw_arc(Vector2.ZERO,11.5*pulse,0.0,TAU,24,Color(0.72,0.30,0.94,0.82),2.5)
		draw_circle(Vector2(3,-3),2.3,Color(0.96,0.72,1.0,0.92))
	elif visual_style == "needle":
		draw_line(Vector2(-15,0),Vector2(13,0),Color(0.10,0.12,0.14,0.92),5.0)
		draw_line(Vector2(-11,0),Vector2(11,0),Color(0.74,0.78,0.82,0.96),2.2)
		draw_circle(Vector2(11,0),3.0,Color(0.88,0.92,0.96,0.95))
	elif visual_style == "moth":
		draw_circle(Vector2(-8,0),6.2*pulse,Color(0.34,0.16,0.48,0.22))
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(1,-9),Vector2(-8,0),Vector2(1,9)]),Color(0.42,0.24,0.66))
		draw_circle(Vector2(3,-2),2.4,Color(0.90,0.76,1.0,0.92))
	elif visual_style == "glass":
		draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(2,-8),Vector2(-9,0),Vector2(2,8)]),Color(0.50,0.84,0.98,0.84))
		draw_line(Vector2(-5,-1),Vector2(9,-1),Color(0.92,0.98,1.0,0.82),2.0)
	else:
		draw_circle(Vector2(-10.0,0.0),5.5*pulse,Color(0.22,0.52,0.78,0.18))
		draw_circle(Vector2(-5.0,0.0),7.0*pulse,Color(0.25,0.60,0.88,0.26))
		var outline := PackedVector2Array([Vector2(12,0),Vector2(3,-9),Vector2(-10,0),Vector2(3,9)])
		draw_colored_polygon(outline,Color(0.025,0.09,0.15,0.72))
		var body := PackedVector2Array([Vector2(10,0),Vector2(3,-7),Vector2(-7,0),Vector2(3,7)])
		draw_colored_polygon(body,Color(0.25,0.63,0.92))
		draw_circle(Vector2(2,-2),3.3,Color(0.65,0.88,1.0,0.86))
		draw_circle(Vector2(4,-3),1.5,Color(0.95,0.99,1.0,0.96))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _steer_toward_enemy(delta: float) -> void:
	var nearest: Node2D = null
	var nearest_distance := 430.0 if void_synergy else 300.0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest == null:
		return
	var desired := global_position.direction_to(nearest.global_position)
	var steer_cap := 0.30 if void_synergy else 0.22
	direction = direction.lerp(desired,clampf(homing_strength*delta,0.0,steer_cap)).normalized()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		var body_id := body.get_instance_id()
		if _hit_ids.has(body_id):
			return
		_hit_ids[body_id] = true
		body.take_damage(damage,global_position)
		_spawn_split_projectiles(body_id)
		if pierce_remaining > 0:
			pierce_remaining -= 1
			return
	queue_free()

func _spawn_split_projectiles(ignored_body_id: int) -> void:
	if split_count <= 0 or _split_triggered:
		return
	_split_triggered = true
	var child_count := clampi(split_count,1,3)
	var total_spread := split_spread*float(maxi(1,child_count-1))
	for i in range(child_count):
		var t := 0.5 if child_count == 1 else float(i)/float(child_count-1)
		var angle := lerpf(-total_spread*0.5,total_spread*0.5,t)
		var child := IsmaelProjectile.new()
		var child_direction := direction.rotated(angle).normalized()
		child.global_position = global_position+child_direction*16.0
		child.direction = child_direction
		child.speed = speed*0.82
		child.lifetime = minf(0.70,lifetime)
		child.damage = maxi(1,int(ceil(float(damage)*0.50)))
		child.homing_strength = homing_strength if split_homing else 0.0
		child.pierce_remaining = 0
		child.visual_style = "moth" if split_homing else "glass"
		child.size_scale = size_scale*0.72
		child.void_synergy = false
		child.split_count = 0
		child._hit_ids[ignored_body_id] = true
		get_tree().current_scene.add_child(child)
