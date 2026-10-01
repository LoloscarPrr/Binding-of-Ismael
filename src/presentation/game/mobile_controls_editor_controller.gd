extends "res://src/presentation/game/mobile_main_controller.gd"

const RoomLootState = preload("res://src/domain/run/room_loot_state.gd")
const TreasureChest = preload("res://scripts/treasure_chest.gd")

# Presentation-only control customization layer plus reconstruction of physical
# room loot from run-scoped domain state. Gameplay rewards remain in the
# application/economy services.

var _saved_left_size_ratio := -1.0
var _saved_right_size_ratio := -1.0
var _room_loot_state = RoomLootState.new()

func _create_touch_ui() -> void:
	super._create_touch_ui()
	if is_instance_valid(control_edit_button):
		control_edit_button.text = "EDITAR CONTROLES"
		control_edit_button.add_theme_font_size_override("font_size",14)

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	super._begin_room(entry_direction)
	_restore_pending_room_pickups()
	_restore_room_chest()

func _spawn_pickup_at(kind: String,ratio: Vector2) -> void:
	var room_key := _loot_room_key()
	var pickup_id := _room_loot_state.register_pickup(room_key,kind,ratio)
	_spawn_tracked_pickup(kind,ratio,room_key,pickup_id)

func _spawn_clear_pickup() -> void:
	if _room_kind in ["inicio","recompensa","tienda"]:
		return
	var kind := "coin"
	if _room_kind == "jefe":
		kind = "key"
	else:
		match (_rooms_cleared_total+_floor_index)%4:
			0: kind = "heart"
			1: kind = "coin"
			2: kind = "bomb"
			3: kind = "key"
	_spawn_pickup_at(kind,Vector2(0.50,0.60))
	if _room_kind in ["combate","emboscada"]:
		_maybe_spawn_room_chest()

func _spawn_special_bundle(kind: String) -> void:
	super._spawn_special_bundle(kind)
	if kind == "minijefe":
		_maybe_spawn_room_chest(22)

func _maybe_spawn_room_chest(extra_chance: int = 0) -> void:
	var room_key := _loot_room_key()
	if _room_loot_state.has_chest(room_key):
		_restore_room_chest()
		return
	var roll := _chest_roll()
	var chance := clampi(34+extra_chance,0,80)
	if roll >= chance:
		return
	var chest_kind := "locked" if (roll+_floor_index+_room_index)%4 == 0 else "wooden"
	_room_loot_state.register_chest(room_key,chest_kind,Vector2(0.50,0.40))
	_restore_room_chest()

func _chest_roll() -> int:
	var value := absi(_current_cell.x*92821+_current_cell.y*68917+_floor_index*193+_room_index*47)
	return value%100

func _restore_room_chest() -> void:
	if _dungeon == null:
		return
	var room_key := _loot_room_key()
	var state := _room_loot_state.chest_state(room_key)
	if state.is_empty():
		return
	for node in get_tree().get_nodes_in_group("room_chests"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if String(node.get_meta("room_chest_room_key","")) == room_key:
			return
	_spawn_room_chest(room_key,state)

func _spawn_room_chest(room_key: String,state: Dictionary) -> void:
	var chest = TreasureChest.new()
	chest.configure(String(state.get("kind","wooden")),bool(state.get("opened",false)))
	var ratio: Vector2 = state.get("ratio",Vector2(0.50,0.40))
	chest.position = room_rect.position+room_rect.size*ratio
	chest.set_meta("room_chest_room_key",room_key)
	chest.set_meta("room_chest_id",int(state.get("id",-1)))
	chest.open_requested.connect(_on_chest_open_requested.bind(room_key,int(state.get("id",-1))))
	add_child(chest)

func _on_chest_open_requested(chest: Node,room_key: String,chest_id: int) -> void:
	if room_key != _loot_room_key() or not is_instance_valid(chest):
		return
	var state := _room_loot_state.chest_state(room_key)
	if state.is_empty() or bool(state.get("opened",false)):
		return
	var chest_kind := String(state.get("kind","wooden"))
	if chest_kind == "locked":
		_sync_inventory_from_legacy()
		if not _economy_service.spend_keys(1):
			status_label.text = "COFRE CERRADO — NECESITAS UNA LLAVE"
			reward_label.text = ""
			return
		_sync_legacy_from_inventory()
		_update_pickup_hud()
	_room_loot_state.mark_chest_opened(room_key)
	if chest.has_method("set_opened"):
		chest.call("set_opened",true)
	status_label.text = "COFRE ABIERTO"
	if chest_kind == "locked":
		reward_label.text = "La llave reveló una reserva mejor"
	else:
		reward_label.text = "Encontraste una pequeña reserva"
	if not bool(state.get("loot_spawned",false)):
		_spawn_chest_loot(room_key,chest_id,chest_kind)
		_room_loot_state.mark_chest_loot_spawned(room_key)

func _spawn_chest_loot(room_key: String,chest_id: int,chest_kind: String) -> void:
	var state := _room_loot_state.chest_state(room_key)
	var base_ratio: Vector2 = state.get("ratio",Vector2(0.50,0.40))
	var seed := absi(chest_id*53+_floor_index*17+_room_index*31)
	var pool: Array[String] = ["coin","bomb","key","heart"]
	var kinds: Array[String] = ["coin",pool[(seed+1)%pool.size()]]
	var offsets: Array[Vector2] = [Vector2(-0.065,0.14),Vector2(0.065,0.14)]
	if chest_kind == "locked":
		kinds.append(pool[(int(seed/4)+2)%pool.size()])
		offsets = [Vector2(-0.085,0.14),Vector2(0.0,0.17),Vector2(0.085,0.14)]
	for i in kinds.size():
		_spawn_pickup_at(kinds[i],base_ratio+offsets[i])

func _spawn_tracked_pickup(kind: String,ratio: Vector2,room_key: String,pickup_id: int) -> void:
	var pickup := IsmaelPickup.new()
	pickup.configure(kind)
	pickup.position = room_rect.position+room_rect.size*ratio
	pickup.set_meta("room_loot_room_key",room_key)
	pickup.set_meta("room_loot_id",pickup_id)
	pickup.collected.connect(_on_persistent_pickup_collected.bind(room_key,pickup_id))
	add_child(pickup)

func _restore_pending_room_pickups() -> void:
	if _dungeon == null:
		return
	var room_key := _loot_room_key()
	var live_ids: Dictionary = {}
	for node in get_tree().get_nodes_in_group("room_pickups"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if String(node.get_meta("room_loot_room_key","")) != room_key:
			continue
		live_ids[int(node.get_meta("room_loot_id",-1))] = true
	for entry_variant in _room_loot_state.pending_pickups(room_key):
		var entry: Dictionary = entry_variant
		var pickup_id := int(entry.get("id",-1))
		if live_ids.has(pickup_id):
			continue
		_spawn_tracked_pickup(
			String(entry.get("kind","coin")),
			entry.get("ratio",Vector2(0.50,0.60)),
			room_key,
			pickup_id
		)

func _on_persistent_pickup_collected(kind: String,room_key: String,pickup_id: int) -> void:
	_room_loot_state.consume_pickup(room_key,pickup_id)
	_on_pickup_collected(kind)

func _loot_room_key() -> String:
	return "%d:%d:%d" % [_floor_index,_current_cell.x,_current_cell.y]

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
