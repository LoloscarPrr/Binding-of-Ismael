extends RefCounted
class_name IsmaelRoomLootState

# Run-scoped domain state for physical pickups and room chests. Presentation
# rebuilds scene nodes from this state whenever the player re-enters a room.

var _pending_by_room: Dictionary = {}
var _chest_by_room: Dictionary = {}
var _next_pickup_id := 1
var _next_chest_id := 1

func register_pickup(room_key: String, kind: String, ratio: Vector2) -> int:
	var pickup_id := _next_pickup_id
	_next_pickup_id += 1
	var entries: Array = _pending_by_room.get(room_key,[])
	entries.append({
		"id":pickup_id,
		"kind":kind,
		"ratio":ratio
	})
	_pending_by_room[room_key] = entries
	return pickup_id

func pending_pickups(room_key: String) -> Array:
	var result: Array = []
	for entry_variant in _pending_by_room.get(room_key,[]):
		var entry: Dictionary = entry_variant
		result.append(entry.duplicate(true))
	return result

func consume_pickup(room_key: String, pickup_id: int) -> void:
	if not _pending_by_room.has(room_key):
		return
	var remaining: Array = []
	for entry_variant in _pending_by_room[room_key]:
		var entry: Dictionary = entry_variant
		if int(entry.get("id",-1)) != pickup_id:
			remaining.append(entry)
	if remaining.is_empty():
		_pending_by_room.erase(room_key)
	else:
		_pending_by_room[room_key] = remaining

func has_pending_pickups(room_key: String) -> bool:
	return not pending_pickups(room_key).is_empty()

func register_chest(room_key: String, chest_kind: String, ratio: Vector2) -> int:
	if _chest_by_room.has(room_key):
		var existing: Dictionary = _chest_by_room[room_key]
		return int(existing.get("id",-1))
	var chest_id := _next_chest_id
	_next_chest_id += 1
	_chest_by_room[room_key] = {
		"id":chest_id,
		"kind":chest_kind,
		"ratio":ratio,
		"opened":false,
		"loot_spawned":false
	}
	return chest_id

func has_chest(room_key: String) -> bool:
	return _chest_by_room.has(room_key)

func chest_state(room_key: String) -> Dictionary:
	if not _chest_by_room.has(room_key):
		return {}
	var state: Dictionary = _chest_by_room[room_key]
	return state.duplicate(true)

func mark_chest_opened(room_key: String) -> void:
	if not _chest_by_room.has(room_key):
		return
	var state: Dictionary = _chest_by_room[room_key]
	state["opened"] = true
	_chest_by_room[room_key] = state

func mark_chest_loot_spawned(room_key: String) -> void:
	if not _chest_by_room.has(room_key):
		return
	var state: Dictionary = _chest_by_room[room_key]
	state["loot_spawned"] = true
	_chest_by_room[room_key] = state
