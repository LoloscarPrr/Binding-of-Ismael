extends Node2D

const TOTAL_ROOMS := 5
const MIN_SPAWN_FROM_PLAYER := 270.0
const MIN_SPAWN_BETWEEN_ENEMIES := 150.0
const ENEMY_SPAWN_GRACE := 0.85

var player: IsmaelPlayer
var left_stick: VirtualStick
var right_stick: VirtualStick
var health_label: Label
var status_label: Label
var room_label: Label
var restart_button: Button
var room_rect := Rect2()
var _enemies_alive := 0
var _game_over := false
var _room_index := 1
var _room_cleared := false
var _transition_locked := false

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_room_rect()
	player = IsmaelPlayer.new()
	player.position = room_rect.get_center()
	player.set_movement_bounds(room_rect)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	add_child(player)
	_create_touch_ui()
	_spawn_room()
	_on_player_health_changed(player.health, player.max_health)
	_layout_touch_ui()
	queue_redraw()

func _spawn_room() -> void:
	_room_cleared = false
	_transition_locked = false
	status_label.text = ""
	room_label.text = "SALA %d / %d" % [_room_index, TOTAL_ROOMS]
	var count: int = mini(3 + _room_index, 7)
	var positions: Array[Vector2] = _safe_spawn_positions(count)
	_enemies_alive = positions.size()
	for spawn_position: Vector2 in positions:
		var enemy := IsmaelEnemy.new()
		enemy.position = spawn_position
		enemy.target = player
		enemy.spawn_grace_time = ENEMY_SPAWN_GRACE if _room_index > 1 else 0.35
		enemy.set_movement_bounds(room_rect)
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)
	queue_redraw()

func _safe_spawn_positions(count: int) -> Array[Vector2]:
	var ratios: Array[Vector2]
	if _room_index == 1:
		ratios = [
			Vector2(0.16, 0.18), Vector2(0.84, 0.18),
			Vector2(0.16, 0.48), Vector2(0.84, 0.48),
			Vector2(0.22, 0.78), Vector2(0.78, 0.78),
			Vector2(0.50, 0.18), Vector2(0.50, 0.72),
			Vector2(0.30, 0.32), Vector2(0.70, 0.32)
		]
	else:
		# Al entrar por abajo, toda la franja inferior queda libre de enemigos.
		ratios = [
			Vector2(0.14, 0.16), Vector2(0.86, 0.16),
			Vector2(0.30, 0.22), Vector2(0.70, 0.22),
			Vector2(0.14, 0.42), Vector2(0.86, 0.42),
			Vector2(0.36, 0.48), Vector2(0.64, 0.48),
			Vector2(0.50, 0.12), Vector2(0.50, 0.38)
		]

	var result: Array[Vector2] = []
	var diagonal: float = room_rect.size.length()
	var required_player_distance: float = maxf(MIN_SPAWN_FROM_PLAYER, diagonal * (0.27 if _room_index > 1 else 0.22))
	var required_enemy_distance: float = maxf(MIN_SPAWN_BETWEEN_ENEMIES, minf(room_rect.size.x, room_rect.size.y) * 0.18)
	var entry_safe_y: float = room_rect.position.y + room_rect.size.y * 0.60

	for ratio: Vector2 in ratios:
		if result.size() >= count:
			break
		var candidate: Vector2 = room_rect.position + room_rect.size * ratio
		if _room_index > 1 and candidate.y > entry_safe_y:
			continue
		if candidate.distance_to(player.position) < required_player_distance:
			continue
		var separated: bool = true
		for existing: Vector2 in result:
			if candidate.distance_to(existing) < required_enemy_distance:
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
	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(room_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(status_label)
	restart_button = Button.new()
	restart_button.text = "REINICIAR"
	restart_button.visible = false
	restart_button.pressed.connect(_restart_game)
	layer.add_child(restart_button)

func _layout_touch_ui() -> void:
	if not is_instance_valid(left_stick):
		return
	var screen_size: Vector2 = get_viewport_rect().size
	var short_side: float = minf(screen_size.x, screen_size.y)
	var ui_scale: float = clampf(short_side / 720.0, 0.78, 1.35)
	var stick_side: float = clampf(short_side * 0.40, 220.0, 320.0)
	var stick_size := Vector2(stick_side, stick_side)
	var margin_x: float = clampf(screen_size.x * 0.025, 22.0, 52.0)
	var margin_bottom: float = clampf(screen_size.y * 0.025, 18.0, 36.0)

	left_stick.size = stick_size
	right_stick.size = stick_size
	left_stick.stick_radius = stick_side * 0.37
	right_stick.stick_radius = stick_side * 0.37
	left_stick.knob_radius = stick_side * 0.16
	right_stick.knob_radius = stick_side * 0.16
	left_stick.position = Vector2(margin_x, screen_size.y - stick_side - margin_bottom)
	right_stick.position = Vector2(screen_size.x - stick_side - margin_x, screen_size.y - stick_side - margin_bottom)

	var health_font: int = maxi(18, int(round(24.0 * ui_scale)))
	var room_font: int = maxi(16, int(round(20.0 * ui_scale)))
	var status_font: int = maxi(20, int(round(28.0 * ui_scale)))
	health_label.add_theme_font_size_override("font_size", health_font)
	room_label.add_theme_font_size_override("font_size", room_font)
	status_label.add_theme_font_size_override("font_size", status_font)
	restart_button.add_theme_font_size_override("font_size", health_font)

	health_label.position = Vector2(margin_x, clampf(screen_size.y * 0.025, 14.0, 28.0))
	var room_width: float = clampf(screen_size.x * 0.20, 190.0, 280.0)
	room_label.position = Vector2(screen_size.x * 0.5 - room_width * 0.5, health_label.position.y)
	room_label.size = Vector2(room_width, 42.0 * ui_scale)
	var status_width: float = clampf(screen_size.x * 0.42, 320.0, 560.0)
	status_label.position = Vector2(screen_size.x * 0.5 - status_width * 0.5, health_label.position.y + 34.0 * ui_scale)
	status_label.size = Vector2(status_width, 48.0 * ui_scale)
	restart_button.size = Vector2(230.0, 76.0) * ui_scale
	restart_button.position = screen_size * 0.5 - restart_button.size * 0.5

func _input(event: InputEvent) -> void:
	if _game_over:
		return
	if left_stick and left_stick.handle_touch(event):
		get_viewport().set_input_as_handled()
		return
	if right_stick and right_stick.handle_touch(event):
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _game_over or not is_instance_valid(player):
		return
	var keyboard_move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var keyboard_aim := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
	player.move_input = left_stick.value if left_stick.value.length() > 0.0 else keyboard_move
	player.aim_input = right_stick.value if right_stick.value.length() > 0.0 else keyboard_aim
	if _room_cleared and not _transition_locked:
		var center := room_rect.get_center()
		if player.position.y < room_rect.position.y + 72.0 and absf(player.position.x - center.x) < 90.0:
			_advance_room()

func _advance_room() -> void:
	_transition_locked = true
	if _room_index >= TOTAL_ROOMS:
		status_label.text = "PISO COMPLETADO"
		return
	_room_index += 1
	player.position = Vector2(room_rect.get_center().x, room_rect.position.y + room_rect.size.y - minf(110.0, room_rect.size.y * 0.16))
	_spawn_room()

func _on_viewport_size_changed() -> void:
	_update_room_rect()
	if is_instance_valid(player):
		player.set_movement_bounds(room_rect)
		player.position.x = clampf(player.position.x, room_rect.position.x, room_rect.end.x)
		player.position.y = clampf(player.position.y, room_rect.position.y, room_rect.end.y)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_movement_bounds(room_rect)
	_layout_touch_ui()
	queue_redraw()

func _update_room_rect() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	var side_margin: float = clampf(screen_size.x * 0.028, 24.0, 52.0)
	var top_margin: float = clampf(screen_size.y * 0.10, 60.0, 96.0)
	var bottom_margin: float = clampf(screen_size.y * 0.04, 18.0, 42.0)
	var room_width: float = maxf(1.0, screen_size.x - side_margin * 2.0)
	var room_height: float = maxf(1.0, screen_size.y - top_margin - bottom_margin)
	room_rect = Rect2(Vector2(side_margin, top_margin), Vector2(room_width, room_height))

func _on_player_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		var hearts := ""
		for i in maximum:
			hearts += "♥" if i < current else "♡"
		health_label.text = hearts

func _on_player_died() -> void:
	_game_over = true
	left_stick.reset()
	right_stick.reset()
	status_label.text = "DERROTA"
	restart_button.visible = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.velocity = Vector2.ZERO
		enemy.set_physics_process(false)

func _on_enemy_defeated(_enemy) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	if _enemies_alive == 0 and not _game_over:
		_room_cleared = true
		status_label.text = "SALA LIMPIA — ENTRA POR LA PUERTA"
		queue_redraw()

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _draw() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.10, 0.085, 0.075))
	draw_rect(room_rect, Color(0.19, 0.16, 0.13))
	draw_rect(room_rect, Color(0.42, 0.34, 0.26), false, 8.0)
	var center: Vector2 = room_rect.get_center()
	var door_color := Color(0.10, 0.55, 0.28) if _room_cleared else Color(0.05, 0.04, 0.035)
	var door_width: float = clampf(room_rect.size.x * 0.09, 90.0, 130.0)
	draw_rect(Rect2(center.x - door_width * 0.5, room_rect.position.y - 8.0, door_width, 24.0), door_color)
