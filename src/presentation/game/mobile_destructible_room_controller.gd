extends "res://src/presentation/game/mobile_room_state_controller.gd"

const DestructibleRock = preload("res://scripts/destructible_rock.gd")
const RoomObstacleState = preload("res://src/domain/run/room_obstacle_state.gd")
const CoverPlanner = preload("res://src/domain/run/room_cover_planner.gd")

var _room_obstacle_state = RoomObstacleState.new()

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	_clear_active_room_rocks()
	super._begin_room(entry_direction)
	_spawn_room_rocks()

func _on_placed_bomb_exploded(world_position: Vector2, blast_radius: float) -> void:
	_audio_sfx("bomb",1.35)
	super._on_placed_bomb_exploded(world_position,blast_radius)
	for rock in get_tree().get_nodes_in_group("room_rocks"):
		if not is_instance_valid(rock) or rock.is_queued_for_deletion():
			continue
		if rock.has_method("blast_hit"):
			rock.call("blast_hit",world_position,blast_radius)

func _spawn_room_rocks() -> void:
	if _room_kind not in ["combate","emboscada","desafio","minijefe"]:
		return
	# En salas con cuatro columnas ya hay cobertura suficiente.
	# Evita las piedras entre columnas que atrapaban a los enemigos.
	if String(get("_room_layout_profile")) == "columnas":
		return
	var room_key := _obstacle_room_key()
	var seed := _obstacle_seed()
	# Solo orillas del combate: nada de piedras en el centro,
	# cruces de puertas ni grupos cerrados detrás de columnas.
	var candidates: Array[Vector2] = [
		Vector2(0.18,0.25),Vector2(0.82,0.25),
		Vector2(0.18,0.75),Vector2(0.82,0.75),
		Vector2(0.35,0.19),Vector2(0.65,0.19),
		Vector2(0.35,0.81),Vector2(0.65,0.81)
	]
	var patterns: Array[Array] = [
		[0,3],[1,2],[0,2,5],[1,3,4],
		[0,3,6],[1,2,7],[4,7],[5,6]
	]
	var pattern: Array = patterns[posmod(seed+_floor_index,patterns.size())]
	var placed: Array[Vector2] = []
	var static_blocks: Array[Rect2] = []
	for obstacle in get_tree().get_nodes_in_group("room_obstacles"):
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion():
			continue
		static_blocks.append(Rect2(
			obstacle.global_position-obstacle.obstacle_size*0.5,
			obstacle.obstacle_size
		))
	var opponents: Array[Vector2] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			opponents.append(enemy.global_position)
	var player_at := player.global_position if is_instance_valid(player) else room_rect.get_center()
	for candidate_variant in pattern:
		var rock_id := int(candidate_variant)
		if _room_obstacle_state.is_destroyed(room_key,rock_id):
			continue
		var world_position := room_rect.position+room_rect.size*candidates[rock_id]
		var sizes: Array[float] = [0.88,1.0,1.08]
		var rock_scale: float = sizes[posmod(seed+rock_id*7,sizes.size())]
		var radius := DestructibleRock.COLLISION_RADIUS*rock_scale
		if not CoverPlanner.is_safe_rock(world_position,radius,room_rect,static_blocks,placed,player_at,opponents):
			continue
		var blockers: Array[Rect2] = static_blocks.duplicate()
		for rock_spot in placed:
			blockers.append(Rect2(rock_spot-Vector2.ONE*35.0,Vector2.ONE*70.0))
		blockers.append(Rect2(world_position-Vector2.ONE*radius,Vector2.ONE*radius*2.0))
		if not CoverPlanner.routes_remain_open(room_rect,blockers):
			continue
		var loot_roll := _rock_loot_roll(rock_id)
		var rock := DestructibleRock.new()
		rock.configure(rock_id,seed+rock_id,loot_roll<14,rock_scale)
		rock.position = world_position
		rock.destroyed.connect(_on_room_rock_destroyed.bind(room_key))
		add_child(rock)
		placed.append(world_position)

func _on_room_rock_destroyed(rock_id: int, world_position: Vector2, room_key: String) -> void:
	_room_obstacle_state.mark_destroyed(room_key,rock_id)
	_maybe_drop_rock_loot(rock_id,world_position)

func _rock_loot_roll(rock_id: int) -> int:
	return posmod(
		absi(_floor_index*131+_current_cell.x*92821+_current_cell.y*68917+rock_id*97),
		100
	)

func _maybe_drop_rock_loot(rock_id: int, world_position: Vector2) -> void:
	var roll := _rock_loot_roll(rock_id)
	if roll>=14:
		return
	var kind := "coin"
	if roll==0:
		kind = "bomb"
	elif roll==1:
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
