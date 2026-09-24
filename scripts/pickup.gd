extends Area2D
class_name IsmaelPickup

signal collected(kind: String)

var kind := "coin"
var _age := 0.0

func configure(kind_value: String) -> void:
	kind = kind_value
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	z_index = 5
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_on_body_entered)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is IsmaelPlayer:
		collected.emit(kind)
		queue_free()

func _draw() -> void:
	var bob := sin(_age*3.4)*3.5
	var pulse := 0.5+0.5*sin(_age*4.2)
	draw_ellipse(Vector2(0,20),Vector2(22,7),Color(0,0,0,0.30))
	draw_circle(Vector2(0,bob),27.0+2.0*pulse,Color(0.92,0.69,0.22,0.045+0.035*pulse))
	draw_set_transform(Vector2(0,bob),0.0,Vector2.ONE)
	match kind:
		"heart":
			draw_circle(Vector2(-8,-4),10.0,Color(0.84,0.05,0.08))
			draw_circle(Vector2(8,-4),10.0,Color(0.84,0.05,0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(-17,1),Vector2(17,1),Vector2(0,22)]),Color(0.78,0.035,0.06))
			draw_circle(Vector2(-7,-7),3.0,Color(1.0,0.65,0.62,0.72))
		"key":
			draw_circle(Vector2(-8,0),10.0,Color(0.88,0.74,0.34),false,5.0)
			draw_line(Vector2(2,0),Vector2(21,0),Color(0.88,0.74,0.34),6.0)
			draw_line(Vector2(13,0),Vector2(13,9),Color(0.88,0.74,0.34),5.0)
			draw_line(Vector2(19,0),Vector2(19,6),Color(0.88,0.74,0.34),4.0)
		"bomb":
			draw_circle(Vector2.ZERO,15.0,Color(0.09,0.10,0.12))
			draw_arc(Vector2.ZERO,15.0,0.0,TAU,24,Color(0.36,0.38,0.42),3.0)
			draw_line(Vector2(8,-11),Vector2(16,-21),Color(0.52,0.32,0.14),4.0)
			draw_circle(Vector2(18,-23),3.5,Color(0.92,0.40,0.08))
		"coin":
			draw_circle(Vector2.ZERO,15.0,Color(0.92,0.67,0.10))
			draw_circle(Vector2.ZERO,10.0,Color(0.62,0.37,0.045),false,3.0)
			draw_line(Vector2(-3,-8),Vector2(-3,8),Color(1.0,0.84,0.34,0.62),2.0)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-18),Vector2(18,0),Vector2(0,18),Vector2(-18,0)]),Color(0.70,0.54,0.25))
			draw_circle(Vector2.ZERO,7.0,Color(0.10,0.08,0.07))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
