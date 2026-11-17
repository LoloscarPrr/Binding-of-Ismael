extends RefCounted
class_name IsmaelRoomSpawnPlanner

# Selecciona apariciones conectadas a Ismael y libres de rocas. El cálculo
# se hace UNA VEZ por oleada, nunca en _physics_process.
const GRID_STEP := 36.0
const BODY_CLEARANCE := 32.0
const WALL_MARGIN := 54.0

static func point_is_clear(point: Vector2, arena: Rect2, blocks: Array[Rect2], clearance: float = BODY_CLEARANCE) -> bool:
	if not arena.grow(-maxf(WALL_MARGIN,clearance+12.0)).has_point(point):
		return false
	for block in blocks:
		if block.grow(clearance+5.0).has_point(point):
			return false
	return true

static func choose_positions(
	count: int,
	arena: Rect2,
	player_at: Vector2,
	blocks: Array[Rect2],
	seed: int,
	player_gap: float,
	enemy_gap: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0 or arena.size.x < 120.0 or arena.size.y < 120.0:
		return result

	# Las celdas libres se conectan con vecinos ortogonales: una isla
	# aislada por coberturas jamás se considera un lugar válido.
	var width := maxi(4,int(ceilf(arena.size.x/GRID_STEP)))
	var height := maxi(4,int(ceilf(arena.size.y/GRID_STEP)))
	var step := Vector2(arena.size.x/float(width),arena.size.y/float(height))
	var free_cells: Dictionary = {}
	var start := Vector2i(-1,-1)
	var closest := INF
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x,y)
			var center := arena.position+Vector2((float(x)+0.5)*step.x,(float(y)+0.5)*step.y)
			if not point_is_clear(center,arena,blocks):
				continue
			free_cells[cell] = center
			var distance := center.distance_squared_to(player_at)
			if distance < closest:
				closest = distance
				start = cell
	if start.x < 0:
		return result

	var reachable: Dictionary = {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i = current+offset
			if free_cells.has(neighbor) and not reachable.has(neighbor):
				reachable[neighbor] = true
				queue.append(neighbor)

	# Preferir posiciones de encuentro legibles; el orden se permuta
	# con la semilla de sala y oleada para no repetir siempre el patrón.
	var ratios: Array[Vector2] = [
		Vector2(0.14,0.16),Vector2(0.86,0.16),
		Vector2(0.32,0.18),Vector2(0.68,0.18),
		Vector2(0.14,0.38),Vector2(0.86,0.38),
		Vector2(0.34,0.42),Vector2(0.66,0.42),
		Vector2(0.50,0.12),Vector2(0.50,0.36),
		Vector2(0.24,0.30),Vector2(0.76,0.30),
		Vector2(0.17,0.67),Vector2(0.83,0.67),
		Vector2(0.32,0.77),Vector2(0.68,0.77),
		Vector2(0.12,0.54),Vector2(0.88,0.54),
		Vector2(0.38,0.27),Vector2(0.62,0.27)
	]
	var rotation := posmod(seed,ratios.size())
	for i in range(ratios.size()):
		var slot: Vector2 = ratios[posmod(rotation+i*7,ratios.size())]
		var candidate := arena.position+arena.size*slot
		_try_candidate(candidate,arena,blocks,player_at,player_gap,enemy_gap,step,width,height,reachable,result)
		if result.size() >= count:
			return result

	# Si un patrón de columnas invalida las posiciones habituales,
	# buscar alternativas en celdas TRANSITABLES, no reducir el margen
	# ni permitir enemigos superpuestos.
	var total := width*height
	var grid_rotation := posmod(seed,total)
	for i in range(total):
		var index := posmod(grid_rotation+i,total)
		var cell := Vector2i(index%width,int(index/width))
		if not reachable.has(cell):
			continue
		var candidate: Vector2 = free_cells[cell]
		_try_candidate(candidate,arena,blocks,player_at,player_gap,enemy_gap,step,width,height,reachable,result)
		if result.size() >= count:
			break
	return result

static func _try_candidate(
	candidate: Vector2,
	arena: Rect2,
	blocks: Array[Rect2],
	player_at: Vector2,
	player_gap: float,
	enemy_gap: float,
	step: Vector2,
	width: int,
	height: int,
	reachable: Dictionary,
	result: Array[Vector2]
) -> void:
	if not point_is_clear(candidate,arena,blocks):
		return
	if candidate.distance_squared_to(player_at) < player_gap*player_gap:
		return
	var cell := Vector2i(
		clampi(int(floor((candidate.x-arena.position.x)/step.x)),0,width-1),
		clampi(int(floor((candidate.y-arena.position.y)/step.y)),0,height-1)
	)
	if not reachable.has(cell):
		return
	for previous in result:
		if candidate.distance_squared_to(previous) < enemy_gap*enemy_gap:
			return
	result.append(candidate)
