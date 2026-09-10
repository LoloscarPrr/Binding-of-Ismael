extends Node2D

const TOTAL_ROOMS := 6
const TOTAL_FLOORS := 2
const ROOM_ENTRY_DELAY := 0.65
const FLOOR_TRANSITION_DELAY := 1.35
const ENEMY_ACTIVATION_DELAY := 0.70
const MIN_ENEMY_SEPARATION_RATIO := 0.16
const REWARD_POOL: Array[String] = ["movimiento", "cadencia", "vida", "curacion", "proyectil", "dano"]

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
var room_rect := Rect2()
var _door: IsmaelRoomDoor
var _enemies_alive := 0
var _game_over := false
var _run_complete := false
var _floor_index := 1
var _room_index := 1
var _room_cleared := false
var _transition_locked := false
var _spawn_generation := 0
var _rooms_cleared_total := 0
var _room_kind := "combate"
var _last_reward := ""
var _offered_rewards: Array[String] = []
var _coins := 0
var _bombs := 0
var _keys := 0

func _ready() -> void:
	_configure_mobile_display()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_room_rect()
	player = IsmaelPlayer.new()
	player.position = _room_entry_position(false)
	player.set_movement_bounds(room_rect)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	add_child(player)
	_create_touch_ui()
	_on_player_health_changed(player.health, player.max_health)
	_update_pickup_hud()
	_layout_touch_ui()
	_begin_room(false)
	queue_redraw()

func _configure_mobile_display() -> void:
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		return
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _begin_room(from_door: bool) -> void:
	_spawn_generation += 1
	var generation: int = _spawn_generation
	_room_cleared = false
	_transition_locked = true
	_enemies_alive = 0
	_room_kind = _get_room_kind()
	room_label.text = "SALA %d / %d" % [_room_index, TOTAL_ROOMS]
	floor_label.text = "PISO %d" % _floor_index
	status_label.text = _room_title()
	reward_label.text = ""
	_hide_reward_choices()
	_clear_room_obstacles()
	_clear_room_pickups()
	_clear_room_door()
	player.position = _room_entry_position(from_door)
	player.velocity = Vector2.ZERO
	player.move_input = Vector2.ZERO
	player.aim_input = Vector2.ZERO
	_build_room_layout()
	_setup_room_door()
	_update_minimap()
	queue_redraw()
	if _room_kind == "recompensa":
		_open_reward_room(generation)
	else:
		_spawn_room_after_entry(generation)

func _get_room_kind() -> String:
	if _room_index == TOTAL_ROOMS:
		return "jefe"
	if _room_index == 4:
		return "recompensa"
	if _room_index == 2:
		return "emboscada"
	return "combate"

func _room_title() -> String:
	match _room_kind:
		"jefe": return "GUARDIÁN DEL PISO"
		"recompensa": return "CÁMARA DE OFRENDA"
		"emboscada": return "EMBOSCADA"
		_: return "PREPÁRATE"

func _clear_room_obstacles() -> void:
	for obstacle in get_tree().get_nodes_in_group("room_obstacles"):
		obstacle.queue_free()

func _clear_room_pickups() -> void:
	for pickup in get_tree().get_nodes_in_group("room_pickups"):
		pickup.queue_free()

func _clear_room_door() -> void:
	if is_instance_valid(_door): _door.queue_free()
	_door = null

func _setup_room_door() -> void:
	_door = IsmaelRoomDoor.new()
	_door.position = Vector2(room_rect.get_center().x, room_rect.position.y + 26.0)
	_door.set_open(false)
	add_child(_door)

func _set_door_open(value: bool) -> void:
	if is_instance_valid(_door): _door.set_open(value)
	queue_redraw()

func _add_obstacle(ratio: Vector2, size_ratio: Vector2, variant: int = 0) -> void:
	var obstacle := IsmaelRoomObstacle.new()
	var obstacle_size := Vector2(room_rect.size.x * size_ratio.x, room_rect.size.y * size_ratio.y)
	obstacle.configure(obstacle_size, variant)
	obstacle.position = room_rect.position + room_rect.size * ratio
	add_child(obstacle)

func _build_room_layout() -> void:
	if _room_kind == "recompensa": return
	var variant: int = 0 if _floor_index == 1 else 1
	if _room_kind == "jefe":
		_add_obstacle(Vector2(0.24, 0.58), Vector2(0.08, 0.16), 2)
		_add_obstacle(Vector2(0.76, 0.58), Vector2(0.08, 0.16), 2)
		return
	if _room_kind == "emboscada":
		_add_obstacle(Vector2(0.38, 0.56), Vector2(0.07, 0.12), variant)
		_add_obstacle(Vector2(0.62, 0.56), Vector2(0.07, 0.12), variant)
		_add_obstacle(Vector2(0.50, 0.47), Vector2(0.08, 0.08), variant)
		return
	match _room_index % 3:
		0:
			_add_obstacle(Vector2(0.35, 0.58), Vector2(0.07, 0.18), variant)
			_add_obstacle(Vector2(0.65, 0.58), Vector2(0.07, 0.18), variant)
		1: _add_obstacle(Vector2(0.50, 0.55), Vector2(0.18, 0.08), variant)
		2:
			_add_obstacle(Vector2(0.30, 0.60), Vector2(0.08, 0.11), variant)
			_add_obstacle(Vector2(0.50, 0.52), Vector2(0.08, 0.11), variant)
			_add_obstacle(Vector2(0.70, 0.60), Vector2(0.08, 0.11), variant)

func _open_reward_room(generation: int) -> void:
	await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
	if generation != _spawn_generation or _game_over: return
	_offered_rewards = _make_reward_choices()
	status_label.text = "ELIGE UNA OFRENDA"
	reward_label.text = "Solo puedes tomar una"
	reward_left.text = _reward_name(_offered_rewards[0])
	reward_right.text = _reward_name(_offered_rewards[1])
	reward_left.visible = true
	reward_right.visible = true
	_transition_locked = true

func _make_reward_choices() -> Array[String]:
	var available: Array[String] = []
	for reward: String in REWARD_POOL:
		if reward != _last_reward: available.append(reward)
	available.shuffle()
	return [available[0], available[1]]

func _reward_name(reward: String) -> String:
	match reward:
		"movimiento": return "PASO LIGERO\n+ MOVIMIENTO"
		"cadencia": return "PULSO RÁPIDO\n+ CADENCIA"
		"vida": return "CORAZÓN VOTIVO\n+ VIDA MÁXIMA"
		"curacion": return "VENDA RITUAL\n+ CURACIÓN"
		"proyectil": return "IMPULSO\n+ VELOCIDAD DE TIRO"
		"dano": return "MARCA ROJA\n+ DAÑO"
		_: return reward

func _choose_reward(index: int) -> void:
	if index < 0 or index >= _offered_rewards.size(): return
	var reward: String = _offered_rewards[index]
	_apply_reward(reward)
	_last_reward = reward
	_hide_reward_choices()
	status_label.text = "OFRENDA RECOGIDA"
	reward_label.text = _reward_name(reward).replace("\n", " — ")
	_room_cleared = true
	_transition_locked = false
	_set_door_open(true)
	queue_redraw()

func _apply_reward(reward: String) -> void:
	match reward:
		"movimiento": player.move_speed += 24.0
		"cadencia": player.fire_rate = maxf(0.09, player.fire_rate - 0.022)
		"vida": player.add_max_health(1)
		"curacion": player.heal(3)
		"proyectil": player.projectile_speed += 120.0
		"dano": player.projectile_damage += 1

func _hide_reward_choices() -> void:
	if is_instance_valid(reward_left): reward_left.visible = false
	if is_instance_valid(reward_right): reward_right.visible = false

func _spawn_room_after_entry(generation: int) -> void:
	await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
	if generation != _spawn_generation or _game_over: return
	if _room_kind == "jefe": _spawn_boss()
	else:
		var count: int = mini(2 + _room_index + _floor_index, 7)
		if _room_kind == "emboscada": count = mini(count + 1, 8)
		var positions: Array[Vector2] = _deterministic_spawn_positions(count)
		_enemies_alive = positions.size()
		for i in positions.size():
			var enemy := IsmaelEnemy.new()
			var kind_index: int = (i + _room_index + _floor_index) % 3
			enemy.configure(kind_index as IsmaelEnemy.EnemyKind, _floor_index)
			enemy.position = positions[i]
			enemy.target = player
			enemy.spawn_grace_time = ENEMY_ACTIVATION_DELAY
			enemy.set_movement_bounds(room_rect)
			enemy.defeated.connect(_on_enemy_defeated)
			add_child(enemy)
	_transition_locked = false
	status_label.text = "" if _room_kind != "jefe" else "GUARDIÁN"
	queue_redraw()

func _spawn_boss() -> void:
	var boss := IsmaelEnemy.new()
	boss.configure(IsmaelEnemy.EnemyKind.BOSS, _floor_index)
	boss.position = Vector2(room_rect.get_center().x, room_rect.position.y + room_rect.size.y * 0.24)
	boss.target = player
	boss.spawn_grace_time = 1.0
	boss.set_movement_bounds(room_rect)
	boss.defeated.connect(_on_enemy_defeated)
	add_child(boss)
	_enemies_alive = 1

func _room_entry_position(from_door: bool) -> Vector2:
	return Vector2(room_rect.get_center().x, room_rect.position.y + room_rect.size.y * (0.88 if from_door else 0.82))

func _deterministic_spawn_positions(count: int) -> Array[Vector2]:
	var base_slots: Array[Vector2] = [Vector2(0.14,0.16),Vector2(0.86,0.16),Vector2(0.32,0.18),Vector2(0.68,0.18),Vector2(0.14,0.38),Vector2(0.86,0.38),Vector2(0.34,0.42),Vector2(0.66,0.42),Vector2(0.50,0.12),Vector2(0.50,0.36),Vector2(0.24,0.30),Vector2(0.76,0.30)]
	var slots: Array[Vector2] = base_slots.duplicate()
	var rotation: int = (_room_index + _floor_index * 2) % slots.size()
	for i in rotation: slots.append(slots.pop_front())
	var result: Array[Vector2] = []
	var minimum_separation: float = maxf(105.0, minf(room_rect.size.x, room_rect.size.y) * MIN_ENEMY_SEPARATION_RATIO)
	var player_safe_radius: float = maxf(room_rect.size.y * 0.43, 300.0)
	for ratio: Vector2 in slots:
		if result.size() >= count: break
		var candidate: Vector2 = room_rect.position + room_rect.size * ratio
		if candidate.distance_to(player.position) < player_safe_radius: continue
		var separated := true
		for existing: Vector2 in result:
			if candidate.distance_to(existing) < minimum_separation: separated = false; break
		if separated: result.append(candidate)
	return result

func _spawn_clear_pickup() -> void:
	var pickup := IsmaelPickup.new()
	var kind := "coin"
	if _room_kind == "jefe": kind = "key"
	else:
		match (_rooms_cleared_total + _floor_index) % 4:
			0: kind = "heart"
			1: kind = "coin"
			2: kind = "bomb"
			3: kind = "key"
	pickup.configure(kind)
	pickup.position = room_rect.position + room_rect.size * Vector2(0.50, 0.68)
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
	if is_instance_valid(pickup_label): pickup_label.text = "¢ %02d    ● %02d    ⚿ %02d" % [_coins, _bombs, _keys]

func _update_minimap() -> void:
	if not is_instance_valid(minimap_label): return
	var map_text := ""
	for i in range(1, TOTAL_ROOMS + 1):
		var symbol := "□"
		if i < _room_index: symbol = "■"
		elif i == _room_index: symbol = "◆"
		if i == TOTAL_ROOMS: symbol += "☠"
		elif i == 4: symbol += "✦"
		if i < TOTAL_ROOMS: symbol += "─"
		map_text += symbol
	minimap_label.text = map_text

func _create_touch_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	hud_backdrop = Panel.new(); hud_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new(); hud_style.bg_color = Color(0.035,0.027,0.023,0.82); hud_style.border_color = Color(0.25,0.19,0.15,0.72); hud_style.border_width_bottom = 2
	hud_backdrop.add_theme_stylebox_override("panel", hud_style); layer.add_child(hud_backdrop)
	left_stick = VirtualStick.new(); layer.add_child(left_stick)
	right_stick = VirtualStick.new(); layer.add_child(right_stick)
	health_hud = IsmaelHealthHud.new(); layer.add_child(health_hud)
	pickup_label = Label.new(); layer.add_child(pickup_label)
	minimap_label = Label.new(); minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; layer.add_child(minimap_label)
	floor_label = Label.new(); floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layer.add_child(floor_label)
	room_label = Label.new(); room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layer.add_child(room_label)
	status_label = Label.new(); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layer.add_child(status_label)
	reward_label = Label.new(); reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layer.add_child(reward_label)
	reward_left = Button.new(); reward_left.visible = false; reward_left.pressed.connect(_choose_reward.bind(0)); layer.add_child(reward_left)
	reward_right = Button.new(); reward_right.visible = false; reward_right.pressed.connect(_choose_reward.bind(1)); layer.add_child(reward_right)
	restart_button = Button.new(); restart_button.text = "NUEVO RECORRIDO"; restart_button.visible = false; restart_button.pressed.connect(_restart_game); layer.add_child(restart_button)

func _layout_touch_ui() -> void:
	if not is_instance_valid(left_stick): return
	var screen_size := get_viewport_rect().size
	var short_side := minf(screen_size.x, screen_size.y)
	var ui_scale := clampf(short_side / 720.0, 0.78, 1.35)
	var stick_side := clampf(short_side * 0.48, 265.0, 380.0)
	var margin_x := clampf(screen_size.x * 0.018, 16.0, 40.0)
	var margin_bottom := clampf(screen_size.y * 0.015, 10.0, 26.0)
	left_stick.size = Vector2(stick_side,stick_side); right_stick.size = left_stick.size
	left_stick.stick_radius = stick_side*0.39; right_stick.stick_radius = left_stick.stick_radius
	left_stick.knob_radius = stick_side*0.17; right_stick.knob_radius = left_stick.knob_radius
	left_stick.position = Vector2(margin_x,screen_size.y-stick_side-margin_bottom); right_stick.position = Vector2(screen_size.x-stick_side-margin_x,screen_size.y-stick_side-margin_bottom)
	var resource_font := maxi(18,int(round(20.0*ui_scale))); var small_font := resource_font; var normal_font := maxi(24,int(round(27.0*ui_scale)))
	pickup_label.add_theme_font_size_override("font_size",resource_font); minimap_label.add_theme_font_size_override("font_size",resource_font); floor_label.add_theme_font_size_override("font_size",small_font); room_label.add_theme_font_size_override("font_size",small_font); status_label.add_theme_font_size_override("font_size",normal_font); reward_label.add_theme_font_size_override("font_size",small_font)
	for label: Label in [pickup_label,minimap_label,floor_label,room_label,status_label,reward_label]:
		label.add_theme_color_override("font_color",Color(0.92,0.86,0.75)); label.add_theme_color_override("font_outline_color",Color(0.025,0.018,0.015,0.98)); label.add_theme_constant_override("outline_size",maxi(3,int(round(4.0*ui_scale))))
	var hud_height := clampf(90.0*ui_scale,86.0,118.0); hud_backdrop.position=Vector2.ZERO; hud_backdrop.size=Vector2(screen_size.x,hud_height)
	var left_width := clampf(screen_size.x*0.30,370.0,520.0); var map_width := clampf(screen_size.x*0.27,330.0,480.0)
	health_hud.icon_size=28.0*ui_scale; health_hud.icon_gap=7.0*ui_scale; health_hud.position=Vector2(margin_x,8.0*ui_scale); health_hud.size=Vector2(left_width,39.0*ui_scale)
	pickup_label.position=Vector2(margin_x,51.0*ui_scale); pickup_label.size=Vector2(left_width,34.0*ui_scale)
	minimap_label.position=Vector2(screen_size.x-map_width-margin_x,20.0*ui_scale); minimap_label.size=Vector2(map_width,50.0*ui_scale)
	var info_width := clampf(screen_size.x*0.12,150.0,240.0); floor_label.position=Vector2(screen_size.x*0.5-info_width-7.0,10.0*ui_scale); floor_label.size=Vector2(info_width,34.0*ui_scale); room_label.position=Vector2(screen_size.x*0.5+7.0,10.0*ui_scale); room_label.size=Vector2(info_width,34.0*ui_scale)
	var center_width := clampf(screen_size.x*0.38,410.0,680.0); status_label.position=Vector2(screen_size.x*0.5-center_width*0.5,49.0*ui_scale); status_label.size=Vector2(center_width,42.0*ui_scale)
	var end_screen_visible := _run_complete or _game_over; var reward_y_ratio := 0.46 if end_screen_visible else 0.58; reward_label.position=Vector2(screen_size.x*0.5-center_width*0.5,screen_size.y*reward_y_ratio); reward_label.size=Vector2(center_width,44.0*ui_scale)
	var choice_size := Vector2(clampf(screen_size.x*0.22,250.0,350.0),clampf(screen_size.y*0.14,90.0,130.0)); reward_left.size=choice_size; reward_right.size=choice_size; reward_left.position=Vector2(screen_size.x*0.5-choice_size.x-18.0,screen_size.y*0.38); reward_right.position=Vector2(screen_size.x*0.5+18.0,screen_size.y*0.38); reward_left.add_theme_font_size_override("font_size",small_font); reward_right.add_theme_font_size_override("font_size",small_font)
	restart_button.size=Vector2(280.0,76.0)*ui_scale; restart_button.position=Vector2(screen_size.x*0.5-restart_button.size.x*0.5,screen_size.y*(0.62 if end_screen_visible else 0.5)); restart_button.add_theme_font_size_override("font_size",small_font)
	if is_instance_valid(_door): _door.position=Vector2(room_rect.get_center().x,room_rect.position.y+26.0)

func _input(event: InputEvent) -> void:
	if _game_over or _run_complete: return
	if left_stick and left_stick.handle_touch(event): get_viewport().set_input_as_handled(); return
	if right_stick and right_stick.handle_touch(event): get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _game_over or _run_complete or not is_instance_valid(player): return
	if _transition_locked: player.move_input=Vector2.ZERO; player.aim_input=Vector2.ZERO; return
	var keyboard_move := Input.get_vector("move_left","move_right","move_up","move_down"); var keyboard_aim := Input.get_vector("shoot_left","shoot_right","shoot_up","shoot_down")
	player.move_input = left_stick.value if left_stick.value.length()>0.0 else keyboard_move; player.aim_input = right_stick.value if right_stick.value.length()>0.0 else keyboard_aim
	if _room_cleared:
		var center := room_rect.get_center()
		if player.position.y < room_rect.position.y+72.0 and absf(player.position.x-center.x)<90.0: _advance_room()

func _advance_room() -> void:
	if _transition_locked: return
	_transition_locked=true
	if _room_index>=TOTAL_ROOMS: _finish_floor(); return
	_room_index+=1; _begin_room(true)

func _finish_floor() -> void:
	_spawn_generation+=1
	if _floor_index>=TOTAL_FLOORS:
		_run_complete=true; status_label.text="RECORRIDO COMPLETADO"; reward_label.text="ISMAEL SOBREVIVIÓ A LOS GUARDIANES"; restart_button.visible=true; left_stick.reset(); right_stick.reset(); _layout_touch_ui(); return
	status_label.text="GUARDIÁN DERROTADO — PISO %d"%_floor_index; reward_label.text=_grant_floor_reward(); _floor_transition()

func _floor_transition() -> void:
	await get_tree().create_timer(FLOOR_TRANSITION_DELAY).timeout
	if _game_over: return
	_floor_index+=1; _room_index=1; _begin_room(false)

func _grant_floor_reward() -> String:
	player.add_max_health(1); return "RELIQUIA: +1 VIDA MÁXIMA"

func _on_viewport_size_changed() -> void:
	_update_room_rect()
	if is_instance_valid(player): player.set_movement_bounds(room_rect); player.position.x=clampf(player.position.x,room_rect.position.x,room_rect.end.x); player.position.y=clampf(player.position.y,room_rect.position.y,room_rect.end.y)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_movement_bounds(room_rect)
	_layout_touch_ui(); queue_redraw()

func _update_room_rect() -> void:
	var s := get_viewport_rect().size; var side := clampf(s.x*0.035,30.0,64.0); var top := clampf(s.y*0.14,100.0,128.0); var bottom := clampf(s.y*0.055,28.0,50.0)
	room_rect=Rect2(Vector2(side,top),Vector2(maxf(1.0,s.x-side*2.0),maxf(1.0,s.y-top-bottom)))

func _on_player_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_hud): health_hud.set_health(current,maximum)

func _on_player_died() -> void:
	_game_over=true; _spawn_generation+=1; _hide_reward_choices(); left_stick.reset(); right_stick.reset(); status_label.text="DERROTA"; reward_label.text=""; restart_button.visible=true; _layout_touch_ui()
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.velocity=Vector2.ZERO; enemy.set_physics_process(false)

func _on_enemy_defeated(_enemy) -> void:
	_enemies_alive=maxi(0,_enemies_alive-1)
	if _enemies_alive==0 and not _game_over:
		_room_cleared=true; _rooms_cleared_total+=1; _set_door_open(true); _spawn_clear_pickup(); status_label.text="GUARDIÁN DERROTADO — RECOGE Y ENTRA" if _room_kind=="jefe" else "SALA LIMPIA — RECOGE Y ENTRA"; queue_redraw()

func _restart_game() -> void: get_tree().reload_current_scene()

func _draw() -> void:
	var s := get_viewport_rect().size
	var floor_tint := Color(0.205,0.165,0.135) if _floor_index==1 else Color(0.145,0.165,0.17)
	if _room_kind=="recompensa": floor_tint=Color(0.20,0.17,0.105)
	elif _room_kind=="jefe": floor_tint=Color(0.19,0.105,0.10)
	draw_rect(Rect2(Vector2.ZERO,s),Color(0.035,0.028,0.024))
	var wall_outer := room_rect.grow(28.0); draw_rect(wall_outer,Color(0.095,0.075,0.062)); draw_rect(wall_outer,Color(0.24,0.19,0.15),false,7.0)
	# stone blocks around the chamber
	var block := 62.0
	var x := wall_outer.position.x
	while x < wall_outer.end.x:
		draw_rect(Rect2(Vector2(x,wall_outer.position.y),Vector2(minf(block,wall_outer.end.x-x),25.0)),Color(0.17,0.135,0.11),false,2.0)
		draw_rect(Rect2(Vector2(x,wall_outer.end.y-25.0),Vector2(minf(block,wall_outer.end.x-x),25.0)),Color(0.17,0.135,0.11),false,2.0); x+=block
	var y := wall_outer.position.y+25.0
	while y < wall_outer.end.y-25.0:
		draw_line(Vector2(wall_outer.position.x,y),Vector2(room_rect.position.x,y),Color(0.17,0.135,0.11),2.0); draw_line(Vector2(room_rect.end.x,y),Vector2(wall_outer.end.x,y),Color(0.17,0.135,0.11),2.0); y+=48.0
	draw_rect(room_rect,floor_tint)
	# subtle floor slabs and grime
	for row in range(1,6):
		var yy := room_rect.position.y + room_rect.size.y*float(row)/6.0
		draw_line(Vector2(room_rect.position.x+12.0,yy),Vector2(room_rect.end.x-12.0,yy),Color(0.09,0.07,0.06,0.22),2.0)
	for col in range(1,9):
		var xx := room_rect.position.x + room_rect.size.x*float(col)/9.0
		draw_line(Vector2(xx,room_rect.position.y+12.0),Vector2(xx,room_rect.end.y-12.0),Color(0.09,0.07,0.06,0.12),1.0)
	for i in range(8):
		var seed := float((_room_index*37+_floor_index*19+i*53)%97)/97.0
		var stain := room_rect.position + Vector2(room_rect.size.x*(0.12+0.76*seed),room_rect.size.y*(0.18+0.64*float((i*31+_room_index)%89)/89.0))
		draw_circle(stain,8.0+float(i%3)*5.0,Color(0.13,0.055,0.045,0.20))
	draw_rect(room_rect,Color(0.38,0.29,0.22),false,6.0)
	var center := room_rect.get_center()
	if _room_kind=="emboscada": draw_circle(center,minf(room_rect.size.x,room_rect.size.y)*0.13,Color(0.31,0.12,0.09,0.55),false,7.0)
	elif _room_kind=="recompensa":
		draw_circle(center,54.0,Color(0.65,0.49,0.17,0.25)); draw_circle(center,54.0,Color(0.78,0.62,0.24),false,6.0)
	elif _room_kind=="jefe": draw_arc(center,minf(room_rect.size.x,room_rect.size.y)*0.23,0.0,TAU,48,Color(0.42,0.08,0.07),9.0)
