extends RefCounted
class_name IsmaelRoomObstacleState

var _destroyed_by_room: Dictionary = {}

func is_destroyed(room_key: String, obstacle_id: int) -> bool:
	var room_state: Dictionary = _destroyed_by_room.get(room_key,{})
	return bool(room_state.get(obstacle_id,false))

func mark_destroyed(room_key: String, obstacle_id: int) -> void:
	var room_state: Dictionary = _destroyed_by_room.get(room_key,{})
	room_state[obstacle_id] = true
	_destroyed_by_room[room_key] = room_state

func clear() -> void:
	_destroyed_by_room.clear()
