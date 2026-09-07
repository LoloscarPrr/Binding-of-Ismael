extends Node2D

const TOTAL_ROOMS := 6
const TOTAL_FLOORS := 2
const ROOM_ENTRY_DELAY := 0.65
const FLOOR_TRANSITION_DELAY := 1.35
const ENEMY_ACTIVATION_DELAY := 0.70
const MIN_ENEMY_SEPARATION_RATIO := 0.16

var player: IsmaelPlayer
var left_stick: VirtualStick
var right_stick: VirtualStick
var health_label: Label
var status_label: Label
var room_label: Label
var floor_label: Label
var reward_label: Label
var restart_button: Button
var room_rect := Rect2()
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

func _ready() -> void:
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
	_layout_touch_ui()
	_begin_room(false)
	queue_redraw()

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
	player.position = _room_entry_position(from_door)
	player.velocity = Vector2.ZERO
	player.move_input = Vector2.ZERO
	player.aim_input = Vector2.ZERO
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

func _open_reward_room(generation: int) -> void:
	await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
	if generation != _spawn_generation or _game_over:
		return
	var reward_text := ""
	if (_floor_index + _rooms_cleared_total) % 2 == 0:
		player.move_speed += 18.0
		reward_text = "OFRENDA RECOGIDA: + MOVIMIENTO"
	else:
		player.fire_rate = maxf(0.10, player.fire_rate - 0.018)
		reward_text = "OFRENDA RECOGIDA: + CADENCIA"
	reward_label.text = reward_text
	status_label.text = "CÁMARA DESPEJADA"
	_room_cleared = true
	_transition_locked = false
	queue_redraw()

func _spawn_room_after_entry(generation: int) -> void:
	await get_tree().create_timer(ROOM_ENTRY_DELAY).timeout
	if generation != _spawn_generation or _game_over:
		return
	if _room_kind == "jefe":
		_spawn_boss()
	else:
		var count: int = mini(2 + _room_index + _floor_index, 7)
		if _room_kind == "emboscada":
			count = mini(count + 1, 8)
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
	var center_x: float = room_rect.get_center().x
	return Vector2(center_x, room_rect.position.y + room_rect.size.y * (0.88 if from_door else 0.82))

func _deterministic_spawn_positions(count: int) -> Array[Vector2]:
	var base_slots: Array[Vector2] = [
		Vector2(0.14, 0.16), Vector2(0.86, 0.16), Vector2(0.32, 0.18), Vector2(0.68, 0.18),
		Vector2(0.14, 0.38), Vector2(0.86, 0.38), Vector2(0.34, 0.42), Vector2(0.66, 0.42),
		Vector2(0.50, 0.12), Vector2(0.50, 0.36), Vector2(0.24, 0.30), Vector2(0.76, 0.30)
	]
	var slots: Array[Vector2] = base_slots.duplicate()
	var rotation: int = (_room_index + _floor_index * 2) % slots.size()
	for i in rotation:
		slots.append(slots.pop_front())
	var result: Array[Vector2] = []
	var min_dimension: float = minf(room_rect.size.x, room_rect.size.y)
	var minimum_separation: float = maxf(105.0, min_dimension * MIN_ENEMY_SEPARATION_RATIO)
	var player_safe_radius: float = maxf(room_rect.size.y * 0.43, 300.0)
	for ratio: Vector2 in slots:
		if result.size() >= count:
			break
		var candidate: Vector2 = room_rect.position + room_rect.size * ratio
		if candidate.distance_to(player.position) < player_safe_radius:
			continue
		var separated: bool = true
		for existing: Vector2 in result:
			if candidate.distance_to(existing) < minimum_separation:
				separated = false
				break
		if separated:
			result.append(candidate)
	return result

func _create_touch_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	left_stick = VirtualStick.new()
	layer.add_child(left_stick)
	right_stick = VirtualStick.new()
	layer.add_child(right_stick)
	health_label = Label.new()
	layer.add_child(health_label)
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
	if not is_instance_valid(left_stick): return
	var screen_size: Vector2 = get_viewport_rect().size
	var short_side: float = minf(screen_size.x, screen_size.y)
	var ui_scale: float = clampf(short_side / 720.0, 0.78, 1.35)
	var stick_side: float = clampf(short_side * 0.50, 270.0, 390.0)
	var stick_size := Vector2(stick_side, stick_side)
	var margin_x: float = clampf(screen_size.x * 0.018, 16.0, 40.0)
	var margin_bottom: float = clampf(screen_size.y * 0.015, 10.0, 26.0)
	left_stick.size = stick_size
	right_stick.size = stick_size
	left_stick.stick_radius = stick_side * 0.39
	right_stick.stick_radius = stick_side * 0.39
	left_stick.knob_radius = stick_side * 0.17
	right_stick.knob_radius = stick_side * 0.17
	left_stick.position = Vector2(margin_x, screen_size.y - stick_side - margin_bottom)
	right_stick.position = Vector2(screen_size.x - stick_side - margin_x, screen_size.y - stick_side - margin_bottom)
	var health_font: int = maxi(18, int(round(24.0 * ui_scale)))
	var small_font: int = maxi(15, int(round(18.0 * ui_scale)))
	var status_font: int = maxi(20, int(round(28.0 * ui_scale)))
	health_label.add_theme_font_size_override("font_size", health_font)
	floor_label.add_theme_font_size_override("font_size", small_font)
	room_label.add_theme_font_size_override("font_size", small_font)
	status_label.add_theme_font_size_override("font_size", status_font)
	reward_label.add_theme_font_size_override("font_size", health_font)
	restart_button.add_theme_font_size_override("font_size", health_font)
	health_label.position = Vector2(margin_x, 16.0)
	var info_width: float = clampf(screen_size.x * 0.18, 180.0, 270.0)
	floor_label.position = Vector2(screen_size.x * 0.5 - info_width - 8.0, 14.0)
	floor_label.size = Vector2(info_width, 32.0 * ui_scale)
	room_label.position = Vector2(screen_size.x * 0.5 + 8.0, 14.0)
	room_label.size = Vector2(info_width, 32.0 * ui_scale)
	var status_width: float = clampf(screen_size.x * 0.46, 360.0, 620.0)
	status_label.position = Vector2(screen_size.x * 0.5 - status_width * 0.5, 48.0 * ui_scale)
	status_label.size = Vector2(status_width, 48.0 * ui_scale)
	reward_label.position = Vector2(screen_size.x * 0.5 - status_width * 0.5, screen_size.y * 0.68)
	reward_label.size = Vector2(status_width, 42.0 * ui_scale)
	restart_button.size = Vector2(280.0, 76.0) * ui_scale
	restart_button.position = screen_size * 0.5 - restart_button.size * 0.5 + Vector2(0.0, 72.0 * ui_scale)

func _input(event: InputEvent) -> void:
	if _game_over or _run_complete: return
	if left_stick and left_stick.handle_touch(event):
		get_viewport().set_input_as_handled(); return
	if right_stick and right_stick.handle_touch(event): get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _game_over or _run_complete or not is_instance_valid(player): return
	if _transition_locked:
		player.move_input = Vector2.ZERO; player.aim_input = Vector2.ZERO; return
	var keyboard_move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var keyboard_aim := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
	player.move_input = left_stick.value if left_stick.value.length() > 0.0 else keyboard_move
	player.aim_input = right_stick.value if right_stick.value.length() > 0.0 else keyboard_aim
	if _room_cleared:
		var center := room_rect.get_center()
		if player.position.y < room_rect.position.y + 72.0 and absf(player.position.x - center.x) < 90.0: _advance_room()

func _advance_room() -> void:
	if _transition_locked: return
	_transition_locked = true
	if _room_index >= TOTAL_ROOMS:
		_finish_floor(); return
	_room_index += 1
	_begin_room(true)

func _finish_floor() -> void:
	_spawn_generation += 1
	if _floor_index >= TOTAL_FLOORS:
		_run_complete = true
		status_label.text = "RECORRIDO COMPLETADO"
		reward_label.text = "ISMAEL SOBREVIVIÓ A LOS GUARDIANES"
		restart_button.visible = true
		left_stick.reset(); right_stick.reset()
		return
	status_label.text = "GUARDIÁN DERROTADO — PISO %d" % _floor_index
	reward_label.text = _grant_floor_reward()
	_floor_transition()

func _floor_transition() -> void:
	await get_tree().create_timer(FLOOR_TRANSITION_DELAY).timeout
	if _game_over: return
	_floor_index += 1
	_room_index = 1
	_begin_room(false)

func _grant_floor_reward() -> String:
	player.max_health += 1
	player.heal(2)
	return "RELIQUIA: +1 VIDA MÁXIMA"

func _on_viewport_size_changed() -> void:
	_update_room_rect()
	if is_instance_valid(player):
		player.set_movement_bounds(room_rect)
		player.position.x = clampf(player.position.x, room_rect.position.x, room_rect.end.x)
		player.position.y = clampf(player.position.y, room_rect.position.y, room_rect.end.y)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_movement_bounds(room_rect)
	_layout_touch_ui(); queue_redraw()

func _update_room_rect() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	var side_margin: float = clampf(screen_size.x * 0.028, 24.0, 52.0)
	var top_margin: float = clampf(screen_size.y * 0.10, 60.0, 96.0)
	var bottom_margin: float = clampf(screen_size.y * 0.04, 18.0, 42.0)
	room_rect = Rect2(Vector2(side_margin, top_margin), Vector2(maxf(1.0, screen_size.x - side_margin * 2.0), maxf(1.0, screen_size.y - top_margin - bottom_margin)))

func _on_player_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		var hearts := ""
		for i in maximum: hearts += "♥" if i < current else "♡"
		health_label.text = hearts

func _on_player_died() -> void:
	_game_over = true; _spawn_generation += 1
	left_stick.reset(); right_stick.reset()
	status_label.text = "DERROTA"; reward_label.text = ""; restart_button.visible = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.velocity = Vector2.ZERO; enemy.set_physics_process(false)

func _on_enemy_defeated(_enemy) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	if _enemies_alive == 0 and not _game_over:
		_room_cleared = true; _rooms_cleared_total += 1
		status_label.text = "GUARDIÁN DERROTADO — ENTRA POR LA PUERTA" if _room_kind == "jefe" else "SALA LIMPIA — ENTRA POR LA PUERTA"
		queue_redraw()

func _restart_game() -> void: get_tree().reload_current_scene()

func _draw() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	var floor_tint: Color = Color(0.19, 0.16, 0.13) if _floor_index == 1 else Color(0.14, 0.17, 0.19)
	if _room_kind == "recompensa": floor_tint = Color(0.18, 0.16, 0.10)
	elif _room_kind == "jefe": floor_tint = Color(0.20, 0.10, 0.11)
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.10, 0.085, 0.075))
	draw_rect(room_rect, floor_tint)
	draw_rect(room_rect, Color(0.42, 0.34, 0.26), false, 8.0)
	var center: Vector2 = room_rect.get_center()
	if _room_kind == "emboscada":
		draw_circle(center, minf(room_rect.size.x, room_rect.size.y) * 0.13, Color(0.30, 0.16, 0.12), false, 7.0)
	elif _room_kind == "recompensa":
		draw_circle(center, 46.0, Color(0.72, 0.58, 0.20), false, 8.0)
	elif _room_kind == "jefe":
		draw_arc(center, minf(room_rect.size.x, room_rect.size.y) * 0.23, 0.0, TAU, 48, Color(0.38, 0.10, 0.10), 8.0)
	var door_color := Color(0.10, 0.55, 0.28) if _room_cleared else Color(0.05, 0.04, 0.035)
	var door_width: float = clampf(room_rect.size.x * 0.09, 90.0, 130.0)
	draw_rect(Rect2(center.x - door_width * 0.5, room_rect.position.y - 8.0, door_width, 24.0), door_color)
