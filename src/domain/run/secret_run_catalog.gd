extends RefCounted
class_name IsmaelSecretRunCatalog

# Contenido post-victoria; deterministicamente ligado al piso y al mapa.
# No sustituye al jefe, al minijefe ni a la tienda.
static func vault_unlocked(completions: int) -> bool:
	return completions >= 1

static func vault_variant(seed_value: int, floor_number: int, cell: Vector2i) -> String:
	var roll := posmod(seed_value+floor_number*79+cell.x*53+cell.y*31,3)
	match roll:
		0: return "reloj"
		1: return "urna"
		_: return "espejo"

static func vault_title(variant: String) -> String:
	match variant:
		"reloj": return "CRIPTA DEL TIEMPO ROTO"
		"urna": return "CRIPTA DE LAS CENIZAS"
		_: return "CRIPTA DEL ESPEJO"

static func vault_reward(variant: String, risk_choice: bool) -> String:
	if risk_choice:
		match variant:
			"reloj": return "reloj_ceniza"
			"urna": return "colmillo_ritual"
			_: return "eco_fragil"
	match variant:
		"reloj": return "escudo"
		"urna": return "alma"
		_: return "perforante"

static func anomaly_unlocked(completions: int) -> bool:
	return completions >= 1

static func anomaly_appears(seed_value: int, floor_number: int) -> bool:
	return floor_number >= 2 and posmod(seed_value*7+floor_number*41+19,100) < 52

static func anomaly_variant(seed_value: int, floor_number: int, cell: Vector2i) -> String:
	var roll := posmod(seed_value+floor_number*137+cell.x*19+cell.y*83,3)
	match roll:
		0: return "asedio"
		1: return "acecho"
		_: return "ceniza"

static func anomaly_title(variant: String) -> String:
	match variant:
		"asedio": return "ANOMALÍA · EL ASEDIO"
		"acecho": return "ANOMALÍA · EL ACECHO"
		_: return "ANOMALÍA · CENIZAS VIVAS"

static func anomaly_description(variant: String) -> String:
	match variant:
		"asedio": return "UNA OLEADA MÁS DENSA · NO TE DEJES RODEAR"
		"acecho": return "LOS PERSEGUIDORES SON MÁS RÁPIDOS · LEE SU MOVIMIENTO"
		_: return "SUELO INESTABLE · CUIDA TUS PASOS"

static func anomaly_bonus_enemies(variant: String) -> int:
	return 2 if variant == "asedio" else (1 if variant == "acecho" else 0)
