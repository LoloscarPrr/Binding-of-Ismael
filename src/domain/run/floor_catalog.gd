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
			return ["chaser","dasher","orbiter"]
		2:
			return ["chaser","dasher","orbiter","brute","chaser"]
		3:
			return ["chaser","dasher","orbiter","brute","spitter","orbiter"]
		4:
			return ["dasher","orbiter","brute","spitter","stalker","spitter"]
		_:
			return ["brute","spitter","stalker","orbiter","stalker","brute","dasher"]

static func challenge_waves(floor_index: int) -> int:
	if floor_index >= 3:
		return 3
	return 2

static func enemy_cap(floor_index: int) -> int:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1,2: return 8
		3: return 9
		_: return 10

static func enemy_count_bonus(floor_index: int) -> int:
	return 1 if floor_index >= 4 else 0

static func miniboss_variant(floor_index: int) -> String:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1: return "boss"
		2: return "brute"
		3: return "spitter"
		4: return "stalker"
		_: return "brute"
