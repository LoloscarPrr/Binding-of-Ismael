extends SceneTree

# Pruebas de humo sin interfaz: se ejecutan antes de exportar el APK.
# No abren ni escriben perfiles reales del usuario.
const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const FloorCatalog = preload("res://src/domain/run/floor_catalog.gd")
const RunProgress = preload("res://src/domain/run/run_progress.gd")
const Player = preload("res://scripts/player.gd")

var _errors: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _assert(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
		printerr("QA FAIL: " + message)

func _run_tests() -> void:
	_test_item_definitions()
	_test_floor_rosters()
	_test_metaprogression()
	_test_shot_cancellation()
	if _errors.is_empty():
		print("QA PASS: %d checks" % _checks)
		quit(0)
	else:
		printerr("QA FAIL: %d of %d checks failed" % [_errors.size(),_checks])
		quit(1)

func _test_item_definitions() -> void:
	var ids: Array[String] = ItemCatalog.reward_ids()
	_assert(ids.size() >= 23,"Se perdieron recompensas del catálogo")
	var seen: Dictionary = {}
	for id in ids:
		_assert(not seen.has(id),"Reliquia repetida: " + id)
		seen[id] = true
		var definition: Dictionary = ItemCatalog.reward_definition(id)
		_assert(not String(definition.get("effect","")).is_empty(),"Reliquia sin efecto: " + id)
	for id in ["eco_fragil","reloj_ceniza","colmillo_ritual"]:
		_assert(ids.has(id),"Falta reliquia meta: " + id)
	var synergy: Dictionary = ItemCatalog.synergy_definition("eco_sangrante")
	_assert(not synergy.is_empty(),"Se perdió sinergia Eco Sangrante")

func _test_floor_rosters() -> void:
	for floor_number in range(1,6):
		var pool: Array[String] = FloorCatalog.enemy_pool(floor_number)
		_assert(not pool.is_empty(),"Piso sin enemigos: %d" % floor_number)
		for seed_value in [11,42,137,927]:
			var roster: Array[String] = FloorCatalog.encounter_roster(floor_number,seed_value,7,"combate","arena")
			var repeated: Array[String] = FloorCatalog.encounter_roster(floor_number,seed_value,7,"combate","arena")
			_assert(roster.size() == 7,"Cantidad incorrecta de enemigos en piso %d" % floor_number)
			_assert(roster == repeated,"Encuentro no determinista en piso %d" % floor_number)
			for enemy_id in roster:
				_assert(pool.has(enemy_id.trim_suffix("_elite")),"Enemigo fuera del pool del piso %d: %s" % [floor_number,enemy_id])

func _test_metaprogression() -> void:
	var progress = RunProgress.new()
	_assert(not progress.has_unlock("santuario_eco"),"Santuario debería exigir una victoria")
	progress.max_floor_reached = 3
	_assert(progress.has_unlock("eco_fragil"),"Esquirla no desbloquea en piso 3")
	progress.events_resolved = 2
	_assert(progress.has_unlock("reloj_ceniza"),"Reloj no desbloquea al resolver eventos")
	progress.pacts_sealed = 3
	_assert(progress.has_unlock("colmillo_ritual"),"Colmillo no desbloquea al sellar pactos")
	progress.runs_completed = 1
	_assert(progress.has_unlock("santuario_eco"),"Cámara del Eco no desbloquea al ganar")
	progress.echo_challenges_completed = 3
	_assert(progress.has_unlock("corona_del_eco"),"Corona no desbloquea con tres desafíos")

func _test_shot_cancellation() -> void:
	var player = Player.new()
	player._shoot_pose = 0.13
	var previous_generation := int(player.get("_shot_generation"))
	player.cancel_queued_shots()
	_assert(int(player.get("_shot_generation")) == previous_generation+1,"Ráfagas pendientes no se invalidan")
	_assert(is_zero_approx(player._shoot_pose),"El estado de disparo no se restablece")
	player.free()
