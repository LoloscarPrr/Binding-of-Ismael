extends RefCounted
class_name IsmaelVisualSpriteAtlas

# Fase 12.1: arte vectorial propio, importado por Godot como textura.
# Reemplaza el render corporal; la física, VFX, fases y telegráficos
# continúan en sus nodos originales.
const ISMAEL_IDLE = preload("res://assets/art/phase12/ismael_idle.svg")
const ISMAEL_STEP_A = preload("res://assets/art/phase12/ismael_stride_a.svg")
const ISMAEL_STEP_B = preload("res://assets/art/phase12/ismael_stride_b.svg")
const ENEMY_CHASER = preload("res://assets/art/phase12/enemy_chaser.svg")
const ENEMY_DASHER = preload("res://assets/art/phase12/enemy_dasher.svg")
const ENEMY_ORBITER = preload("res://assets/art/phase12/enemy_orbiter.svg")
const ENEMY_BRUTE = preload("res://assets/art/phase12/enemy_brute.svg")
const ENEMY_SPITTER = preload("res://assets/art/phase12/enemy_spitter.svg")
const ENEMY_STALKER = preload("res://assets/art/phase12/enemy_stalker.svg")
const BOSS_CARCELERO = preload("res://assets/art/phase12/boss_carcelero.svg")
const BOSS_MANDIBULA = preload("res://assets/art/phase12/boss_mandibula.svg")
const BOSS_VIGIA = preload("res://assets/art/phase12/boss_vigia.svg")
const BOSS_SEPULTURERO = preload("res://assets/art/phase12/boss_sepulturero.svg")
const BOSS_HUECO = preload("res://assets/art/phase12/boss_hueco.svg")

static func player_texture(moving: bool, age_seconds: float) -> Texture2D:
	if not moving:
		return ISMAEL_IDLE
	return ISMAEL_STEP_A if posmod(int(age_seconds*8.0),2)==0 else ISMAEL_STEP_B

static func enemy_texture(kind_id: String) -> Texture2D:
	match kind_id:
		"chaser": return ENEMY_CHASER
		"dasher": return ENEMY_DASHER
		"orbiter": return ENEMY_ORBITER
		"brute": return ENEMY_BRUTE
		"spitter": return ENEMY_SPITTER
		"stalker": return ENEMY_STALKER
	return ENEMY_CHASER

static func boss_texture(floor_index: int) -> Texture2D:
	match clampi(floor_index,1,5):
		1: return BOSS_CARCELERO
		2: return BOSS_MANDIBULA
		3: return BOSS_VIGIA
		4: return BOSS_SEPULTURERO
		_: return BOSS_HUECO

static func player_draw_rect() -> Rect2:
	return Rect2(-43.0,-49.0,86.0,86.0)

static func enemy_draw_rect(kind_id: String) -> Rect2:
	match kind_id:
		"brute": return Rect2(-38.0,-39.0,76.0,76.0)
		"stalker": return Rect2(-31.0,-33.0,62.0,65.0)
	return Rect2(-34.0,-37.0,68.0,70.0)

static func boss_draw_rect() -> Rect2:
	return Rect2(-77.0,-82.0,154.0,154.0)
