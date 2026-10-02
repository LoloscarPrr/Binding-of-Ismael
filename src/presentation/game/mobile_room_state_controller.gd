extends "res://src/presentation/game/mobile_controls_editor_controller.gd"

# Mobile room interaction refinement:
# - completed rooms keep their correct revisit status;
# - room doors sit flush with the combat wall instead of occupying floor space;
# - hidden walls announce themselves, but bombs are only spent by the BOMBA button.

const DOOR_FLUSH_OFFSET := 36.0

var bomb_button: Button
var _bomb_action_armed := false

func _create_touch_ui() -> void:
	super._create_touch_ui()
	var layer := left_stick.get_parent() if is_instance_valid(left_stick) else null
	if layer == null:
		return
	bomb_button = Button.new()
	bomb_button.name = "BombButton"
	bomb_button.text = "BOMBA"
	bomb_button.z_index = 9
	bomb_button.focus_mode = Control.FOCUS_NONE
	bomb_button.pressed.connect(_on_bomb_button_pressed)
	bomb_button.add_theme_font_size_override("font_size",16)
	bomb_button.add_theme_color_override("font_color",Color(0.96,0.84,0.57))
	bomb_button.add_theme_color_override("font_hover_color",Color(1.0,0.91,0.67))
	bomb_button.add_theme_color_override("font_pressed_color",Color(1.0,0.76,0.36))
	bomb_button.add_theme_stylebox_override("normal",_bomb_button_style(Color(0.30,0.20,0.11,0.92),Color(0.67,0.45,0.20,0.84)))
	bomb_button.add_theme_stylebox_override("hover",_bomb_button_style(Color(0.36,0.24,0.12,0.96),Color(0.82,0.57,0.24,0.96)))
	bomb_button.add_theme_stylebox_override("pressed",_bomb_button_style(Color(0.20,0.12,0.065,0.98),Color(0.94,0.64,0.25,1.0)))
	layer.add_child(bomb_button)
	_refresh_bomb_button()

func _bomb_button_style(background: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(bomb_button):
		return
	var screen_size := get_viewport_rect().size
	var available_left := maxf(104.0,room_rect.position.x-28.0)
	var button_w := clampf(available_left,104.0,150.0)
	bomb_button.size = Vector2(button_w,42.0)
	bomb_button.position = Vector2(14.0,10.0)
	bomb_button.visible = not _run_complete and not _game_over
	_refresh_bomb_button()

func _update_pickup_hud() -> void:
	super._update_pickup_hud()
	_refresh_bomb_button()

func _refresh_bomb_button() -> void:
	if not is_instance_valid(bomb_button):
		return
	bomb_button.text = "BOMBA  %02d" % maxi(0,_bombs)

func _on_bomb_button_pressed() -> void:
	if _game_over or _run_complete or not is_instance_valid(player):
		return
	if not _room_cleared:
		status_label.text = "AÚN HAY PELIGRO EN LA SALA"
		reward_label.text = "Las paredes secretas se abren cuando la sala está despejada"
		return
	var direction := _detect_hidden_wall_direction()
	if direction == Vector2i.ZERO:
		status_label.text = "ACÉRCATE A UNA PARED SOSPECHOSA"
		reward_label.text = "No se consumió ninguna bomba"
		return
	_bomb_action_armed = true
	_try_reveal_hidden_room(direction)
	_bomb_action_armed = false
	_refresh_bomb_button()

# The inherited physics loop still detects proximity to a hidden wall. We
# intercept that call so detection only shows the clue; spending a bomb is
# allowed exclusively while the explicit BOMBA action is armed.
func _try_reveal_hidden_room(direction: Vector2i) -> void:
	if not _bomb_action_armed:
		if direction != Vector2i.ZERO:
			status_label.text = "PARED SOSPECHOSA"
			reward_label.text = "Usa el botón BOMBA para abrirla"
		return
	super._try_reveal_hidden_room(direction)

# Doors are moved outward until the innermost part of their stone frame is
# aligned with room_rect. Their collision no longer protrudes into the combat
# floor, so enemies can move cleanly along the wall beside a doorway.
func _create_room_door(direction: Vector2i) -> void:
	if _doors.has(direction):
		return
	var door := IsmaelRoomDoor.new()
	var center := room_rect.get_center()
	if direction == Vector2i(0,-1):
		door.position = Vector2(center.x,room_rect.position.y-DOOR_FLUSH_OFFSET)
		door.rotation = 0.0
	elif direction == Vector2i(0,1):
		door.position = Vector2(center.x,room_rect.end.y+DOOR_FLUSH_OFFSET)
		door.rotation = PI
	elif direction == Vector2i(-1,0):
		door.position = Vector2(room_rect.position.x-DOOR_FLUSH_OFFSET,center.y)
		door.rotation = -PI*0.5
	else:
		door.position = Vector2(room_rect.end.x+DOOR_FLUSH_OFFSET,center.y)
		door.rotation = PI*0.5
	var destination := _current_cell+direction
	if _dungeon.has_room(destination) and _dungeon.is_hidden(destination):
		door.modulate = Color(0.62,0.47,0.30,0.90)
	door.set_open(_room_cleared)
	add_child(door)
	_doors[direction] = door

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	super._begin_room(entry_direction)
	_refresh_completed_room_status()
	_refresh_bomb_button()

func _refresh_completed_room_status() -> void:
	if not _room_cleared or not is_instance_valid(status_label):
		return
	match _room_kind:
		"combate":
			status_label.text = "SALA LIMPIA"
		"emboscada":
			status_label.text = "EMBOSCADA SUPERADA"
		"desafio":
			status_label.text = "DESAFÍO SUPERADO"
		"minijefe":
			status_label.text = "GUARDIÁN MENOR DERROTADO"
		"jefe":
			status_label.text = "GUARDIÁN DERROTADO — ENCUENTRA LA SALIDA"
