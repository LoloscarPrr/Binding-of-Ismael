extends StaticBody2D
class_name IsmaelRoomDoor

var door_size := Vector2(126.0,42.0)
var is_open := false
var _collision: CollisionShape2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	_collision = CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = door_size
	_collision.shape = rectangle
	add_child(_collision)
	_apply_state()
	queue_redraw()

func set_open(value: bool) -> void:
	is_open = value
	_apply_state()
	queue_redraw()

func _apply_state() -> void:
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled",is_open)

func _draw() -> void:
	var half_w := door_size.x*0.5
	var half_h := door_size.y*0.5
	var stone_dark := Color(0.075,0.052,0.043)
	var stone_mid := Color(0.25,0.18,0.13)
	var stone_light := Color(0.46,0.33,0.21)
	var wood_dark := Color(0.075,0.032,0.018)
	var wood_mid := Color(0.27,0.105,0.045)
	draw_rect(Rect2(-half_w-24,-half_h-26,door_size.x+48,door_size.y+36),Color(0,0,0,0.46))
	draw_arc(Vector2(0,-half_h+1),half_w+18.0,PI,TAU,40,stone_dark,14.0)
	draw_arc(Vector2(0,-half_h+1),half_w+13.0,PI,TAU,40,stone_mid,7.0)
	draw_rect(Rect2(-half_w-18,-half_h-17,door_size.x+36,18),stone_dark)
	draw_rect(Rect2(-half_w-14,-half_h-13,door_size.x+28,11),stone_mid)
	draw_line(Vector2(-half_w-11,-half_h-11),Vector2(half_w+11,-half_h-11),stone_light,2.0)
	for x in [-half_w-18.0,half_w+4.0]:
		draw_rect(Rect2(x,-half_h-7,14,door_size.y+22),stone_dark)
		draw_rect(Rect2(x+3,-half_h-3,8,door_size.y+14),stone_mid)
	if is_open:
		draw_rect(Rect2(-half_w+1,-half_h,door_size.x-2,door_size.y+7),Color(0.004,0.004,0.005))
		draw_rect(Rect2(-half_w+8,half_h-8,door_size.x-16,8),Color(0.45,0.30,0.16,0.78))
		draw_line(Vector2(-half_w+10,half_h-10),Vector2(half_w-10,half_h-10),Color(0.95,0.69,0.28,0.28),3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-half_w+12,half_h-7),Vector2(half_w-12,half_h-7),Vector2(half_w-28,half_h+20),Vector2(-half_w+28,half_h+20)]),Color(0.64,0.38,0.12,0.09))
		return
	var rect := Rect2(-half_w+2,-half_h+1,door_size.x-4,door_size.y-2)
	draw_rect(rect,wood_dark)
	draw_rect(Rect2(rect.position+Vector2(5,4),rect.size-Vector2(10,8)),wood_mid)
	for x in [-34.0,0.0,34.0]:
		draw_line(Vector2(x,-half_h+5),Vector2(x,half_h-5),Color(0.055,0.025,0.015),3.0)
	draw_line(Vector2(-half_w+8,-7),Vector2(half_w-8,-7),Color(0.08,0.06,0.05),6.0)
	draw_line(Vector2(-half_w+8,8),Vector2(half_w-8,8),Color(0.08,0.06,0.05),5.0)
	for x in [-48.0,-16.0,16.0,48.0]:
		draw_circle(Vector2(x,-7),3.2,Color(0.44,0.34,0.22))
	draw_circle(Vector2(29,2),6.5,Color(0.60,0.43,0.16))
	draw_circle(Vector2(29,2),2.2,Color(0.10,0.05,0.025))
