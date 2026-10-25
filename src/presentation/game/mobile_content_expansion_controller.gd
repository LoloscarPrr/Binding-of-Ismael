extends "res://src/presentation/game/mobile_floor_expansion_controller.gd"

const ExtraEnemy = preload("res://scripts/extra_enemy.gd")
const RoomHazard = preload("res://scripts/room_hazard.gd")
const ExpandedItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const PactPedestal = preload("res://scripts/world_pact_pedestal.gd")
const EventPedestal = preload("res://scripts/world_event_pedestal.gd")
const RunProgress = preload("res://src/domain/run/run_progress.gd")
const VictorySummary = preload("res://scripts/victory_summary.gd")
const GameShell = preload("res://scripts/game_shell.gd")

var _prepared_content_floor := 0
var _unlocked_treasure_rooms: Dictionary = {}
var _pact_offers: Dictionary = {}
var _curse_rooms_remaining := 0
var _curse_active_in_room := false
var _rare_event_states: Dictionary = {}
var _echo_sanctuary_states: Dictionary = {}
var _floor_mutator := "normal"
var _mutator_floor := 0
var _route_blood := 0
var _route_witness := 0
var _route_wanderer := 0
var _abismo_route_applied := false
var _run_progress
var _meta_completion_recorded := false
var _meta_defeat_recorded := false
var _record_flags: Dictionary = {}
var _legacy_start_applied := false
var _run_started_msec := 0
var _enemies_defeated_total := 0
var _victory_summary: IsmaelVictorySummary
var _game_shell: IsmaelGameShell

func _ready() -> void:
	_run_started_msec = Time.get_ticks_msec()
	_run_progress = RunProgress.new()
	_run_progress.load_profile()
	super._ready()
	_apply_meta_starting_unlocks()
	_create_game_shell()

func _create_game_shell() -> void:
	if not is_instance_valid(hud_backdrop):
		return
	var layer := hud_backdrop.get_parent()
	if layer == null or is_instance_valid(_game_shell):
		return
	_game_shell = GameShell.new()
	_game_shell.configure(self,_run_progress,_audio_director)
	layer.add_child(_game_shell)

func _apply_meta_starting_unlocks() -> void:
	if _legacy_start_applied or _run_progress == null:
		return
	_legacy_start_applied = true
	if _run_progress.has_unlock("marca_del_hueco"):
		_bombs += 1
		_keys += 1
		_update_pickup_hud()

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	if _run_progress != null:
		_run_progress.record_floor(_floor_index)
	if _mutator_floor != _floor_index and _dungeon != null:
		_prepare_floor_mutator()
		_mutator_floor = _floor_index
	if _prepared_content_floor != _floor_index and _dungeon != null:
		_prepare_extra_room_kinds()
		_prepared_content_floor = _floor_index
	_clear_content_hazards()
	super._begin_room(entry_direction)
	_curse_active_in_room = false
	if _curse_rooms_remaining > 0 and _room_kind in ["combate","emboscada","desafio","minijefe","maldicion"]:
		_curse_active_in_room = true
		_curse_rooms_remaining -= 1
		if is_instance_valid(reward_label):
			reward_label.text = "PACTO MALDITO · %d SALAS RESTANTES" % _curse_rooms_remaining
	_spawn_content_hazards()
	if _room_kind == "inicio" and _floor_mutator != "normal":
		if is_instance_valid(status_label):
			status_label.text = "MUTADOR · %s" % _mutator_title()
		if is_instance_valid(reward_label):
			reward_label.text = _mutator_description()

	if _room_kind == "inicio" and _floor_index == 5:
		if is_instance_valid(status_label):
			status_label.text = _run_route_title()
		if is_instance_valid(reward_label):
			match _run_route():
				"sangre": reward_label.text = "El Abismo responde a tus pactos"
				"testigo": reward_label.text = "El Abismo ya no puede ocultarse"
				_: reward_label.text = "Llegaste al Abismo protegiendo lo que conservaste"

func _prepare_floor_mutator() -> void:
	if _dungeon == null:
		_floor_mutator = "normal"
		return
	var roll := posmod(_dungeon.seed_value+_floor_index*173,100)
	if roll >= 72:
		_floor_mutator = "normal"
		return
	var variants: Array[String] = ["enjambre","carne_dura","polvorin","velo"]
	_floor_mutator = variants[posmod(_dungeon.seed_value+_floor_index*41,variants.size())]

func _mutator_title() -> String:
	match _floor_mutator:
		"enjambre": return "ENJAMBRE"
		"carne_dura": return "CARNE DURA"
		"polvorin": return "POLVORÍN"
		"velo": return "VELO"
		_: return "SIN MUTADOR"

func _mutator_description() -> String:
	match _floor_mutator:
		"enjambre": return "+1 enemigo por combate · +1 moneda al limpiar"
		"carne_dura": return "Enemigos más resistentes · pickups extra"
		"polvorin": return "Bombas rinden el doble · enemigos más rápidos"
		"velo": return "Minimapa oculto · mejores recompensas de sala"
		_: return ""

func _prepare_extra_room_kinds() -> void:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in _dungeon.order:
		if cell == Vector2i.ZERO:
			continue
		if _dungeon.kind(cell) != "combate":
			continue
		if _dungeon.distance(cell) < 2:
			continue
		candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return _dungeon.distance(a) > _dungeon.distance(b)
	)
	var rare_roll := posmod(_dungeon.seed_value+_floor_index*97,100)
	var rare_threshold := 48 if _run_progress != null and _run_progress.has_unlock("eventos_profundos") else 38
	if rare_roll < rare_threshold and not candidates.is_empty():
		var event_index := -1
		for i in range(candidates.size()):
			if _dungeon.route_role(candidates[i]) == "branch":
				event_index = i
				break
		if event_index < 0:
			event_index = candidates.size()-1
		var event_cell: Vector2i = candidates[event_index]
		candidates.remove_at(event_index)
		_set_content_room_kind(event_cell,"evento")
	if _floor_index >= 2 and not candidates.is_empty():
		var pact_index := -1
		for i in range(candidates.size()):
			if _dungeon.route_role(candidates[i]) == "branch":
				pact_index = i
				break
		if pact_index >= 0:
			var pact_cell: Vector2i = candidates[pact_index]
			candidates.remove_at(pact_index)
			_set_content_room_kind(pact_cell,"pacto")
	if _floor_index >= 2 and _run_progress != null and _run_progress.has_unlock("santuario_eco") and not candidates.is_empty():
		var echo_roll := posmod(_dungeon.seed_value+_floor_index*211+37,100)
		if echo_roll < 52:
			var echo_index := -1
			for i in range(candidates.size()):
				if _dungeon.route_role(candidates[i]) == "branch":
					echo_index = i
					break
			if echo_index < 0:
				echo_index = candidates.size()-1
			var echo_cell: Vector2i = candidates[echo_index]
			candidates.remove_at(echo_index)
			_set_content_room_kind(echo_cell,"santuario_eco")
	if _floor_index >= 2 and not candidates.is_empty():
		_set_content_room_kind(candidates.pop_front(),"maldicion")
	if _floor_index >= 3 and not candidates.is_empty():
		_set_content_room_kind(candidates.pop_front(),"biblioteca")
	if _floor_index >= 5 and not candidates.is_empty():
		_set_content_room_kind(candidates.pop_front(),"maldicion")

	if _floor_index == 5 and not _abismo_route_applied:
		_apply_abismo_route()
		_abismo_route_applied = true

func _run_route() -> String:
	if _route_blood > _route_witness and _route_blood > _route_wanderer:
		return "sangre"
	if _route_witness > _route_blood and _route_witness > _route_wanderer:
		return "testigo"
	if _route_wanderer > _route_blood and _route_wanderer > _route_witness:
		return "errante"
	var seed := 0
	if _dungeon != null:
		seed = _dungeon.seed_value
	match posmod(seed+_route_blood*7+_route_witness*11+_route_wanderer*13,3):
		0: return "sangre"
		1: return "testigo"
		_: return "errante"

func _run_route_title() -> String:
	match _run_route():
		"sangre": return "RUTA DE SANGRE"
		"testigo": return "RUTA DEL TESTIGO"
		_: return "RUTA DEL ERRANTE"

func _apply_abismo_route() -> void:
	if _dungeon == null:
		return
	match _run_route():
		"sangre":
			_curse_rooms_remaining = maxi(_curse_rooms_remaining,2)
			for cell: Vector2i in _dungeon.order:
				if _dungeon.kind(cell) == "combate" and _dungeon.distance(cell) >= 3:
					_set_content_room_kind(cell,"maldicion")
					break
		"testigo":
			_dungeon.reveal_public_rooms()
			for cell: Vector2i in _dungeon.order:
				if _dungeon.kind(cell) == "combate" and _dungeon.route_role(cell) == "branch":
					_set_content_room_kind(cell,"biblioteca")
					break
		"errante":
			if is_instance_valid(player):
				player.floor_shield_enabled = true
				player.refill_floor_shield()
			_coins += 4
			_update_pickup_hud()

func _finish_floor() -> void:
	var unlocks_before: Dictionary = {}
	if _run_progress != null:
		unlocks_before = _run_progress.unlocks.duplicate(true)
	super._finish_floor()
	if _run_complete and not _meta_completion_recorded and _run_progress != null:
		_meta_completion_recorded = true
		_record_flags = _run_progress.record_completion(_run_route(),_current_run_stats())
	if _run_complete:
		if is_instance_valid(_game_shell):
			_game_shell.hide_for_game_end()
		_show_victory_summary(unlocks_before)

func _show_victory_summary(unlocks_before: Dictionary, is_defeat: bool = false) -> void:
	if is_instance_valid(_victory_summary) or not is_instance_valid(hud_backdrop):
		return
	var layer := hud_backdrop.get_parent()
	if layer == null:
		return
	var item_snapshot: Dictionary = _build_state.snapshot()
	var owned: Dictionary = item_snapshot.get("owned_items",{})
	var item_keys: Array[String] = []
	var item_count := 0
	for id in owned.keys():
		var count := int(owned[id])
		if count <= 0:
			continue
		item_count += count
		item_keys.append(String(id))
	item_keys.sort()
	var item_names: Array[String] = []
	for id in item_keys:
		var title := String(ItemCatalog.reward_definition(id).get("title",id.to_upper()))
		var count := int(owned.get(id,0))
		item_names.append(title + (" x%d" % count if count > 1 else ""))
	var items_text := " · ".join(item_names)
	if items_text.is_empty():
		items_text = "NINGUNA RELIQUIA"

	var synergy_names := get_active_synergy_names()
	var synergies_text := " · ".join(synergy_names) if not synergy_names.is_empty() else "NINGUNA"
	var new_unlocks: Array[String] = []
	var unlocked_labels: Dictionary = {
		"reliquias_archivo":"RELIQUIAS DEL ARCHIVO",
		"eventos_profundos":"EVENTOS PROFUNDOS",
		"pacto_profundo":"PACTOS PROFUNDOS",
		"marca_del_hueco":"MARCA DEL HUECO",
		"santuario_eco":"CÁMARA DEL ECO",
		"eco_fragil":"ESQUIRLA DEL ECO",
		"reloj_ceniza":"RELOJ DE CENIZA",
		"colmillo_ritual":"COLMILLO RITUAL",
		"corona_del_eco":"CORONA DEL ECO"
	}
	if _run_progress != null:
		for id in unlocked_labels.keys():
			if _run_progress.has_unlock(String(id)) and not bool(unlocks_before.get(id,false)):
				new_unlocks.append(String(unlocked_labels[id]))
	new_unlocks.sort()
	var unlocks_text := " · ".join(new_unlocks)
	if unlocks_text.is_empty():
		unlocks_text = "COMPLETADOS: %d · FINALES: %d/3" % [
			_run_progress.runs_completed if _run_progress != null else 1,
			_run_progress.endings.size() if _run_progress != null else 1
		]
	else:
		unlocks_text = "¡DESBLOQUEADO! " + unlocks_text
	var new_records: Array[String] = []
	if bool(_record_flags.get("best_time",false)):
		new_records.append("MEJOR TIEMPO")
	if bool(_record_flags.get("best_kills",false)):
		new_records.append("MÁS BAJAS")
	if bool(_record_flags.get("best_rooms",false)):
		new_records.append("MÁS SALAS")
	if is_defeat:
		unlocks_text = _run_progress.records_text() if _run_progress != null else "PRIMER INTENTO"
	elif not new_records.is_empty():
		unlocks_text += "\nNUEVO RÉCORD: " + " · ".join(new_records)
	elif _run_progress != null:
		unlocks_text += "\n" + _run_progress.records_text()
	var stats := _current_run_stats()
	_victory_summary = VictorySummary.new()
	layer.add_child(_victory_summary)
	_victory_summary.configure_summary(
		"EL DESCENSO TERMINA AQUÍ" if is_defeat else _completion_ending_title(),
		("ISMAEL CAYÓ EN P%d · %s" % [_floor_index,FloorCatalog.floor_name(_floor_index)]) if is_defeat else _completion_ending_subtitle(),
		stats,items_text,synergies_text,unlocks_text,Callable(self,"_restart_game"),
		"DERROTA" if is_defeat else "VICTORIA"
	)
	if is_instance_valid(restart_button):
		restart_button.visible = false
	if is_instance_valid(status_label):
		status_label.visible = false
	if is_instance_valid(reward_label):
		reward_label.visible = false

func _current_run_stats() -> Dictionary:
	var seconds := maxi(0,int((Time.get_ticks_msec()-_run_started_msec)/1000))
	var owned: Dictionary = _build_state.snapshot().get("owned_items",{})
	var item_count := 0
	for count in owned.values():
		item_count += maxi(0,int(count))
	return {
		"rooms":_rooms_cleared_total,
		"kills":_enemies_defeated_total,
		"floor":_floor_index,
		"seconds":seconds,
		"time":"%02d:%02d" % [int(seconds/60),seconds%60],
		"items":item_count
	}

func _on_player_died() -> void:
	if _game_over:
		return
	super._on_player_died()
	if is_instance_valid(_game_shell):
		_game_shell.hide_for_game_end()
	if not _meta_defeat_recorded and _run_progress != null:
		_meta_defeat_recorded = true
		_record_flags = _run_progress.record_defeat(_current_run_stats())
	_show_victory_summary({},true)

func _completion_status_text() -> String:
	return _run_route_title()

func _completion_reward_text() -> String:
	var base := ""
	match _run_route():
		"sangre": base = "ISMAEL VENCIÓ AL HUECO CARGANDO SUS PACTOS"
		"testigo": base = "ISMAEL VIO LO QUE HABÍA DETRÁS DEL ÚLTIMO SELLO"
		_: base = "ISMAEL SALIÓ DEL ABISMO CON LO QUE PUDO CONSERVAR"
	if _run_progress != null:
		return "%s · %s" % [base,_run_progress.summary_text()]
	return base

func _completion_ending_title() -> String:
	match _run_route():
		"sangre": return "EL SELLO BEBIÓ SANGRE"
		"testigo": return "EL TESTIGO MIRÓ DE VUELTA"
		_: return "EL ERRANTE ENCONTRÓ LA SALIDA"

func _completion_ending_subtitle() -> String:
	match _run_route():
		"sangre": return "EL HUECO CAYÓ, PERO LOS PACTOS SIGUEN VIVOS"
		"testigo": return "EL HUECO CAYÓ Y EL ÚLTIMO SECRETO QUEDÓ ABIERTO"
		_: return "EL HUECO CAYÓ Y ISMAEL ELIGIÓ SEGUIR CAMINANDO"

func _set_content_room_kind(cell: Vector2i, kind_value: String) -> void:
	if not _dungeon.rooms.has(cell):
		return
	var data: Dictionary = _dungeon.rooms[cell]
	data["kind"] = kind_value
	_dungeon.rooms[cell] = data

func _room_title() -> String:
	match _room_kind:
		"maldicion": return "CÁMARA MALDITA"
		"biblioteca": return "ARCHIVO PROHIBIDO"
		"pacto": return "CÁMARA DE PACTO"
		"evento": return "EVENTO RARO"
		"santuario_eco": return "CÁMARA DEL ECO"
	return super._room_title()

func _spawn_room_after_entry(generation: int) -> void:
	if _room_kind == "santuario_eco":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		_open_echo_sanctuary()
		return
	if _room_kind == "evento":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		_open_rare_event_room()
		return
	if _room_kind == "pacto":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		_open_pact_room()
		return
	if _room_kind == "biblioteca":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		_open_library_room()
		return
	if _room_kind == "maldicion":
		await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
		if generation != _spawn_generation or _game_over:
			return
		var depth := _dungeon.distance(_current_cell)+2
		var count := mini(5+_floor_index,FloorCatalog.enemy_cap(_floor_index)+1)
		_spawn_enemy_pack(count,depth)
		_transition_locked = false
		status_label.text = "CÁMARA MALDITA"
		reward_label.text = "Más enemigos · suelo peligroso · mejor recompensa"
		queue_redraw()
		return
	super._spawn_room_after_entry(generation)

func _open_echo_sanctuary() -> void:
	var key := _rare_event_key()
	var state := String(_echo_sanctuary_states.get(key,""))
	if state == "claimed":
		status_label.text = "EL ECO FUE RECLAMADO"
		reward_label.text = "El santuario ya no tiene ofrendas"
		_mark_current_room_cleared(false)
		_transition_locked = false
		return
	status_label.text = "CÁMARA DEL ECO"
	reward_label.text = "UN CAMINO EXIGE RECURSOS. EL OTRO EXIGE SANGRE."
	_spawn_echo_choice("pagar_eco","ABRIR EL SELLO","COSTE: 2 LLAVES + 1 BOMBA","RELOJ DE CENIZA",Vector2(0.36,0.53))
	_spawn_echo_choice("luchar_eco","DESPERTAR EL ECO","COSTE: COMBATE INTENSO","RELIQUIA OCULTA",Vector2(0.64,0.53))
	_transition_locked = false

func _spawn_echo_choice(id: String,title: String,cost: String,reward: String,ratio: Vector2) -> void:
	var pedestal := EventPedestal.new()
	pedestal.configure_choice(id,title,cost,reward)
	pedestal.position = room_rect.position+room_rect.size*ratio
	pedestal.chosen.connect(_on_echo_sanctuary_choice)
	add_child(pedestal)

func _echo_sanctuary_reward() -> String:
	var pool: Array[String] = ["eco_fragil","reloj_ceniza"]
	if _run_progress != null and _run_progress.has_unlock("colmillo_ritual"):
		pool.append("colmillo_ritual")
	var seed := absi(_dungeon.seed_value+_floor_index*107+_current_cell.x*137+_current_cell.y*43)
	return pool[seed % pool.size()]

func _on_echo_sanctuary_choice(choice_id: String) -> void:
	var key := _rare_event_key()
	if _room_cleared or String(_echo_sanctuary_states.get(key,"")) != "":
		return
	if choice_id == "pagar_eco":
		if _keys < 2 or _bombs < 1:
			status_label.text = "OFRENDA INSUFICIENTE"
			reward_label.text = "Necesitas 2 llaves y 1 bomba, o puedes luchar"
			_reset_event_offerings_after_failed_payment()
			return
		_keys -= 2
		_bombs -= 1
		var reward := "reloj_ceniza" if _run_progress != null and _run_progress.has_unlock("reloj_ceniza") else "escudo"
		_apply_reward(reward)
		_echo_sanctuary_states[key] = "claimed"
		_route_wanderer += 1
		_consume_event_offerings()
		_mark_current_room_cleared(false)
		_update_pickup_hud()
		status_label.text = "EL SELLO RESPONDIÓ"
		reward_label.text = "El santuario te entregó %s" % _reward_name(reward).replace("\n"," — ")
		_audio_sfx("pickup",1.1)
		return
	if choice_id != "luchar_eco":
		_reset_event_offerings_after_failed_payment()
		return
	_echo_sanctuary_states[key] = "trial"
	_consume_event_offerings()
	var depth := _dungeon.distance(_current_cell)+_floor_index+2
	var count := mini(3+_floor_index,FloorCatalog.enemy_cap(_floor_index))
	_spawn_enemy_pack(count,depth)
	status_label.text = "PRUEBA DEL ECO"
	reward_label.text = "SOBREVIVE PARA OBTENER UNA RELIQUIA ESPECIAL"
	_audio_sfx("boss_phase",1.0)

func _rare_event_key() -> String:
	return "%d:%d:%d" % [_floor_index,_current_cell.x,_current_cell.y]

func _rare_event_id() -> String:
	var seed := absi(_dungeon.seed_value+_floor_index*149+_current_cell.x*92821+_current_cell.y*68917)
	match posmod(seed,3):
		0: return "mercader"
		1: return "pozo"
		_: return "altar"

func _open_rare_event_room() -> void:
	var key := _rare_event_key()
	if bool(_rare_event_states.get(key,false)):
		status_label.text = "EVENTO CONSUMIDO"
		reward_label.text = "No queda nada más aquí"
		_mark_current_room_cleared(false)
		_transition_locked = false
		return
	match _rare_event_id():
		"mercader":
			status_label.text = "MERCADER CIEGO"
			reward_label.text = "COMPRA SEGURIDAD O ROBA PODER"
			_spawn_event_choice("comprar","COMPRAR RELIQUIA","COSTE: 7 MONEDAS","OBJETO DE COMBATE",Vector2(0.37,0.53))
			_spawn_event_choice("robar","ROBAR AL MERCADER","COSTE: 2 SALAS MALDITAS","OBJETO DE COMBATE",Vector2(0.63,0.53))
		"pozo":
			status_label.text = "POZO DE ECOS"
			reward_label.text = "ENTREGA ALGO Y EL POZO RESPONDERÁ"
			_spawn_event_choice("tributo_llave","ARROJAR UNA LLAVE","COSTE: 1 LLAVE","MAPA + 4 MONEDAS",Vector2(0.37,0.53))
			_spawn_event_choice("sangre_pozo","DAR SANGRE","COSTE: 1 CORAZÓN","ALMA + CURACIÓN",Vector2(0.63,0.53))
		_:
			status_label.text = "ALTAR DE CENIZA"
			reward_label.text = "QUEMA RECURSOS PARA ALTERAR TU RUN"
			_spawn_event_choice("quemar_bombas","QUEMAR BOMBAS","COSTE: 2 BOMBAS","+ DAÑO",Vector2(0.37,0.53))
			_spawn_event_choice("quemar_monedas","QUEMAR MONEDAS","COSTE: 6 MONEDAS","+ VIDA MÁXIMA",Vector2(0.63,0.53))
	_transition_locked = false

func _spawn_event_choice(id: String, title: String, cost: String, reward: String, ratio: Vector2) -> void:
	var pedestal := EventPedestal.new()
	pedestal.configure_choice(id,title,cost,reward)
	pedestal.position = room_rect.position+room_rect.size*ratio
	pedestal.chosen.connect(_on_rare_event_choice)
	add_child(pedestal)

func _rare_event_reward() -> String:
	var pool: Array[String] = ["dano","cadencia","proyectil","buscadora","perforante","rafaga"]
	var seed := absi(_floor_index*313+_current_cell.x*92821+_current_cell.y*68917)
	return pool[seed%pool.size()]

func _reset_event_offerings_after_failed_payment() -> void:
	for pedestal in get_tree().get_nodes_in_group("event_offerings"):
		if is_instance_valid(pedestal):
			pedestal.claimed_state = false
			pedestal.monitoring = true

func _consume_event_offerings() -> void:
	for pedestal in get_tree().get_nodes_in_group("event_offerings"):
		if is_instance_valid(pedestal):
			pedestal.queue_free()

func _on_rare_event_choice(choice_id: String) -> void:
	var accepted := false
	var result_text := ""
	match choice_id:
		"comprar":
			if _coins >= 7:
				_coins -= 7
				var reward := _rare_event_reward()
				_apply_reward(reward)
				_update_pickup_hud()
				result_text = "Compraste %s" % _reward_name(reward).replace("\n"," — ")
				_route_wanderer += 1
				accepted = true
			else:
				status_label.text = "NO TIENES 7 MONEDAS"
		"robar":
			var reward := _rare_event_reward()
			_apply_reward(reward)
			_curse_rooms_remaining = maxi(_curse_rooms_remaining,2)
			_route_blood += 2
			result_text = "Robaste poder · 2 salas cargarán la maldición"
			accepted = true
		"tributo_llave":
			if _keys >= 1:
				_keys -= 1
				_coins += 4
				_apply_reward("mapa")
				_update_pickup_hud()
				result_text = "El pozo reveló el piso y devolvió 4 monedas"
				_route_witness += 2
				accepted = true
			else:
				status_label.text = "NO TIENES UNA LLAVE"
		"sangre_pozo":
			if player.health > 1:
				player.take_damage(1)
				player.heal(1)
				_spawn_pickup_at("soul",Vector2(0.50,0.58))
				result_text = "El pozo respondió con alma"
				_route_witness += 1
				accepted = true
			else:
				status_label.text = "NO PUEDES DAR TU ÚLTIMO CORAZÓN"
		"quemar_bombas":
			if _bombs >= 2:
				_bombs -= 2
				_apply_reward("dano")
				_update_pickup_hud()
				result_text = "La ceniza fortaleció tus lágrimas"
				_route_blood += 1
				accepted = true
			else:
				status_label.text = "NECESITAS 2 BOMBAS"
		"quemar_monedas":
			if _coins >= 6:
				_coins -= 6
				_apply_reward("vida")
				_update_pickup_hud()
				result_text = "La ceniza endureció tu cuerpo"
				_route_wanderer += 1
				accepted = true
			else:
				status_label.text = "NECESITAS 6 MONEDAS"
	if not accepted:
		reward_label.text = "Puedes irte o elegir la otra opción"
		_reset_event_offerings_after_failed_payment()
		return
	_rare_event_states[_rare_event_key()] = true
	if _run_progress != null:
		_run_progress.record_event()
	_audio_sfx("pickup",1.15)
	_consume_event_offerings()
	status_label.text = "DECISIÓN SELLADA"
	reward_label.text = result_text
	_mark_current_room_cleared(false)
	queue_redraw()

func _open_pact_room() -> void:
	var room_key := _reward_room_key()
	var offers: Array[String] = []
	if _pact_offers.has(room_key):
		for value in _pact_offers[room_key]:
			offers.append(String(value))
	else:
		offers = _pact_choices()
		_pact_offers[room_key] = offers.duplicate()
	status_label.text = "CÁMARA DE PACTO"
	reward_label.text = "ELIGE UN PRECIO — SÓLO UN PACTO PUEDE SELLARSE"
	_spawn_pact_pedestal(offers[0],room_rect.position+room_rect.size*Vector2(0.37,0.53))
	_spawn_pact_pedestal(offers[1],room_rect.position+room_rect.size*Vector2(0.63,0.53))
	_transition_locked = false

func _pact_choices() -> Array[String]:
	var pool: Array[String] = ["sangre","tributo","maldicion"]
	if _run_progress != null and _run_progress.has_unlock("pacto_profundo"):
		pool.append("hueco")
	var seed := absi(_floor_index*211+_current_cell.x*92821+_current_cell.y*68917)
	var first := pool[seed%pool.size()]
	var second := pool[(seed*5+1)%pool.size()]
	if second == first:
		second = pool[(seed+1)%pool.size()]
	return [first,second]

func _spawn_pact_pedestal(pact_id: String, world_position: Vector2) -> void:
	var pedestal := PactPedestal.new()
	match pact_id:
		"sangre":
			pedestal.configure_pact("sangre","PACTO DE SANGRE","COSTE: 2 CORAZONES","+ DAÑO · + CADENCIA")
		"tributo":
			pedestal.configure_pact("tributo","TRIBUTO DEL ERRANTE","COSTE: 5 MONEDAS","ESCUDO · +3 MONEDAS")
		"hueco":
			pedestal.configure_pact("hueco","PACTO DEL HUECO","COSTE: 1 LLAVE + 1 BOMBA","FORTUNA · DOBLE DISPARO")
		_:
			pedestal.configure_pact("maldicion","SELLO MALDITO","COSTE: 3 SALAS MÁS DURAS","MAPA REVELADO · + DAÑO")
	pedestal.position = world_position
	pedestal.chosen.connect(_on_pact_chosen)
	add_child(pedestal)

func _on_pact_chosen(pact_id: String) -> void:
	if _room_cleared:
		return
	var accepted := false
	match pact_id:
		"sangre":
			if player.health > 2:
				player.take_damage(2)
				_apply_reward("dano")
				_apply_reward("cadencia")
				_route_blood += 2
				accepted = true
			else:
				status_label.text = "NO PUEDES PAGAR EL PRECIO"
				reward_label.text = "Necesitas más de 2 corazones"
		"tributo":
			if _coins >= 5:
				_coins -= 5
				_apply_reward("escudo")
				_coins += 3
				_route_wanderer += 2
				_update_pickup_hud()
				accepted = true
			else:
				status_label.text = "TRIBUTO INSUFICIENTE"
				reward_label.text = "Necesitas 5 monedas"
		"hueco":
			if _keys >= 1 and _bombs >= 1:
				_keys -= 1
				_bombs -= 1
				_apply_reward("fortuna")
				_apply_reward("doble")
				_route_witness += 1
				_route_blood += 1
				_update_pickup_hud()
				accepted = true
			else:
				status_label.text = "EL HUECO EXIGE DOS TRIBUTOS"
				reward_label.text = "Necesitas 1 llave y 1 bomba"
		"maldicion":
			_curse_rooms_remaining = maxi(_curse_rooms_remaining,3)
			_apply_reward("mapa")
			_apply_reward("dano")
			_route_blood += 1
			_route_witness += 1
			accepted = true
	if not accepted:
		for pedestal in get_tree().get_nodes_in_group("pact_offerings"):
			if is_instance_valid(pedestal):
				pedestal.claimed_state = false
				pedestal.monitoring = true
		return
	if _run_progress != null:
		_run_progress.record_pact()
	_audio_sfx("pickup",1.25)
	for pedestal in get_tree().get_nodes_in_group("pact_offerings"):
		if is_instance_valid(pedestal):
			pedestal.queue_free()
	status_label.text = "PACTO SELLADO"
	match pact_id:
		"sangre":
			reward_label.text = "La sangre compró poder"
		"tributo":
			reward_label.text = "El tributo compró protección"
		"hueco":
			reward_label.text = "El Hueco dejó una marca en tu disparo"
		_:
			reward_label.text = "Tres salas cargarán la maldición"
	_mark_current_room_cleared(false)
	queue_redraw()

func _open_library_room() -> void:
	var room_key := _reward_room_key()
	if _reward_offers.has(room_key):
		_offered_rewards.clear()
		for value in _reward_offers[room_key]:
			_offered_rewards.append(String(value))
	else:
		_offered_rewards = _library_choices()
		_reward_offers[room_key] = _offered_rewards.duplicate()
	status_label.text = "ARCHIVO PROHIBIDO"
	reward_label.text = "ELIGE UN OBJETO — EL OTRO SE PERDERÁ"
	_spawn_reward_pedestal(_offered_rewards[0],room_rect.position+room_rect.size*Vector2(0.38,0.53))
	_spawn_reward_pedestal(_offered_rewards[1],room_rect.position+room_rect.size*Vector2(0.62,0.53))
	_transition_locked = false

func _library_choices() -> Array[String]:
	var pool: Array[String] = [
		"doble","lente","alma","adrenalina","mapa","buscadora","perforante","fortuna"
	]
	if _run_progress != null and _run_progress.has_unlock("reliquias_archivo"):
		pool.append_array(["carne","polvora","llavero"])
	if _run_progress != null and _run_progress.has_unlock("eco_fragil"):
		pool.append("eco_fragil")
	if _run_progress != null and _run_progress.has_unlock("reloj_ceniza"):
		pool.append("reloj_ceniza")
	if _run_progress != null and _run_progress.has_unlock("colmillo_ritual"):
		pool.append("colmillo_ritual")
	var seed := absi(_floor_index*131+_current_cell.x*92821+_current_cell.y*68917)
	var first := pool[seed%pool.size()]
	var second := pool[(seed*3+5)%pool.size()]
	if second == first:
		second = pool[(seed+1)%pool.size()]
	return [first,second]

func _spawn_enemy_pack(count: int, depth: int) -> void:
	var resolved_count := count
	if _curse_active_in_room:
		resolved_count += 1
	if _floor_mutator == "enjambre":
		resolved_count += 1
	super._spawn_enemy_pack(resolved_count,depth)

func _create_floor_enemy(kind_id: String):
	var enemy
	if kind_id in ["flyer","turret","leaper","flyer_elite","turret_elite","leaper_elite"]:
		enemy = ExtraEnemy.new()
		enemy.configure_extra(kind_id,_floor_index)
	else:
		enemy = super._create_floor_enemy(kind_id)
	if is_instance_valid(enemy):
		if _floor_mutator == "carne_dura":
			enemy.health = maxi(enemy.health+1,int(ceil(float(enemy.health)*1.22)))
			enemy.max_health = enemy.health
		elif _floor_mutator == "polvorin":
			enemy.speed *= 1.12
	return enemy

func _travel_to(direction: Vector2i) -> void:
	if _transition_locked:
		return
	var destination := _current_cell+direction
	if _dungeon != null and _dungeon.has_room(destination) and _dungeon.kind(destination) == "recompensa":
		var key := _treasure_unlock_key(destination)
		if not bool(_unlocked_treasure_rooms.get(key,false)):
			if _keys <= 0:
				status_label.text = "PUERTA DEL TESORO CERRADA"
				reward_label.text = "Necesitas 1 llave para entrar"
				if is_instance_valid(player):
					player.position -= Vector2(direction.x,direction.y)*56.0
				return
			_keys -= 1
			_unlocked_treasure_rooms[key] = true
			_update_pickup_hud()
			status_label.text = "PUERTA DEL TESORO ABIERTA"
			reward_label.text = "Se consumió 1 llave"
	super._travel_to(direction)

func _treasure_unlock_key(cell: Vector2i) -> String:
	return "%d:%d:%d" % [_floor_index,cell.x,cell.y]

func _set_door_open(value: bool) -> void:
	super._set_door_open(value)
	if not value or _dungeon == null:
		return
	for dir: Vector2i in DIRS:
		var destination := _current_cell+dir
		if not _dungeon.has_room(destination) or _dungeon.kind(destination) != "recompensa":
			continue
		if bool(_unlocked_treasure_rooms.get(_treasure_unlock_key(destination),false)):
			continue
		var door = _doors.get(dir)
		if is_instance_valid(door):
			door.set_open(false)
			door.modulate = Color(0.95,0.72,0.20,1.0)

func _create_room_door(direction: Vector2i) -> void:
	super._create_room_door(direction)
	var destination := _current_cell+direction
	if not _dungeon.has_room(destination):
		return
	var door = _doors.get(direction)
	if not is_instance_valid(door):
		return
	match _dungeon.kind(destination):
		"recompensa": door.modulate = Color(0.95,0.72,0.20,1.0)
		"biblioteca": door.modulate = Color(0.58,0.42,0.82,1.0)
		"maldicion": door.modulate = Color(0.64,0.12,0.16,1.0)
		"pacto": door.modulate = Color(0.72,0.18,0.22,1.0)
		"evento": door.modulate = Color(0.54,0.68,0.34,1.0)
		"santuario_eco": door.modulate = Color(0.35,0.72,0.82,1.0)

func _spawn_clear_pickup() -> void:
	super._spawn_clear_pickup()
	if _room_kind in ["inicio","recompensa","tienda","biblioteca","pacto","evento","santuario_eco"]:
		return
	if _floor_mutator == "enjambre":
		_coins += 1
		_update_pickup_hud()
	elif _floor_mutator == "carne_dura":
		var bonus_kind := "heart" if posmod(_room_index+_floor_index,2)==0 else "coin"
		_spawn_pickup_at(bonus_kind,Vector2(0.42,0.61))
	elif _floor_mutator == "velo":
		var veil_roll := posmod(_room_index*31+_floor_index*17,3)
		if veil_roll == 0:
			_spawn_pickup_at("coin5",Vector2(0.42,0.61))
		elif veil_roll == 1:
			_spawn_pickup_at("soul",Vector2(0.42,0.61))
	var roll := absi(_floor_index*71+_room_index*43+_current_cell.x*97+_current_cell.y*53)%100
	if _floor_index >= 2 and roll < 7:
		_spawn_pickup_at("soul",Vector2(0.58,0.61))
	elif _floor_index >= 3 and roll >= 7 and roll < 12:
		_spawn_pickup_at("coin5",Vector2(0.58,0.61))

func _on_pickup_collected(kind: String) -> void:
	super._on_pickup_collected(kind)
	if _floor_mutator == "polvorin" and kind == "bomb":
		_bombs += 1
		_update_pickup_hud()

func _update_minimap() -> void:
	if _floor_mutator == "velo" and not _map_reveal_active:
		if is_instance_valid(minimap_label):
			minimap_label.text = "◈ VELO\nMAPA SILENCIADO"
		return
	super._update_minimap()

func _spawn_chest_loot(room_key: String,chest_id: int,chest_kind: String) -> void:
	super._spawn_chest_loot(room_key,chest_id,chest_kind)
	if chest_kind != "locked":
		return
	var state := _room_loot_state.chest_state(room_key)
	var base_ratio: Vector2 = state.get("ratio",Vector2(0.50,0.40))
	if posmod(chest_id+_floor_index,2) == 0:
		_spawn_pickup_at("coin5",base_ratio+Vector2(0.0,0.24))
	else:
		_spawn_pickup_at("soul",base_ratio+Vector2(0.0,0.24))

func _on_enemy_defeated(enemy) -> void:
	if not _run_complete and not _game_over:
		_enemies_defeated_total += 1
	var was_cleared := _room_cleared
	super._on_enemy_defeated(enemy)
	if not was_cleared and _room_cleared and _room_kind == "santuario_eco":
		var key := _rare_event_key()
		if String(_echo_sanctuary_states.get(key,"")) == "trial":
			_echo_sanctuary_states[key] = "claimed"
			var reward := _echo_sanctuary_reward()
			_apply_reward(reward)
			_spawn_pickup_at("soul",Vector2(0.50,0.61))
			_route_blood += 1
			if _run_progress != null:
				_run_progress.record_echo_challenge()
			status_label.text = "EL ECO FUE SOMETIDO"
			reward_label.text = "GANASTE %s · +1 ALMA" % _reward_name(reward).replace("\n"," — ")
			_audio_sfx("boss_death",1.1)
	if not was_cleared and _room_cleared and _room_kind == "maldicion":
		_spawn_pickup_at("soul",Vector2(0.44,0.61))
		_spawn_pickup_at("coin5",Vector2(0.56,0.61))
		status_label.text = "MALDICIÓN SUPERADA"
		reward_label.text = "La cámara dejó una recompensa excepcional"

func _clear_content_hazards() -> void:
	for hazard in get_tree().get_nodes_in_group("room_hazards"):
		if is_instance_valid(hazard):
			hazard.queue_free()

func _spawn_content_hazards() -> void:
	if _room_kind not in ["combate","emboscada","desafio","maldicion"]:
		return
	var ratios: Array[Vector2] = _hazard_ratios_for_layout()
	var count := 0
	if _room_kind == "maldicion":
		count = 4+int(_floor_index>=4)
	elif _room_kind == "desafio":
		count = 1+int(_floor_index>=3)
	else:
		match clampi(_floor_index,1,5):
			1: count = 0
			2: count = 1
			3: count = 2
			4: count = 2
			_: count = 3
	if _room_layout_profile == "abierta":
		count = mini(count,1)
	elif _room_layout_profile in ["embudo","corredor_maldito"]:
		count = mini(count+1,5)
	var seed := absi(_floor_index*193+_current_cell.x*92821+_current_cell.y*68917+_room_index*17)
	for i in range(count):
		var ratio := ratios[posmod(seed+i*3,ratios.size())]
		var kind := "spike"
		match clampi(_floor_index,1,5):
			1:
				kind = "spike"
			2:
				kind = "spike"
			3:
				kind = "fire" if i==count-1 or posmod(seed+i,4)==0 else "spike"
			4:
				kind = "fire" if i%2==1 else "spike"
			_:
				kind = "fire" if i%2==0 else "spike"
		if _room_kind == "maldicion" and i>=maxi(0,count-2):
			kind = "fire"
		var hazard_id := 100+i
		var room_key := _obstacle_room_key()
		if kind == "fire" and _room_obstacle_state.is_destroyed(room_key,hazard_id):
			continue
		var hazard := RoomHazard.new()
		hazard.configure(hazard_id,kind)
		hazard.position = room_rect.position+room_rect.size*ratio
		hazard.destroyed.connect(_on_content_hazard_destroyed.bind(room_key))
		add_child(hazard)

func _hazard_ratios_for_layout() -> Array[Vector2]:
	match _room_layout_profile:
		"embudo":
			return [
				Vector2(0.50,0.52),Vector2(0.50,0.66),Vector2(0.38,0.44),
				Vector2(0.62,0.44),Vector2(0.50,0.36)
			]
		"corredor_maldito":
			return [
				Vector2(0.50,0.34),Vector2(0.50,0.48),Vector2(0.50,0.62),
				Vector2(0.42,0.55),Vector2(0.58,0.55)
			]
		"columnas":
			return [
				Vector2(0.50,0.48),Vector2(0.50,0.66),Vector2(0.24,0.56),
				Vector2(0.76,0.56)
			]
		"cruzada","arena_cruzada":
			return [
				Vector2(0.50,0.46),Vector2(0.32,0.66),Vector2(0.68,0.66),
				Vector2(0.50,0.72)
			]
		"pinza":
			return [
				Vector2(0.50,0.46),Vector2(0.34,0.68),Vector2(0.66,0.68)
			]
		_:
			return [
				Vector2(0.30,0.38),Vector2(0.70,0.38),Vector2(0.38,0.66),
				Vector2(0.62,0.66),Vector2(0.50,0.48),Vector2(0.24,0.62),
				Vector2(0.76,0.62)
			]

func _on_content_hazard_destroyed(hazard_id: int, _world_position: Vector2, room_key: String) -> void:
	_room_obstacle_state.mark_destroyed(room_key,hazard_id)

func _on_placed_bomb_exploded(world_position: Vector2, blast_radius: float) -> void:
	super._on_placed_bomb_exploded(world_position,blast_radius)
	for hazard in get_tree().get_nodes_in_group("room_hazards"):
		if is_instance_valid(hazard) and hazard.has_method("blast_hit"):
			hazard.call("blast_hit",world_position,blast_radius)
