extends Control
class_name VirtualStick

signal layout_changed

@export var stick_radius := 108.0
@export var knob_radius := 47.0
@export var deadzone := 0.08
@export var response_curve := 1.15
@export var smoothing_speed := 22.0
@export var floating_origin := false

var value := Vector2.ZERO
var _target_value := Vector2.ZERO
var _touch_id := -1
var _default_center := Vector2.ZERO
var _edit_mode := false
var _drag_offset := Vector2.ZERO
var _edit_center_bounds := Rect2()

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
	if _edit_mode:
		value = Vector2.ZERO
		_target_value = Vector2.ZERO
		return
	var weight := 1.0 - exp(-smoothing_speed * delta)
	value = value.lerp(_target_value, weight)
	if value.length() < 0.006 and _target_value == Vector2.ZERO:
		value = Vector2.ZERO
	queue_redraw()

func set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	reset()
	queue_redraw()

func set_edit_center_bounds(bounds: Rect2) -> void:
	_edit_center_bounds = bounds

func handle_touch(event: InputEvent) -> bool:
	if _edit_mode:
		return _handle_edit_touch(event)
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

func _handle_edit_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position):
			_touch_id = event.index
			_drag_offset = event.position - global_position
			return true
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			layout_changed.emit()
			return true
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var screen_size := get_viewport_rect().size
		var new_pos: Vector2 = event.position - _drag_offset
		var new_center := new_pos+size*0.5
		if _edit_center_bounds.size.x > 0.0 and _edit_center_bounds.size.y > 0.0:
			new_center.x = clampf(new_center.x,_edit_center_bounds.position.x,_edit_center_bounds.end.x)
			new_center.y = clampf(new_center.y,_edit_center_bounds.position.y,_edit_center_bounds.end.y)
			new_pos = new_center-size*0.5
		new_pos.x = clampf(new_pos.x,0.0,maxf(0.0,screen_size.x-size.x))
		new_pos.y = clampf(new_pos.y,0.0,maxf(0.0,screen_size.y-size.y))
		position = new_pos
		queue_redraw()
		return true
	return false

func reset() -> void:
	_touch_id = -1
	_target_value = Vector2.ZERO
	queue_redraw()

func _update_target(global_pos: Vector2) -> void:
	var local_pos := global_pos - global_position
	var offset := local_pos - _default_center
	var distance := minf(offset.length(), stick_radius)
	if distance <= stick_radius * deadzone:
		_target_value = Vector2.ZERO
		return
	var normalized_distance := (distance / stick_radius - deadzone) / (1.0 - deadzone)
	normalized_distance = clampf(normalized_distance, 0.0, 1.0)
	var curved_distance := pow(normalized_distance, response_curve)
	_target_value = offset.normalized() * curved_distance

func _draw() -> void:
	var center := size * 0.5
	var active_strength := clampf(value.length(), 0.0, 1.0)
	var base_alpha := 0.15 if not _edit_mode else 0.25
	var rim_alpha := 0.18 if not _edit_mode else 0.42
	var knob_alpha := 0.30 + active_strength * 0.22
	draw_circle(center + Vector2(0,5), stick_radius + 8.0, Color(0.0,0.0,0.0,0.18))
	draw_circle(center, stick_radius, Color(0.82,0.84,0.86,base_alpha))
	draw_arc(center, stick_radius, 0.0, TAU, 64, Color(0.92,0.93,0.94,rim_alpha), 3.0)
	draw_circle(center + value * stick_radius, knob_radius + 4.0, Color(0.0,0.0,0.0,0.22))
	draw_circle(center + value * stick_radius, knob_radius, Color(0.92,0.93,0.94,knob_alpha))
	draw_arc(center + value * stick_radius, knob_radius, 0.0, TAU, 48, Color(1.0,1.0,1.0,0.24 + active_strength*0.22), 2.5)
	if _edit_mode:
		draw_arc(center, stick_radius + 15.0, 0.0, TAU, 48, Color(1.0,0.76,0.32,0.62), 4.0)
		draw_line(center + Vector2(-24,0), center + Vector2(24,0), Color(1.0,0.76,0.32,0.46), 2.0)
		draw_line(center + Vector2(0,-24), center + Vector2(0,24), Color(1.0,0.76,0.32,0.46), 2.0)
