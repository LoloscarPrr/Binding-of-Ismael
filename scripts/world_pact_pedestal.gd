extends Area2D
class_name IsmaelWorldPactPedestal

signal chosen(pact_id: String)

const CONTACT_CONFIRMATION := 0.18

var pact_id := ""
var pact_title := "PACTO"
var pact_cost := ""
var pact_reward := ""
var claimed_state := false
var _label: Label
var _age := 0.0
var _armed := false
var _contact_token := 0

func configure_pact(id: String, title: String, cost: String, reward: String) -> void:
	pact_id = id
	pact_title = title
	pact_cost = cost
	pact_reward = reward
	if is_instance_valid(_label):
		_refresh_label()
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	add_to_group("pact_offerings")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	z_index = 5
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	collision.shape = circle
	add_child(collision)

	_label = Label.new()
	_label.position = Vector2(-150.0,64.0)
	_label.size = Vector2(300.0,84.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",15)
	_label.add_theme_color_override("font_color",Color(0.96,0.86,0.78))
	_label.add_theme_color_override("font_outline_color",Color(0.02,0.01,0.012,1.0))
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
	chosen.emit(pact_id)

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
		_label.text = "%s
%s
%s" % [pact_title,pact_cost,pact_reward]

func _draw() -> void:
	var pulse := 0.5+0.5*sin(_age*3.1)
	var bob := sin(_age*2.4+float(get_instance_id()%9))*2.5
	draw_ellipse(Vector2(0,43),Vector2(65,15),Color(0.0,0.0,0.0,0.45))
	var base := PackedVector2Array([Vector2(-54,18),Vector2(54,18),Vector2(46,50),Vector2(-46,50)])
	draw_colored_polygon(base,Color(0.16,0.11,0.12))
	draw_polyline(PackedVector2Array([base[0],base[1],base[2],base[3],base[0]]),Color(0.46,0.18,0.18),3.0,true)
	draw_line(Vector2(-49,14),Vector2(49,14),Color(0.82,0.16,0.14,0.90),3.0)
	draw_circle(Vector2(0,bob-10),39.0+3.0*pulse,Color(0.76,0.06,0.08,0.05+0.03*pulse))
	draw_set_transform(Vector2(0,bob-10),0.0,Vector2.ONE)
	match pact_id:
		"sangre":
			_draw_blood_mark()
		"tributo":
			_draw_coin_mark()
		_:
			_draw_curse_mark()
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_blood_mark() -> void:
	draw_circle(Vector2(0,-4),22.0,Color(0.50,0.03,0.05))
	draw_line(Vector2(0,-31),Vector2(0,29),Color(0.88,0.12,0.10),6.0)
	draw_line(Vector2(-22,-5),Vector2(22,-5),Color(0.88,0.12,0.10),5.0)
	draw_circle(Vector2(0,30),6.0,Color(0.74,0.04,0.06))

func _draw_coin_mark() -> void:
	draw_circle(Vector2.ZERO,27.0,Color(0.68,0.49,0.12))
	draw_circle(Vector2.ZERO,20.0,Color(0.16,0.10,0.05))
	draw_circle(Vector2.ZERO,12.0,Color(0.76,0.58,0.17))
	draw_line(Vector2(-7,0),Vector2(7,0),Color(0.18,0.11,0.04),3.0)

func _draw_curse_mark() -> void:
	draw_arc(Vector2.ZERO,28.0,-PI*0.92,PI*0.92,30,Color(0.58,0.20,0.72),5.0)
	draw_circle(Vector2(-9,-2),5.0,Color(0.04,0.02,0.05))
	draw_circle(Vector2(9,-2),5.0,Color(0.04,0.02,0.05))
	draw_line(Vector2(-13,15),Vector2(13,15),Color(0.08,0.03,0.09),4.0)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
