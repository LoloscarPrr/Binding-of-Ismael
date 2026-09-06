extends Node2D

const ROOM_SIDE_MARGIN := 36.0
const ROOM_TOP := 72.0
const ROOM_BOTTOM_MARGIN := 28.0
const STICK_SIZE := Vector2(290.0, 290.0)
const STICK_MARGIN_X := 42.0
const STICK_MARGIN_BOTTOM := 24.0
const TOTAL_ROOMS := 5
const MIN_SPAWN_FROM_PLAYER := 270.0
const MIN_SPAWN_BETWEEN_ENEMIES := 150.0

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
		enemy.set_movement_bounds(room_rect)
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)
	queue_redraw()

func _safe_spawn_positions(count: int) -> Array[Vector2]:
	var ratios: Array[Vector2] = [
		Vector2(0.16, 0.18), Vector2(0.84, 0.18),
		Vector2(0.16, 0.48), Vector2(0.84, 0.48),
		Vector2(0.16, 0.78), Vector2(0.84, 0.78),
		Vector2(0.50, 0.18), Vector2(0.50, 0.45),
		Vector2(0.30, 0.32), Vector2(0.70, 0.32)
	]
	var result: Array[Vector2] = []
	var required_player_distance: float = MIN_SPAWN_FROM_PLAYER + float(maxi(_room_index - 2, 0)) * 25.0
	for ratio: Vector2 in ratios:
		if result.size() >= count:
			break
		var candidate: Vector2 = room_rect.position + room_rect.size * ratio
		if candidate.distance_to(player.position) < required_player_distance:
			continue
		var separated: bool = true
		for existing: Vector2 in result:
			if candidate.distance_to(existing) < MIN_SPAWN_BETWEEN_ENEMIES:
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
	left_stick.size = STICK_SIZE
	left_stick.stick_radius = 108.0
	left_stick.knob_radius = 47.0
	layer.add_child(left_stick)
	right_stick = VirtualStick.new()
	right_stick.size = STICK_SIZE
	right_stick.stick_radius = 108.0
	right_stick.knob_radius = 47.0
	layer.add_child(right_stick)
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(health_label)
	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(room_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(status_label)
	restart_button = Button.new()
	restart_button.text = "REINICIAR"
	restart_button.size = Vector2(230.0, 76.0)
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.visible = false
	restart_button.pressed.connect(_restart_game)
	layer.add_child(restart_button)

func _layout_touch_ui() -> void:
	if not is_instance_valid(left_stick): return
	var s := get_viewport_rect().size
	left_stick.position = Vector2(STICK_MARGIN_X, s.y - STICK_SIZE.y - STICK_MARGIN_BOTTOM)
	right_stick.position = Vector2(s.x - STICK_SIZE.x - STICK_MARGIN_X, s.y - STICK_SIZE.y - STICK_MARGIN_BOTTOM)
	health_label.position = Vector2(30.0, 22.0)
	room_label.position = Vector2(s.x * 0.5 - 120.0, 22.0)
	room_label.size = Vector2(240.0, 38.0)
	status_label.position = Vector2(s.x * 0.5 - 210.0, 52.0)
	status_label.size = Vector2(420.0, 44.0)
	restart_button.position = s * 0.5 - restart_button.size * 0.5

func _input(event: InputEvent) -> void:
	if _game_over: return
	if left_stick and left_stick.handle_touch(event):
		get_viewport().set_input_as_handled()
		return
	if right_stick and right_stick.handle_touch(event):
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _game_over or not is_instance_valid(player): return
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
	player.position = Vector2(room_rect.get_center().x, room_rect.position.y + room_rect.size.y - 110.0)
	_spawn_room()

func _on_viewport_size_changed() -> void:
	_update_room_rect()
	if is_instance_valid(player): player.set_movement_bounds(room_rect)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_movement_bounds(room_rect)
	_layout_touch_ui()
	queue_redraw()

func _update_room_rect() -> void:
	var s := get_viewport_rect().size
	room_rect = Rect2(Vector2(ROOM_SIDE_MARGIN, ROOM_TOP), Vector2(maxf(500.0, s.x - ROOM_SIDE_MARGIN * 2.0), maxf(360.0, s.y - ROOM_TOP - ROOM_BOTTOM_MARGIN)))

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
	var s := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.10, 0.085, 0.075))
	draw_rect(room_rect, Color(0.19, 0.16, 0.13))
	draw_rect(room_rect, Color(0.42, 0.34, 0.26), false, 8.0)
	var c := room_rect.get_center()
	var door_color := Color(0.10, 0.55, 0.28) if _room_cleared else Color(0.05, 0.04, 0.035)
	draw_rect(Rect2(c.x - 58.0, room_rect.position.y - 8.0, 116.0, 24.0), door_color)
