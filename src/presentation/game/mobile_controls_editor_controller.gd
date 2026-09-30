extends "res://src/presentation/game/mobile_main_controller.gd"

# Presentation-only control customization layer.
# Keeps gameplay and domain/application logic untouched while allowing each
# virtual stick to have an independent position and size on mobile.

var _saved_left_size_ratio := -1.0
var _saved_right_size_ratio := -1.0

func _create_touch_ui() -> void:
	super._create_touch_ui()
	if is_instance_valid(control_edit_button):
		control_edit_button.text = "EDITAR CONTROLES"
		control_edit_button.add_theme_font_size_override("font_size",14)

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(left_stick) or not is_instance_valid(right_stick):
		return
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return

	var short_side := minf(screen_size.x,screen_size.y)
	var default_side := clampf(short_side*0.31,220.0,270.0)
	var minimum_side := clampf(short_side*0.15,120.0,165.0)
	var maximum_side := clampf(short_side*0.44,320.0,420.0)

	var left_center := left_stick.position+left_stick.size*0.5
	var right_center := right_stick.position+right_stick.size*0.5
	var left_side := _resolved_stick_side(_saved_left_size_ratio,default_side,short_side,minimum_side,maximum_side)
	var right_side := _resolved_stick_side(_saved_right_size_ratio,default_side,short_side,minimum_side,maximum_side)

	left_stick.configure_edit_size(left_side,minimum_side,maximum_side)
	right_stick.configure_edit_size(right_side,minimum_side,maximum_side)
	left_stick.set_edit_center_bounds(Rect2())
	right_stick.set_edit_center_bounds(Rect2())

	left_stick.position = _position_inside_viewport(left_center,left_stick.size,screen_size)
	right_stick.position = _position_inside_viewport(right_center,right_stick.size,screen_size)

	# Keep the edit action readable without moving any of the HUD composition.
	if is_instance_valid(control_edit_button):
		control_edit_button.text = "GUARDAR" if _editing_controls else "EDITAR CONTROLES"
		control_edit_button.add_theme_font_size_override("font_size",14)

func _resolved_stick_side(
	ratio: float,
	default_side: float,
	short_side: float,
	minimum_side: float,
	maximum_side: float
) -> float:
	if ratio <= 0.0:
		return default_side
	return clampf(ratio*short_side,minimum_side,maximum_side)

func _position_inside_viewport(center: Vector2, control_size: Vector2, screen_size: Vector2) -> Vector2:
	var pos := center-control_size*0.5
	pos.x = clampf(pos.x,0.0,maxf(0.0,screen_size.x-control_size.x))
	pos.y = clampf(pos.y,0.0,maxf(0.0,screen_size.y-control_size.y))
	return pos

func _toggle_control_edit_mode() -> void:
	_editing_controls = not _editing_controls
	left_stick.set_edit_mode(_editing_controls)
	right_stick.set_edit_mode(_editing_controls)
	control_edit_button.text = "GUARDAR" if _editing_controls else "EDITAR CONTROLES"
	if _editing_controls:
		status_label.text = "ARRASTRA LOS STICKS · PELLIZCA PARA CAMBIAR TAMAÑO"
		reward_label.text = "Cada stick se puede mover y redimensionar de forma independiente"
	else:
		_store_control_centers()
		_capture_stick_size_ratios()
		_save_control_layout()
		status_label.text = "CONTROLES GUARDADOS"
		reward_label.text = ""

func _on_control_layout_changed() -> void:
	if not _editing_controls:
		return
	_store_control_centers()
	_capture_stick_size_ratios()
	_save_control_layout()

func _capture_stick_size_ratios() -> void:
	var screen_size := get_viewport_rect().size
	var short_side := minf(screen_size.x,screen_size.y)
	if short_side <= 1.0:
		return
	if is_instance_valid(left_stick):
		_saved_left_size_ratio = left_stick.get_control_side()/short_side
	if is_instance_valid(right_stick):
		_saved_right_size_ratio = right_stick.get_control_side()/short_side

func _save_control_layout() -> void:
	_capture_stick_size_ratios()
	_control_layout_repository.save_layout(
		_saved_left_center,
		_saved_right_center,
		_saved_left_size_ratio,
		_saved_right_size_ratio
	)

func _load_control_layout() -> void:
	var stored := _control_layout_repository.load_layout()
	_saved_left_center = stored.get("left_center",Vector2(-1.0,-1.0))
	_saved_right_center = stored.get("right_center",Vector2(-1.0,-1.0))
	_saved_left_size_ratio = float(stored.get("left_size_ratio",-1.0))
	_saved_right_size_ratio = float(stored.get("right_size_ratio",-1.0))
