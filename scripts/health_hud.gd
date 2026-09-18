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
	current_health = maxi(0,current)
	maximum_health = maxi(0,maximum)
	queue_redraw()

func _draw() -> void:
	for index in maximum_health:
		var center := Vector2(icon_size*0.5+index*(icon_size+icon_gap),size.y*0.5)
		_draw_heart(center,index<current_health)

func _draw_heart(center: Vector2, filled: bool) -> void:
	var radius := icon_size*0.48
	var points := PackedVector2Array([
		center+Vector2(0.00,0.90)*radius,
		center+Vector2(-0.72,0.22)*radius,
		center+Vector2(-0.94,-0.14)*radius,
		center+Vector2(-0.90,-0.50)*radius,
		center+Vector2(-0.62,-0.78)*radius,
		center+Vector2(-0.30,-0.80)*radius,
		center+Vector2(0.00,-0.54)*radius,
		center+Vector2(0.30,-0.80)*radius,
		center+Vector2(0.62,-0.78)*radius,
		center+Vector2(0.90,-0.50)*radius,
		center+Vector2(0.94,-0.14)*radius,
		center+Vector2(0.72,0.22)*radius
	])
	var shadow := PackedVector2Array()
	for p: Vector2 in points:
		shadow.append(p+Vector2(2.5,3.5))
	draw_colored_polygon(shadow,Color(0.0,0.0,0.0,0.44))
	var fill_color := Color(0.76,0.055,0.085) if filled else Color(0.14,0.055,0.06)
	var outline_color := Color(0.98,0.55,0.48) if filled else Color(0.39,0.22,0.20)
	draw_colored_polygon(points,fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline,outline_color,maxf(2.0,icon_size*0.085),true)
	if filled:
		draw_circle(center+Vector2(-radius*0.28,-radius*0.32),radius*0.12,Color(1.0,0.78,0.70,0.72))
		draw_line(center+Vector2(-radius*0.42,radius*0.22),center+Vector2(0,radius*0.62),Color(0.40,0.02,0.04,0.30),2.0)
