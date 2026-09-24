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
var _armed := false
var _contact_token := 0
const CONTACT_CONFIRMATION := 0.16

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
	body_exited.connect(_on_body_exited)
	set_process(true)
	call_deferred("_arm_after_spawn")
	_refresh_label()
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	_feedback = maxf(0.0,_feedback-delta)
	queue_redraw()

func _arm_after_spawn() -> void:
	await get_tree().physics_frame
	_armed = true
	for body in get_overlapping_bodies():
		if body is IsmaelPlayer:
			_armed = false
			break

func _on_body_entered(body: Node) -> void:
	if sold or not _armed or not body is IsmaelPlayer:
		return
	_contact_token += 1
	var token := _contact_token
	await get_tree().create_timer(CONTACT_CONFIRMATION).timeout
	if sold or token != _contact_token or not is_instance_valid(body):
		return
	if not overlaps_body(body):
		return
	_armed = false
	purchase_requested.emit(self)

func _on_body_exited(body: Node) -> void:
	if not body is IsmaelPlayer:
		return
	_contact_token += 1
	if not sold:
		_armed = true

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
			_draw_bandage()
		"vida":
			_draw_heart(true)
		"dano":
			_draw_eye(Color(0.82,0.08,0.06))
		"cadencia":
			_draw_watch()
		"proyectil":
			_draw_tear()
		"movimiento":
			_draw_boots()
		"buscadora":
			_draw_eye(Color(0.58,0.70,0.34))
		"perforante":
			_draw_needle()
		"escudo":
			_draw_rosary()
		"rafaga":
			_draw_glove()
		"mapa":
			_draw_map()
		"monedero":
			_draw_purse()
		_:
			_draw_unknown_item()
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if _feedback > 0.0:
		draw_arc(Vector2.ZERO,58.0*(1.0-_feedback*0.18),0.0,TAU,34,Color(accent,clampf(_feedback,0.0,0.72)),5.0)

func _draw_heart(rare: bool = false) -> void:
	var c := Color(0.70,0.035,0.06) if rare else Color(0.82,0.05,0.08)
	draw_circle(Vector2(-11,-13),14.0,c)
	draw_circle(Vector2(11,-13),14.0,c)
	draw_colored_polygon(PackedVector2Array([Vector2(-24,-7),Vector2(24,-7),Vector2(0,25)]),c)
	draw_circle(Vector2(-10,-17),4.0,Color(1.0,0.68,0.66,0.74))
	if rare:
		draw_arc(Vector2(0,-2),34.0,0.0,TAU,28,Color(0.90,0.70,0.20,0.58),3.0)

func _draw_bandage() -> void:
	draw_set_transform(Vector2.ZERO,-0.55,Vector2.ONE)
	draw_rect(Rect2(-31,-10,62,20),Color(0.82,0.70,0.51))
	draw_rect(Rect2(-11,-13,22,26),Color(0.94,0.84,0.66))
	draw_circle(Vector2(-22,0),3.2,Color(0.54,0.39,0.27))
	draw_circle(Vector2(22,0),3.2,Color(0.54,0.39,0.27))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_boots() -> void:
	var leather := Color(0.42,0.27,0.16)
	draw_rect(Rect2(-26,-25,17,35),leather)
	draw_colored_polygon(PackedVector2Array([Vector2(-26,5),Vector2(-7,5),Vector2(1,20),Vector2(-29,20)]),leather)
	draw_rect(Rect2(9,-25,17,35),leather)
	draw_colored_polygon(PackedVector2Array([Vector2(9,5),Vector2(28,5),Vector2(34,20),Vector2(5,20)]),leather)
	draw_line(Vector2(-24,-12),Vector2(-10,-12),Color(0.74,0.58,0.36),3.0)
	draw_line(Vector2(11,-12),Vector2(25,-12),Color(0.74,0.58,0.36),3.0)

func _draw_watch() -> void:
	draw_rect(Rect2(-8,-35,16,18),Color(0.28,0.22,0.18))
	draw_rect(Rect2(-8,17,16,18),Color(0.28,0.22,0.18))
	draw_circle(Vector2.ZERO,23.0,Color(0.62,0.54,0.40))
	draw_circle(Vector2.ZERO,18.0,Color(0.12,0.12,0.12))
	draw_line(Vector2.ZERO,Vector2(0,-12),Color(0.95,0.76,0.30),3.0)
	draw_line(Vector2.ZERO,Vector2(10,5),Color(0.95,0.76,0.30),3.0)

func _draw_tear() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0,-31),Vector2(22,5),Vector2(15,23),Vector2(0,31),Vector2(-15,23),Vector2(-22,5)]),Color(0.30,0.66,0.92))
	draw_circle(Vector2(-7,-3),5.0,Color(0.82,0.95,1.0,0.78))

func _draw_eye(iris: Color) -> void:
	var eye := PackedVector2Array([Vector2(-34,0),Vector2(-18,-17),Vector2(0,-23),Vector2(18,-17),Vector2(34,0),Vector2(18,17),Vector2(0,23),Vector2(-18,17)])
	draw_colored_polygon(eye,Color(0.88,0.82,0.72))
	draw_circle(Vector2.ZERO,13.0,iris)
	draw_circle(Vector2.ZERO,6.0,Color(0.04,0.03,0.03))
	draw_circle(Vector2(-4,-5),2.5,Color(1.0,1.0,1.0,0.85))

func _draw_needle() -> void:
	draw_set_transform(Vector2.ZERO,-0.65,Vector2.ONE)
	draw_rect(Rect2(-3,-34,6,62),Color(0.72,0.74,0.70))
	draw_colored_polygon(PackedVector2Array([Vector2(-3,28),Vector2(3,28),Vector2(0,39)]),Color(0.86,0.88,0.84))
	draw_circle(Vector2(0,-29),5.0,Color(0.28,0.26,0.24))
	draw_circle(Vector2(0,-29),2.0,Color(0.06,0.05,0.05))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_rosary() -> void:
	for i in range(10):
		var a := TAU*float(i)/10.0
		draw_circle(Vector2(cos(a)*22.0,sin(a)*19.0-4.0),4.5,Color(0.55,0.56,0.52))
	draw_line(Vector2(0,15),Vector2(0,33),Color(0.62,0.60,0.53),4.0)
	draw_line(Vector2(-7,26),Vector2(7,26),Color(0.62,0.60,0.53),4.0)

func _draw_glove() -> void:
	var skin := Color(0.48,0.20,0.16)
	draw_rect(Rect2(-17,-3,34,31),skin)
	for x in [-14.0,-5.0,4.0,13.0]:
		draw_rect(Rect2(x-4.0,-28.0,8.0,27.0),skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-18,7),Vector2(-31,-7),Vector2(-25,-14),Vector2(-11,0)]),skin)
	draw_line(Vector2(-16,18),Vector2(16,18),Color(0.76,0.52,0.24),3.0)

func _draw_map() -> void:
	var paper := Color(0.73,0.62,0.43)
	var pts := PackedVector2Array([Vector2(-32,-25),Vector2(-10,-29),Vector2(10,-23),Vector2(32,-28),Vector2(30,25),Vector2(9,29),Vector2(-11,23),Vector2(-31,28)])
	draw_colored_polygon(pts,paper)
	draw_line(Vector2(-10,-28),Vector2(-11,23),Color(0.35,0.26,0.17),2.0)
	draw_line(Vector2(10,-23),Vector2(9,29),Color(0.35,0.26,0.17),2.0)
	draw_line(Vector2(-23,-10),Vector2(18,12),Color(0.45,0.16,0.12),3.0)

func _draw_purse() -> void:
	draw_circle(Vector2(0,8),25.0,Color(0.36,0.24,0.15))
	draw_rect(Rect2(-21,-9,42,15),Color(0.42,0.28,0.17))
	draw_line(Vector2(-17,-8),Vector2(17,-8),Color(0.79,0.63,0.28),4.0)
	draw_circle(Vector2(0,8),9.0,Color(0.78,0.58,0.15))
	draw_circle(Vector2(0,8),5.0,Color(0.24,0.16,0.08))

func _draw_unknown_item() -> void:
	var c := Color(0.74,0.58,0.28)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-31),Vector2(27,-12),Vector2(27,18),Vector2(0,34),Vector2(-27,18),Vector2(-27,-12)]),Color(0.18,0.15,0.13))
	draw_polyline(PackedVector2Array([Vector2(0,-31),Vector2(27,-12),Vector2(27,18),Vector2(0,34),Vector2(-27,18),Vector2(-27,-12),Vector2(0,-31)]),c,3.0,true)
	draw_string(ThemeDB.fallback_font,Vector2(-8,9),"? ",HORIZONTAL_ALIGNMENT_LEFT,20.0,28,Color(0.96,0.84,0.48))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU*float(i)/24.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)
