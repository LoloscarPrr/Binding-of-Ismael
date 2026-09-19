extends "res://scripts/main.gd"

var room_visual: IsmaelRoomVisual
var boss_hud: IsmaelBossHud

func _ready() -> void:
	room_visual = IsmaelRoomVisual.new()
	room_visual.z_index = -20
	add_child(room_visual)
	super._ready()
	_sync_room_visual()
	_polish_hud()

func _begin_room(from_door: bool) -> void:
	if is_instance_valid(boss_hud):
		boss_hud.hide_boss()
	super._begin_room(from_door)
	_sync_room_visual()

func _create_touch_ui() -> void:
	super._create_touch_ui()
	var layer := hud_backdrop.get_parent()
	left_stick.floating_origin = false
	right_stick.floating_origin = false
	left_stick.smoothing_speed = 38.0
	right_stick.smoothing_speed = 42.0
	if is_instance_valid(reward_left):
		reward_left.queue_free()
	if is_instance_valid(reward_right):
		reward_right.queue_free()
	reward_left = IsmaelRewardPedestal.new()
	reward_left.visible = false
	reward_left.pressed.connect(_choose_reward.bind(0))
	layer.add_child(reward_left)
	reward_right = IsmaelRewardPedestal.new()
	reward_right.visible = false
	reward_right.pressed.connect(_choose_reward.bind(1))
	layer.add_child(reward_right)
	boss_hud = IsmaelBossHud.new()
	layer.add_child(boss_hud)
	_polish_hud()

func _polish_hud() -> void:
	if not is_instance_valid(hud_backdrop):
		return
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.025,0.021,0.019,0.93)
	hud_style.border_color = Color(0.48,0.34,0.20,0.72)
	hud_style.border_width_bottom = 3
	hud_style.shadow_color = Color(0.0,0.0,0.0,0.48)
	hud_style.shadow_size = 8
	hud_style.shadow_offset = Vector2(0,5)
	hud_backdrop.add_theme_stylebox_override("panel",hud_style)
	for label: Label in [pickup_label,minimap_label,floor_label,room_label,status_label,reward_label]:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color",Color(0.93,0.88,0.76))
			label.add_theme_color_override("font_outline_color",Color(0.015,0.012,0.011,1.0))
			label.add_theme_constant_override("outline_size",4)
	if is_instance_valid(status_label):
		status_label.add_theme_color_override("font_color",Color(1.0,0.84,0.58))
	if is_instance_valid(pickup_label):
		pickup_label.add_theme_color_override("font_color",Color(0.94,0.81,0.54))
	if is_instance_valid(minimap_label):
		minimap_label.add_theme_color_override("font_color",Color(0.78,0.82,0.80))

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(left_stick):
		return
	var screen_size := get_viewport_rect().size
	var short_side := minf(screen_size.x,screen_size.y)
	var pad_side := clampf(short_side*0.44,270.0,350.0)
	var margin_x := clampf(screen_size.x*0.020,16.0,36.0)
	var margin_bottom := clampf(screen_size.y*0.014,10.0,22.0)
	left_stick.size = Vector2(pad_side,pad_side)
	right_stick.size = left_stick.size
	left_stick.stick_radius = pad_side*0.42
	right_stick.stick_radius = left_stick.stick_radius
	left_stick.position = Vector2(margin_x,screen_size.y-pad_side-margin_bottom)
	right_stick.position = Vector2(screen_size.x-pad_side-margin_x,screen_size.y-pad_side-margin_bottom)
	if is_instance_valid(boss_hud):
		var width := clampf(screen_size.x*0.44,500.0,760.0)
		boss_hud.size = Vector2(width,72.0)
		boss_hud.position = Vector2(screen_size.x*0.5-width*0.5,screen_size.y-88.0)

func _update_minimap() -> void:
	if not is_instance_valid(minimap_label):
		return
	var map_text := ""
	for i in range(1,TOTAL_ROOMS+1):
		var symbol := "□"
		if i < _room_index:
			symbol = "■"
		elif i == _room_index:
			symbol = "◆"
		if i == TOTAL_ROOMS:
			symbol += "☠"
		elif i == 3:
			symbol += "¢"
		elif i == 4:
			symbol += "✦"
		if i < TOTAL_ROOMS:
			symbol += "─"
		map_text += symbol
	minimap_label.text = map_text

func _spawn_boss() -> void:
	super._spawn_boss()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is IsmaelEnemy and enemy.kind == IsmaelEnemy.EnemyKind.BOSS:
			if not enemy.health_changed.is_connected(_on_boss_health_changed):
				enemy.health_changed.connect(_on_boss_health_changed)
			if is_instance_valid(boss_hud):
				boss_hud.show_boss("GUARDIÁN DEL PISO",enemy.health)
			break

func _on_boss_health_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(boss_hud):
		return
	if boss_hud.max_health != maximum:
		boss_hud.max_health = maximum
	boss_hud.set_health(current)

func _on_enemy_defeated(enemy) -> void:
	var was_boss: bool = enemy is IsmaelEnemy and enemy.kind == IsmaelEnemy.EnemyKind.BOSS
	super._on_enemy_defeated(enemy)
	if was_boss and is_instance_valid(boss_hud):
		boss_hud.hide_boss()

func _on_viewport_size_changed() -> void:
	super._on_viewport_size_changed()
	_sync_room_visual()

func _sync_room_visual() -> void:
	if is_instance_valid(room_visual):
		room_visual.configure(room_rect,_room_kind,_floor_index,_room_index)

func _draw() -> void:
	pass
