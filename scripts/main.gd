extends Node2D

const ROOM_SIDE_MARGIN := 54.0
const ROOM_TOP := 82.0
const ROOM_BOTTOM_MARGIN := 54.0
const STICK_SIZE := Vector2(250.0, 250.0)
const STICK_MARGIN := 40.0

var player: IsmaelPlayer
var left_stick: VirtualStick
var right_stick: VirtualStick
var health_label: Label
var status_label: Label
var restart_button: Button
var room_rect := Rect2()
var _enemies_alive := 0
var _game_over := false

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_room_rect()

	player = IsmaelPlayer.new()
	player.position = room_rect.get_center()
	player.set_movement_bounds(room_rect)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	add_child(player)

	for relative_position in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
		var enemy := IsmaelEnemy.new()
		enemy.position = room_rect.position + room_rect.size * relative_position
		enemy.target = player
		enemy.set_movement_bounds(room_rect)
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)
		_enemies_alive += 1

	_create_touch_ui()
	_on_player_health_changed(player.health, player.max_health)
	_layout_touch_ui()
	queue_redraw()

func _create_touch_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	left_stick = VirtualStick.new()
	left_stick.size = STICK_SIZE
	layer.add_child(left_stick)

	right_stick = VirtualStick.new()
	right_stick.size = STICK_SIZE
	layer.add_child(right_stick)

	var title := Label.new()
	title.text = "BINDING OF ISMAEL — v0.1.1"
	title.position = Vector2(34.0, 20.0)
	title.add_theme_font_size_override("font_size", 22)
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "Izquierdo: mover    •    Derecho: disparar"
	hint.position = Vector2(34.0, 50.0)
	hint.add_theme_font_size_override("font_size", 16)
	layer.add_child(hint)

	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(health_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	layer.add_child(status_label)

	restart_button = Button.new()
	restart_button.text = "REINICIAR"
	restart_button.size = Vector2(220.0, 72.0)
	restart_button.add_theme_font_size_override("font_size", 24)
	restart_button.visible = false
	restart_button.pressed.connect(_restart_game)
	layer.add_child(restart_button)

func _layout_touch_ui() -> void:
	if not is_instance_valid(left_stick):
		return
	var viewport_size := get_viewport_rect().size
	left_stick.position = Vector2(STICK_MARGIN, viewport_size.y - STICK_SIZE.y - STICK_MARGIN)
	right_stick.position = Vector2(viewport_size.x - STICK_SIZE.x - STICK_MARGIN, viewport_size.y - STICK_SIZE.y - STICK_MARGIN)
	health_label.position = Vector2(viewport_size.x - 175.0, 22.0)
	status_label.position = Vector2(viewport_size.x * 0.5 - 180.0, 24.0)
	status_label.size = Vector2(360.0, 44.0)
	restart_button.position = viewport_size * 0.5 - restart_button.size * 0.5

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

func _on_viewport_size_changed() -> void:
	_update_room_rect()
	if is_instance_valid(player):
		player.set_movement_bounds(room_rect)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_movement_bounds(room_rect)
	_layout_touch_ui()
	queue_redraw()

func _update_room_rect() -> void:
	var viewport_size := get_viewport_rect().size
	room_rect = Rect2(
		Vector2(ROOM_SIDE_MARGIN, ROOM_TOP),
		Vector2(
			maxf(400.0, viewport_size.x - ROOM_SIDE_MARGIN * 2.0),
			maxf(300.0, viewport_size.y - ROOM_TOP - ROOM_BOTTOM_MARGIN)
		)
	)

func _on_player_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "VIDA  %d / %d" % [current, maximum]

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
		status_label.text = "SALA LIMPIA"

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.10, 0.085, 0.075))
	draw_rect(room_rect, Color(0.19, 0.16, 0.13))
	draw_rect(room_rect, Color(0.42, 0.34, 0.26), false, 8.0)

	var room_center := room_rect.get_center()
	draw_rect(Rect2(room_center.x - 50.0, room_rect.position.y - 12.0, 100.0, 20.0), Color(0.05, 0.04, 0.035))
	draw_rect(Rect2(room_center.x - 50.0, room_rect.position.y + room_rect.size.y - 8.0, 100.0, 20.0), Color(0.05, 0.04, 0.035))
	draw_rect(Rect2(room_rect.position.x - 10.0, room_center.y - 50.0, 20.0, 100.0), Color(0.05, 0.04, 0.035))
	draw_rect(Rect2(room_rect.position.x + room_rect.size.x - 10.0, room_center.y - 50.0, 20.0, 100.0), Color(0.05, 0.04, 0.035))
