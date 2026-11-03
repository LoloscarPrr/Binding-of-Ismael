extends RefCounted
class_name IsmaelBossArenaComposition

# Cinco configuraciones de arenas con el centro transitable.
# La decoración no modifica ataques, fases ni salud del guardián.
static func cover_slots(floor_number: int) -> Array[Vector2]:
	match clampi(floor_number,1,5):
		1: return [Vector2(0.16,0.26),Vector2(0.84,0.26)]
		2: return [Vector2(0.17,0.73),Vector2(0.83,0.73)]
		3: return [Vector2(0.15,0.31),Vector2(0.85,0.31)]
		4: return [Vector2(0.17,0.25),Vector2(0.83,0.25)]
		_: return [] # El Hueco necesita una arena abierta para esquivas

static func cover_sizes(floor_number: int) -> Vector2:
	match clampi(floor_number,1,5):
		1: return Vector2(0.045,0.075)
		2: return Vector2(0.052,0.085)
		3: return Vector2(0.045,0.085)
		4: return Vector2(0.048,0.078)
		_: return Vector2.ZERO

static func center_is_clear(floor_number: int) -> bool:
	for slot in cover_slots(floor_number):
		var delta := slot-Vector2(0.5,0.5)
		if absf(delta.x)<0.24 and absf(delta.y)<0.23:
			return false
	return true

static func cover_rects(floor_number: int,area: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var sizes := cover_sizes(floor_number)
	for slot in cover_slots(floor_number):
		var center := area.position+area.size*slot
		var footprint := area.size*sizes
		result.append(Rect2(center-footprint*0.5,footprint))
	return result
