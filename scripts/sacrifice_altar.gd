extends Area2D
class_name IsmaelSacrificeAltar

signal requested(altar)

var used := false
var _age := 0.0
var _cooldown := 0.0
var _label: Label

func _ready() -> void:
	add_to_group("room_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	z_index = 4
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	collision.shape = circle
	add_child(collision)

	_label = Label.new()
	_label.position = Vector2(-120,54)
	_label.size = Vector2(240,52)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size",16)
	_label.add_theme_color_override("font_color",Color(0.88,0.72,0.62))
	_label.add_theme_color_override("font_outline_color",Color(0.03,0.01,0.015))
	_label.add_theme_constant_override("outline_size",4)
	_label.text = "OFRECE 1 CORAZÓN"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	body_entered.connect(_on_body_entered)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	_cooldown = maxf(0.0,_cooldown-delta)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if used or _cooldown>0.0:
		return
	if body is IsmaelPlayer:
		_cooldown = 0.8
		requested.emit(self)

func mark_used() -> void:
	used = true
	monitoring = false
	if is_instance_valid(_label):
		_label.text = "ALTAR SILENCIOSO"
	queue_redraw()

func show_blocked() -> void:
	if not is_instance_valid(_label) or used:
		return
	_label.text = "NECESITAS MÁS VIDA"
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(_label) and not used:
		_label.text = "OFRECE 1 CORAZÓN"

func _draw() -> void:
	var pulse := 0.5+0.5*sin(_age*2.8)
	draw_ellipse(Vector2(0,31),Vector2(54,15),Color(0,0,0,0.34))
	draw_circle(Vector2.ZERO,43.0,Color(0.16,0.045,0.055,0.25))
	draw_arc(Vector2.ZERO,42.0,0.0,TAU,40,Color(0.50,0.12,0.15,0.45),4.0)
	for a in range(0,360,72):
		var d := Vector2.RIGHT.rotated(deg_to_rad(float(a)))
		draw_line(d*18.0,d*34.0,Color(0.44,0.08,0.10,0.52),3.0)
	if used:
		draw_circle(Vector2.ZERO,12.0,Color(0.12,0.10,0.10))
		draw_line(Vector2(-14,-14),Vector2(14,14),Color(0.24,0.20,0.18),4.0)
		return
	var glow := Color(0.74,0.06,0.09,0.08+0.06*pulse)
	draw_circle(Vector2(0,-5),26.0+4.0*pulse,glow)
	var c := Color(0.68,0.035,0.06)
	draw_circle(Vector2(-7,-8),8.5,c)
	draw_circle(Vector2(7,-8),8.5,c)
	draw_colored_polygon(PackedVector2Array([Vector2(-15,-4),Vector2(15,-4),Vector2(0,18)]),c)
	draw_circle(Vector2(-5,-10),2.4,Color(1.0,0.64,0.60,0.72))

func draw_ellipse(center: Vector2,radii: Vector2,color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
