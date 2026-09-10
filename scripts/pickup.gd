extends Area2D
class_name IsmaelPickup

signal collected(kind: String)

var kind := "coin"

func configure(kind_value: String) -> void:
	kind = kind_value
	queue_redraw()

func _ready() -> void:
	add_to_group("room_pickups")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	collision.shape = circle
	add_child(collision)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is IsmaelPlayer:
		collected.emit(kind)
		queue_free()

func _draw() -> void:
	match kind:
		"heart":
			draw_circle(Vector2(-7, -3), 9.0, Color(0.78, 0.08, 0.10))
			draw_circle(Vector2(7, -3), 9.0, Color(0.78, 0.08, 0.10))
			var points := PackedVector2Array([Vector2(-15, 1), Vector2(15, 1), Vector2(0, 20)])
			draw_colored_polygon(points, Color(0.78, 0.08, 0.10))
		"key":
			draw_circle(Vector2(-7, 0), 9.0, Color(0.83, 0.76, 0.45), false, 5.0)
			draw_line(Vector2(1, 0), Vector2(18, 0), Color(0.83, 0.76, 0.45), 6.0)
			draw_line(Vector2(12, 0), Vector2(12, 8), Color(0.83, 0.76, 0.45), 5.0)
		"bomb":
			draw_circle(Vector2.ZERO, 14.0, Color(0.12, 0.12, 0.14))
			draw_line(Vector2(8, -11), Vector2(15, -20), Color(0.52, 0.36, 0.18), 4.0)
		"coin":
			draw_circle(Vector2.ZERO, 14.0, Color(0.88, 0.66, 0.14))
			draw_circle(Vector2.ZERO, 8.0, Color(0.72, 0.48, 0.08), false, 3.0)
