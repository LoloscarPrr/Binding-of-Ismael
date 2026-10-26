extends "res://src/presentation/game/mobile_destructible_room_controller.gd"

const FloorCatalog = preload("res://src/domain/run/floor_catalog.gd")
const BossSeals = preload("res://src/domain/run/boss_seal_catalog.gd")
const BossPhases = preload("res://src/domain/run/boss_phase_profile.gd")
const AdvancedEnemy = preload("res://scripts/advanced_enemy.gd")
const SpecialEnemy = preload("res://scripts/special_enemy.gd")

var _room_layout_profile := "abierta"

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	_challenge_waves_total = FloorCatalog.challenge_waves(_floor_index)
	super._begin_room(entry_direction)
	if is_instance_valid(floor_label):
		floor_label.text = "P%d · %s" % [_floor_index,FloorCatalog.floor_name(_floor_index)]
	if is_instance_valid(room_label) and _dungeon != null:
		var route := _dungeon.route_label(_current_cell)
		var risk := _dungeon.risk_level(_current_cell)
		var risk_text := "" if risk<=0 else " · R%d" % risk
		room_label.text = "%s · %s%s" % [room_label.text,route,risk_text]
	if _room_kind == "inicio" and is_instance_valid(status_label):
		status_label.text = "ENTRADA — %s" % FloorCatalog.floor_name(_floor_index)
		if is_instance_valid(reward_label):
			reward_label.text = FloorCatalog.floor_identity(_floor_index)

func _build_room_layout() -> void:
	if _room_kind in ["inicio","recompensa","tienda","sacrificio","secreta","supersecreta","biblioteca","pacto","evento"]:
		_room_layout_profile = "abierta"
		return
	var seed := absi(
		_floor_index*193
		+_room_index*47
		+_current_cell.x*92821
		+_current_cell.y*68917
	)
	var route := _dungeon.route_role(_current_cell) if _dungeon != null else "branch"
	var risk := _dungeon.risk_level(_current_cell) if _dungeon != null else 0
	_room_layout_profile = FloorCatalog.room_layout_profile(
		_floor_index,_room_kind,seed,route,risk
	)

	var variant := clampi(_floor_index-1,0,4)
	match _room_layout_profile:
		"abierta":
			pass
		"barricada":
			_add_obstacle(Vector2(0.50,0.56),Vector2(0.22,0.07),variant)
		"columnas":
			_add_obstacle(Vector2(0.32,0.44),Vector2(0.07,0.16),variant)
			_add_obstacle(Vector2(0.68,0.44),Vector2(0.07,0.16),variant)
			_add_obstacle(Vector2(0.32,0.70),Vector2(0.07,0.12),variant)
			_add_obstacle(Vector2(0.68,0.70),Vector2(0.07,0.12),variant)
		"cruzada":
			_add_obstacle(Vector2(0.38,0.52),Vector2(0.08,0.11),variant)
			_add_obstacle(Vector2(0.62,0.52),Vector2(0.08,0.11),variant)
			_add_obstacle(Vector2(0.50,0.68),Vector2(0.16,0.06),variant)
		"embudo":
			_add_obstacle(Vector2(0.33,0.56),Vector2(0.08,0.18),variant)
			_add_obstacle(Vector2(0.67,0.56),Vector2(0.08,0.18),variant)
			_add_obstacle(Vector2(0.50,0.72),Vector2(0.16,0.05),variant)
		"islas":
			_add_obstacle(Vector2(0.30,0.50),Vector2(0.08,0.09),variant)
			_add_obstacle(Vector2(0.50,0.42),Vector2(0.08,0.09),variant)
			_add_obstacle(Vector2(0.70,0.50),Vector2(0.08,0.09),variant)
			_add_obstacle(Vector2(0.50,0.68),Vector2(0.08,0.09),variant)
		"pinza":
			_add_obstacle(Vector2(0.40,0.57),Vector2(0.06,0.13),variant)
			_add_obstacle(Vector2(0.60,0.57),Vector2(0.06,0.13),variant)
		"arena":
			_add_obstacle(Vector2(0.26,0.52),Vector2(0.06,0.18),2)
			_add_obstacle(Vector2(0.74,0.52),Vector2(0.06,0.18),2)
		"arena_cruzada":
			_add_obstacle(Vector2(0.28,0.50),Vector2(0.06,0.18),2)
			_add_obstacle(Vector2(0.72,0.50),Vector2(0.06,0.18),2)
			_add_obstacle(Vector2(0.50,0.67),Vector2(0.18,0.05),2)
		"duelo":
			_add_obstacle(Vector2(0.24,0.68),Vector2(0.07,0.10),2)
			_add_obstacle(Vector2(0.76,0.68),Vector2(0.07,0.10),2)
		"boss_arena":
			_add_obstacle(Vector2(0.24,0.58),Vector2(0.08,0.16),2)
			_add_obstacle(Vector2(0.76,0.58),Vector2(0.08,0.16),2)
		"corredor_maldito":
			_add_obstacle(Vector2(0.30,0.52),Vector2(0.07,0.22),2)
			_add_obstacle(Vector2(0.70,0.52),Vector2(0.07,0.22),2)

func _room_layout_title() -> String:
	return FloorCatalog.room_layout_title(_room_layout_profile)

func _spawn_enemy_pack(count: int, depth: int) -> void:
	var resolved_count := mini(
		count+FloorCatalog.enemy_count_bonus(_floor_index),
		FloorCatalog.enemy_cap(_floor_index)
	)
	var positions: Array[Vector2] = _deterministic_spawn_positions(resolved_count)
	_enemies_alive = positions.size()
	var encounter_seed := absi(
		_floor_index*193
		+_room_index*47
		+depth*31
		+_current_cell.x*92821
		+_current_cell.y*68917
		+_challenge_wave*17
	)
	var roster := FloorCatalog.encounter_roster(
		_floor_index,
		encounter_seed,
		positions.size(),
		_room_kind,
		_room_layout_profile
	)
	if is_instance_valid(status_label) and _room_kind in ["combate","emboscada","desafio","maldicion"]:
		status_label.text = "%s · %s" % [
			FloorCatalog.encounter_name(_floor_index,encounter_seed,_room_kind,_room_layout_profile),
			_room_layout_title()
		]
	for i in positions.size():
		var kind_id := roster[i]
		var enemy = _create_floor_enemy(kind_id)
		enemy.configure_squad_role(i,positions.size(),encounter_seed)
		enemy.position = positions[i]
		enemy.target = player
		enemy.spawn_grace_time = ENEMY_ACTIVATION_DELAY
		enemy.set_movement_bounds(room_rect)
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)

func _create_floor_enemy(kind_id: String):
	if kind_id in ["brute","spitter","stalker","brute_elite","spitter_elite","stalker_elite"]:
		var advanced := AdvancedEnemy.new()
		advanced.configure_advanced(kind_id,_floor_index)
		return advanced
	if kind_id in ["shielded","burrower","splitter"]:
		var special := SpecialEnemy.new()
		special.configure_special(kind_id,_floor_index)
		return special
	var enemy := IsmaelEnemy.new()
	match kind_id:
		"dasher":
			enemy.configure(IsmaelEnemy.EnemyKind.DASHER,_floor_index)
		"orbiter":
			enemy.configure(IsmaelEnemy.EnemyKind.ORBITER,_floor_index)
		_:
			enemy.configure(IsmaelEnemy.EnemyKind.CHASER,_floor_index)
	return enemy

func _on_enemy_defeated(enemy) -> void:
	if enemy is SpecialEnemy and enemy.is_splitter():
		var origin: Vector2 = enemy.global_position
		for i in range(2):
			var child := IsmaelEnemy.new()
			child.configure(IsmaelEnemy.EnemyKind.CHASER,maxi(1,_floor_index-1))
			child.health = maxi(2,int(ceil(float(child.health)*0.62)))
			child.max_health = child.health
			child.speed *= 1.18
			child.scale = Vector2(0.68,0.68)
			var angle := -0.55 if i==0 else 0.55
			var offset := Vector2.RIGHT.rotated(angle+float(_room_index)*0.31)*34.0
			child.global_position = origin+offset
			child.target = player
			child.spawn_grace_time = 0.42
			child.set_movement_bounds(room_rect)
			child.defeated.connect(_on_enemy_defeated)
			add_child(child)
			_enemies_alive += 1
	super._on_enemy_defeated(enemy)

func _spawn_challenge_wave() -> void:
	var depth := _dungeon.distance(_current_cell)+_challenge_wave
	var count := mini(
		2+_floor_index+_challenge_wave*2,
		FloorCatalog.enemy_cap(_floor_index)+1
	)
	_spawn_enemy_pack(count,depth)
	if is_instance_valid(reward_label):
		reward_label.text = "OLEADA %d / %d · cambia la composición" % [_challenge_wave,_challenge_waves_total]

func _spawn_miniboss() -> void:
	var variant := FloorCatalog.miniboss_variant(_floor_index)
	var elite = AdvancedEnemy.new()
	elite.configure_advanced(variant,_floor_index)
	# Balance del Guardián Menor: se sobreescribe la vida de la variante avanzada
	# para evitar heredar los HP del jefe principal (110+ desde el piso 1).
	elite.health = 8 + maxi(0, _floor_index - 1) * 2
	elite.max_health = elite.health
	elite.speed *= 1.04
	if variant == "boss":
		elite.scale *= 0.76
	else:
		elite.scale *= 1.10
	elite.position = _safe_guardian_spawn_position(Vector2(0.50,0.32))
	elite.target = player
	elite.spawn_grace_time = 0.9
	elite.set_movement_bounds(room_rect)
	elite.defeated.connect(_on_enemy_defeated)
	add_child(elite)
	_enemies_alive = 1
	# El controlador de pisos reemplaza al spawn base; debe enlazar su propio HUD.
	if not elite.health_changed.is_connected(_on_boss_health_changed):
		elite.health_changed.connect(_on_boss_health_changed)
	if is_instance_valid(boss_hud):
		boss_hud.show_boss("GUARDIÁN MENOR",elite.health)

# El spawn se decide DESPUÉS del retardo de entrada. El jugador
# puede moverse durante ese retardo, por lo que un punto fijo causa
# apariciones prácticamente encima de Ismael, especialmente en puertas norte.
func _safe_guardian_spawn_position(preferred_ratio: Vector2) -> Vector2:
	var preferred := room_rect.position+room_rect.size*preferred_ratio
	if not is_instance_valid(player):
		return preferred
	var minimum_distance := maxf(225.0,minf(room_rect.size.x,room_rect.size.y)*0.46)
	if preferred.distance_to(player.global_position) >= minimum_distance:
		return preferred
	var alternatives: Array[Vector2] = [
		Vector2(0.50,0.72),Vector2(0.25,0.28),Vector2(0.75,0.28),
		Vector2(0.25,0.72),Vector2(0.75,0.72),Vector2(0.50,0.28)
	]
	var safest := preferred
	var best_distance := preferred.distance_squared_to(player.global_position)
	for ratio in alternatives:
		var candidate := room_rect.position+room_rect.size*ratio
		var distance_squared := candidate.distance_squared_to(player.global_position)
		if distance_squared > best_distance:
			safest = candidate
			best_distance = distance_squared
	return safest

func _spawn_boss() -> void:
	var boss = AdvancedEnemy.new()
	boss.configure_advanced("boss",_floor_index)
	boss.position = _safe_guardian_spawn_position(Vector2(0.50,0.28))
	boss.target = player
	boss.spawn_grace_time = 1.70
	boss.set_movement_bounds(room_rect)
	boss.defeated.connect(_on_enemy_defeated)
	boss.boss_phase_changed.connect(_on_floor_boss_phase_changed)
	add_child(boss)
	_enemies_alive = 1
	if not boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)
	if is_instance_valid(boss_hud):
		boss_hud.show_boss(FloorCatalog.boss_name(_floor_index),boss.health)
		boss_hud.set_phase(1)
	if is_instance_valid(presentation_overlay):
		presentation_overlay.present_boss(
			FloorCatalog.boss_name(_floor_index),
			BossSeals.omen(_floor_index),
			_floor_index
		)
	_audio_sfx("boss_phase",0.85)

func _on_floor_boss_phase_changed(phase_number: int, phase_title: String) -> void:
	if _game_over or _run_complete:
		return
	if is_instance_valid(boss_hud):
		boss_hud.set_phase(phase_number)
	if is_instance_valid(presentation_overlay):
		presentation_overlay.present(phase_title,BossPhases.phase_subtitle(phase_number),1.06,0.47)
	_audio_sfx("boss_phase",1.14 if phase_number == 3 else 0.98)

func _refresh_floor_exit_label(opened: bool) -> void:
	if not is_instance_valid(floor_exit_label) or _room_kind != "jefe":
		return
	floor_exit_label.visible = true
	if _floor_index<FloorCatalog.TOTAL_FLOORS:
		var next_floor := _floor_index+1
		floor_exit_label.text = (
			"▼ PISO %d · %s ▼" if opened else "PISO %d · %s"
		) % [next_floor,FloorCatalog.floor_name(next_floor)]
	else:
		floor_exit_label.text = "▼ SALIDA FINAL ▼" if opened else "SALIDA FINAL"

func _floor_transition() -> void:
	var leaving_floor := _floor_index
	_audio_sfx("floor",1.2)
	await get_tree().create_timer(FLOOR_TRANSITION_DELAY).timeout
	if _game_over:
		return
	_floor_index = mini(leaving_floor+1,FloorCatalog.TOTAL_FLOORS)
	_dungeon.generate(_floor_index)
	if _map_reveal_active:
		_dungeon.reveal_public_rooms()
	if is_instance_valid(player) and player.floor_shield_enabled:
		player.refill_floor_shield()
	_current_cell = Vector2i.ZERO
	_begin_room(Vector2i.ZERO)

func _finish_floor() -> void:
	if _transition_locked:
		return
	_transition_locked = true
	_spawn_generation += 1
	if _floor_index>=FloorCatalog.TOTAL_FLOORS:
		_run_complete = true
		status_label.text = "RECORRIDO COMPLETADO"
		reward_label.text = "ISMAEL SOBREVIVIÓ A LOS CINCO GUARDIANES"
		restart_button.visible = true
		left_stick.reset()
		right_stick.reset()
		_layout_touch_ui()
		_apply_completion_ui()
		if is_instance_valid(bomb_button):
			bomb_button.visible = false
		return
	status_label.text = "GUARDIÁN DERROTADO — %s" % FloorCatalog.floor_name(_floor_index)
	reward_label.text = _grant_floor_reward()
	_floor_transition()
