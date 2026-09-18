extends StaticBody2D
class_name IsmaelRoomObstacle

var obstacle_size := Vector2(120.0,80.0)
var variant := 0

func configure(size_value: Vector2, variant_value: int = 0) -> void:
	obstacle_size = size_value
	variant = variant_value
	queue_redraw()

func _ready() -> void:
	add_to_group("room_obstacles")
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = obstacle_size
	collision.shape = rectangle
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-obstacle_size*0.5,obstacle_size)
	var fill := Color(0.22,0.18,0.15)
	var rim := Color(0.43,0.33,0.24)
	var highlight := Color(0.58,0.45,0.31)
	if variant==1:
		fill = Color(0.16,0.19,0.20)
		rim = Color(0.31,0.38,0.40)
		highlight = Color(0.48,0.56,0.57)
	elif variant==2:
		fill = Color(0.23,0.085,0.08)
		rim = Color(0.44,0.16,0.13)
		highlight = Color(0.64,0.29,0.22)
	var depth := clampf(obstacle_size.y*0.13,7.0,15.0)
	var shadow := Rect2(rect.position+Vector2(7,depth+7),rect.size)
	draw_rect(shadow,Color(0.01,0.008,0.007,0.50))
	var side := PackedVector2Array([Vector2(rect.end.x,rect.position.y+depth),Vector2(rect.end.x+depth,rect.position.y),Vector2(rect.end.x+depth,rect.end.y-depth),Vector2(rect.end.x,rect.end.y)])
	draw_colored_polygon(side,fill.darkened(0.30))
	var top := PackedVector2Array([rect.position+Vector2(0,depth),rect.position+Vector2(depth,0),Vector2(rect.end.x+depth,rect.position.y),Vector2(rect.end.x,rect.position.y+depth)])
	draw_colored_polygon(top,highlight.darkened(0.12))
	draw_rect(rect,fill)
	draw_rect(rect,rim,false,5.0)
	draw_line(rect.position+Vector2(4,4),Vector2(rect.end.x-4,rect.position.y+4),highlight,3.0)
	draw_line(Vector2(rect.position.x+4,rect.end.y-4),rect.end-Vector2(4,4),rim.darkened(0.32),3.0)
	var crack := obstacle_size*0.22
	draw_line(Vector2(-crack.x,-crack.y),Vector2(-5,-2),rim.darkened(0.18),3.0)
	draw_line(Vector2(-5,-2),Vector2(crack.x*0.42,crack.y*0.18),rim.darkened(0.18),3.0)
	draw_line(Vector2(crack.x*0.42,crack.y*0.18),Vector2(crack.x,-crack.y*0.45),rim.darkened(0.18),2.5)
