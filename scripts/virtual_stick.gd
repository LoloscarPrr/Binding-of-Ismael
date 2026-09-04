extends Control
class_name VirtualStick

@export var stick_radius := 92.0
@export var knob_radius := 40.0
@export var deadzone := 0.16

var value := Vector2.ZERO
var _touch_id := -1
var _center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center = size * 0.5
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5
		queue_redraw()

func handle_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position):
			_touch_id = event.index
			_update_value(event.position)
			return true
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			value = Vector2.ZERO
			queue_redraw()
			return true
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_update_value(event.position)
		return true
	return false

func _update_value(global_pos: Vector2) -> void:
	var local_pos := global_pos - global_position
	var offset := local_pos - _center
	if offset.length() > stick_radius:
		offset = offset.normalized() * stick_radius
	value = offset / stick_radius
	if value.length() < deadzone:
		value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var base_color := Color(1, 1, 1, 0.16)
	var rim_color := Color(1, 1, 1, 0.32)
	var knob_color := Color(1, 1, 1, 0.42)
	draw_circle(_center, stick_radius, base_color)
	draw_arc(_center, stick_radius, 0.0, TAU, 64, rim_color, 3.0)
	draw_circle(_center + value * stick_radius, knob_radius, knob_color)
