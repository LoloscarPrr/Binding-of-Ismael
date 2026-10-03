extends Control
class_name IsmaelEditableBombButton

signal activated
signal layout_changed

var _count := 0
var _edit_mode := false
var _touch_id := -1
var _pressed_inside := false
var _drag_offset := Vector2.ZERO
var _edit_touches: Dictionary = {}
var _pinch_initial_distance := 0.0
var _pinch_initial_side := 0.0
var _resize_min_side := 72.0
var _resize_max_side := 170.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()

func set_count(value: int) -> void:
	_count = maxi(0,value)
	queue_redraw()

func set_edit_mode(enabled: bool) -> void:
	_edit_mode = enabled
	_touch_id = -1
	_pressed_inside = false
	_edit_touches.clear()
	_pinch_initial_distance = 0.0
	_pinch_initial_side = 0.0
	queue_redraw()

func configure_edit_size(side: float, minimum_side: float, maximum_side: float) -> void:
	_resize_min_side = maxf(56.0,minimum_side)
	_resize_max_side = maxf(_resize_min_side,maximum_side)
	_apply_side(clampf(side,_resize_min_side,_resize_max_side))

func get_control_side() -> float:
	return size.x

func handle_touch(event: InputEvent) -> bool:
	if _edit_mode:
		return _handle_edit_touch(event)
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position):
			_touch_id = event.index
			_pressed_inside = true
			queue_redraw()
			return true
		elif not event.pressed and event.index == _touch_id:
			var should_activate := _pressed_inside and get_global_rect().has_point(event.position)
			_touch_id = -1
			_pressed_inside = false
			queue_redraw()
			if should_activate:
				activated.emit()
			return true
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_pressed_inside = get_global_rect().has_point(event.position)
		queue_redraw()
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			_pressed_inside = true
			queue_redraw()
			return true
		elif not event.pressed and _pressed_inside:
			var should_activate_mouse := get_global_rect().has_point(event.position)
			_pressed_inside = false
			queue_redraw()
			if should_activate_mouse:
				activated.emit()
			return true
	return false

func _handle_edit_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit_rect := get_global_rect().grow(28.0)
			if _edit_touches.is_empty() and not hit_rect.has_point(event.position):
				return false
			if _edit_touches.size() >= 2:
				return false
			_edit_touches[event.index] = event.position
			if _edit_touches.size() == 1:
				_touch_id = event.index
				_drag_offset = event.position-global_position
			else:
				_begin_pinch()
			return true
		elif _edit_touches.has(event.index):
			_edit_touches.erase(event.index)
			if _edit_touches.is_empty():
				_touch_id = -1
				_pinch_initial_distance = 0.0
				_pinch_initial_side = 0.0
				layout_changed.emit()
			else:
				var ids := _edit_touches.keys()
				_touch_id = int(ids[0])
				var remaining_pos: Vector2 = _edit_touches[_touch_id]
				_drag_offset = remaining_pos-global_position
				_pinch_initial_distance = 0.0
			return true
	elif event is InputEventScreenDrag and _edit_touches.has(event.index):
		_edit_touches[event.index] = event.position
		if _edit_touches.size() >= 2:
			_update_pinch()
		else:
			_update_edit_drag(event.position)
		return true
	return false

func _begin_pinch() -> void:
	var ids := _edit_touches.keys()
	if ids.size() < 2:
		return
	var p0: Vector2 = _edit_touches[int(ids[0])]
	var p1: Vector2 = _edit_touches[int(ids[1])]
	_pinch_initial_distance = maxf(1.0,p0.distance_to(p1))
	_pinch_initial_side = size.x

func _update_pinch() -> void:
	var ids := _edit_touches.keys()
	if ids.size() < 2:
		return
	var p0: Vector2 = _edit_touches[int(ids[0])]
	var p1: Vector2 = _edit_touches[int(ids[1])]
	if _pinch_initial_distance <= 0.0 or _pinch_initial_side <= 0.0:
		_begin_pinch()
	var distance := maxf(1.0,p0.distance_to(p1))
	var scale_factor := distance/_pinch_initial_distance
	var midpoint := (p0+p1)*0.5
	_apply_side(clampf(_pinch_initial_side*scale_factor,_resize_min_side,_resize_max_side))
	_set_center_inside_viewport(midpoint)

func _update_edit_drag(pointer: Vector2) -> void:
	var screen_size := get_viewport_rect().size
	var new_pos := pointer-_drag_offset
	new_pos.x = clampf(new_pos.x,0.0,maxf(0.0,screen_size.x-size.x))
	new_pos.y = clampf(new_pos.y,0.0,maxf(0.0,screen_size.y-size.y))
	position = new_pos
	queue_redraw()

func _apply_side(side: float) -> void:
	var center := position+size*0.5
	size = Vector2(side,side)
	position = center-size*0.5
	queue_redraw()

func _set_center_inside_viewport(center: Vector2) -> void:
	var screen_size := get_viewport_rect().size
	var pos := center-size*0.5
	pos.x = clampf(pos.x,0.0,maxf(0.0,screen_size.x-size.x))
	pos.y = clampf(pos.y,0.0,maxf(0.0,screen_size.y-size.y))
	position = pos
	queue_redraw()

func _draw() -> void:
	var center := size*0.5
	var radius := size.x*0.42
	var pressed_alpha := 0.92 if _pressed_inside else 0.72
	draw_circle(center+Vector2(0,5),radius+7.0,Color(0.0,0.0,0.0,0.24))
	draw_circle(center,radius,Color(0.16,0.12,0.09,pressed_alpha))
	draw_arc(center,radius,0.0,TAU,48,Color(0.82,0.58,0.24,0.78),3.0)
	var bomb_center := center+Vector2(0,-4)
	draw_circle(bomb_center,size.x*0.16,Color(0.06,0.065,0.075,0.98))
	draw_arc(bomb_center,size.x*0.16,0.0,TAU,28,Color(0.50,0.52,0.56,0.85),2.0)
	draw_line(bomb_center+Vector2(size.x*0.10,-size.x*0.11),bomb_center+Vector2(size.x*0.18,-size.x*0.22),Color(0.52,0.32,0.13),maxf(2.0,size.x*0.035))
	draw_circle(bomb_center+Vector2(size.x*0.20,-size.x*0.24),maxf(3.0,size.x*0.035),Color(0.96,0.42,0.08,0.96))
	var font := ThemeDB.fallback_font
	var font_size := maxi(11,int(round(size.x*0.14)))
	var count_text := "%02d" % _count
	draw_string(font,Vector2(4.0,size.y-8.0),count_text,HORIZONTAL_ALIGNMENT_CENTER,size.x-8.0,font_size,Color(0.98,0.88,0.62))
	if _edit_mode:
		draw_arc(center,radius+10.0,0.0,TAU,48,Color(1.0,0.76,0.32,0.82),4.0)
		draw_line(center+Vector2(-18,0),center+Vector2(18,0),Color(1.0,0.76,0.32,0.50),2.0)
		draw_line(center+Vector2(0,-18),center+Vector2(0,18),Color(1.0,0.76,0.32,0.50),2.0)
