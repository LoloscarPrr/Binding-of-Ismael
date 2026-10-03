extends "res://src/presentation/game/mobile_controls_editor_controller.gd"

const EditableBombButton = preload("res://scripts/editable_bomb_button.gd")
const PlacedBomb = preload("res://scripts/placed_bomb.gd")
const DOOR_FLUSH_OFFSET := 36.0

var bomb_button: IsmaelEditableBombButton
var _saved_bomb_center_ratio := Vector2(-1.0,-1.0)
var _saved_bomb_size_ratio := -1.0

func _load_control_layout() -> void:
	super._load_control_layout()
	var stored := _control_layout_repository.load_layout()
	_saved_bomb_center_ratio = stored.get("bomb_center_ratio",Vector2(-1.0,-1.0))
	_saved_bomb_size_ratio = float(stored.get("bomb_size_ratio",-1.0))

func _create_touch_ui() -> void:
	super._create_touch_ui()
	var layer := left_stick.get_parent() if is_instance_valid(left_stick) else null
	if layer == null:
		return
	bomb_button = EditableBombButton.new()
	bomb_button.name = "BombButton"
	bomb_button.z_index = 9
	bomb_button.activated.connect(_on_bomb_button_pressed)
	bomb_button.layout_changed.connect(_on_bomb_layout_changed)
	layer.add_child(bomb_button)
	_refresh_bomb_button()

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(bomb_button):
		return
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return
	var short_side := minf(screen_size.x,screen_size.y)
	var default_side := clampf(short_side*0.13,88.0,108.0)
	var minimum_side := clampf(short_side*0.085,64.0,78.0)
	var maximum_side := clampf(short_side*0.22,138.0,170.0)
	var resolved_side := default_side
	if _saved_bomb_size_ratio > 0.0:
		resolved_side = clampf(_saved_bomb_size_ratio*short_side,minimum_side,maximum_side)
	bomb_button.configure_edit_size(resolved_side,minimum_side,maximum_side)

	var center := Vector2.ZERO
	if _has_saved_bomb_center():
		center = Vector2(
			_saved_bomb_center_ratio.x*screen_size.x,
			_saved_bomb_center_ratio.y*screen_size.y
		)
	else:
		var right_center := right_stick.position+right_stick.size*0.5
		center = Vector2(right_stick.position.x-resolved_side*0.58,right_center.y)
	bomb_button.position = _position_inside_viewport(center,bomb_button.size,screen_size)
	bomb_button.visible = not _run_complete and not _game_over
	bomb_button.set_edit_mode(_editing_controls)
	_refresh_bomb_button()

func _input(event: InputEvent) -> void:
	if is_instance_valid(bomb_button) and bomb_button.visible:
		if bomb_button.handle_touch(event):
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _toggle_control_edit_mode() -> void:
	super._toggle_control_edit_mode()
	if is_instance_valid(bomb_button):
		bomb_button.set_edit_mode(_editing_controls)
	if _editing_controls:
		status_label.text = "EDITA STICKS Y BOMBA"
		reward_label.text = "Arrastra libremente · pellizca para cambiar tamaño"
	else:
		_capture_bomb_layout()
		_save_bomb_layout()
		status_label.text = "CONTROLES GUARDADOS"
		reward_label.text = ""

func _on_bomb_layout_changed() -> void:
	if not _editing_controls:
		return
	_capture_bomb_layout()
	_save_bomb_layout()

func _capture_bomb_layout() -> void:
	if not is_instance_valid(bomb_button):
		return
	var screen_size := get_viewport_rect().size
	var short_side := minf(screen_size.x,screen_size.y)
	if screen_size.x <= 1.0 or screen_size.y <= 1.0 or short_side <= 1.0:
		return
	var center := bomb_button.position+bomb_button.size*0.5
	_saved_bomb_center_ratio = Vector2(center.x/screen_size.x,center.y/screen_size.y)
	_saved_bomb_size_ratio = bomb_button.get_control_side()/short_side

func _save_bomb_layout() -> void:
	_control_layout_repository.save_bomb_layout(_saved_bomb_center_ratio,_saved_bomb_size_ratio)

func _has_saved_bomb_center() -> bool:
	return (
		_saved_bomb_center_ratio.x >= 0.0 and _saved_bomb_center_ratio.x <= 1.0
		and _saved_bomb_center_ratio.y >= 0.0 and _saved_bomb_center_ratio.y <= 1.0
	)

func _update_pickup_hud() -> void:
	super._update_pickup_hud()
	_refresh_bomb_button()

func _refresh_bomb_button() -> void:
	if is_instance_valid(bomb_button):
		bomb_button.set_count(maxi(0,_bombs))

func _on_bomb_button_pressed() -> void:
	if _editing_controls or _game_over or _run_complete or not is_instance_valid(player):
		return
	if _bombs <= 0:
		status_label.text = "NO TE QUEDAN BOMBAS"
		reward_label.text = "Busca una bomba antes de colocar otra"
		return
	_bombs -= 1
	_update_pickup_hud()
	var bomb := PlacedBomb.new()
	bomb.configure(player)
	bomb.global_position = player.global_position
	bomb.exploded.connect(_on_placed_bomb_exploded)
	add_child(bomb)
	status_label.text = "BOMBA COLOCADA — ¡CORRE!"
	reward_label.text = "La explosión daña enemigos y también puede dañarte"

# Proximity still gives the clue, but never consumes a bomb automatically.
# Secret walls now react only to the physical blast of a placed bomb.
func _try_reveal_hidden_room(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO:
		status_label.text = "PARED SOSPECHOSA"
		reward_label.text = "Coloca una bomba cerca y aléjate"

func _on_placed_bomb_exploded(world_position: Vector2, blast_radius: float) -> void:
	var direction := _detect_hidden_wall_from_point(world_position,blast_radius)
	if direction != Vector2i.ZERO:
		_reveal_hidden_room_from_blast(direction)

func _detect_hidden_wall_from_point(point: Vector2, blast_radius: float) -> Vector2i:
	if _dungeon == null:
		return Vector2i.ZERO
	var center := room_rect.get_center()
	var edge := clampf(blast_radius*0.86,96.0,138.0)
	var doorway_half := 116.0
	for dir: Vector2i in DIRS:
		var destination := _current_cell+dir
		if not _dungeon.has_room(destination):
			continue
		if not _dungeon.is_hidden(destination) or _dungeon.is_discovered(destination):
			continue
		if dir == Vector2i(0,-1) and point.y < room_rect.position.y+edge and absf(point.x-center.x)<doorway_half:
			return dir
		if dir == Vector2i(0,1) and point.y > room_rect.end.y-edge and absf(point.x-center.x)<doorway_half:
			return dir
		if dir == Vector2i(-1,0) and point.x < room_rect.position.x+edge and absf(point.y-center.y)<doorway_half:
			return dir
		if dir == Vector2i(1,0) and point.x > room_rect.end.x-edge and absf(point.y-center.y)<doorway_half:
			return dir
	return Vector2i.ZERO

func _reveal_hidden_room_from_blast(direction: Vector2i) -> void:
	var destination := _current_cell+direction
	if not _dungeon.has_room(destination) or not _dungeon.is_hidden(destination):
		return
	if _dungeon.is_discovered(destination):
		return
	_dungeon.reveal(destination)
	_clear_room_doors()
	_setup_room_doors()
	_set_door_open(_room_cleared)
	var secret_door: IsmaelRoomDoor = _doors.get(direction)
	if is_instance_valid(secret_door):
		secret_door.set_open(true)
	_update_minimap()
	status_label.text = "PARED SECRETA ABIERTA"
	reward_label.text = "La explosión reveló un acceso oculto"

# Doors remain pushed outward so their stone frame and collision do not occupy
# the combat floor or trap enemies beside a doorway.
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
	_clear_active_room_bombs()
	super._begin_room(entry_direction)
	_refresh_completed_room_status()
	_refresh_bomb_button()

func _clear_active_room_bombs() -> void:
	for bomb in get_tree().get_nodes_in_group("room_bombs"):
		if is_instance_valid(bomb):
			bomb.queue_free()

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
