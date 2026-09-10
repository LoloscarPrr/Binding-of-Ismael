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
	var rim := Color(0.38, 0.28, 0.20)
	if is_open:
		# Open door is drawn as two side posts, leaving a clear frontal passage.
		var post_w := 18.0
		draw_rect(Rect2(Vector2(-half_w, -half_h), Vector2(post_w, door_size.y)), Color(0.10, 0.07, 0.055))
		draw_rect(Rect2(Vector2(half_w - post_w, -half_h), Vector2(post_w, door_size.y)), Color(0.10, 0.07, 0.055))
		draw_line(Vector2(-half_w, -half_h), Vector2(-half_w + post_w, -half_h), Color(0.18, 0.60, 0.30), 5.0)
		draw_line(Vector2(half_w - post_w, -half_h), Vector2(half_w, -half_h), Color(0.18, 0.60, 0.30), 5.0)
		return
	var rect := Rect2(-door_size * 0.5, door_size)
	draw_rect(rect, Color(0.08, 0.055, 0.045))
	draw_rect(rect, rim, false, 6.0)
	draw_circle(Vector2(0, 3), 7.0, Color(0.58, 0.46, 0.24))
