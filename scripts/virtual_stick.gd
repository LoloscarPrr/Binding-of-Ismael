extends Control
class_name VirtualStick

@export var stick_radius := 108.0
@export var knob_radius := 47.0
@export var deadzone := 0.08
@export var response_curve := 1.35
@export var smoothing_speed := 18.0
@export var floating_origin := true

var value := Vector2.ZERO
var _target_value := Vector2.ZERO
var _touch_id := -1
var _default_center := Vector2.ZERO
var _active_center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_default_center = size * 0.5
	_active_center = _default_center
	set_process(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_default_center = size * 0.5
		if _touch_id == -1:
			_active_center = _default_center
		queue_redraw()

func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * delta)
	value = value.lerp(_target_value, weight)
	if value.length() < 0.006 and _target_value == Vector2.ZERO:
		value = Vector2.ZERO
	queue_redraw()

func handle_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position):
			_touch_id = event.index
			if floating_origin:
				_active_center = _clamp_origin(event.position - global_position)
			else:
				_active_center = _default_center
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
	_active_center = _default_center
	queue_redraw()

func _clamp_origin(local_pos: Vector2) -> Vector2:
	var padding := stick_radius + 8.0
	return Vector2(
		clampf(local_pos.x, padding, maxf(padding, size.x - padding)),
		clampf(local_pos.y, padding, maxf(padding, size.y - padding))
	)

func _update_target(global_pos: Vector2) -> void:
	var local_pos := global_pos - global_position
	var offset := local_pos - _active_center
	var distance := minf(offset.length(), stick_radius)
	if distance <= stick_radius * deadzone:
		_target_value = Vector2.ZERO
		return
	var normalized_distance := (distance / stick_radius - deadzone) / (1.0 - deadzone)
	normalized_distance = clampf(normalized_distance, 0.0, 1.0)
	var curved_distance := pow(normalized_distance, response_curve)
	_target_value = offset.normalized() * curved_distance

func _draw() -> void:
	var base_color := Color(1, 1, 1, 0.11)
	var rim_color := Color(1, 1, 1, 0.26)
	var knob_color := Color(1, 1, 1, 0.38)
	draw_circle(_active_center, stick_radius, base_color)
	draw_arc(_active_center, stick_radius, 0.0, TAU, 64, rim_color, 3.0)
	draw_circle(_active_center + value * stick_radius, knob_radius, knob_color)
