extends Node2D

var player: IsmaelPlayer
var left_stick: VirtualStick
var right_stick: VirtualStick

func _ready() -> void:
	player = IsmaelPlayer.new()
	player.position = Vector2(640, 360)
	add_child(player)

	for pos in [Vector2(340, 210), Vector2(920, 220), Vector2(360, 520), Vector2(920, 500)]:
		var enemy := IsmaelEnemy.new()
		enemy.position = pos
		enemy.target = player
		add_child(enemy)

	_create_touch_ui()
	queue_redraw()

func _create_touch_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	left_stick = VirtualStick.new()
	left_stick.position = Vector2(40, 430)
	left_stick.size = Vector2(250, 250)
	layer.add_child(left_stick)

	right_stick = VirtualStick.new()
	right_stick.position = Vector2(990, 430)
	right_stick.size = Vector2(250, 250)
	layer.add_child(right_stick)

	var title := Label.new()
	title.text = "BINDING OF ISMAEL — combat prototype"
	title.position = Vector2(34, 22)
	title.add_theme_font_size_override("font_size", 22)
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "Izquierdo: mover    •    Derecho: disparar"
	hint.position = Vector2(34, 52)
	hint.add_theme_font_size_override("font_size", 16)
	layer.add_child(hint)

func _input(event: InputEvent) -> void:
	if left_stick and left_stick.handle_touch(event):
		get_viewport().set_input_as_handled()
		return
	if right_stick and right_stick.handle_touch(event):
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	var keyboard_move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var keyboard_aim := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")

	player.move_input = left_stick.value if left_stick.value.length() > 0.0 else keyboard_move
	player.aim_input = right_stick.value if right_stick.value.length() > 0.0 else keyboard_aim

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.10, 0.085, 0.075))
	draw_rect(Rect2(54, 82, 1172, 584), Color(0.19, 0.16, 0.13))
	draw_rect(Rect2(54, 82, 1172, 584), Color(0.42, 0.34, 0.26), false, 8.0)

	# Simple doorway markers for the room-system prototype.
	draw_rect(Rect2(590, 70, 100, 20), Color(0.05, 0.04, 0.035))
	draw_rect(Rect2(590, 658, 100, 20), Color(0.05, 0.04, 0.035))
	draw_rect(Rect2(44, 310, 20, 100), Color(0.05, 0.04, 0.035))
	draw_rect(Rect2(1216, 310, 20, 100), Color(0.05, 0.04, 0.035))
