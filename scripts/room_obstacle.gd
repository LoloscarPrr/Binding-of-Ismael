extends StaticBody2D
class_name IsmaelRoomObstacle

var obstacle_size := Vector2(120.0, 80.0)
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
	var rect := Rect2(-obstacle_size * 0.5, obstacle_size)
	var fill := Color(0.28, 0.24, 0.20)
	var rim := Color(0.46, 0.38, 0.30)
	if variant == 1:
		fill = Color(0.23, 0.25, 0.27)
		rim = Color(0.40, 0.46, 0.50)
	elif variant == 2:
		fill = Color(0.30, 0.16, 0.14)
		rim = Color(0.52, 0.24, 0.20)
	draw_rect(rect, fill)
	draw_rect(rect, rim, false, 5.0)
	var crack := obstacle_size * 0.22
	draw_line(Vector2(-crack.x, -crack.y), Vector2(0.0, 0.0), rim, 3.0)
	draw_line(Vector2(0.0, 0.0), Vector2(crack.x, -crack.y * 0.45), rim, 3.0)
