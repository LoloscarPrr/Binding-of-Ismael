extends Node2D
class_name IsmaelRoomVisual

var room_rect := Rect2()
var room_kind := "combate"
var floor_index := 1
var room_index := 1

func configure(rect: Rect2, kind: String, floor_number: int, room_number: int) -> void:
	room_rect = rect
	room_kind = kind
	floor_index = floor_number
	room_index = room_number
	queue_redraw()

func _draw() -> void:
	if room_rect.size.x <= 1.0 or room_rect.size.y <= 1.0:
		return
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.025, 0.019, 0.017))
	_draw_wall_shell()
	_draw_floor()
	_draw_room_markings()
	_draw_debris()
	_draw_props()

func _draw_wall_shell() -> void:
	var outer := room_rect.grow(34.0)
	draw_rect(outer, Color(0.060, 0.045, 0.038))
	draw_rect(outer, Color(0.24, 0.18, 0.135), false, 8.0)
	draw_rect(room_rect.grow(18.0), Color(0.115, 0.084, 0.064), false, 18.0)
	var brick_w := 74.0
	var top_y := outer.position.y + 4.0
	var bottom_y := outer.end.y - 28.0
	var x := outer.position.x + 6.0
	var n := 0
	while x < outer.end.x - 6.0:
		var width := minf(brick_w, outer.end.x - 6.0 - x)
		var tone := Color(0.17, 0.125, 0.095) if n % 2 == 0 else Color(0.14, 0.105, 0.082)
		draw_rect(Rect2(Vector2(x, top_y), Vector2(width - 3.0, 23.0)), tone)
		draw_rect(Rect2(Vector2(x, bottom_y), Vector2(width - 3.0, 23.0)), tone)
		x += brick_w
		n += 1
	var y := outer.position.y + 31.0
	while y < outer.end.y - 31.0:
		draw_rect(Rect2(Vector2(outer.position.x + 5.0, y), Vector2(26.0, 38.0)), Color(0.145,0.105,0.082))
		draw_rect(Rect2(Vector2(outer.end.x - 31.0, y), Vector2(26.0, 38.0)), Color(0.145,0.105,0.082))
		y += 41.0

func _draw_floor() -> void:
	var floor_color := Color(0.205, 0.165, 0.135) if floor_index == 1 else Color(0.145, 0.165, 0.17)
	match room_kind:
		"recompensa": floor_color = Color(0.185, 0.155, 0.095)
		"jefe": floor_color = Color(0.155, 0.085, 0.078)
		"tesoro": floor_color = Color(0.235, 0.185, 0.095)
		"tienda": floor_color = Color(0.175, 0.135, 0.085)
		"maldicion": floor_color = Color(0.105, 0.085, 0.115)
	draw_rect(room_rect, floor_color)
	for row in range(1, 7):
		var yy := room_rect.position.y + room_rect.size.y * float(row) / 7.0
		draw_line(Vector2(room_rect.position.x + 8.0, yy), Vector2(room_rect.end.x - 8.0, yy), Color(0.075,0.055,0.045,0.25), 2.0)
	for col in range(1, 11):
		var xx := room_rect.position.x + room_rect.size.x * float(col) / 11.0
		draw_line(Vector2(xx, room_rect.position.y + 8.0), Vector2(xx, room_rect.end.y - 8.0), Color(0.075,0.055,0.045,0.13), 1.0)
	draw_rect(room_rect, Color(0.34,0.255,0.19), false, 6.0)

func _draw_room_markings() -> void:
	var center := room_rect.get_center()
	match room_kind:
		"emboscada":
			draw_arc(center, minf(room_rect.size.x, room_rect.size.y) * 0.10, 0.0, TAU, 40, Color(0.38,0.11,0.08,0.42), 5.0)
		"recompensa":
			# Marca ritual discreta: evita el aro amarillo gigante de v0.4.0.
			draw_circle(center, 24.0, Color(0.70,0.50,0.16,0.08))
			draw_arc(center, 24.0, 0.0, TAU, 32, Color(0.78,0.59,0.23,0.32), 3.0)
		"jefe":
			# El jefe y su barra son el foco; la marca del suelo queda ambiental.
			draw_arc(center, 58.0, 0.0, TAU, 48, Color(0.48,0.055,0.045,0.24), 5.0)
			draw_line(center+Vector2(-38,0), center+Vector2(38,0), Color(0.35,0.04,0.035,0.18), 3.0)

func _draw_debris() -> void:
	for i in range(18):
		var sx := float((room_index * 47 + floor_index * 29 + i * 71) % 997) / 997.0
		var sy := float((room_index * 83 + floor_index * 41 + i * 43) % 991) / 991.0
		var p := room_rect.position + Vector2(room_rect.size.x * (0.07 + sx * 0.86), room_rect.size.y * (0.10 + sy * 0.82))
		var radius := 3.0 + float(i % 4) * 2.0
		var stain := Color(0.12,0.045,0.035,0.34) if i % 3 == 0 else Color(0.08,0.065,0.05,0.26)
		draw_circle(p, radius, stain)
		if i % 5 == 0:
			draw_line(p + Vector2(-7,-2), p + Vector2(7,3), Color(0.09,0.05,0.04,0.30), 2.0)

func _draw_props() -> void:
	# Props simples pero legibles: piedras y vasijas pegadas a los bordes para no obstruir combate.
	var points := [
		room_rect.position + Vector2(92, 92),
		Vector2(room_rect.end.x - 100, room_rect.position.y + 105),
		Vector2(room_rect.position.x + 118, room_rect.end.y - 92),
		room_rect.end - Vector2(118, 96)
	]
	for i in range(points.size()):
		var p: Vector2 = points[i]
		if i % 2 == 0:
			draw_circle(p + Vector2(3,5), 15.0, Color(0.025,0.02,0.018,0.38))
			draw_circle(p, 14.0, Color(0.19,0.16,0.14))
			draw_arc(p, 14.0, PI, TAU, 14, Color(0.32,0.27,0.22), 3.0)
		else:
			draw_circle(p + Vector2(2,5), 13.0, Color(0.025,0.02,0.018,0.4))
			draw_circle(p, 12.0, Color(0.28,0.13,0.09))
			draw_rect(Rect2(p + Vector2(-8,-15), Vector2(16,6)), Color(0.36,0.18,0.11))
