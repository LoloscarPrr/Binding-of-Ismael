extends Area2D
class_name IsmaelShopItem

signal purchase_requested(item)

var reward_id := ""
var cost := 0
var display_name := ""
var sold := false
var _label: Label
var _age := 0.0
var _feedback := 0.0
var _unaffordable := false

func configure(reward_value: String, cost_value: int, name_value: String) -> void:
	reward_id = reward_value
	cost = cost_value
	display_name = name_value
	if is_instance_valid(_label):
		_refresh_label()
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	add_to_group("shop_items")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	z_index = 4
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	collision.shape = circle
	add_child(collision)
	_label = Label.new()
	_label.position = Vector2(-104.0,58.0)
	_label.size = Vector2(208.0,66.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",18)
	_label.add_theme_color_override("font_color",Color(0.96,0.86,0.62))
	_label.add_theme_color_override("font_outline_color",Color(0.025,0.015,0.012))
	_label.add_theme_constant_override("outline_size",5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	body_entered.connect(_on_body_entered)
	set_process(true)
	_refresh_label()
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	_feedback = maxf(0.0,_feedback-delta)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if sold:
		return
	if body is IsmaelPlayer:
		purchase_requested.emit(self)

func mark_sold() -> void:
	if sold:
		return
	sold = true
	monitoring = false
	_feedback = 0.45
	_unaffordable = false
	_refresh_label()
	queue_redraw()

func show_unaffordable() -> void:
	if sold or not is_instance_valid(_label):
		return
	_unaffordable = true
	_feedback = 0.65
	_label.text = "FALTAN MONEDAS\n¢ %d" % cost
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(_label) and not sold:
		_unaffordable = false
		_refresh_label()

func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	if sold:
		_label.text = "AGOTADO"
	else:
		_label.text = "%s\n¢ %d" % [display_name,cost]

func _draw() -> void:
	var bob := sin(_age*2.7+float(get_instance_id()%5))*3.0
	var pulse := 0.5+0.5*sin(_age*3.5)
	var accent := Color(0.88,0.67,0.18)
	if _unaffordable:
		accent = Color(0.85,0.16,0.10)
	var shadow := Color(0.015,0.01,0.008,0.55)
	var stone := Color(0.25,0.19,0.14)
	var stone_edge := Color(0.52,0.39,0.24)
	var muted := Color(0.18,0.17,0.17)
	draw_ellipse(Vector2(0,38),Vector2(60,16),shadow)
	var base := PackedVector2Array([Vector2(-50,17),Vector2(50,17),Vector2(42,48),Vector2(-42,48)])
	draw_colored_polygon(base,stone if not sold else muted)
	draw_polyline(PackedVector2Array([Vector2(-50,17),Vector2(50,17),Vector2(42,48),Vector2(-42,48),Vector2(-50,17)]),stone_edge,3.0,true)
	var top := PackedVector2Array([Vector2(-56,12),Vector2(56,12),Vector2(45,24),Vector2(-45,24)])
	draw_colored_polygon(top,Color(0.38,0.27,0.17) if not sold else Color(0.24,0.23,0.23))
	draw_line(Vector2(-50,13),Vector2(50,13),accent,3.5)
	if sold:
		draw_line(Vector2(-24,-20),Vector2(24,12),Color(0.36,0.07,0.055),7.0)
		draw_line(Vector2(24,-20),Vector2(-24,12),Color(0.36,0.07,0.055),7.0)
		return
	draw_circle(Vector2(0,bob-7),33.0+3.0*pulse,Color(accent,0.045+0.025*pulse))
	draw_set_transform(Vector2(0,bob),0.0,Vector2.ONE)
	match reward_id:
		"curacion":
			draw_circle(Vector2(-10,-15),13.0,Color(0.82,0.05,0.08))
			draw_circle(Vector2(10,-15),13.0,Color(0.82,0.05,0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(-22,-9),Vector2(22,-9),Vector2(0,20)]),Color(0.78,0.04,0.06))
		"vida":
			draw_circle(Vector2(-11,-15),14.0,Color(0.66,0.035,0.06))
			draw_circle(Vector2(11,-15),14.0,Color(0.66,0.035,0.06))
			draw_colored_polygon(PackedVector2Array([Vector2(-24,-9),Vector2(24,-9),Vector2(0,22)]),Color(0.63,0.03,0.055))
			draw_arc(Vector2(0,-3),34.0,0.0,TAU,28,Color(0.90,0.70,0.20,0.62),3.0)
		"dano":
			draw_circle(Vector2(0,-4),27.0,Color(0.31,0.02,0.025))
			draw_circle(Vector2(0,-4),12.0,Color(0.82,0.08,0.06))
			draw_line(Vector2(-29,-4),Vector2(29,-4),Color(0.90,0.68,0.18),3.0)
		"cadencia":
			draw_arc(Vector2(0,-4),25.0,-2.5,2.5,24,Color(0.72,0.80,0.86),6.0)
			draw_line(Vector2(0,-4),Vector2(19,-20),Color(0.92,0.68,0.18),5.0)
		"proyectil":
			draw_circle(Vector2(7,-5),15.0,Color(0.38,0.68,0.84))
			draw_line(Vector2(-32,-5),Vector2(-8,-5),Color(0.72,0.88,0.96),7.0)
		"movimiento":
			draw_colored_polygon(PackedVector2Array([Vector2(-27,10),Vector2(-9,-22),Vector2(4,-11),Vector2(24,-31),Vector2(11,2),Vector2(26,12),Vector2(-2,12)]),Color(0.78,0.70,0.48))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if _feedback > 0.0:
		draw_arc(Vector2.ZERO,58.0*(1.0-_feedback*0.18),0.0,TAU,34,Color(accent,clampf(_feedback,0.0,0.72)),5.0)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU*float(i)/24.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)
