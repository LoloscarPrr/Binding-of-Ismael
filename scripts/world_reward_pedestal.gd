extends Area2D
class_name IsmaelWorldRewardPedestal

signal claimed(reward_id: String)

const CONTACT_CONFIRMATION := 0.16

var reward_id := ""
var reward_title := "OFRENDA"
var reward_effect := ""
var claimed_state := false
var _label: Label
var _age := 0.0
var _armed := false
var _contact_token := 0

func configure_reward(id: String, full_name: String) -> void:
	reward_id = id
	var parts := full_name.split("\n",false,1)
	reward_title = parts[0] if parts.size()>0 else id.to_upper()
	reward_effect = parts[1] if parts.size()>1 else ""
	if is_instance_valid(_label):
		_refresh_label()
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	add_to_group("reward_offerings")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	z_index = 5
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 54.0
	collision.shape = circle
	add_child(collision)
	_label = Label.new()
	_label.position = Vector2(-132.0,64.0)
	_label.size = Vector2(264.0,62.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",16)
	_label.add_theme_color_override("font_color",Color(0.96,0.90,0.76))
	_label.add_theme_color_override("font_outline_color",Color(0.02,0.015,0.012,1.0))
	_label.add_theme_constant_override("outline_size",5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(true)
	_refresh_label()
	call_deferred("_arm_after_spawn")

func _arm_after_spawn() -> void:
	await get_tree().physics_frame
	_armed = true
	for body in get_overlapping_bodies():
		if body is IsmaelPlayer:
			_armed = false
			break

func _on_body_entered(body: Node) -> void:
	if claimed_state or not _armed or not body is IsmaelPlayer:
		return
	_contact_token += 1
	var token := _contact_token
	await get_tree().create_timer(CONTACT_CONFIRMATION).timeout
	if claimed_state or token != _contact_token or not is_instance_valid(body):
		return
	if not overlaps_body(body):
		return
	claimed_state = true
	monitoring = false
	claimed.emit(reward_id)

func _on_body_exited(body: Node) -> void:
	if not body is IsmaelPlayer:
		return
	_contact_token += 1
	if not claimed_state:
		_armed = true

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _refresh_label() -> void:
	if is_instance_valid(_label):
		_label.text = "%s\n%s" % [reward_title,reward_effect]

func _draw() -> void:
	var bob := sin(_age*2.8+float(get_instance_id()%7))*3.0
	var pulse := 0.5+0.5*sin(_age*3.4)
	draw_ellipse(Vector2(0,43),Vector2(63,15),Color(0.0,0.0,0.0,0.42))
	var base := PackedVector2Array([Vector2(-52,18),Vector2(52,18),Vector2(44,49),Vector2(-44,49)])
	draw_colored_polygon(base,Color(0.22,0.18,0.15))
	draw_polyline(PackedVector2Array([base[0],base[1],base[2],base[3],base[0]]),Color(0.48,0.38,0.28),3.0,true)
	var slab := PackedVector2Array([Vector2(-58,12),Vector2(58,12),Vector2(47,25),Vector2(-47,25)])
	draw_colored_polygon(slab,Color(0.34,0.27,0.20))
	draw_line(Vector2(-50,13),Vector2(50,13),Color(0.72,0.54,0.25,0.85),3.0)
	draw_circle(Vector2(0,bob-8),38.0+3.0*pulse,Color(0.78,0.62,0.28,0.04+0.025*pulse))
	draw_set_transform(Vector2(0,bob-9),0.0,Vector2.ONE)
	_draw_object()
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_object() -> void:
	match reward_id:
		"vida":
			_draw_heart()
		"curacion":
			_draw_bandage()
		"movimiento":
			_draw_boots()
		"cadencia":
			_draw_watch()
		"proyectil":
			_draw_tear()
		"dano":
			_draw_eye(Color(0.80,0.10,0.08))
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
			draw_circle(Vector2.ZERO,22.0,Color(0.72,0.58,0.30))

func _draw_heart() -> void:
	var c := Color(0.76,0.05,0.07)
	draw_circle(Vector2(-11,-8),15.0,c)
	draw_circle(Vector2(11,-8),15.0,c)
	draw_colored_polygon(PackedVector2Array([Vector2(-25,-3),Vector2(25,-3),Vector2(0,30)]),c)
	draw_circle(Vector2(-10,-13),4.0,Color(1.0,0.68,0.66,0.75))

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
	var white := PackedVector2Array([Vector2(-34,0),Vector2(-18,-17),Vector2(0,-23),Vector2(18,-17),Vector2(34,0),Vector2(18,17),Vector2(0,23),Vector2(-18,17)])
	draw_colored_polygon(white,Color(0.88,0.82,0.72))
	draw_circle(Vector2.ZERO,13.0,iris)
	draw_circle(Vector2.ZERO,6.0,Color(0.04,0.03,0.03))
	draw_circle(Vector2(-4,-5),2.5,Color(1,1,1,0.85))

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
		draw_circle(Vector2(cos(a)*22,sin(a)*19-4),4.5,Color(0.55,0.56,0.52))
	draw_line(Vector2(0,15),Vector2(0,33),Color(0.62,0.60,0.53),4.0)
	draw_line(Vector2(-7,26),Vector2(7,26),Color(0.62,0.60,0.53),4.0)

func _draw_glove() -> void:
	var skin := Color(0.48,0.20,0.16)
	draw_rect(Rect2(-17,-3,34,31),skin)
	for x in [-14.0,-5.0,4.0,13.0]:
		draw_rect(Rect2(x-4,-28,8,27),skin)
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

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
