extends "res://src/presentation/game/mobile_room_state_controller.gd"

const DestructibleRock = preload("res://scripts/destructible_rock.gd")
const RoomObstacleState = preload("res://src/domain/run/room_obstacle_state.gd")

var _room_obstacle_state = RoomObstacleState.new()

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	_clear_active_room_rocks()
	super._begin_room(entry_direction)
	_spawn_room_rocks()

func _on_placed_bomb_exploded(world_position: Vector2, blast_radius: float) -> void:
	super._on_placed_bomb_exploded(world_position,blast_radius)
	for rock in get_tree().get_nodes_in_group("room_rocks"):
		if not is_instance_valid(rock) or rock.is_queued_for_deletion():
			continue
		if rock.has_method("blast_hit"):
			rock.call("blast_hit",world_position,blast_radius)

func _spawn_room_rocks() -> void:
	if _room_kind not in ["combate","emboscada","desafio","minijefe"]:
		return
	var room_key := _obstacle_room_key()
	var seed := _obstacle_seed()
	var candidates: Array[Vector2] = [
		Vector2(0.25,0.28),Vector2(0.75,0.28),
		Vector2(0.25,0.72),Vector2(0.75,0.72),
		Vector2(0.36,0.45),Vector2(0.64,0.45),
		Vector2(0.38,0.64),Vector2(0.62,0.64)
	]
	var desired_count := 2+posmod(seed,3)
	var start_index := posmod(seed,candidates.size())
	var step := 3 if posmod(seed,2) == 0 else 5
	var spawned := 0
	for scan in range(candidates.size()):
		if spawned >= desired_count:
			break
		var candidate_index := posmod(start_index+scan*step,candidates.size())
		var rock_id := candidate_index
		if _room_obstacle_state.is_destroyed(room_key,rock_id):
			continue
		var world_position := room_rect.position+room_rect.size*candidates[candidate_index]
		if not _rock_position_is_safe(world_position):
			continue
		var rock := DestructibleRock.new()
		rock.configure(rock_id,seed+rock_id)
		rock.position = world_position
		rock.destroyed.connect(_on_room_rock_destroyed.bind(room_key))
		add_child(rock)
		spawned += 1

func _rock_position_is_safe(world_position: Vector2) -> bool:
	if is_instance_valid(player) and world_position.distance_to(player.global_position) < 112.0:
		return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if world_position.distance_to(enemy.global_position) < 96.0:
				return false
	for chest in get_tree().get_nodes_in_group("room_chests"):
		if is_instance_valid(chest) and not chest.is_queued_for_deletion():
			if world_position.distance_to(chest.global_position) < 86.0:
				return false
	return true

func _on_room_rock_destroyed(rock_id: int, world_position: Vector2, room_key: String) -> void:
	_room_obstacle_state.mark_destroyed(room_key,rock_id)
	_maybe_drop_rock_loot(rock_id,world_position)

func _maybe_drop_rock_loot(rock_id: int, world_position: Vector2) -> void:
	var roll := posmod(
		absi(_floor_index*131+_current_cell.x*92821+_current_cell.y*68917+rock_id*97),
		100
	)
	if roll >= 14:
		return
	var kind := "coin"
	if roll == 0:
		kind = "bomb"
	elif roll == 1:
		kind = "heart"
	var ratio := Vector2(
		clampf((world_position.x-room_rect.position.x)/maxf(room_rect.size.x,1.0),0.08,0.92),
		clampf((world_position.y-room_rect.position.y)/maxf(room_rect.size.y,1.0),0.08,0.92)
	)
	_spawn_pickup_at(kind,ratio)

func _clear_active_room_rocks() -> void:
	for rock in get_tree().get_nodes_in_group("room_rocks"):
		if is_instance_valid(rock):
			rock.queue_free()

func _obstacle_room_key() -> String:
	return "%d:%d:%d" % [_floor_index,_current_cell.x,_current_cell.y]

func _obstacle_seed() -> int:
	return absi(
		_floor_index*193+_current_cell.x*92821+_current_cell.y*68917+_room_index*47
	)
