extends Area2D
class_name IsmaelTreasureChest

signal open_requested(chest)

var chest_kind := "wooden"
var opened := false
var _age := 0.0

func configure(kind_value: String, opened_value: bool = false) -> void:
	chest_kind = kind_value
	opened = opened_value
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	add_to_group("room_chests")
	collision_layer = 0
	collision_mask = 1
	monitoring = not opened
	monitorable = true
	z_index = 4
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(78.0,54.0)
	collision.shape = shape
	collision.position = Vector2(0,5)
	add_child(collision)
	body_entered.connect(_on_body_entered)
	set_process(true)
	queue_redraw()

func set_opened(value: bool) -> void:
	opened = value
	monitoring = not opened
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if opened:
		return
	if body is IsmaelPlayer:
		open_requested.emit(self)

func _draw() -> void:
	var pulse := 0.5+0.5*sin(_age*3.0)
	var wood := Color(0.33,0.16,0.055)
	var wood_light := Color(0.48,0.25,0.08)
	var metal := Color(0.50,0.38,0.19)
	if chest_kind == "locked":
		wood = Color(0.30,0.20,0.055)
		wood_light = Color(0.58,0.42,0.09)
		metal = Color(0.88,0.68,0.20)

	_draw_ellipse(Vector2(0,29),Vector2(48,10),Color(0,0,0,0.32))
	if not opened:
		draw_rect(Rect2(Vector2(-40,-9),Vector2(80,42)),wood,true)
		draw_rect(Rect2(Vector2(-40,-20),Vector2(80,18)),wood_light,true)
		draw_line(Vector2(-40,-2),Vector2(40,-2),metal,4.0)
		draw_line(Vector2(-39,31),Vector2(39,31),Color(0.12,0.07,0.025),3.0)
		draw_rect(Rect2(Vector2(-5,-8),Vector2(10,21)),metal,true)
		if chest_kind == "locked":
			draw_rect(Rect2(Vector2(-9,4),Vector2(18,16)),Color(0.90,0.70,0.18),true)
			draw_arc(Vector2(0,4),8.0,PI,TAU,18,Color(0.96,0.79,0.29),3.5)
		draw_arc(Vector2.ZERO,47.0,0.22,PI-0.22,28,Color(0.95,0.76,0.28,0.10+0.10*pulse),3.0)
	else:
		draw_rect(Rect2(Vector2(-40,1),Vector2(80,32)),wood,true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-39,-2),Vector2(-31,-28),Vector2(31,-28),Vector2(39,-2)
		]),wood_light)
		draw_line(Vector2(-31,-28),Vector2(31,-28),metal,4.0)
		draw_line(Vector2(-39,-2),Vector2(39,-2),metal,3.0)
		draw_circle(Vector2(0,10),5.0,metal)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(28):
		var angle := TAU*float(i)/28.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)
