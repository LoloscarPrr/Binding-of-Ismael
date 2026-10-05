extends StaticBody2D
class_name IsmaelDestructibleRock

signal destroyed(rock_id: int, world_position: Vector2)

const COLLISION_RADIUS := 31.0

var rock_id := -1
var variant := 0
var contains_loot := false
var _destroyed := false
var _collision: CollisionShape2D

func configure(
	id_value: int,
	visual_variant: int = 0,
	loot_hint: bool = false,
	size_scale: float = 1.0
) -> void:
	rock_id = id_value
	variant = posmod(visual_variant,3)
	contains_loot = loot_hint
	var resolved_scale := clampf(size_scale,0.84,1.18)
	scale = Vector2(resolved_scale,resolved_scale)

func _ready() -> void:
	add_to_group("room_rocks")
	collision_layer = 8
	collision_mask = 0
	z_index = 2
	_collision = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLLISION_RADIUS
	_collision.shape = circle
	add_child(_collision)
	queue_redraw()

func blast_hit(blast_center: Vector2, blast_radius: float) -> bool:
	if _destroyed:
		return false
	var effective_radius := blast_radius+COLLISION_RADIUS*scale.x*0.45
	if global_position.distance_to(blast_center) > effective_radius:
		return false
	_destroyed = true
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled",true)
	destroyed.emit(rock_id,global_position)
	queue_free()
	return true

func _draw() -> void:
	var outline := Color(0.08,0.065,0.055)
	var base := Color(0.29,0.27,0.25)
	var mid := Color(0.39,0.36,0.32)
	var light := Color(0.50,0.45,0.38)
	if variant == 1:
		base = Color(0.25,0.27,0.28)
		mid = Color(0.34,0.37,0.38)
		light = Color(0.45,0.48,0.47)
	elif variant == 2:
		base = Color(0.32,0.25,0.21)
		mid = Color(0.42,0.33,0.27)
		light = Color(0.54,0.42,0.32)

	draw_ellipse(Vector2(0,22),Vector2(34,10),Color(0.0,0.0,0.0,0.28))
	var shell := PackedVector2Array([
		Vector2(-31,9),Vector2(-27,-13),Vector2(-15,-29),Vector2(7,-33),
		Vector2(27,-22),Vector2(34,-2),Vector2(27,20),Vector2(9,29),Vector2(-16,27)
	])
	draw_colored_polygon(shell,outline)
	var inner := PackedVector2Array([
		Vector2(-27,7),Vector2(-23,-11),Vector2(-12,-25),Vector2(7,-28),
		Vector2(23,-19),Vector2(29,-1),Vector2(23,16),Vector2(7,24),Vector2(-14,22)
	])
	draw_colored_polygon(inner,base)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18,-14),Vector2(-8,-23),Vector2(9,-25),Vector2(19,-17),
		Vector2(10,-8),Vector2(-7,-7)
	]),mid)
	draw_line(Vector2(-3,-7),Vector2(5,3),light,2.4)
	draw_line(Vector2(5,3),Vector2(-1,14),light,2.4)
	draw_line(Vector2(5,3),Vector2(16,9),light,2.4)
	draw_line(Vector2(-17,4),Vector2(-7,11),Color(0.16,0.14,0.13),2.0)
	draw_circle(Vector2(-12,-15),4.0,Color(light.r,light.g,light.b,0.28))
	if contains_loot:
		# A subtle warm mineral vein hints that this rock may be worth bombing.
		# It is intentionally readable without guaranteeing a specific drop type.
		var glow := 0.62+sin(Time.get_ticks_msec()*0.004+float(rock_id))*0.16
		draw_line(Vector2(-14,-4),Vector2(-4,2),Color(0.92,0.64,0.24,glow),2.6)
		draw_line(Vector2(-4,2),Vector2(5,-2),Color(0.92,0.64,0.24,glow),2.6)
		draw_line(Vector2(5,-2),Vector2(13,5),Color(0.92,0.64,0.24,glow),2.2)
		draw_circle(Vector2(10,-14),2.5,Color(1.0,0.82,0.38,0.72))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(28):
		var angle := TAU*float(i)/28.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)
