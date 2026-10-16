extends Area2D
class_name IsmaelWorldEventPedestal

signal chosen(choice_id: String)

const CONTACT_CONFIRMATION := 0.18

var choice_id := ""
var choice_title := "DECISIÓN"
var choice_cost := ""
var choice_reward := ""
var claimed_state := false
var _label: Label
var _age := 0.0
var _armed := false
var _contact_token := 0

func configure_choice(id: String, title: String, cost: String, reward: String) -> void:
	choice_id = id
	choice_title = title
	choice_cost = cost
	choice_reward = reward
	if is_instance_valid(_label):
		_refresh_label()
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	add_to_group("event_offerings")
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
	_label.position = Vector2(-152.0,62.0)
	_label.size = Vector2(304.0,86.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",15)
	_label.add_theme_color_override("font_color",Color(0.90,0.91,0.82))
	_label.add_theme_color_override("font_outline_color",Color(0.018,0.014,0.012,1.0))
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
	chosen.emit(choice_id)

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
%s" % [choice_title,choice_cost,choice_reward]

func _draw() -> void:
	var pulse := 0.5+0.5*sin(_age*2.7)
	var bob := sin(_age*2.1+float(get_instance_id()%11))*2.5
	draw_ellipse(Vector2(0,43),Vector2(63,14),Color(0.0,0.0,0.0,0.42))
	var base := PackedVector2Array([Vector2(-51,18),Vector2(51,18),Vector2(44,49),Vector2(-44,49)])
	draw_colored_polygon(base,Color(0.14,0.15,0.13))
	draw_polyline(PackedVector2Array([base[0],base[1],base[2],base[3],base[0]]),Color(0.43,0.49,0.35),3.0,true)
	draw_circle(Vector2(0,bob-8),37.0+3.0*pulse,Color(0.58,0.72,0.38,0.05+0.03*pulse))
	draw_set_transform(Vector2(0,bob-8),0.0,Vector2.ONE)
	match choice_id:
		"comprar","tributo_llave":
			_draw_coin()
		"robar","sangre_pozo":
			_draw_hand()
		"quemar_bombas","quemar_monedas":
			_draw_flame()
		_:
			_draw_eye()
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_coin() -> void:
	draw_circle(Vector2.ZERO,25.0,Color(0.73,0.58,0.18))
	draw_circle(Vector2.ZERO,18.0,Color(0.15,0.12,0.06))
	draw_circle(Vector2.ZERO,10.0,Color(0.76,0.62,0.22))

func _draw_hand() -> void:
	draw_rect(Rect2(-15,-2,30,31),Color(0.47,0.36,0.28))
	for x in [-12.0,-4.0,4.0,12.0]:
		draw_rect(Rect2(x-3,-27,6,27),Color(0.47,0.36,0.28))
	draw_line(Vector2(-18,18),Vector2(18,18),Color(0.78,0.17,0.12),4.0)

func _draw_flame() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0,-32),Vector2(19,-5),Vector2(12,24),Vector2(0,31),
		Vector2(-16,19),Vector2(-21,-4),Vector2(-7,8)
	]),Color(0.86,0.34,0.10))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0,-12),Vector2(9,4),Vector2(4,21),Vector2(-5,16),Vector2(-8,1)
	]),Color(0.95,0.72,0.22))

func _draw_eye() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32,0),Vector2(-16,-16),Vector2(0,-21),Vector2(16,-16),
		Vector2(32,0),Vector2(16,16),Vector2(0,21),Vector2(-16,16)
	]),Color(0.74,0.76,0.63))
	draw_circle(Vector2.ZERO,12.0,Color(0.32,0.48,0.23))
	draw_circle(Vector2.ZERO,5.0,Color(0.03,0.03,0.025))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
