extends RefCounted
class_name IsmaelRoomCoverPlanner

# Cada cobertura debe dejar un carril real para un enemigo + radio
# de colisión; no basta comprobar que dos objetos no se toquen.
const ROCK_NAV_MARGIN := 43.0
const ROCK_GAP := 78.0
const DOOR_CLEARANCE := 150.0

static func is_safe_rock(
	spot: Vector2,
	radius: float,
	arena: Rect2,
	static_blocks: Array[Rect2],
	placed_rocks: Array[Vector2],
	player_spot: Vector2,
	enemy_spots: Array[Vector2]
) -> bool:
	if not arena.grow(-radius-30.0).has_point(spot):
		return false
	var mid := arena.get_center()
	# Libre el acceso a las cuatro puertas y el espacio central.
	if absf(spot.x-mid.x) < 115.0 and (spot.y < arena.position.y+DOOR_CLEARANCE or spot.y > arena.end.y-DOOR_CLEARANCE):
		return false
	if absf(spot.y-mid.y) < 104.0 and (spot.x < arena.position.x+DOOR_CLEARANCE or spot.x > arena.end.x-DOOR_CLEARANCE):
		return false
	if absf(spot.x-mid.x)<120.0 and absf(spot.y-mid.y)<112.0:
		return false
	if spot.distance_to(player_spot)<radius+115.0:
		return false
	for enemy_spot in enemy_spots:
		if spot.distance_to(enemy_spot)<radius+95.0:
			return false
	for center in placed_rocks:
		if spot.distance_to(center)<radius*2.0+ROCK_GAP:
			return false
	for block in static_blocks:
		if block.grow(radius+ROCK_NAV_MARGIN).has_point(spot):
			return false
	return true

static func routes_remain_open(arena: Rect2,blocks: Array[Rect2]) -> bool:
	# Prueba de conectividad en un grid de 37 px, radio 28 px:
	# desde el centro deben alcanzarse las cuatro entradas.
	const STEP := 37.0
	var w := maxi(3,int(floor(arena.size.x/STEP)))
	var h := maxi(3,int(floor(arena.size.y/STEP)))
	var safe: Dictionary = {}
	for y in range(h):
		for x in range(w):
			var point := arena.position+Vector2((float(x)+0.5)*arena.size.x/float(w),(float(y)+0.5)*arena.size.y/float(h))
			var passable := true
			for obstacle in blocks:
				if obstacle.grow(29.0).has_point(point):
					passable = false
					break
			if passable:
				safe[Vector2i(x,y)] = true
	var start := Vector2i(w/2,h/2)
	if not safe.has(start):
		return false
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start:true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for step in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+step
			if safe.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	for door in [Vector2i(w/2,1),Vector2i(w/2,h-2),Vector2i(1,h/2),Vector2i(w-2,h/2)]:
		if not visited.has(door):
			return false
	return true
