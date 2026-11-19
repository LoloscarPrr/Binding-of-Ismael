extends RefCounted
class_name IsmaelGuardianEchoCatalog

# Los Ecos aparecen solo en salas de combate convertidas. Cada encuentro
# tiene dos roles reales: custodio defensor y heraldo a distancia.
static func title(floor_index: int) -> String:
	match clampi(floor_index,1,7):
		1: return "ECO DEL CARCELERO"
		2: return "ECO DE LA MANDÍBULA"
		3: return "ECO DEL VIGÍA"
		4: return "ECO DEL SEPULTURERO"
		5: return "ECO DEL HUECO"
		6: return "ECO DEL CORROÍDO"
		_: return "ECO DE LA CAMPANA"

static func herald_kind(floor_index: int) -> String:
	match clampi(floor_index,1,7):
		1: return "orbiter"
		2: return "leaper"
		3: return "spitter"
		4: return "burrower"
		5: return "stalker"
		6: return "spitter"
		_: return "leaper"

static func reward(floor_index: int) -> String:
	match clampi(floor_index,1,7):
		1: return "escudo"
		2: return "dano"
		3: return "buscadora"
		4: return "perforante"
		5: return "eco_fragil"
		6: return "alma"
		_: return "reloj_ceniza"

static func support_roster(floor_index: int) -> Array[String]:
	match clampi(floor_index,1,7):
		1: return ["chaser","dasher"]
		2: return ["leaper","shielded"]
		3: return ["turret","spitter"]
		4: return ["burrower","stalker"]
		5: return ["flyer","splitter"]
		6: return ["shielded","spitter"]
		_: return ["leaper","splitter"]

static func should_appear(seed_value: int, floor_index: int) -> bool:
	# 62% por piso; 1 cámara como máximo en cada piso.
	return posmod(seed_value*3+floor_index*187+53,100) < 62

static func tribute_cost(floor_index: int) -> int:
	return 6+maxi(0,floor_index-1)*2

static func trial_enemy_count(floor_index: int) -> int:
	return mini(4+floor_index/2,6)
