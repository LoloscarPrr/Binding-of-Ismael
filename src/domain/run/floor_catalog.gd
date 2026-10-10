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

static func floor_identity(floor_index: int) -> String:
	match clampi(floor_index,1,TOTAL_FLOORS):
		1: return "ESPACIOS ABIERTOS · PRESIÓN BÁSICA"
		2: return "CARGAS · PINZAS · PÚAS"
		3: return "FUEGO CRUZADO · COBERTURAS · LLAMAS"
		4: return "EMBUDOS · ACECHO · ALTA PRESIÓN"
		_: return "CAOS MIXTO · RIESGO MÁXIMO"

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

static func encounter_roster(
	floor_index: int,
	encounter_seed: int,
	count: int,
	room_kind: String = "combate",
	layout_profile: String = "abierta"
) -> Array[String]:
	var pool := enemy_pool(floor_index)
	var melee: Array[String] = ["chaser","brute","flyer"]
	var chargers: Array[String] = ["dasher","leaper","stalker"]
	var ranged: Array[String] = ["orbiter","spitter","turret"]
	var pattern := posmod(encounter_seed+floor_index*3,5)
	if room_kind == "emboscada":
		pattern = 1
	elif room_kind == "desafio":
		pattern = posmod(encounter_seed,4)+1
	elif room_kind == "maldicion":
		pattern = 4

	# Layout can override the generic encounter rhythm. This makes room geometry
	# matter tactically without introducing new enemy classes.
	match layout_profile:
		"abierta":
			pattern = 3 # mobile ranged pressure works best with room to kite.
		"barricada":
			pattern = 2 # ranged units exploit sight lines while melee flushes cover.
		"columnas":
			pattern = 3 # orbiters/chargers force movement around cover islands.
		"cruzada","arena_cruzada":
			pattern = 2 # crossfire rewards breaking lines of sight.
		"embudo","corredor_maldito":
			pattern = 1 # chargers turn narrow lanes into positional threats.
		"islas":
			pattern = 3 # mobile threats punish staying behind one island.
		"pinza":
			pattern = 1
		"arena":
			pattern = 4

	var roster: Array[String] = []
	for i in range(count):
		var candidates: Array[String]
		match pattern:
			0: # Presión frontal: masa cuerpo a cuerpo con una amenaza puntual.
				candidates = chargers if i == count-1 and count >= 4 else melee
			1: # Emboscada: varias cargas obligan a reposicionarse.
				candidates = chargers if i%3 != 2 else melee
			2: # Fuego cruzado: tiradores protegidos por uno o dos perseguidores.
				candidates = ranged if i%3 != 0 else melee
			3: # Cerco móvil: orbitadores/rango + cargadores.
				candidates = ranged if i%2 == 0 else chargers
			_: # Mixta de alta presión.
				match i%3:
					0: candidates = melee
					1: candidates = chargers
					_: candidates = ranged
		var valid: Array[String] = []
		for kind_id in candidates:
			if pool.has(kind_id):
				valid.append(kind_id)
		if valid.is_empty():
			valid = pool
		roster.append(valid[posmod(encounter_seed+i*2+floor_index,valid.size())])
	return roster

static func encounter_name(
	floor_index: int,
	encounter_seed: int,
	room_kind: String = "combate",
	layout_profile: String = "abierta"
) -> String:
	if room_kind == "emboscada":
		return "EMBOSCADA MÓVIL"
	if room_kind == "maldicion":
		return "CERCO MALDITO"
	match layout_profile:
		"barricada","cruzada","arena_cruzada":
			return "FUEGO CRUZADO"
		"embudo","corredor_maldito","pinza":
			return "CARGA"
		"abierta","columnas","islas":
			return "CERCO"
	var pattern := posmod(encounter_seed+floor_index*3,5)
	match pattern:
		0: return "PRESIÓN FRONTAL"
		1: return "CARGA"
		2: return "FUEGO CRUZADO"
		3: return "CERCO"
		_: return "ASALTO MIXTO"

static func room_layout_profile(
	floor_index: int,
	room_kind: String,
	room_seed: int,
	route_role: String = "branch",
	risk_level: int = 0
) -> String:
	if room_kind == "jefe":
		return "boss_arena"
	if room_kind == "minijefe":
		return "duelo"
	if room_kind == "desafio":
		return "arena_cruzada" if floor_index>=3 else "arena"
	if room_kind == "emboscada":
		return "pinza"
	if room_kind == "maldicion":
		return "corredor_maldito"
	if room_kind not in ["combate"]:
		return "abierta"

	var profiles: Array[String] = []
	match clampi(floor_index,1,TOTAL_FLOORS):
		1:
			profiles = ["abierta","abierta","barricada","columnas"]
		2:
			profiles = ["barricada","pinza","columnas","embudo"]
		3:
			profiles = ["cruzada","columnas","islas","barricada"]
		4:
			profiles = ["embudo","pinza","cruzada","islas"]
		_:
			profiles = ["embudo","cruzada","islas","columnas","barricada"]
	if risk_level>=2:
		profiles.append("embudo")
	if route_role=="main" and risk_level<=1:
		profiles.append("abierta")
	return profiles[posmod(room_seed+floor_index*11+risk_level*7,profiles.size())]

static func room_layout_title(profile: String) -> String:
	match profile:
		"barricada": return "BARRICADA"
		"columnas": return "COLUMNAS"
		"cruzada": return "FUEGO CRUZADO"
		"embudo": return "EMBUDO"
		"islas": return "ISLAS"
		"pinza": return "PINZA"
		"arena": return "ARENA"
		"arena_cruzada": return "ARENA CRUZADA"
		"duelo": return "DUELO"
		"boss_arena": return "ARENA DEL GUARDIÁN"
		"corredor_maldito": return "CORREDOR MALDITO"
		_: return "ABIERTA"

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
