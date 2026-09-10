extends StaticBody2D
class_name IsmaelRoomDoor

var door_size := Vector2(126.0, 42.0)
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
		_collision.set_deferred("disabled", is_open)

func _draw() -> void:
	var half_w := door_size.x * 0.5
	var half_h := door_size.y * 0.5
	var stone_dark := Color(0.12, 0.085, 0.065)
	var stone_mid := Color(0.28, 0.21, 0.16)
	var stone_light := Color(0.43, 0.34, 0.25)
	var wood_dark := Color(0.11, 0.055, 0.03)
	var wood_mid := Color(0.28, 0.13, 0.065)
	# Heavy stone lintel and side blocks, visually embedded into the room wall.
	draw_rect(Rect2(-half_w - 15.0, -half_h - 14.0, door_size.x + 30.0, 15.0), stone_dark)
	draw_rect(Rect2(-half_w - 11.0, -half_h - 11.0, door_size.x + 22.0, 10.0), stone_mid)
	for x in [-half_w - 15.0, half_w + 1.0]:
		draw_rect(Rect2(x, -half_h - 4.0, 14.0, door_size.y + 17.0), stone_dark)
		draw_rect(Rect2(x + 3.0, -half_h, 8.0, door_size.y + 10.0), stone_mid)
		draw_line(Vector2(x + 3.0, -half_h + 4.0), Vector2(x + 11.0, -half_h + 4.0), stone_light, 2.0)
	if is_open:
		# Black passage with a lit threshold; no center collision.
		draw_rect(Rect2(-half_w + 2.0, -half_h + 1.0, door_size.x - 4.0, door_size.y - 2.0), Color(0.018, 0.014, 0.012))
		draw_rect(Rect2(-half_w + 8.0, half_h - 6.0, door_size.x - 16.0, 6.0), Color(0.34, 0.27, 0.19, 0.75))
		draw_line(Vector2(-half_w + 9.0, half_h - 7.0), Vector2(half_w - 9.0, half_h - 7.0), Color(0.56, 0.44, 0.29, 0.45), 2.0)
		return
	# Closed wooden slab with iron braces.
	var rect := Rect2(-half_w + 2.0, -half_h + 1.0, door_size.x - 4.0, door_size.y - 2.0)
	draw_rect(rect, wood_dark)
	draw_rect(Rect2(rect.position + Vector2(5.0, 4.0), rect.size - Vector2(10.0, 8.0)), wood_mid)
	for x in [-34.0, 0.0, 34.0]:
		draw_line(Vector2(x, -half_h + 5.0), Vector2(x, half_h - 5.0), Color(0.08, 0.04, 0.025), 3.0)
	draw_line(Vector2(-half_w + 8.0, -6.0), Vector2(half_w - 8.0, -6.0), Color(0.08, 0.06, 0.05), 5.0)
	draw_circle(Vector2(28.0, 2.0), 6.0, Color(0.55, 0.40, 0.18))
	draw_circle(Vector2(28.0, 2.0), 2.0, Color(0.12, 0.07, 0.03))
