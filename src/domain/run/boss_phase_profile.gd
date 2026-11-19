extends RefCounted
class_name IsmaelBossPhaseProfile

# Solo guardianes principales: el Guardián Menor no gana fases nuevas.
# Umbrales deliberadamente amplios, sin aumentar la salud existente.
const SECOND_PHASE_PERCENT := 55
const LAST_PHASE_PERCENT := 25

static func phase_for_health(health: int, max_health: int) -> int:
	if health <= 0:
		return 0
	if max_health <= 0:
		return 1
	if health * 100 <= max_health * LAST_PHASE_PERCENT:
		return 3
	if health * 100 <= max_health * SECOND_PHASE_PERCENT:
		return 2
	return 1

static func speed_multiplier(floor_index: int, phase: int) -> float:
	if phase <= 1:
		return 1.0
	var increases: Array[float] = [0.07,0.16,0.08,0.04,0.10,0.08,0.07]
	var bonus := increases[clampi(floor_index,1,increases.size())-1]
	return 1.0 + bonus * (1.0 if phase == 2 else 1.65)

static func attack_multiplier(phase: int) -> float:
	match phase:
		2: return 0.92
		3: return 0.84
		_: return 1.0

static func mechanic_stride(phase: int) -> int:
	return 4 if phase <= 1 else (3 if phase == 2 else 3)

static func phase_title(floor_index: int, phase: int) -> String:
	if phase == 2:
		match clampi(floor_index,1,7):
			1: return "EL CARCELERO · CIERRE DE CELDAS"
			2: return "LA MANDÍBULA · HAMBRE DESATADA"
			3: return "EL VIGÍA · MIRADA DESPIERTA"
			4: return "EL SEPULTURERO · TUMBAS ABIERTAS"
			5: return "EL HUECO · ECO DEL ABISMO"
			6: return "EL CORROÍDO · CANALES ROTOS"
			_: return "LA CAMPANA ROTA · PRIMER TAÑIDO"
	if phase == 3:
		match clampi(floor_index,1,7):
			1: return "ÚLTIMO CERROJO"
			2: return "HAMBRE FINAL"
			3: return "OJO DEL JUICIO"
			4: return "EL ÚLTIMO ENTIERRO"
			5: return "EL VACÍO RESPONDE"
			6: return "OXIDACIÓN TOTAL"
			_: return "ÚLTIMA CAMPANADA"
	return "PRIMER SELLO"

static func phase_subtitle(phase: int) -> String:
	match phase:
		2: return "FASE II · EL GUARDIÁN CAMBIA SU RITMO"
		3: return "FASE III · ÚLTIMO ESFUERZO · BUSCA UNA BRECHA"
		_: return "FASE I"
