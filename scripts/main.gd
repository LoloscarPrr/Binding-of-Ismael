extends Node2D

const TOTAL_FLOORS := 2
const ROOM_ENTRY_DELAY := 0.65
const FLOOR_TRANSITION_DELAY := 1.35
const ENEMY_ACTIVATION_DELAY := 0.70
const MIN_ENEMY_SEPARATION_RATIO := 0.16
const REWARD_POOL: Array[String] = [
	"vida","curacion","movimiento","cadencia","proyectil","dano",
	"buscadora","perforante","escudo","rafaga","mapa","monedero"
]
const DIRS: Array[Vector2i] = [
	Vector2i(0,-1),
	Vector2i(1,0),
	Vector2i(0,1),
	Vector2i(-1,0)
]

var player: IsmaelPlayer
var left_stick: VirtualStick
var right_stick: VirtualStick
var hud_backdrop: Panel
var health_hud: IsmaelHealthHud
var pickup_label: Label
var minimap_label: Label
var status_label: Label
var room_label: Label
var floor_label: Label
var reward_label: Label
var restart_button: Button
var reward_left: Button
var reward_right: Button
var floor_exit_label: Label
var room_rect := Rect2()

var _dungeon: IsmaelDungeonMap
var _current_cell := Vector2i.ZERO
var _doors: Dictionary = {}
var _floor_exit_direction := Vector2i.ZERO

var _enemies_alive := 0
var _game_over := false
var _run_complete := false
var _floor_index := 1
var _room_index := 1
var _room_cleared := false
var _transition_locked := false
var _spawn_generation := 0
var _rooms_cleared_total := 0
var _room_kind := "inicio"
var _last_reward := ""
var _offered_rewards: Array[String] = []
var _coins := 0
var _bombs := 0
var _keys := 0
var _challenge_wave := 0
var _challenge_waves_total := 2
var _special_used: Dictionary = {}
var _reward_offers: Dictionary = {}
var _map_reveal_active := false
var _coin_bonus_per_clear := 0

func _ready() -> void:
	_configure_mobile_display()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_room_rect()
	_dungeon = IsmaelDungeonMap.new()
	_dungeon.generate(_floor_index)
	_current_cell = Vector2i.ZERO
	player = IsmaelPlayer.new()
	player.position = _room_entry_position(Vector2i.ZERO)
	player.set_movement_bounds(room_rect)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	add_child(player)
	_create_touch_ui()
	_create_floor_exit_label()
	_on_player_health_changed(player.health,player.max_health)
	_update_pickup_hud()
	_layout_touch_ui()
	_begin_room(Vector2i.ZERO)
	queue_redraw()

func _configure_mobile_display() -> void:
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		return
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	_spawn_generation += 1
	var generation: int = _spawn_generation
	_transition_locked = true
	_enemies_alive = 0
	_dungeon.mark_entered(_current_cell)
	_room_index = _dungeon.display_ordinal(_current_cell)
	_room_kind = _dungeon.kind(_current_cell)
	_room_cleared = _dungeon.is_cleared(_current_cell)
	_challenge_wave = 0
	if _dungeon.is_hidden(_current_cell):
		room_label.text = "SALA OCULTA"
	else:
		room_label.text = "SALA %d / %d" % [_room_index,_dungeon.public_room_count()]
	floor_label.text = "PISO %d" % _floor_index
	status_label.text = _room_title()
	reward_label.text = ""
	_hide_reward_choices()
	_clear_room_obstacles()
	_clear_room_pickups()
	_clear_enemy_projectiles()
	_clear_room_doors()
	if is_instance_valid(floor_exit_label):
		floor_exit_label.visible = false
	player.position = _room_entry_position(entry_direction)
	player.velocity = Vector2.ZERO
	player.move_input = Vector2.ZERO
	player.aim_input = Vector2.ZERO
	_build_room_layout()
	_setup_room_doors()
	_update_minimap()
	queue_redraw()

	if _room_kind == "inicio":
		_mark_current_room_cleared(false)
		status_label.text = "ENTRADA"
		return
	if _room_kind == "tienda":
		_mark_current_room_cleared(false)
		status_label.text = "TIENDA DEL ERRANTE"
		reward_label.text = "Explora antes de seguir"
		return
	if _room_kind == "sacrificio":
		_open_sacrifice_room()
		return
	if _room_kind in ["secreta","supersecreta"]:
		_open_hidden_loot_room()
		return
	if _room_cleared:
		_transition_locked = false
		_set_door_open(true)
		status_label.text = _room_title()
		return
	if _room_kind == "recompensa":
		_open_reward_room(generation)
	else:
		_spawn_room_after_entry(generation)

func _get_room_kind() -> String:
	return _dungeon.kind(_current_cell) if _dungeon != null else "combate"

func _room_title() -> String:
	match _room_kind:
		"inicio": return "ENTRADA"
		"jefe": return "GUARDIÁN DEL PISO"
		"recompensa": return "CÁMARA DE OFRENDA"
		"tienda": return "TIENDA DEL ERRANTE"
		"emboscada": return "EMBOSCADA"
		"desafio": return "CÁMARA DE DESAFÍO"
		"minijefe": return "GUARDIÁN MENOR"
		"sacrificio": return "ALTAR DE SACRIFICIO"
		"secreta": return "CÁMARA SECRETA"
		"supersecreta": return "SANTUARIO OCULTO"
		_: return "PREPÁRATE"

func _clear_room_obstacles() -> void:
	for obstacle in get_tree().get_nodes_in_group("room_obstacles"):
		obstacle.queue_free()

func _clear_room_pickups() -> void:
	for pickup in get_tree().get_nodes_in_group("room_pickups"):
		pickup.queue_free()

func _clear_enemy_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()

func _clear_room_doors() -> void:
	for door_variant in _doors.values():
		var door: Node = door_variant
		if is_instance_valid(door):
			door.queue_free()
	_doors.clear()
	_floor_exit_direction = Vector2i.ZERO

func _setup_room_doors() -> void:
	for dir: Vector2i in DIRS:
		var destination := _current_cell+dir
		if not _dungeon.has_room(destination):
			continue
		if _dungeon.is_hidden(destination) and not _dungeon.is_discovered(destination):
			continue
		_create_room_door(dir)
	if _room_kind == "jefe":
		_floor_exit_direction = _dungeon.outward_direction(_current_cell)
		if not _dungeon.has_room(_current_cell+_floor_exit_direction):
			_create_room_door(_floor_exit_direction)
			var exit_door: IsmaelRoomDoor = _doors.get(_floor_exit_direction)
			if is_instance_valid(exit_door):
				exit_door.mark_floor_exit(_floor_index+1)
			_position_floor_exit_label(_floor_exit_direction)
			_refresh_floor_exit_label(_room_cleared)

func _create_room_door(direction: Vector2i) -> void:
	if _doors.has(direction):
		return
	var door := IsmaelRoomDoor.new()
	var center := room_rect.get_center()
	if direction == Vector2i(0,-1):
		door.position = Vector2(center.x,room_rect.position.y+25.0)
		door.rotation = 0.0
	elif direction == Vector2i(0,1):
		door.position = Vector2(center.x,room_rect.end.y-25.0)
		door.rotation = PI
	elif direction == Vector2i(-1,0):
		door.position = Vector2(room_rect.position.x+25.0,center.y)
		door.rotation = -PI*0.5
	else:
		door.position = Vector2(room_rect.end.x-25.0,center.y)
		door.rotation = PI*0.5
	var destination := _current_cell+direction
	if _dungeon.has_room(destination) and _dungeon.is_hidden(destination):
		door.modulate = Color(0.62,0.47,0.30,0.90)
	door.set_open(_room_cleared)
	add_child(door)
	_doors[direction] = door

func _set_door_open(value: bool) -> void:
	for door_variant in _doors.values():
		var door: IsmaelRoomDoor = door_variant
		if is_instance_valid(door):
			door.set_open(value)
	if _room_kind == "jefe":
		_refresh_floor_exit_label(value)
	queue_redraw()

func _mark_current_room_cleared(count_clear: bool = true) -> void:
	var was_cleared := _dungeon.is_cleared(_current_cell)
	_room_cleared = true
	_dungeon.set_cleared(_current_cell,true)
	_transition_locked = false
	_set_door_open(true)
	if count_clear and not was_cleared:
		_rooms_cleared_total += 1
		if is_instance_valid(player) and player.has_method("notify_room_cleared"):
			player.notify_room_cleared()
	_update_minimap()

func _add_obstacle(ratio: Vector2,size_ratio: Vector2,variant: int = 0) -> void:
	var obstacle := IsmaelRoomObstacle.new()
	var obstacle_size := Vector2(room_rect.size.x*size_ratio.x,room_rect.size.y*size_ratio.y)
	obstacle.configure(obstacle_size,variant)
	obstacle.position = room_rect.position+room_rect.size*ratio
	add_child(obstacle)

func _build_room_layout() -> void:
	if _room_kind in ["inicio","recompensa","tienda","sacrificio","secreta","supersecreta"]:
		return
	var variant: int = 0 if _floor_index == 1 else 1
	if _room_kind == "jefe":
		_add_obstacle(Vector2(0.24,0.58),Vector2(0.08,0.16),2)
		_add_obstacle(Vector2(0.76,0.58),Vector2(0.08,0.16),2)
		return
	if _room_kind == "emboscada":
		_add_obstacle(Vector2(0.38,0.56),Vector2(0.07,0.12),variant)
		_add_obstacle(Vector2(0.62,0.56),Vector2(0.07,0.12),variant)
		_add_obstacle(Vector2(0.50,0.47),Vector2(0.08,0.08),variant)
		return
	if _room_kind == "desafio":
		_add_obstacle(Vector2(0.28,0.50),Vector2(0.06,0.17),2)
		_add_obstacle(Vector2(0.72,0.50),Vector2(0.06,0.17),2)
		return
	if _room_kind == "minijefe":
		_add_obstacle(Vector2(0.22,0.66),Vector2(0.07,0.10),2)
		_add_obstacle(Vector2(0.78,0.66),Vector2(0.07,0.10),2)
		return
	match _room_index % 4:
		0:
			_add_obstacle(Vector2(0.35,0.58),Vector2(0.07,0.18),variant)
			_add_obstacle(Vector2(0.65,0.58),Vector2(0.07,0.18),variant)
		1:
			_add_obstacle(Vector2(0.50,0.55),Vector2(0.18,0.08),variant)
		2:
			_add_obstacle(Vector2(0.30,0.60),Vector2(0.08,0.11),variant)
			_add_obstacle(Vector2(0.50,0.52),Vector2(0.08,0.11),variant)
			_add_obstacle(Vector2(0.70,0.60),Vector2(0.08,0.11),variant)
		3:
			_add_obstacle(Vector2(0.32,0.42),Vector2(0.09,0.09),variant)
			_add_obstacle(Vector2(0.68,0.68),Vector2(0.09,0.09),variant)

func _open_reward_room(generation: int) -> void:
	await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
	if generation != _spawn_generation or _game_over:
		return
	var room_key := _reward_room_key()
	if _reward_offers.has(room_key):
		_offered_rewards.clear()
		for value in _reward_offers[room_key]:
			_offered_rewards.append(String(value))
	else:
		_offered_rewards = _make_reward_choices()
		_reward_offers[room_key] = _offered_rewards.duplicate()
	status_label.text = "ELIGE UNA OFRENDA"
	reward_label.text = "CAMINA SOBRE UN OBJETO — EL OTRO DESAPARECERÁ"
	_spawn_reward_pedestal(_offered_rewards[0],room_rect.position+room_rect.size*Vector2(0.38,0.53))
	_spawn_reward_pedestal(_offered_rewards[1],room_rect.position+room_rect.size*Vector2(0.62,0.53))
	_transition_locked = false

func _reward_room_key() -> String:
	return "%d:%d:%d" % [_floor_index,_current_cell.x,_current_cell.y]

func _spawn_reward_pedestal(reward: String, world_position: Vector2) -> void:
	var pedestal := IsmaelWorldRewardPedestal.new()
	pedestal.configure_reward(reward,_reward_name(reward))
	pedestal.position = world_position
	pedestal.claimed.connect(_on_reward_pedestal_claimed)
	add_child(pedestal)

func _make_reward_choices() -> Array[String]:
	var available: Array[String] = []
	for reward: String in REWARD_POOL:
		if reward != _last_reward:
			available.append(reward)
	available.shuffle()
	return [available[0],available[1]]

func _reward_name(reward: String) -> String:
	match reward:
		"vida": return "CORAZÓN VOTIVO\n+1 VIDA MÁXIMA"
		"curacion": return "VENDA RITUAL\nCURA 1 CADA 3 SALAS"
		"movimiento": return "BOTAS GASTADAS\n+ MOVIMIENTO"
		"cadencia": return "RELOJ ROTO\n+ CADENCIA"
		"proyectil": return "LÁGRIMA DE VIDRIO\n+ VELOCIDAD DE LÁGRIMA"
		"dano": return "OJO ROJO\n+ DAÑO"
		"buscadora": return "OJO DE POLILLA\nLÁGRIMAS BUSCADORAS"
		"perforante": return "AGUJA HUECA\nLÁGRIMAS PERFORANTES"
		"escudo": return "ROSARIO DE HIERRO\nBLOQUEA 1 GOLPE POR PISO"
		"rafaga": return "GUANTE NERVIOSO\nRÁFAGA DE 3 LÁGRIMAS"
		"mapa": return "MAPA QUEMADO\nREVELA EL PISO"
		"monedero": return "MONEDERO VIEJO\n+ ECONOMÍA POR SALA"
		_: return reward

func _on_reward_pedestal_claimed(reward: String) -> void:
	if _room_cleared or not _offered_rewards.has(reward):
		return
	_apply_reward(reward)
	_last_reward = reward
	for pedestal in get_tree().get_nodes_in_group("reward_offerings"):
		if is_instance_valid(pedestal):
			pedestal.queue_free()
	status_label.text = "OFRENDA RECOGIDA"
	reward_label.text = _reward_name(reward).replace("\n"," — ")
	_mark_current_room_cleared(false)
	queue_redraw()

func _apply_reward(reward: String) -> void:
	match reward:
		"vida":
			player.add_max_health(1)
		"curacion":
			player.room_heal_interval = 3
			player.heal(1)
		"movimiento":
			player.move_speed += 24.0
		"cadencia":
			player.fire_rate = maxf(0.09,player.fire_rate-0.022)
		"proyectil":
			player.projectile_speed += 120.0
		"dano":
			player.projectile_damage += 1
		"buscadora":
			player.homing_strength = maxf(player.homing_strength,4.8)
		"perforante":
			player.projectile_pierce = maxi(player.projectile_pierce,1)
		"escudo":
			player.floor_shield_enabled = true
			player.refill_floor_shield()
		"rafaga":
			player.burst_count = maxi(player.burst_count,3)
		"mapa":
			_map_reveal_active = true
			if _dungeon != null:
				_dungeon.reveal_public_rooms()
				_update_minimap()
		"monedero":
			_coins += 5
			_coin_bonus_per_clear = maxi(_coin_bonus_per_clear,1)
			_update_pickup_hud()

func _hide_reward_choices() -> void:
	for pedestal in get_tree().get_nodes_in_group("reward_offerings"):
		if is_instance_valid(pedestal):
			pedestal.queue_free()

func _spawn_room_after_entry(generation: int) -> void:
	await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
	if generation != _spawn_generation or _game_over:
		return
	if _room_kind == "jefe":
		_spawn_boss()
	elif _room_kind == "minijefe":
		_spawn_miniboss()
	elif _room_kind == "desafio":
		_challenge_wave = 1
		_spawn_challenge_wave()
	else:
		var depth := _dungeon.distance(_current_cell)
		var count: int = mini(2+depth+_floor_index,8)
		if _room_kind == "emboscada":
			count = mini(count+2,9)
		_spawn_enemy_pack(count,depth)
	_transition_locked = false
	if _room_kind == "jefe":
		status_label.text = "GUARDIÁN"
	elif _room_kind == "minijefe":
		status_label.text = "GUARDIÁN MENOR"
	elif _room_kind == "desafio":
		status_label.text = "OLEADA 1 / %d" % _challenge_waves_total
	else:
		status_label.text = ""
	queue_redraw()

func _spawn_enemy_pack(count: int,depth: int) -> void:
	var positions: Array[Vector2] = _deterministic_spawn_positions(count)
	_enemies_alive = positions.size()
	for i in positions.size():
		var enemy := IsmaelEnemy.new()
		var kind_index: int = (i+depth+_floor_index)%3
		enemy.configure(kind_index as IsmaelEnemy.EnemyKind,_floor_index)
		enemy.position = positions[i]
		enemy.target = player
		enemy.spawn_grace_time = ENEMY_ACTIVATION_DELAY
		enemy.set_movement_bounds(room_rect)
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)

func _spawn_challenge_wave() -> void:
	var depth := _dungeon.distance(_current_cell)+_challenge_wave
	var count := mini(2+_floor_index+_challenge_wave*2,8)
	_spawn_enemy_pack(count,depth)

func _spawn_miniboss() -> void:
	var elite := IsmaelEnemy.new()
	elite.configure(IsmaelEnemy.EnemyKind.BOSS,_floor_index)
	elite.health = 10+_floor_index*3
	elite.max_health = elite.health
	elite.speed = 112.0+_floor_index*6.0
	elite.scale = Vector2(0.78,0.78)
	elite.position = room_rect.position+room_rect.size*Vector2(0.50,0.32)
	elite.target = player
	elite.spawn_grace_time = 0.9
	elite.set_movement_bounds(room_rect)
	elite.defeated.connect(_on_enemy_defeated)
	add_child(elite)
	_enemies_alive = 1

func _special_room_key() -> String:
	return "%d:%d:%d:%s" % [_floor_index,_current_cell.x,_current_cell.y,_room_kind]

func _open_sacrifice_room() -> void:
	_mark_current_room_cleared(false)
	status_label.text = "ALTAR DE SACRIFICIO"
	reward_label.text = "Acércate al altar si deseas ofrecer vida"
	var key := _special_room_key()
	if bool(_special_used.get(key,false)):
		reward_label.text = "El altar ya recibió tu ofrenda"
		return
	var altar := IsmaelSacrificeAltar.new()
	altar.position = room_rect.get_center()
	altar.requested.connect(_on_sacrifice_requested)
	add_child(altar)

func _on_sacrifice_requested(altar: IsmaelSacrificeAltar) -> void:
	if not is_instance_valid(altar) or altar.used:
		return
	if player.health <= 1:
		altar.show_blocked()
		status_label.text = "NO PUEDES OFRECER TU ÚLTIMO CORAZÓN"
		return
	player.take_damage(1)
	var key := _special_room_key()
	_special_used[key] = true
	altar.mark_used()
	_coins += 4+_floor_index
	_keys += 1
	var rewards: Array[String] = ["movimiento","cadencia","proyectil","dano"]
	var reward := rewards[abs(_current_cell.x*17+_current_cell.y*31+_floor_index)%rewards.size()]
	_apply_reward(reward)
	_update_pickup_hud()
	status_label.text = "OFRENDA ACEPTADA"
	reward_label.text = "%s  ·  + MONEDAS Y LLAVE" % _reward_name(reward).replace("\n"," ")

func _open_hidden_loot_room() -> void:
	_mark_current_room_cleared(false)
	var key := _special_room_key()
	if bool(_special_used.get(key,false)):
		status_label.text = "CÁMARA VACÍA"
		reward_label.text = ""
		return
	_special_used[key] = true
	if _room_kind == "supersecreta":
		status_label.text = "SANTUARIO OCULTO"
		reward_label.text = "Una reserva excepcional"
		_spawn_pickup_at("heart",Vector2(0.43,0.53))
		_spawn_pickup_at("key",Vector2(0.50,0.48))
		_spawn_pickup_at("bomb",Vector2(0.57,0.53))
		_coins += 5
		_update_pickup_hud()
	else:
		status_label.text = "CÁMARA SECRETA"
		reward_label.text = "Encontraste una reserva escondida"
		_spawn_pickup_at("coin",Vector2(0.44,0.52))
		_spawn_pickup_at("bomb",Vector2(0.56,0.52))

func _spawn_special_bundle(kind: String) -> void:
	if kind == "minijefe":
		_spawn_pickup_at("key",Vector2(0.45,0.55))
		_spawn_pickup_at("heart",Vector2(0.55,0.55))
		_coins += 3
	else:
		_spawn_pickup_at("bomb",Vector2(0.42,0.55))
		_spawn_pickup_at("coin",Vector2(0.50,0.50))
		_spawn_pickup_at("key",Vector2(0.58,0.55))
	_update_pickup_hud()

func _spawn_pickup_at(kind: String,ratio: Vector2) -> void:
	var pickup := IsmaelPickup.new()
	pickup.configure(kind)
	pickup.position = room_rect.position+room_rect.size*ratio
	pickup.collected.connect(_on_pickup_collected)
	add_child(pickup)

func _detect_hidden_wall_direction() -> Vector2i:
	var center := room_rect.get_center()
	var edge := 66.0
	var doorway_half := 88.0
	for dir: Vector2i in DIRS:
		var destination := _current_cell+dir
		if not _dungeon.has_room(destination):
			continue
		if not _dungeon.is_hidden(destination) or _dungeon.is_discovered(destination):
			continue
		if dir == Vector2i(0,-1) and player.position.y < room_rect.position.y+edge and absf(player.position.x-center.x)<doorway_half:
			return dir
		if dir == Vector2i(0,1) and player.position.y > room_rect.end.y-edge and absf(player.position.x-center.x)<doorway_half:
			return dir
		if dir == Vector2i(-1,0) and player.position.x < room_rect.position.x+edge and absf(player.position.y-center.y)<doorway_half:
			return dir
		if dir == Vector2i(1,0) and player.position.x > room_rect.end.x-edge and absf(player.position.y-center.y)<doorway_half:
			return dir
	return Vector2i.ZERO

func _try_reveal_hidden_room(direction: Vector2i) -> void:
	var destination := _current_cell+direction
	if not _dungeon.has_room(destination) or not _dungeon.is_hidden(destination):
		return
	if _bombs <= 0:
		status_label.text = "PARED SOSPECHOSA — NECESITAS UNA BOMBA"
		return
	_bombs -= 1
	_update_pickup_hud()
	_dungeon.reveal(destination)
	_clear_room_doors()
	_setup_room_doors()
	_set_door_open(true)
	_update_minimap()
	status_label.text = "PARED SECRETA ABIERTA"
	reward_label.text = "Se consumió 1 bomba"

func _spawn_boss() -> void:
	var boss := IsmaelEnemy.new()
	boss.configure(IsmaelEnemy.EnemyKind.BOSS,_floor_index)
	boss.position = Vector2(room_rect.get_center().x,room_rect.position.y+room_rect.size.y*0.28)
	boss.target = player
	boss.spawn_grace_time = 1.0
	boss.set_movement_bounds(room_rect)
	boss.defeated.connect(_on_enemy_defeated)
	add_child(boss)
	_enemies_alive = 1

func _room_entry_position(travel_direction: Vector2i) -> Vector2:
	var center := room_rect.get_center()
	if travel_direction == Vector2i(0,-1):
		return Vector2(center.x,room_rect.end.y-92.0)
	if travel_direction == Vector2i(0,1):
		return Vector2(center.x,room_rect.position.y+92.0)
	if travel_direction == Vector2i(-1,0):
		return Vector2(room_rect.end.x-92.0,center.y)
	if travel_direction == Vector2i(1,0):
		return Vector2(room_rect.position.x+92.0,center.y)
	return Vector2(center.x,room_rect.position.y+room_rect.size.y*0.82)

func _deterministic_spawn_positions(count: int) -> Array[Vector2]:
	var base_slots: Array[Vector2] = [
		Vector2(0.14,0.16),Vector2(0.86,0.16),Vector2(0.32,0.18),Vector2(0.68,0.18),
		Vector2(0.14,0.38),Vector2(0.86,0.38),Vector2(0.34,0.42),Vector2(0.66,0.42),
		Vector2(0.50,0.12),Vector2(0.50,0.36),Vector2(0.24,0.30),Vector2(0.76,0.30)
	]
	var slots: Array[Vector2] = base_slots.duplicate()
	var rotation: int = (_room_index+_floor_index*2)%slots.size()
	for i in rotation:
		slots.append(slots.pop_front())
	var result: Array[Vector2] = []
	var minimum_separation: float = maxf(105.0,minf(room_rect.size.x,room_rect.size.y)*MIN_ENEMY_SEPARATION_RATIO)
	var player_safe_radius: float = maxf(room_rect.size.y*0.36,250.0)
	for ratio: Vector2 in slots:
		if result.size() >= count:
			break
		var candidate: Vector2 = room_rect.position+room_rect.size*ratio
		if candidate.distance_to(player.position) < player_safe_radius:
			continue
		var separated := true
		for existing: Vector2 in result:
			if candidate.distance_to(existing) < minimum_separation:
				separated = false
				break
		if separated:
			result.append(candidate)
	return result

func _spawn_clear_pickup() -> void:
	if _room_kind in ["inicio","recompensa","tienda"]:
		return
	var pickup := IsmaelPickup.new()
	var kind := "coin"
	if _room_kind == "jefe":
		kind = "key"
	else:
		match (_rooms_cleared_total+_floor_index)%4:
			0: kind = "heart"
			1: kind = "coin"
			2: kind = "bomb"
			3: kind = "key"
	pickup.configure(kind)
	pickup.position = room_rect.position+room_rect.size*Vector2(0.50,0.60)
	pickup.collected.connect(_on_pickup_collected)
	add_child(pickup)

func _on_pickup_collected(kind: String) -> void:
	match kind:
		"heart": player.heal(2)
		"coin": _coins += 1
		"bomb": _bombs += 1
		"key": _keys += 1
	_update_pickup_hud()

func _update_pickup_hud() -> void:
	if is_instance_valid(pickup_label):
		pickup_label.text = "¢ %02d    ● %02d    ⚿ %02d" % [_coins,_bombs,_keys]

func _update_minimap() -> void:
	if not is_instance_valid(minimap_label) or _dungeon == null:
		return
	minimap_label.text = _dungeon.minimap_text(_current_cell)

func _create_floor_exit_label() -> void:
	floor_exit_label = Label.new()
	floor_exit_label.visible = false
	floor_exit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_exit_label.z_index = 8
	floor_exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floor_exit_label.add_theme_font_size_override("font_size",18)
	floor_exit_label.add_theme_color_override("font_color",Color(1.0,0.86,0.46))
	floor_exit_label.add_theme_color_override("font_outline_color",Color(0.04,0.025,0.012,1.0))
	floor_exit_label.add_theme_constant_override("outline_size",5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03,0.022,0.016,0.86)
	style.border_color = Color(0.72,0.48,0.16,0.72)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	floor_exit_label.add_theme_stylebox_override("normal",style)
	add_child(floor_exit_label)

func _position_floor_exit_label(direction: Vector2i) -> void:
	if not is_instance_valid(floor_exit_label):
		return
	var center := room_rect.get_center()
	floor_exit_label.size = Vector2(236.0,38.0)
	if direction == Vector2i(0,-1):
		floor_exit_label.position = Vector2(center.x-118.0,room_rect.position.y+58.0)
	elif direction == Vector2i(0,1):
		floor_exit_label.position = Vector2(center.x-118.0,room_rect.end.y-96.0)
	elif direction == Vector2i(-1,0):
		floor_exit_label.position = Vector2(room_rect.position.x+46.0,center.y-48.0)
	else:
		floor_exit_label.position = Vector2(room_rect.end.x-282.0,center.y-48.0)
	floor_exit_label.visible = true

func _refresh_floor_exit_label(opened: bool) -> void:
	if not is_instance_valid(floor_exit_label) or _room_kind != "jefe":
		return
	floor_exit_label.visible = true
	if _floor_index < TOTAL_FLOORS:
		floor_exit_label.text = ("▼ BAJAR AL PISO %d ▼" if opened else "SALIDA AL PISO %d") % (_floor_index+1)
	else:
		floor_exit_label.text = "▼ SALIDA FINAL ▼" if opened else "SALIDA FINAL"

func _create_touch_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud_backdrop = Panel.new()
	hud_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.035,0.027,0.023,0.82)
	hud_style.border_color = Color(0.25,0.19,0.15,0.72)
	hud_style.border_width_bottom = 2
	hud_backdrop.add_theme_stylebox_override("panel",hud_style)
	layer.add_child(hud_backdrop)
	left_stick = VirtualStick.new()
	layer.add_child(left_stick)
	right_stick = VirtualStick.new()
	layer.add_child(right_stick)
	health_hud = IsmaelHealthHud.new()
	layer.add_child(health_hud)
	pickup_label = Label.new()
	layer.add_child(pickup_label)
	minimap_label = Label.new()
	minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(minimap_label)
	floor_label = Label.new()
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(floor_label)
	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(room_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(status_label)
	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(reward_label)
	restart_button = Button.new()
	restart_button.text = "NUEVO RECORRIDO"
	restart_button.visible = false
	restart_button.pressed.connect(_restart_game)
	layer.add_child(restart_button)

func _layout_touch_ui() -> void:
	if not is_instance_valid(left_stick):
		return
	var screen_size := get_viewport_rect().size
	var short_side := minf(screen_size.x,screen_size.y)
	var ui_scale := clampf(short_side/720.0,0.78,1.35)
	var stick_side := clampf(short_side*0.48,265.0,380.0)
	var margin_x := clampf(screen_size.x*0.018,16.0,40.0)
	var margin_bottom := clampf(screen_size.y*0.015,10.0,26.0)
	left_stick.size = Vector2(stick_side,stick_side)
	right_stick.size = left_stick.size
	left_stick.stick_radius = stick_side*0.39
	right_stick.stick_radius = left_stick.stick_radius
	left_stick.knob_radius = stick_side*0.17
	right_stick.knob_radius = left_stick.knob_radius
	left_stick.position = Vector2(margin_x,screen_size.y-stick_side-margin_bottom)
	right_stick.position = Vector2(screen_size.x-stick_side-margin_x,screen_size.y-stick_side-margin_bottom)
	var resource_font := maxi(18,int(round(20.0*ui_scale)))
	var small_font := resource_font
	var normal_font := maxi(24,int(round(27.0*ui_scale)))
	pickup_label.add_theme_font_size_override("font_size",resource_font)
	minimap_label.add_theme_font_size_override("font_size",resource_font)
	floor_label.add_theme_font_size_override("font_size",small_font)
	room_label.add_theme_font_size_override("font_size",small_font)
	status_label.add_theme_font_size_override("font_size",normal_font)
	reward_label.add_theme_font_size_override("font_size",small_font)
	for label: Label in [pickup_label,minimap_label,floor_label,room_label,status_label,reward_label]:
		label.add_theme_color_override("font_color",Color(0.92,0.86,0.75))
		label.add_theme_color_override("font_outline_color",Color(0.025,0.018,0.015,0.98))
		label.add_theme_constant_override("outline_size",maxi(3,int(round(4.0*ui_scale))))
	var hud_height := clampf(90.0*ui_scale,86.0,118.0)
	hud_backdrop.position = Vector2.ZERO
	hud_backdrop.size = Vector2(screen_size.x,hud_height)
	var left_width := clampf(screen_size.x*0.30,370.0,520.0)
	var map_width := clampf(screen_size.x*0.27,330.0,480.0)
	health_hud.icon_size = 28.0*ui_scale
	health_hud.icon_gap = 7.0*ui_scale
	health_hud.position = Vector2(margin_x,8.0*ui_scale)
	health_hud.size = Vector2(left_width,39.0*ui_scale)
	pickup_label.position = Vector2(margin_x,51.0*ui_scale)
	pickup_label.size = Vector2(left_width,34.0*ui_scale)
	minimap_label.position = Vector2(screen_size.x-map_width-margin_x,7.0*ui_scale)
	minimap_label.size = Vector2(map_width,76.0*ui_scale)
	var info_width := clampf(screen_size.x*0.12,150.0,240.0)
	floor_label.position = Vector2(screen_size.x*0.5-info_width-7.0,10.0*ui_scale)
	floor_label.size = Vector2(info_width,34.0*ui_scale)
	room_label.position = Vector2(screen_size.x*0.5+7.0,10.0*ui_scale)
	room_label.size = Vector2(info_width,34.0*ui_scale)
	var center_width := clampf(screen_size.x*0.38,410.0,680.0)
	status_label.position = Vector2(screen_size.x*0.5-center_width*0.5,49.0*ui_scale)
	status_label.size = Vector2(center_width,42.0*ui_scale)
	var end_screen_visible := _run_complete or _game_over
	var reward_y_ratio := 0.46 if end_screen_visible else 0.58
	reward_label.position = Vector2(screen_size.x*0.5-center_width*0.5,screen_size.y*reward_y_ratio)
	reward_label.size = Vector2(center_width,44.0*ui_scale)
	restart_button.size = Vector2(280.0,76.0)*ui_scale
	restart_button.position = Vector2(screen_size.x*0.5-restart_button.size.x*0.5,screen_size.y*(0.62 if end_screen_visible else 0.5))
	restart_button.add_theme_font_size_override("font_size",small_font)

func _input(event: InputEvent) -> void:
	if _game_over or _run_complete:
		return
	if left_stick and left_stick.handle_touch(event):
		get_viewport().set_input_as_handled()
		return
	if right_stick and right_stick.handle_touch(event):
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _game_over or _run_complete or not is_instance_valid(player):
		return
	if _transition_locked:
		player.move_input = Vector2.ZERO
		player.aim_input = Vector2.ZERO
		return
	var keyboard_move := Input.get_vector("move_left","move_right","move_up","move_down")
	var keyboard_aim := Input.get_vector("shoot_left","shoot_right","shoot_up","shoot_down")
	player.move_input = left_stick.value if left_stick.value.length()>0.0 else keyboard_move
	player.aim_input = right_stick.value if right_stick.value.length()>0.0 else keyboard_aim
	if _room_cleared:
		var exit_direction := _detect_exit_direction()
		if exit_direction != Vector2i.ZERO:
			if _room_kind == "jefe" and exit_direction == _floor_exit_direction and not _dungeon.has_room(_current_cell+exit_direction):
				_finish_floor()
			else:
				_travel_to(exit_direction)
			return
		var hidden_direction := _detect_hidden_wall_direction()
		if hidden_direction != Vector2i.ZERO:
			_try_reveal_hidden_room(hidden_direction)

func _detect_exit_direction() -> Vector2i:
	var center := room_rect.get_center()
	var edge := 74.0
	var doorway_half := 96.0
	if _doors.has(Vector2i(0,-1)) and player.position.y < room_rect.position.y+edge and absf(player.position.x-center.x)<doorway_half:
		return Vector2i(0,-1)
	if _doors.has(Vector2i(0,1)) and player.position.y > room_rect.end.y-edge and absf(player.position.x-center.x)<doorway_half:
		return Vector2i(0,1)
	if _doors.has(Vector2i(-1,0)) and player.position.x < room_rect.position.x+edge and absf(player.position.y-center.y)<doorway_half:
		return Vector2i(-1,0)
	if _doors.has(Vector2i(1,0)) and player.position.x > room_rect.end.x-edge and absf(player.position.y-center.y)<doorway_half:
		return Vector2i(1,0)
	return Vector2i.ZERO

func _travel_to(direction: Vector2i) -> void:
	if _transition_locked:
		return
	var destination := _current_cell+direction
	if not _dungeon.has_room(destination):
		return
	_transition_locked = true
	_current_cell = destination
	_begin_room(direction)

func _finish_floor() -> void:
	if _transition_locked:
		return
	_transition_locked = true
	_spawn_generation += 1
	if _floor_index >= TOTAL_FLOORS:
		_run_complete = true
		status_label.text = "RECORRIDO COMPLETADO"
		reward_label.text = "ISMAEL SOBREVIVIÓ A LOS GUARDIANES"
		restart_button.visible = true
		left_stick.reset()
		right_stick.reset()
		_layout_touch_ui()
		return
	status_label.text = "GUARDIÁN DERROTADO — PISO %d" % _floor_index
	reward_label.text = _grant_floor_reward()
	_floor_transition()

func _floor_transition() -> void:
	await get_tree().create_timer(FLOOR_TRANSITION_DELAY).timeout
	if _game_over:
		return
	_floor_index += 1
	_dungeon.generate(_floor_index)
	if _map_reveal_active:
		_dungeon.reveal_public_rooms()
	if is_instance_valid(player) and player.floor_shield_enabled:
		player.refill_floor_shield()
	_current_cell = Vector2i.ZERO
	_begin_room(Vector2i.ZERO)

func _grant_floor_reward() -> String:
	player.add_max_health(1)
	return "RELIQUIA: +1 VIDA MÁXIMA"

func _on_viewport_size_changed() -> void:
	_update_room_rect()
	if is_instance_valid(player):
		player.set_movement_bounds(room_rect)
		player.position.x = clampf(player.position.x,room_rect.position.x,room_rect.end.x)
		player.position.y = clampf(player.position.y,room_rect.position.y,room_rect.end.y)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_movement_bounds(room_rect)
	_clear_room_doors()
	_setup_room_doors()
	_set_door_open(_room_cleared)
	_layout_touch_ui()
	queue_redraw()

func _update_room_rect() -> void:
	var s := get_viewport_rect().size
	var side := clampf(s.x*0.035,30.0,64.0)
	var top := clampf(s.y*0.14,100.0,128.0)
	var bottom := clampf(s.y*0.055,28.0,50.0)
	room_rect = Rect2(Vector2(side,top),Vector2(maxf(1.0,s.x-side*2.0),maxf(1.0,s.y-top-bottom)))

func _on_player_health_changed(current: int,maximum: int) -> void:
	if is_instance_valid(health_hud):
		health_hud.set_health(current,maximum)

func _on_player_died() -> void:
	_game_over = true
	_spawn_generation += 1
	_hide_reward_choices()
	_clear_enemy_projectiles()
	left_stick.reset()
	right_stick.reset()
	status_label.text = "DERROTA"
	reward_label.text = ""
	restart_button.visible = true
	_layout_touch_ui()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.velocity = Vector2.ZERO
		enemy.set_physics_process(false)

func _on_enemy_defeated(_enemy) -> void:
	_enemies_alive = maxi(0,_enemies_alive-1)
	if _enemies_alive != 0 or _game_over:
		return
	_clear_enemy_projectiles()
	if _room_kind == "desafio" and _challenge_wave < _challenge_waves_total:
		_challenge_wave += 1
		status_label.text = "OLEADA %d / %d" % [_challenge_wave,_challenge_waves_total]
		var generation := _spawn_generation
		await get_tree().create_timer(0.75).timeout
		if generation == _spawn_generation and not _game_over:
			_spawn_challenge_wave()
		return
	_mark_current_room_cleared(true)
	if _room_kind == "desafio":
		_spawn_special_bundle("desafio")
		status_label.text = "DESAFÍO SUPERADO"
	elif _room_kind == "minijefe":
		_spawn_special_bundle("minijefe")
		status_label.text = "GUARDIÁN MENOR DERROTADO"
	else:
		_spawn_clear_pickup()
		if _room_kind == "jefe":
			status_label.text = "GUARDIÁN DERROTADO — ENCUENTRA LA SALIDA"
		else:
			status_label.text = "SALA LIMPIA"
	queue_redraw()

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _draw() -> void:
	pass
