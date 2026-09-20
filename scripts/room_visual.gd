extends Node2D
class_name IsmaelRoomVisual

var room_rect := Rect2()
var room_kind := "combate"
var floor_index := 1
var room_index := 1
var _age := 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

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
	draw_rect(Rect2(Vector2.ZERO,viewport_size),Color(0.014,0.012,0.012))
	_draw_wall_shell()
	_draw_floor()
	_draw_room_markings()
	_draw_debris()
	_draw_props()
	_draw_wall_torches()
	_draw_light_pools()
	_draw_edge_shadows()

func _draw_wall_shell() -> void:
	var outer := room_rect.grow(42.0)
	draw_rect(outer.grow(12.0),Color(0.0,0.0,0.0,0.58))
	draw_rect(outer,Color(0.052,0.040,0.035))
	draw_rect(outer,Color(0.26,0.18,0.12),false,8.0)
	draw_rect(room_rect.grow(27.0),Color(0.10,0.073,0.058))
	draw_rect(room_rect.grow(19.0),Color(0.20,0.145,0.105),false,7.0)
	var brick_w := 72.0
	var x := outer.position.x + 7.0
	var n := 0
	while x < outer.end.x - 8.0:
		var width := minf(brick_w,outer.end.x-8.0-x)
		var tone := Color(0.17,0.115,0.082) if n%2==0 else Color(0.135,0.094,0.074)
		var top_rect := Rect2(Vector2(x,outer.position.y+7.0),Vector2(width-3.0,28.0))
		var bottom_rect := Rect2(Vector2(x,outer.end.y-35.0),Vector2(width-3.0,28.0))
		draw_rect(top_rect,tone)
		draw_line(top_rect.position+Vector2(2,2),Vector2(top_rect.end.x-2,top_rect.position.y+2),Color(0.34,0.24,0.16,0.55),2.0)
		draw_line(Vector2(top_rect.position.x,top_rect.end.y-2),top_rect.end-Vector2(0,2),Color(0.03,0.02,0.018,0.72),3.0)
		draw_rect(bottom_rect,tone.darkened(0.08))
		draw_line(bottom_rect.position+Vector2(2,2),Vector2(bottom_rect.end.x-2,bottom_rect.position.y+2),Color(0.30,0.21,0.15,0.45),2.0)
		x += brick_w
		n += 1
	var y := outer.position.y + 39.0
	while y < outer.end.y - 40.0:
		for side_x in [outer.position.x+7.0,outer.end.x-34.0]:
			var block := Rect2(Vector2(side_x,y),Vector2(27.0,39.0))
			draw_rect(block,Color(0.145,0.10,0.078))
			draw_line(block.position+Vector2(2,1),Vector2(block.end.x-2,block.position.y+1),Color(0.32,0.23,0.16,0.45),2.0)
		y += 42.0

func _floor_color() -> Color:
	var color := Color(0.185,0.145,0.116) if floor_index==1 else Color(0.115,0.135,0.14)
	match room_kind:
		"recompensa": color = Color(0.17,0.135,0.073)
		"jefe": color = Color(0.13,0.060,0.058)
		"tienda": color = Color(0.155,0.112,0.065)
	return color

func _draw_floor() -> void:
	var base := _floor_color()
	draw_rect(room_rect,base)
	var cols := 9
	var rows := 5
	var tile_w := room_rect.size.x/float(cols)
	var tile_h := room_rect.size.y/float(rows)
	for row in range(rows):
		for col in range(cols):
			var tile := Rect2(room_rect.position+Vector2(col*tile_w,row*tile_h),Vector2(tile_w,tile_h))
			var variation := float((col*19+row*31+room_index*7+floor_index*11)%9)/100.0
			var tile_color := base.lightened(variation) if (col+row)%2==0 else base.darkened(variation*0.72)
			draw_rect(tile.grow(-1.0),tile_color)
			draw_line(tile.position+Vector2(2,2),Vector2(tile.end.x-2,tile.position.y+2),Color(1,0.78,0.55,0.045),1.5)
			draw_line(Vector2(tile.position.x+2,tile.end.y-2),tile.end-Vector2(2,2),Color(0.02,0.015,0.012,0.18),2.0)
	draw_rect(room_rect,Color(0.34,0.24,0.17),false,6.0)
	if room_kind=="tienda":
		var rug := Rect2(room_rect.position+room_rect.size*Vector2(0.22,0.33),room_rect.size*Vector2(0.56,0.31))
		draw_rect(rug,Color(0.22,0.055,0.045,0.55))
		draw_rect(rug,Color(0.62,0.40,0.16,0.48),false,4.0)
		for i in range(1,6):
			var xx := rug.position.x+rug.size.x*float(i)/6.0
			draw_line(Vector2(xx,rug.position.y+5),Vector2(xx,rug.end.y-5),Color(0.68,0.45,0.18,0.16),2.0)

func _draw_room_markings() -> void:
	var center := room_rect.get_center()
	match room_kind:
		"emboscada":
			draw_circle(center,58.0,Color(0.34,0.07,0.05,0.16))
			draw_arc(center,62.0,0.0,TAU,40,Color(0.50,0.10,0.07,0.46),5.0)
			for a in range(0,360,60):
				var d := Vector2.RIGHT.rotated(deg_to_rad(float(a)))
				draw_line(center+d*31.0,center+d*55.0,Color(0.45,0.08,0.06,0.34),3.0)
		"recompensa":
			draw_circle(center,28.0,Color(0.78,0.57,0.16,0.10))
			draw_arc(center,30.0,0.0,TAU,32,Color(0.84,0.66,0.29,0.42),3.0)
		"jefe":
			draw_circle(center,72.0,Color(0.38,0.02,0.025,0.11))
			draw_arc(center,74.0,0.0,TAU,48,Color(0.55,0.05,0.045,0.34),6.0)
			draw_line(center+Vector2(-48,0),center+Vector2(48,0),Color(0.38,0.03,0.03,0.24),3.0)
			draw_line(center+Vector2(0,-48),center+Vector2(0,48),Color(0.38,0.03,0.03,0.18),3.0)
		"tienda":
			var shelf_y := room_rect.position.y+room_rect.size.y*0.25
			draw_rect(Rect2(Vector2(room_rect.position.x+room_rect.size.x*0.20,shelf_y),Vector2(room_rect.size.x*0.60,12)),Color(0.09,0.04,0.025,0.68))
			draw_rect(Rect2(Vector2(room_rect.position.x+room_rect.size.x*0.21,shelf_y-10),Vector2(room_rect.size.x*0.58,9)),Color(0.31,0.15,0.07,0.72))

func _draw_debris() -> void:
	for i in range(28):
		var sx := float((room_index*47+floor_index*29+i*71)%997)/997.0
		var sy := float((room_index*83+floor_index*41+i*43)%991)/991.0
		var p := room_rect.position+Vector2(room_rect.size.x*(0.05+sx*0.90),room_rect.size.y*(0.08+sy*0.84))
		var radius := 2.5+float(i%4)*1.6
		var stain := Color(0.12,0.035,0.028,0.28) if i%3==0 else Color(0.05,0.045,0.038,0.22)
		draw_circle(p,radius,stain)
		if i%4==0:
			var branch := Vector2(11.0+float(i%3)*3.0,4.0).rotated(float(i)*0.77)
			draw_line(p-branch*0.45,p+branch*0.55,Color(0.055,0.036,0.03,0.44),2.0)
			draw_line(p+branch*0.1,p+branch*0.1+Vector2(-branch.y,branch.x)*0.30,Color(0.055,0.036,0.03,0.36),1.5)
		if i%7==0:
			draw_circle(p+Vector2(4,-3),radius*1.8,Color(0.20,0.025,0.022,0.16))
			draw_circle(p+Vector2(-3,2),radius*1.1,Color(0.26,0.035,0.028,0.12))

func _draw_props() -> void:
	var points := [
		room_rect.position+Vector2(90,88),
		Vector2(room_rect.end.x-96,room_rect.position.y+96),
		Vector2(room_rect.position.x+112,room_rect.end.y-86),
		room_rect.end-Vector2(112,90)
	]
	for i in range(points.size()):
		var p: Vector2 = points[i]
		draw_ellipse(p+Vector2(4,9),Vector2(18,7),Color(0,0,0,0.34))
		if i%2==0:
			draw_circle(p,15.0,Color(0.16,0.14,0.13))
			draw_arc(p,15.0,PI,TAU,16,Color(0.35,0.29,0.22),3.0)
			draw_line(p+Vector2(-10,4),p+Vector2(8,-6),Color(0.07,0.06,0.055,0.7),2.0)
		else:
			draw_circle(p,13.0,Color(0.24,0.09,0.06))
			draw_rect(Rect2(p+Vector2(-9,-16),Vector2(18,6)),Color(0.36,0.16,0.09))
	if room_kind=="tienda":
		for ratio in [0.31,0.50,0.69]:
			var p := room_rect.position+room_rect.size*Vector2(ratio,0.68)
			draw_ellipse(p+Vector2(0,6),Vector2(45,11),Color(0,0,0,0.24))
			draw_circle(p,4.0,Color(0.84,0.57,0.15,0.78))
	if room_kind=="jefe":
		for side in [-1.0,1.0]:
			var p := room_rect.get_center()+Vector2(side*room_rect.size.x*0.32,-room_rect.size.y*0.30)
			draw_circle(p,13.0,Color(0.12,0.04,0.025))
			draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-7),p+Vector2(0,-28),p+Vector2(7,-7)]),Color(0.75,0.18,0.06,0.72))

func _draw_wall_torches() -> void:
	var flicker := 0.86 + sin(_age*7.0)*0.08 + sin(_age*11.3)*0.04
	var torch_y := room_rect.position.y + 22.0
	for ratio in [0.22,0.78]:
		var p := Vector2(room_rect.position.x+room_rect.size.x*ratio,torch_y)
		draw_rect(Rect2(p+Vector2(-4,-5),Vector2(8,22)),Color(0.10,0.055,0.025))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-7,-6),p+Vector2(0,-28*flicker),p+Vector2(8,-5),p+Vector2(0,5)]),Color(0.88,0.24,0.05,0.78))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-4,-6),p+Vector2(0,-20*flicker),p+Vector2(5,-5),p+Vector2(0,1)]),Color(1.0,0.72,0.20,0.88))
		draw_circle(p+Vector2(0,-10),34.0,Color(0.96,0.42,0.10,0.055))

func _draw_light_pools() -> void:
	var center := room_rect.get_center()
	for radius in [290.0,220.0,155.0]:
		var alpha := 0.018 if radius>250.0 else (0.026 if radius>180.0 else 0.036)
		draw_circle(center,radius,Color(0.86,0.60,0.34,alpha))
	for ratio in [0.22,0.78]:
		var p := Vector2(room_rect.position.x+room_rect.size.x*ratio,room_rect.position.y+58.0)
		for r in [110.0,80.0,52.0]:
			var a := 0.018 if r>100.0 else (0.028 if r>70.0 else 0.042)
			draw_circle(p,r,Color(1.0,0.48,0.12,a))

func _draw_edge_shadows() -> void:
	var depth := 34.0
	draw_rect(Rect2(room_rect.position,Vector2(room_rect.size.x,depth)),Color(0,0,0,0.22))
	draw_rect(Rect2(Vector2(room_rect.position.x,room_rect.end.y-depth),Vector2(room_rect.size.x,depth)),Color(0,0,0,0.14))
	draw_rect(Rect2(room_rect.position,Vector2(depth,room_rect.size.y)),Color(0,0,0,0.12))
	draw_rect(Rect2(Vector2(room_rect.end.x-depth,room_rect.position.y),Vector2(depth,room_rect.size.y)),Color(0,0,0,0.12))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU*float(i)/24.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)
