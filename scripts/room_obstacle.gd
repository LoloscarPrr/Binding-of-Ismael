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
	var shadow := rect.grow(7.0)
	shadow.position += Vector2(5.0, 8.0)
	var fill := Color(0.24, 0.20, 0.17)
	var rim := Color(0.43, 0.35, 0.28)
	var highlight := Color(0.53, 0.44, 0.35)
	if variant == 1:
		fill = Color(0.19, 0.21, 0.22)
		rim = Color(0.34, 0.39, 0.41)
		highlight = Color(0.46, 0.51, 0.52)
	elif variant == 2:
		fill = Color(0.25, 0.12, 0.11)
		rim = Color(0.45, 0.20, 0.17)
		highlight = Color(0.58, 0.29, 0.23)
	draw_rect(shadow, Color(0.035, 0.025, 0.022, 0.62))
	draw_rect(rect, fill)
	draw_rect(rect, rim, false, 6.0)
	var inner := rect.grow(-8.0)
	draw_line(inner.position, Vector2(inner.end.x, inner.position.y), highlight, 3.0)
	var crack := obstacle_size * 0.22
	draw_line(Vector2(-crack.x, -crack.y), Vector2(-4.0, -2.0), rim, 4.0)
	draw_line(Vector2(-4.0, -2.0), Vector2(crack.x * 0.42, crack.y * 0.18), rim, 4.0)
	draw_line(Vector2(crack.x * 0.42, crack.y * 0.18), Vector2(crack.x, -crack.y * 0.45), rim, 3.0)
	if obstacle_size.x > 150.0:
		draw_line(Vector2(-obstacle_size.x * 0.18, rect.position.y + 5.0), Vector2(-obstacle_size.x * 0.18, rect.end.y - 5.0), Color(rim, 0.7), 2.0)
		draw_line(Vector2(obstacle_size.x * 0.20, rect.position.y + 5.0), Vector2(obstacle_size.x * 0.20, rect.end.y - 5.0), Color(rim, 0.7), 2.0)
