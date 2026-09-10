extends Control
class_name IsmaelHealthHud

var current_health := 0
var maximum_health := 0
var icon_size := 30.0:
	set(value):
		icon_size = value
		queue_redraw()
var icon_gap := 8.0:
	set(value):
		icon_gap = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_health(current: int, maximum: int) -> void:
	current_health = maxi(0, current)
	maximum_health = maxi(0, maximum)
	queue_redraw()

func _draw() -> void:
	for index in maximum_health:
		var center := Vector2(
			icon_size * 0.5 + index * (icon_size + icon_gap),
			size.y * 0.5
		)
		_draw_heart(center, index < current_health)

func _draw_heart(center: Vector2, filled: bool) -> void:
	var radius := icon_size * 0.48
	var points := PackedVector2Array([
		center + Vector2(0.00, 0.90) * radius,
		center + Vector2(-0.72, 0.22) * radius,
		center + Vector2(-0.94, -0.14) * radius,
		center + Vector2(-0.90, -0.50) * radius,
		center + Vector2(-0.62, -0.78) * radius,
		center + Vector2(-0.30, -0.80) * radius,
		center + Vector2(0.00, -0.54) * radius,
		center + Vector2(0.30, -0.80) * radius,
		center + Vector2(0.62, -0.78) * radius,
		center + Vector2(0.90, -0.50) * radius,
		center + Vector2(0.94, -0.14) * radius,
		center + Vector2(0.72, 0.22) * radius
	])
	var fill_color := Color(0.82, 0.13, 0.16) if filled else Color(0.20, 0.075, 0.08)
	var outline_color := Color(1.0, 0.74, 0.67) if filled else Color(0.56, 0.32, 0.28)
	draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, maxf(2.0, icon_size * 0.085), true)
