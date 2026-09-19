extends Control
class_name VirtualStick

@export var stick_radius := 108.0
@export var knob_radius := 47.0
@export var deadzone := 0.10
@export var response_curve := 1.0
@export var smoothing_speed := 34.0
@export var floating_origin := false

var value := Vector2.ZERO
var _target_value := Vector2.ZERO
var _touch_id := -1
var _default_center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_default_center = size * 0.5
	set_process(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_default_center = size * 0.5
		queue_redraw()

func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * delta)
	value = value.lerp(_target_value, weight)
	if value.length() < 0.01 and _target_value == Vector2.ZERO:
		value = Vector2.ZERO
	queue_redraw()

func handle_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position):
			_touch_id = event.index
			_update_target(event.position)
			return true
		elif not event.pressed and event.index == _touch_id:
			reset()
			return true
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_update_target(event.position)
		return true
	return false

func reset() -> void:
	_touch_id = -1
	_target_value = Vector2.ZERO
	queue_redraw()

func _update_target(global_pos: Vector2) -> void:
	var local_pos := global_pos - global_position
	var offset := local_pos - _default_center
	var axis_threshold := maxf(18.0, stick_radius * 0.14)
	var x := 0.0
	var y := 0.0
	if offset.x > axis_threshold:
		x = 1.0
	elif offset.x < -axis_threshold:
		x = -1.0
	if offset.y > axis_threshold:
		y = 1.0
	elif offset.y < -axis_threshold:
		y = -1.0
	var next := Vector2(x, y)
	_target_value = next.normalized() if next.length_squared() > 0.0 else Vector2.ZERO

func _draw() -> void:
	var center := size * 0.5
	var button_size := maxf(72.0, stick_radius * 0.72)
	var spacing := maxf(62.0, stick_radius * 0.58)
	var plate_radius := stick_radius * 0.96
	draw_circle(center + Vector2(0, 5), plate_radius, Color(0.015,0.018,0.022,0.18))
	draw_arc(center, plate_radius, 0.0, TAU, 48, Color(0.78,0.82,0.86,0.065), 2.0)
	_draw_arrow_button(center, Vector2.UP, Vector2(0,-spacing), button_size, _target_value.y < -0.2)
	_draw_arrow_button(center, Vector2.DOWN, Vector2(0,spacing), button_size, _target_value.y > 0.2)
	_draw_arrow_button(center, Vector2.LEFT, Vector2(-spacing,0), button_size, _target_value.x < -0.2)
	_draw_arrow_button(center, Vector2.RIGHT, Vector2(spacing,0), button_size, _target_value.x > 0.2)
	var core := button_size * 0.40
	draw_rect(Rect2(center-Vector2(core,core)*0.5+Vector2(0,4),Vector2(core,core)),Color(0.02,0.025,0.03,0.28))
	draw_rect(Rect2(center-Vector2(core,core)*0.5,Vector2(core,core)),Color(0.10,0.11,0.12,0.38))
	draw_rect(Rect2(center-Vector2(core,core)*0.5,Vector2(core,core)),Color(0.74,0.77,0.79,0.09),false,2.0)

func _draw_arrow_button(center: Vector2, direction: Vector2, offset: Vector2, button_size: float, active: bool) -> void:
	var c := center + offset
	var half := button_size * 0.5
	var shadow_rect := Rect2(c-Vector2(half,half)+Vector2(0,5),Vector2(button_size,button_size))
	var rect := Rect2(c-Vector2(half,half),Vector2(button_size,button_size))
	draw_rect(shadow_rect,Color(0.005,0.008,0.012,0.26))
	var fill := Color(0.20,0.22,0.24,0.42) if not active else Color(0.48,0.50,0.51,0.76)
	var rim := Color(0.82,0.84,0.84,0.13) if not active else Color(0.98,0.91,0.72,0.48)
	draw_rect(rect,fill)
	draw_rect(rect,rim,false,2.5)
	var perp := Vector2(-direction.y,direction.x)
	var tip := c + direction * button_size * 0.25
	var back := c - direction * button_size * 0.16
	var arrow := PackedVector2Array([
		tip,
		back + perp * button_size * 0.19,
		back + perp * button_size * 0.07,
		c - direction * button_size * 0.28 + perp * button_size * 0.07,
		c - direction * button_size * 0.28 - perp * button_size * 0.07,
		back - perp * button_size * 0.07,
		back - perp * button_size * 0.19
	])
	draw_colored_polygon(arrow,Color(0.94,0.94,0.91,0.38 if not active else 0.90))
