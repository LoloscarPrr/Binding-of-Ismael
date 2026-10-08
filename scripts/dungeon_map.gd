extends RefCounted
class_name IsmaelDungeonMap

const CARDINALS: Array[Vector2i] = [
	Vector2i(0,-1),
	Vector2i(1,0),
	Vector2i(0,1),
	Vector2i(-1,0)
]
const HIDDEN_KINDS: Array[String] = ["secreta","supersecreta"]

var rooms: Dictionary = {}
var order: Array[Vector2i] = []
var seed_value := 0
var floor_index := 1
var critical_path: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()

func generate(floor_number: int) -> void:
	floor_index = maxi(1,floor_number)
	rooms.clear()
	order.clear()
	_rng.randomize()
	seed_value = int(_rng.randi())
	_rng.seed = seed_value

	var target_count := clampi(9+floor_index,9,12)
	_add_room(Vector2i.ZERO)
	var attempts := 0
	while rooms.size() < target_count and attempts < 1000:
		attempts += 1
		var parent: Vector2i
		if _rng.randf() < 0.46 and order.size() > 2:
			parent = order[_rng.randi_range(maxi(0,order.size()-5),order.size()-1)]
		else:
			parent = order[_rng.randi_range(0,order.size()-1)]
		var dirs: Array[Vector2i] = CARDINALS.duplicate()
		dirs.shuffle()
		for dir: Vector2i in dirs:
			var candidate := parent+dir
			if rooms.has(candidate):
				continue
			if absi(candidate.x)>4 or absi(candidate.y)>3:
				continue
			if _neighbor_count(candidate)>2:
				continue
			_add_room(candidate)
			break

	_assign_distances()
	_build_critical_path()
	_assign_route_roles()
	_assign_room_kinds()
	_append_hidden_room("secreta",false)
	_append_hidden_room("supersecreta",true)
	_assign_distances()
	_mark_discovered(Vector2i.ZERO)

func _add_room(cell: Vector2i) -> void:
	var data := {
		"kind":"combate",
		"visited":false,
		"discovered":false,
		"cleared":false,
		"distance":0,
		"ordinal":order.size()+1,
		"route_role":"branch"
	}
	rooms[cell] = data
	order.append(cell)

func _neighbor_count(cell: Vector2i) -> int:
	var count := 0
	for dir: Vector2i in CARDINALS:
		if rooms.has(cell+dir):
			count += 1
	return count

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in CARDINALS:
		var next := cell+dir
		if rooms.has(next):
			result.append(next)
	return result

func has_room(cell: Vector2i) -> bool:
	return rooms.has(cell)

func room_count() -> int:
	return rooms.size()

func public_room_count() -> int:
	var count := 0
	for cell: Vector2i in order:
		if not is_hidden(cell):
			count += 1
	return count

func display_ordinal(cell: Vector2i) -> int:
	if is_hidden(cell):
		return 0
	var count := 0
	for ordered: Vector2i in order:
		if is_hidden(ordered):
			continue
		count += 1
		if ordered == cell:
			return count
	return 1

func kind(cell: Vector2i) -> String:
	if not rooms.has(cell):
		return "combate"
	return String(rooms[cell]["kind"])

func is_hidden(cell: Vector2i) -> bool:
	return rooms.has(cell) and HIDDEN_KINDS.has(String(rooms[cell]["kind"]))

func is_discovered(cell: Vector2i) -> bool:
	return rooms.has(cell) and bool(rooms[cell]["discovered"])

func reveal(cell: Vector2i) -> void:
	if not rooms.has(cell):
		return
	var data: Dictionary = rooms[cell]
	data["discovered"] = true
	rooms[cell] = data

func hidden_neighbor_direction(cell: Vector2i,include_super: bool = true) -> Vector2i:
	for dir: Vector2i in CARDINALS:
		var next := cell+dir
		if not rooms.has(next):
			continue
		var k := kind(next)
		if k=="secreta" or (include_super and k=="supersecreta"):
			if not is_discovered(next):
				return dir
	return Vector2i.ZERO

func distance(cell: Vector2i) -> int:
	if not rooms.has(cell):
		return 0
	return int(rooms[cell]["distance"])

func is_cleared(cell: Vector2i) -> bool:
	return rooms.has(cell) and bool(rooms[cell]["cleared"])

func set_cleared(cell: Vector2i,value: bool = true) -> void:
	if not rooms.has(cell):
		return
	var data: Dictionary = rooms[cell]
	data["cleared"] = value
	rooms[cell] = data

func mark_entered(cell: Vector2i) -> void:
	if not rooms.has(cell):
		return
	var data: Dictionary = rooms[cell]
	data["visited"] = true
	data["discovered"] = true
	rooms[cell] = data
	_mark_discovered(cell)

func _mark_discovered(cell: Vector2i) -> void:
	if rooms.has(cell):
		var here: Dictionary = rooms[cell]
		here["discovered"] = true
		rooms[cell] = here
	for next: Vector2i in neighbors(cell):
		if is_hidden(next):
			continue
		var data: Dictionary = rooms[next]
		data["discovered"] = true
		rooms[next] = data

func _assign_distances() -> void:
	if not rooms.has(Vector2i.ZERO):
		return
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var distances: Dictionary = {Vector2i.ZERO:0}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var d := int(distances[cell])
		var data: Dictionary = rooms[cell]
		data["distance"] = d
		rooms[cell] = data
		for next: Vector2i in neighbors(cell):
			if distances.has(next):
				continue
			distances[next] = d+1
			queue.append(next)

func _assign_room_kinds() -> void:
	for cell: Vector2i in order:
		_set_kind(cell,"combate")
	_set_kind(Vector2i.ZERO,"inicio")

	var boss := critical_path[-1] if critical_path.size()>1 else _pick_farthest_dead_end([])
	_set_kind(boss,"jefe")
	var excluded: Array[Vector2i] = [Vector2i.ZERO,boss]

	# The reward is deliberately placed on an optional branch whenever possible.
	var reward := _pick_branch_dead_end(excluded,2)
	if reward == Vector2i.ZERO:
		reward = _pick_farthest_dead_end(excluded)
	if reward != Vector2i.ZERO:
		_set_kind(reward,"recompensa")
		excluded.append(reward)

	# Shops live in the first half of the critical route: useful, but never free at spawn.
	var shop := _pick_main_route_cell(excluded,1,maxi(2,critical_path.size()/2))
	if shop == Vector2i.ZERO:
		shop = _pick_shop_cell(excluded)
	if shop != Vector2i.ZERO:
		_set_kind(shop,"tienda")
		excluded.append(shop)

	# Challenge rooms are optional risk/reward detours.
	var challenge := _pick_branch_cell(excluded,2)
	if challenge == Vector2i.ZERO:
		challenge = _pick_regular_cell(excluded,2)
	if challenge != Vector2i.ZERO:
		_set_kind(challenge,"desafio")
		excluded.append(challenge)

	# A late miniboss pressures the main route before the floor guardian.
	var miniboss := _pick_main_route_cell(excluded,maxi(2,critical_path.size()/2),maxi(2,critical_path.size()-2))
	if miniboss == Vector2i.ZERO:
		miniboss = _pick_regular_cell(excluded,3)
	if miniboss != Vector2i.ZERO:
		_set_kind(miniboss,"minijefe")
		excluded.append(miniboss)

	var sacrifice := _pick_branch_dead_end(excluded,2)
	if sacrifice == Vector2i.ZERO:
		sacrifice = _pick_dead_end_or_regular(excluded,2)
	if sacrifice != Vector2i.ZERO:
		_set_kind(sacrifice,"sacrificio")
		excluded.append(sacrifice)

	# Ambushes favour connector rooms, so they feel like danger on the route rather than loot rooms.
	var ambush := _pick_connector_cell(excluded,2)
	if ambush == Vector2i.ZERO:
		ambush = _pick_regular_cell(excluded,2)
	if ambush != Vector2i.ZERO:
		_set_kind(ambush,"emboscada")

func _build_critical_path() -> void:
	critical_path.clear()
	var target := _pick_farthest_dead_end([])
	if target == Vector2i.ZERO:
		critical_path.append(Vector2i.ZERO)
		return
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var parents: Dictionary = {Vector2i.ZERO:Vector2i(9999,9999)}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == target:
			break
		for next: Vector2i in neighbors(cell):
			if parents.has(next):
				continue
			parents[next] = cell
			queue.append(next)
	var cursor := target
	var reversed_path: Array[Vector2i] = [cursor]
	while cursor != Vector2i.ZERO and parents.has(cursor):
		cursor = parents[cursor]
		if cursor != Vector2i(9999,9999):
			reversed_path.append(cursor)
	reversed_path.reverse()
	critical_path = reversed_path

func _assign_route_roles() -> void:
	for cell: Vector2i in order:
		var data: Dictionary = rooms[cell]
		data["route_role"] = "main" if cell in critical_path else "branch"
		rooms[cell] = data

func route_role(cell: Vector2i) -> String:
	if not rooms.has(cell):
		return "branch"
	return String(rooms[cell].get("route_role","branch"))

func route_label(cell: Vector2i) -> String:
	if is_hidden(cell):
		return "OCULTA"
	if cell == Vector2i.ZERO:
		return "ENTRADA"
	if route_role(cell) == "main":
		return "RUTA"
	return "DESVÍO"

func risk_level(cell: Vector2i) -> int:
	if not rooms.has(cell):
		return 0
	var value := mini(3,maxi(0,distance(cell)/2))
	if route_role(cell) == "branch":
		value = mini(3,value+1)
	match kind(cell):
		"desafio","minijefe","emboscada","sacrificio":
			value = mini(3,value+1)
	return value

func _pick_branch_dead_end(excluded: Array[Vector2i],minimum_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell in excluded or cell==Vector2i.ZERO:
			continue
		if route_role(cell)!="branch" or distance(cell)<minimum_distance:
			continue
		if neighbors(cell).size()==1:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return distance(a)>distance(b)
	)
	return candidates[0]

func _pick_branch_cell(excluded: Array[Vector2i],minimum_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell in excluded or cell==Vector2i.ZERO:
			continue
		if route_role(cell)=="branch" and distance(cell)>=minimum_distance:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[_rng.randi_range(0,candidates.size()-1)]

func _pick_main_route_cell(excluded: Array[Vector2i],minimum_step: int,maximum_step: int) -> Vector2i:
	if critical_path.size()<=2:
		return Vector2i.ZERO
	var candidates: Array[Vector2i] = []
	for i in range(1,critical_path.size()-1):
		var cell := critical_path[i]
		if cell in excluded:
			continue
		if i>=minimum_step and i<=maximum_step:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[_rng.randi_range(0,candidates.size()-1)]

func _pick_connector_cell(excluded: Array[Vector2i],minimum_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell in excluded or cell==Vector2i.ZERO or distance(cell)<minimum_distance:
			continue
		if neighbors(cell).size()>=2:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[_rng.randi_range(0,candidates.size()-1)]

func _append_hidden_room(hidden_kind: String,prefer_far: bool) -> void:
	var hosts: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell == Vector2i.ZERO:
			continue
		if kind(cell) in ["jefe","recompensa","tienda","sacrificio"]:
			continue
		if prefer_far and distance(cell)<3:
			continue
		var empty_dirs := _empty_directions(cell)
		if not empty_dirs.is_empty():
			hosts.append(cell)
	if hosts.is_empty() and prefer_far:
		for cell: Vector2i in order:
			if cell != Vector2i.ZERO and kind(cell)!="jefe" and not _empty_directions(cell).is_empty():
				hosts.append(cell)
	if hosts.is_empty():
		return

	if prefer_far:
		hosts.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
			return distance(a)>distance(b)
		)
		hosts = hosts.slice(0,mini(3,hosts.size()))

	var host := hosts[_rng.randi_range(0,hosts.size()-1)]
	var dirs := _empty_directions(host)
	dirs.shuffle()
	var cell := host+dirs[0]
	_add_room(cell)
	_set_kind(cell,hidden_kind)
	var data: Dictionary = rooms[cell]
	data["discovered"] = false
	rooms[cell] = data

func _empty_directions(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in CARDINALS:
		var candidate := cell+dir
		if rooms.has(candidate):
			continue
		if absi(candidate.x)>5 or absi(candidate.y)>4:
			continue
		result.append(dir)
	return result

func _set_kind(cell: Vector2i,value: String) -> void:
	if not rooms.has(cell):
		return
	var data: Dictionary = rooms[cell]
	data["kind"] = value
	rooms[cell] = data

func _pick_farthest_dead_end(excluded: Array[Vector2i]) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := -1
	for cell: Vector2i in order:
		if cell in excluded or cell==Vector2i.ZERO:
			continue
		if neighbors(cell).size()!=1:
			continue
		var d := distance(cell)
		if d>best_distance:
			best = cell
			best_distance = d
	if best_distance>=0:
		return best
	return _pick_regular_cell(excluded,1)

func _pick_dead_end_or_regular(excluded: Array[Vector2i],minimum_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell in excluded or cell==Vector2i.ZERO:
			continue
		if distance(cell)>=minimum_distance and neighbors(cell).size()==1:
			candidates.append(cell)
	if not candidates.is_empty():
		return candidates[_rng.randi_range(0,candidates.size()-1)]
	return _pick_regular_cell(excluded,minimum_distance)

func _pick_shop_cell(excluded: Array[Vector2i]) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell in excluded:
			continue
		var d := distance(cell)
		if d>=1 and d<=4:
			candidates.append(cell)
	if candidates.is_empty():
		return _pick_regular_cell(excluded,1)
	return candidates[_rng.randi_range(0,candidates.size()-1)]

func _pick_regular_cell(excluded: Array[Vector2i],minimum_distance: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in order:
		if cell in excluded:
			continue
		if distance(cell)>=minimum_distance:
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[_rng.randi_range(0,candidates.size()-1)]

func outward_direction(cell: Vector2i) -> Vector2i:
	var preferred := CARDINALS.duplicate()
	preferred.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return (cell+a).length_squared()>(cell+b).length_squared()
	)
	for dir: Vector2i in preferred:
		if not rooms.has(cell+dir):
			return dir
	return Vector2i(0,-1)

func reveal_public_rooms() -> void:
	for cell: Vector2i in order:
		if is_hidden(cell):
			continue
		var data: Dictionary = rooms[cell]
		data["discovered"] = true
		rooms[cell] = data

func minimap_text(current: Vector2i) -> String:
	var visible: Array[Vector2i] = []
	for cell_variant in rooms.keys():
		var cell: Vector2i = cell_variant
		var data: Dictionary = rooms[cell]
		if bool(data["discovered"]):
			visible.append(cell)
	if visible.is_empty():
		return "◆"

	var min_x := visible[0].x
	var max_x := visible[0].x
	var min_y := visible[0].y
	var max_y := visible[0].y
	for cell: Vector2i in visible:
		min_x = mini(min_x,cell.x)
		max_x = maxi(max_x,cell.x)
		min_y = mini(min_y,cell.y)
		max_y = maxi(max_y,cell.y)

	var width := (max_x-min_x)*2+1
	var height := (max_y-min_y)*2+1
	var grid: Array = []
	for y in range(height):
		var row: Array[String] = []
		for x in range(width):
			row.append(" ")
		grid.append(row)

	for cell: Vector2i in visible:
		var gx := (cell.x-min_x)*2
		var gy := (cell.y-min_y)*2
		grid[gy][gx] = _room_symbol(cell,current)
		for next: Vector2i in neighbors(cell):
			if not rooms.has(next) or not is_discovered(next):
				continue
			var dx := next.x-cell.x
			var dy := next.y-cell.y
			var cx := gx+dx
			var cy := gy+dy
			if cy>=0 and cy<height and cx>=0 and cx<width:
				grid[cy][cx] = "─" if dx!=0 else "│"

	var lines: Array[String] = []
	for row: Array[String] in grid:
		lines.append("".join(row))
	return "\n".join(lines)

func _room_symbol(cell: Vector2i,current: Vector2i) -> String:
	if cell==current:
		return "◆"
	var data: Dictionary = rooms[cell]
	if not bool(data["visited"]):
		return "□"
	match String(data["kind"]):
		"inicio": return "○"
		"jefe": return "☠"
		"recompensa": return "✦"
		"tienda": return "$"
		"emboscada": return "!"
		"desafio": return "D"
		"minijefe": return "M"
		"sacrificio": return "†"
		"secreta": return "?"
		"supersecreta": return "★"
		_: return "■"
