extends RefCounted
class_name IsmaelRoomLootState

# Run-scoped domain state for physical pickups that have spawned but have not
# been collected yet. Presentation can rebuild the corresponding scene nodes
# whenever the player re-enters a room without duplicating rewards.

var _pending_by_room: Dictionary = {}
var _next_pickup_id := 1

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
