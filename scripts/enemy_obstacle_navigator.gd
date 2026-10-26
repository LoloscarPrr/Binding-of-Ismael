extends RefCounted
class_name IsmaelEnemyObstacleNavigator

# Navegación geométrica liviana para salas pequeñas. Las coberturas y rocas
# generan nodos en sus esquinas; Dijkstra encuentra una ruta transitable.
# No necesita navmesh, teleportación ni cambiar la física de Godot.
const WAYPOINT_MARGIN := 10.0
const EPSILON := 0.0001

static func segment_is_clear(from_point: Vector2, to_point: Vector2, blocks: Array[Rect2]) -> bool:
	for block in blocks:
		if _segment_hits_rect(from_point,to_point,block):
			return false
	return true

# Intersección de segmento y AABB (slab test). Incluye borde para no
# elegir rutas que rocen la geometría con el radio del enemigo.
static func _segment_hits_rect(a: Vector2,b: Vector2,rect: Rect2) -> bool:
	var diff := b-a
	var t_min := 0.0
	var t_max := 1.0
	for axis in range(2):
		var axis_a := a.x if axis == 0 else a.y
		var axis_d := diff.x if axis == 0 else diff.y
		var lo := rect.position.x if axis == 0 else rect.position.y
		var hi := rect.end.x if axis == 0 else rect.end.y
		if absf(axis_d) < EPSILON:
			if axis_a >= lo and axis_a <= hi:
				continue
			return false
		var t0 := (lo-axis_a)/axis_d
		var t1 := (hi-axis_a)/axis_d
		if t0 > t1:
			var swap := t0
			t0 = t1
			t1 = swap
		t_min = maxf(t_min,t0)
		t_max = minf(t_max,t1)
		if t_min > t_max:
			return false
	return t_max >= 0.0 and t_min <= 1.0

static func next_corner(origin: Vector2,goal: Vector2,blocks: Array[Rect2],arena: Rect2) -> Vector2:
	if blocks.is_empty() or segment_is_clear(origin,goal,blocks):
		return goal

	# Index 0 = enemigo, index 1 = jugador. Los demás son esquinas
	# separadas diez píxeles de las áreas físicas expandidas.
	var nodes: Array[Vector2] = [origin,goal]
	for block in blocks:
		var outer := block.grow(WAYPOINT_MARGIN)
		var corners: Array[Vector2] = [
			outer.position,
			Vector2(outer.end.x,outer.position.y),
			outer.end,
			Vector2(outer.position.x,outer.end.y)
		]
		for corner in corners:
			if arena.has_point(corner):
				nodes.append(corner)
	var n := nodes.size()
	var cost: Array[float] = []
	var prev: Array[int] = []
	var visited: Array[bool] = []
	for i in range(n):
		cost.append(INF)
		prev.append(-1)
		visited.append(false)
	cost[0] = 0.0

	for iteration in range(n):
		var chosen := -1
		var best := INF
		for i in range(n):
			if not visited[i] and cost[i] < best:
				chosen = i
				best = cost[i]
		if chosen < 0 or chosen == 1:
			break
		visited[chosen] = true
		for next_index in range(n):
			if next_index == chosen or visited[next_index]:
				continue
			if not _can_step(nodes[chosen],nodes[next_index],blocks):
				continue
			var candidate := cost[chosen]+nodes[chosen].distance_to(nodes[next_index])
			if candidate+EPSILON < cost[next_index]:
				cost[next_index] = candidate
				prev[next_index] = chosen

	if prev[1] < 0:
		return goal # Physic collisions remain authoritative: never teleport.
	var cursor := 1
	for i in range(n):
		if prev[cursor] == 0:
			return nodes[cursor]
		if prev[cursor] < 0:
			break
		cursor = prev[cursor]
	return goal

static func _can_step(a: Vector2,b: Vector2,blocks: Array[Rect2]) -> bool:
	for rect in blocks:
		if _segment_hits_rect(a,b,rect):
			# Si una roca se destruyó/rozó y el actor quedó dentro del
			# margen expandido, se permite SALIR hacia afuera del centro.
			if rect.has_point(a) and not rect.has_point(b):
				var center := rect.get_center()
				if b.distance_squared_to(center) > a.distance_squared_to(center):
					continue
			return false
	return true
