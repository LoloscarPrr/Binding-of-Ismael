extends RefCounted
class_name IsmaelBossSealCatalog

# Datos puros para presentación, recompensas y crónicas.
# No se crean enemigos ni se cambian sus puntos de vida.
const BOSSES := [
	{
		"name":"EL CARCELERO","seal":"SELLO DE LOS GRILLETES",
		"omen":"LAS PUERTAS SE CIERRAN · LOS GRILLETES DESPIERTAN",
		"lore":"Antiguo custodio de la entrada. Encerró a quienes intentaron recordar el camino de regreso.",
		"tip":"Lee la apertura del abanico: sus proyectiles dejan huecos entre barrotes.",
		"rewards":["escudo","cadencia","movimiento"],"accent":Color(0.85,0.27,0.23)
	},
	{
		"name":"LA MANDÍBULA","seal":"SELLO DEL HAMBRE",
		"omen":"EL HAMBRE NO DUERME BAJO LAS FOSAS",
		"lore":"Una boca nacida del hambre de las Fosas. Devora juramentos y devuelve solamente huesos.",
		"tip":"Sus ráfagas alternan abanicos y anillos. Nunca te quedes inmóvil frente a ella.",
		"rewards":["dano","curacion","vida"],"accent":Color(0.94,0.53,0.20)
	},
	{
		"name":"EL VIGÍA","seal":"SELLO DE LA MIRADA",
		"omen":"TE HA VISTO · TODA SOMBRA ES UNA SEÑAL",
		"lore":"El ojo que custodia las Catacumbas observa cada sendero, pero es incapaz de comprender la compasión.",
		"tip":"Mira las señales del suelo: alterna cruces y disparos rectos de alta velocidad.",
		"rewards":["buscadora","mapa","lente"],"accent":Color(0.64,0.45,0.92)
	},
	{
		"name":"EL SEPULTURERO","seal":"SELLO DE LA TUMBA",
		"omen":"LAS TUMBAS GUARDAN LO QUE NUNCA MURIÓ",
		"lore":"Acarrea los nombres olvidados y los entierra en círculos, siempre dejando un camino estrecho a la salida.",
		"tip":"Sus anillos tienen una brecha rotatoria. Síguela en lugar de huir en línea recta.",
		"rewards":["perforante","alma","adrenalina"],"accent":Color(0.46,0.79,0.79)
	},
	{
		"name":"EL HUECO","seal":"SELLO DEL VACÍO",
		"omen":"EL ÚLTIMO SELLO NO QUIERE SER ROTO",
		"lore":"No es un guardián: es el espacio que dejaron todos los demás al desaparecer.",
		"tip":"Alterna cuatro patrones. Observa la dirección del aviso y guarda espacio para la fase final.",
		"rewards":["eco_fragil","reloj_ceniza","escudo"],"accent":Color(0.80,0.36,0.70)
	}
]

static func definition(floor_index: int) -> Dictionary:
	return BOSSES[clampi(floor_index,1,5)-1].duplicate(true)

static func seal_title(floor_index: int) -> String:
	return String(definition(floor_index)["seal"])

static func boss_name(floor_index: int) -> String:
	return String(definition(floor_index)["name"])

static func omen(floor_index: int) -> String:
	return String(definition(floor_index)["omen"])

static func reward_choices(floor_index: int, encounter_seed: int, owned: Dictionary = {}) -> Array[String]:
	var pool: Array = definition(floor_index).get("rewards",[])
	var first := String(pool[posmod(encounter_seed+floor_index*7,pool.size())])
	var second := String(pool[posmod(encounter_seed+floor_index*7+1,pool.size())])
	if owned.has(first) and not owned.has(second):
		return [second,first]
	return [first,second]

static func codex_entry(floor_index: int, victories: int) -> String:
	var entry := definition(floor_index)
	var title := String(entry["name"])
	var seal := String(entry["seal"])
	if victories <= 0:
		return "P%d · ??? · SELLO SIN DESCUBRIR\nVence al guardián para descubrir su historia.\n" % floor_index
	return "P%d · %s · %s\nDERROTADO %d %s\n%s\nESTRATEGIA: %s\n" % [
		floor_index,title,seal,victories,"VEZ" if victories == 1 else "VECES",
		String(entry["lore"]),String(entry["tip"])
	]
