extends Area2D
class_name IsmaelShopItem

signal purchase_requested(item)

var reward_id := ""
var cost := 0
var display_name := ""
var sold := false
var _label: Label

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
	circle.radius = 48.0
	collision.shape = circle
	add_child(collision)

	_label = Label.new()
	_label.position = Vector2(-92.0, 50.0)
	_label.size = Vector2(184.0, 62.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.02))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	body_entered.connect(_on_body_entered)
	_refresh_label()
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
	_refresh_label()
	queue_redraw()

func show_unaffordable() -> void:
	if sold or not is_instance_valid(_label):
		return
	_label.text = "FALTAN MONEDAS\n¢ %d" % cost
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(_label) and not sold:
		_refresh_label()

func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	if sold:
		_label.text = "AGOTADO"
	else:
		_label.text = "%s\n¢ %d" % [display_name, cost]

func _draw() -> void:
	var shadow := Color(0.03, 0.02, 0.015, 0.42)
	var stone := Color(0.29, 0.23, 0.18)
	var stone_edge := Color(0.49, 0.38, 0.26)
	var gold := Color(0.88, 0.67, 0.18)
	var muted := Color(0.24, 0.22, 0.21)

	draw_ellipse(Vector2(0, 31), Vector2(51, 15), shadow)
	draw_rect(Rect2(-43, 13, 86, 30), stone if not sold else muted)
	draw_rect(Rect2(-47, 8, 94, 10), stone_edge if not sold else Color(0.34,0.31,0.30))

	if sold:
		draw_line(Vector2(-22, -24), Vector2(22, 10), Color(0.35,0.10,0.08), 7.0)
		draw_line(Vector2(22, -24), Vector2(-22, 10), Color(0.35,0.10,0.08), 7.0)
		return

	match reward_id:
		"curacion":
			draw_circle(Vector2(-9, -13), 12.0, Color(0.78,0.08,0.10))
			draw_circle(Vector2(9, -13), 12.0, Color(0.78,0.08,0.10))
			draw_colored_polygon(PackedVector2Array([Vector2(-20,-8),Vector2(20,-8),Vector2(0,17)]), Color(0.78,0.08,0.10))
		"vida":
			draw_circle(Vector2(-10, -14), 13.0, Color(0.64,0.05,0.08))
			draw_circle(Vector2(10, -14), 13.0, Color(0.64,0.05,0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(-22,-8),Vector2(22,-8),Vector2(0,20)]), Color(0.64,0.05,0.08))
			draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 24, gold, 3.0)
		"dano":
			draw_circle(Vector2.ZERO, 25.0, Color(0.39,0.035,0.035))
			draw_circle(Vector2.ZERO, 11.0, Color(0.78,0.10,0.08))
			draw_line(Vector2(-28,0), Vector2(28,0), gold, 3.0)
		"cadencia":
			draw_arc(Vector2.ZERO, 24.0, -2.5, 2.5, 24, Color(0.72,0.80,0.86), 6.0)
			draw_line(Vector2.ZERO, Vector2(18,-15), gold, 5.0)
		"proyectil":
			draw_circle(Vector2(5, -2), 14.0, Color(0.44,0.69,0.82))
			draw_line(Vector2(-30, -2), Vector2(-7, -2), Color(0.72,0.86,0.94), 7.0)
		"movimiento":
			draw_colored_polygon(PackedVector2Array([Vector2(-25,11),Vector2(-8,-20),Vector2(4,-9),Vector2(22,-28),Vector2(10,2),Vector2(24,12),Vector2(-2,12)]), Color(0.75,0.69,0.50))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
