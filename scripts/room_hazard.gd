extends Area2D
class_name IsmaelRoomHazard

signal destroyed(hazard_id: int, world_position: Vector2)

var hazard_id := -1
var hazard_kind := "spike"
var _age := 0.0
var _damage_cooldown := 0.0
var _destroyed := false

func configure(id_value: int, kind_value: String) -> void:
	hazard_id = id_value
	hazard_kind = kind_value
	queue_redraw()

func _ready() -> void:
	add_to_group("room_hazards")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	z_index = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0 if hazard_kind == "spike" else 28.0
	shape.shape = circle
	add_child(shape)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	_damage_cooldown = maxf(0.0,_damage_cooldown-delta)
	if not _destroyed and _damage_cooldown <= 0.0:
		for body in get_overlapping_bodies():
			if body is IsmaelPlayer:
				body.take_contact_damage(1,global_position)
				_damage_cooldown = 0.92 if hazard_kind == "spike" else 0.72
				break
	queue_redraw()

func blast_hit(blast_center: Vector2, blast_radius: float) -> bool:
	if _destroyed or hazard_kind != "fire":
		return false
	if global_position.distance_to(blast_center) > blast_radius+20.0:
		return false
	_destroyed = true
	monitoring = false
	destroyed.emit(hazard_id,global_position)
	queue_free()
	return true

func _draw() -> void:
	if hazard_kind == "fire":
		_draw_fire()
	else:
		_draw_spikes()

func _draw_spikes() -> void:
	var pulse := 0.5+0.5*sin(_age*3.2)
	draw_ellipse(Vector2(0,14),Vector2(31,8),Color(0,0,0,0.28))
	for i in range(6):
		var a := TAU*float(i)/6.0
		var center := Vector2(cos(a),sin(a))*12.0
		var d := center.normalized()
		var side := Vector2(-d.y,d.x)
		var tip := center+d*(20.0+2.0*pulse)
		var base_left := center-side*6.0-d*5.0
		var base_right := center+side*6.0-d*5.0
		draw_colored_polygon(PackedVector2Array([base_left,tip,base_right]),Color(0.48,0.46,0.43))
		draw_line(base_left,tip,Color(0.76,0.72,0.65,0.72),1.5)
	draw_circle(Vector2.ZERO,10.0,Color(0.16,0.14,0.13))

func _draw_fire() -> void:
	var sway := sin(_age*9.0)*3.5
	var pulse := 0.5+0.5*sin(_age*7.0)
	draw_ellipse(Vector2(0,20),Vector2(28,8),Color(0,0,0,0.30))
	draw_circle(Vector2.ZERO,31.0+3.0*pulse,Color(0.95,0.31,0.04,0.055))
	var outer := PackedVector2Array([
		Vector2(-21,16),Vector2(-17,-5),Vector2(-7,-28),Vector2(0,-14),
		Vector2(8,-34+sway),Vector2(13,-10),Vector2(22,5),Vector2(17,20),Vector2(-15,20)
	])
	draw_colored_polygon(outer,Color(0.72,0.14,0.025))
	var inner := PackedVector2Array([
		Vector2(-12,15),Vector2(-8,-1),Vector2(0,-19),Vector2(6,-7),
		Vector2(11,-20+sway*0.45),Vector2(14,3),Vector2(10,16)
	])
	draw_colored_polygon(inner,Color(0.96,0.48,0.07))
	draw_colored_polygon(PackedVector2Array([Vector2(-5,14),Vector2(0,-7),Vector2(7,14)]),Color(1.0,0.82,0.25))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
