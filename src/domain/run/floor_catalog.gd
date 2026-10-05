extends RefCounted
class_name IsmaelFloorCatalog

const TOTAL_FLOORS := 5

static func floor_name(floor_index: int) -> String:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1: return "SÓTANO"
		2: return "FOSAS"
		3: return "CATACUMBAS"
		4: return "CRIPTA"
		_: return "ABISMO"

static func boss_name(floor_index: int) -> String:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1: return "EL CARCELERO"
		2: return "LA MANDÍBULA"
		3: return "EL VIGÍA"
		4: return "EL SEPULTURERO"
		_: return "EL HUECO"

static func enemy_pool(floor_index: int) -> Array[String]:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1:
			return ["chaser","dasher","orbiter","flyer","chaser"]
		2:
			return ["chaser","dasher","orbiter","brute","flyer","leaper"]
		3:
			return ["dasher","orbiter","brute","spitter","flyer","turret","leaper"]
		4:
			return ["orbiter","brute","spitter","stalker","turret","leaper","flyer","spitter"]
		_:
			return ["brute","spitter","stalker","orbiter","turret","leaper","flyer","stalker","brute"]

static func challenge_waves(floor_index: int) -> int:
	if floor_index >= 4:
		return 4
	if floor_index >= 3:
		return 3
	return 2

static func enemy_cap(floor_index: int) -> int:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1: return 8
		2: return 9
		3: return 10
		4: return 10
		_: return 11

static func enemy_count_bonus(floor_index: int) -> int:
	return 1 if floor_index >= 4 else 0

static func miniboss_variant(floor_index: int) -> String:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1: return "boss"
		2: return "brute"
		3: return "spitter"
		4: return "stalker"
		_: return "brute"
