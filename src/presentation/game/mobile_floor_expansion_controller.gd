extends "res://src/presentation/game/mobile_destructible_room_controller.gd"

const FloorCatalog = preload("res://src/domain/run/floor_catalog.gd")
const AdvancedEnemy = preload("res://scripts/advanced_enemy.gd")

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
		_room_kind
	)
	if is_instance_valid(status_label) and _room_kind in ["combate","emboscada","desafio","maldicion"]:
		status_label.text = FloorCatalog.encounter_name(_floor_index,encounter_seed,_room_kind)
	for i in positions.size():
		var kind_id := roster[i]
		var enemy = _create_floor_enemy(kind_id)
		enemy.position = positions[i]
		enemy.target = player
		enemy.spawn_grace_time = ENEMY_ACTIVATION_DELAY
		enemy.set_movement_bounds(room_rect)
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)

func _create_floor_enemy(kind_id: String):
	if kind_id in ["brute","spitter","stalker"]:
		var advanced := AdvancedEnemy.new()
		advanced.configure_advanced(kind_id,_floor_index)
		return advanced
	var enemy := IsmaelEnemy.new()
	match kind_id:
		"dasher":
			enemy.configure(IsmaelEnemy.EnemyKind.DASHER,_floor_index)
		"orbiter":
			enemy.configure(IsmaelEnemy.EnemyKind.ORBITER,_floor_index)
		_:
			enemy.configure(IsmaelEnemy.EnemyKind.CHASER,_floor_index)
	return enemy

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
	elite.health = maxi(12+_floor_index*4,int(round(float(elite.health)*1.45)))
	elite.max_health = elite.health
	elite.speed *= 1.04
	if variant == "boss":
		elite.scale *= 0.76
	else:
		elite.scale *= 1.10
	elite.position = room_rect.position+room_rect.size*Vector2(0.50,0.32)
	elite.target = player
	elite.spawn_grace_time = 0.9
	elite.set_movement_bounds(room_rect)
	elite.defeated.connect(_on_enemy_defeated)
	add_child(elite)
	_enemies_alive = 1

func _spawn_boss() -> void:
	var boss = AdvancedEnemy.new()
	boss.configure_advanced("boss",_floor_index)
	boss.position = Vector2(room_rect.get_center().x,room_rect.position.y+room_rect.size.y*0.28)
	boss.target = player
	boss.spawn_grace_time = 1.0
	boss.set_movement_bounds(room_rect)
	boss.defeated.connect(_on_enemy_defeated)
	add_child(boss)
	_enemies_alive = 1
	if not boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)
	if is_instance_valid(boss_hud):
		boss_hud.show_boss(FloorCatalog.boss_name(_floor_index),boss.health)

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
