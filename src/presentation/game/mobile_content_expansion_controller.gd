extends "res://src/presentation/game/mobile_floor_expansion_controller.gd"

const ExtraEnemy = preload("res://scripts/extra_enemy.gd")
const RoomHazard = preload("res://scripts/room_hazard.gd")
const ExpandedItemCatalog = preload("res://src/domain/items/item_catalog.gd")

var _prepared_content_floor := 0
var _unlocked_treasure_rooms: Dictionary = {}

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	if _prepared_content_floor != _floor_index and _dungeon != null:
		_prepare_extra_room_kinds()
		_prepared_content_floor = _floor_index
	_clear_content_hazards()
	super._begin_room(entry_direction)
	_spawn_content_hazards()

func _prepare_extra_room_kinds() -> void:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in _dungeon.order:
		if cell == Vector2i.ZERO:
			continue
		if _dungeon.kind(cell) != "combate":
			continue
		if _dungeon.distance(cell) < 2:
			continue
		candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return _dungeon.distance(a) > _dungeon.distance(b)
	)
	if _floor_index >= 2 and not candidates.is_empty():
		_set_content_room_kind(candidates.pop_front(),"maldicion")
	if _floor_index >= 3 and not candidates.is_empty():
		_set_content_room_kind(candidates.pop_front(),"biblioteca")
	if _floor_index >= 5 and not candidates.is_empty():
		_set_content_room_kind(candidates.pop_front(),"maldicion")

func _set_content_room_kind(cell: Vector2i, kind_value: String) -> void:
	if not _dungeon.rooms.has(cell):
		return
	var data: Dictionary = _dungeon.rooms[cell]
	data["kind"] = kind_value
	_dungeon.rooms[cell] = data

func _room_title() -> String:
	match _room_kind:
		"maldicion": return "CÁMARA MALDITA"
		"biblioteca": return "ARCHIVO PROHIBIDO"
	return super._room_title()

func _spawn_room_after_entry(generation: int) -> void:
	if _room_kind == "biblioteca":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		_open_library_room()
		return
	if _room_kind == "maldicion":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		var depth := _dungeon.distance(_current_cell)+2
		var count := mini(5+_floor_index,FloorCatalog.enemy_cap(_floor_index)+1)
		_spawn_enemy_pack(count,depth)
		_transition_locked = false
		status_label.text = "CÁMARA MALDITA"
		reward_label.text = "Más enemigos · suelo peligroso · mejor recompensa"
		queue_redraw()
		return
	super._spawn_room_after_entry(generation)

func _open_library_room() -> void:
	var room_key := _reward_room_key()
	if _reward_offers.has(room_key):
		_offered_rewards.clear()
		for value in _reward_offers[room_key]:
			_offered_rewards.append(String(value))
	else:
		_offered_rewards = _library_choices()
		_reward_offers[room_key] = _offered_rewards.duplicate()
	status_label.text = "ARCHIVO PROHIBIDO"
	reward_label.text = "ELIGE UN OBJETO — EL OTRO SE PERDERÁ"
	_spawn_reward_pedestal(_offered_rewards[0],room_rect.position+room_rect.size*Vector2(0.38,0.53))
	_spawn_reward_pedestal(_offered_rewards[1],room_rect.position+room_rect.size*Vector2(0.62,0.53))
	_transition_locked = false

func _library_choices() -> Array[String]:
	var pool: Array[String] = [
		"doble","lente","alma","adrenalina","mapa","buscadora","perforante","fortuna"
	]
	var seed := absi(_floor_index*131+_current_cell.x*92821+_current_cell.y*68917)
	var first := pool[seed%pool.size()]
	var second := pool[(seed*3+5)%pool.size()]
	if second == first:
		second = pool[(seed+1)%pool.size()]
	return [first,second]

func _create_floor_enemy(kind_id: String):
	if kind_id in ["flyer","turret","leaper"]:
		var enemy := ExtraEnemy.new()
		enemy.configure_extra(kind_id,_floor_index)
		return enemy
	return super._create_floor_enemy(kind_id)

func _travel_to(direction: Vector2i) -> void:
	if _transition_locked:
		return
	var destination := _current_cell+direction
	if _dungeon != null and _dungeon.has_room(destination) and _dungeon.kind(destination) == "recompensa":
		var key := _treasure_unlock_key(destination)
		if not bool(_unlocked_treasure_rooms.get(key,false)):
			if _keys <= 0:
				status_label.text = "PUERTA DEL TESORO CERRADA"
				reward_label.text = "Necesitas 1 llave para entrar"
				if is_instance_valid(player):
					player.position -= Vector2(direction.x,direction.y)*56.0
				return
			_keys -= 1
			_unlocked_treasure_rooms[key] = true
			_update_pickup_hud()
			status_label.text = "PUERTA DEL TESORO ABIERTA"
			reward_label.text = "Se consumió 1 llave"
	super._travel_to(direction)

func _treasure_unlock_key(cell: Vector2i) -> String:
	return "%d:%d:%d" % [_floor_index,cell.x,cell.y]

func _set_door_open(value: bool) -> void:
	super._set_door_open(value)
	if not value or _dungeon == null:
		return
	for dir: Vector2i in DIRS:
		var destination := _current_cell+dir
		if not _dungeon.has_room(destination) or _dungeon.kind(destination) != "recompensa":
			continue
		if bool(_unlocked_treasure_rooms.get(_treasure_unlock_key(destination),false)):
			continue
		var door = _doors.get(dir)
		if is_instance_valid(door):
			door.set_open(false)
			door.modulate = Color(0.95,0.72,0.20,1.0)

func _create_room_door(direction: Vector2i) -> void:
	super._create_room_door(direction)
	var destination := _current_cell+direction
	if not _dungeon.has_room(destination):
		return
	var door = _doors.get(direction)
	if not is_instance_valid(door):
		return
	match _dungeon.kind(destination):
		"recompensa": door.modulate = Color(0.95,0.72,0.20,1.0)
		"biblioteca": door.modulate = Color(0.58,0.42,0.82,1.0)
		"maldicion": door.modulate = Color(0.64,0.12,0.16,1.0)

func _spawn_clear_pickup() -> void:
	super._spawn_clear_pickup()
	if _room_kind in ["inicio","recompensa","tienda","biblioteca"]:
		return
	var roll := absi(_floor_index*71+_room_index*43+_current_cell.x*97+_current_cell.y*53)%100
	if _floor_index >= 2 and roll < 7:
		_spawn_pickup_at("soul",Vector2(0.58,0.61))
	elif _floor_index >= 3 and roll >= 7 and roll < 12:
		_spawn_pickup_at("coin5",Vector2(0.58,0.61))

func _spawn_chest_loot(room_key: String,chest_id: int,chest_kind: String) -> void:
	super._spawn_chest_loot(room_key,chest_id,chest_kind)
	if chest_kind != "locked":
		return
	var state := _room_loot_state.chest_state(room_key)
	var base_ratio: Vector2 = state.get("ratio",Vector2(0.50,0.40))
	if posmod(chest_id+_floor_index,2) == 0:
		_spawn_pickup_at("coin5",base_ratio+Vector2(0.0,0.24))
	else:
		_spawn_pickup_at("soul",base_ratio+Vector2(0.0,0.24))

func _on_enemy_defeated(enemy) -> void:
	var was_cleared := _room_cleared
	super._on_enemy_defeated(enemy)
	if not was_cleared and _room_cleared and _room_kind == "maldicion":
		_spawn_pickup_at("soul",Vector2(0.44,0.61))
		_spawn_pickup_at("coin5",Vector2(0.56,0.61))
		status_label.text = "MALDICIÓN SUPERADA"
		reward_label.text = "La cámara dejó una recompensa excepcional"

func _clear_content_hazards() -> void:
	for hazard in get_tree().get_nodes_in_group("room_hazards"):
		if is_instance_valid(hazard):
			hazard.queue_free()

func _spawn_content_hazards() -> void:
	if _room_kind not in ["combate","emboscada","desafio","maldicion"]:
		return
	var ratios: Array[Vector2] = _hazard_ratios_for_layout()
	var count := 0
	if _room_kind == "maldicion":
		count = 5
	elif _room_kind == "desafio":
		count = 2 if _floor_index >= 2 else 0
	elif _floor_index >= 2:
		count = 1+int(_floor_index>=4)
	if _room_layout_profile == "abierta":
		count = mini(count,1)
	elif _room_layout_profile in ["embudo","corredor_maldito"]:
		count = mini(count+1,5)
	var seed := absi(_floor_index*193+_current_cell.x*92821+_current_cell.y*68917+_room_index*17)
	for i in range(count):
		var ratio := ratios[posmod(seed+i*3,ratios.size())]
		var kind := "spike"
		if (_room_kind == "maldicion" and i>=4) or (_floor_index>=3 and i==count-1 and posmod(seed,3)==0):
			kind = "fire"
		var hazard_id := 100+i
		var room_key := _obstacle_room_key()
		if kind == "fire" and _room_obstacle_state.is_destroyed(room_key,hazard_id):
			continue
		var hazard := RoomHazard.new()
		hazard.configure(hazard_id,kind)
		hazard.position = room_rect.position+room_rect.size*ratio
		hazard.destroyed.connect(_on_content_hazard_destroyed.bind(room_key))
		add_child(hazard)

func _hazard_ratios_for_layout() -> Array[Vector2]:
	match _room_layout_profile:
		"embudo":
			return [
				Vector2(0.50,0.52),Vector2(0.50,0.66),Vector2(0.38,0.44),
				Vector2(0.62,0.44),Vector2(0.50,0.36)
			]
		"corredor_maldito":
			return [
				Vector2(0.50,0.34),Vector2(0.50,0.48),Vector2(0.50,0.62),
				Vector2(0.42,0.55),Vector2(0.58,0.55)
			]
		"columnas":
			return [
				Vector2(0.50,0.48),Vector2(0.50,0.66),Vector2(0.24,0.56),
				Vector2(0.76,0.56)
			]
		"cruzada","arena_cruzada":
			return [
				Vector2(0.50,0.46),Vector2(0.32,0.66),Vector2(0.68,0.66),
				Vector2(0.50,0.72)
			]
		"pinza":
			return [
				Vector2(0.50,0.46),Vector2(0.34,0.68),Vector2(0.66,0.68)
			]
		_:
			return [
				Vector2(0.30,0.38),Vector2(0.70,0.38),Vector2(0.38,0.66),
				Vector2(0.62,0.66),Vector2(0.50,0.48),Vector2(0.24,0.62),
				Vector2(0.76,0.62)
			]

func _on_content_hazard_destroyed(hazard_id: int, _world_position: Vector2, room_key: String) -> void:
	_room_obstacle_state.mark_destroyed(room_key,hazard_id)

func _on_placed_bomb_exploded(world_position: Vector2, blast_radius: float) -> void:
	super._on_placed_bomb_exploded(world_position,blast_radius)
	for hazard in get_tree().get_nodes_in_group("room_hazards"):
		if is_instance_valid(hazard) and hazard.has_method("blast_hit"):
			hazard.call("blast_hit",world_position,blast_radius)
