extends "res://scripts/main.gd"

const CONTROL_LAYOUT_PATH := "user://control_layout.cfg"

var room_visual: IsmaelRoomVisual
var boss_hud: IsmaelBossHud
var control_edit_button: Button
var _editing_controls := false
var _saved_left_center := Vector2(-1.0,-1.0)
var _saved_right_center := Vector2(-1.0,-1.0)

func _ready() -> void:
	_load_control_layout()
	room_visual = IsmaelRoomVisual.new()
	room_visual.z_index = -20
	add_child(room_visual)
	super._ready()
	_sync_room_visual()
	_polish_hud()
	_apply_saved_control_positions()

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
	left_stick.smoothing_speed = 24.0
	right_stick.smoothing_speed = 27.0
	left_stick.layout_changed.connect(_on_control_layout_changed)
	right_stick.layout_changed.connect(_on_control_layout_changed)
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
	control_edit_button = Button.new()
	control_edit_button.text = "MOVER CONTROLES"
	control_edit_button.pressed.connect(_toggle_control_edit_mode)
	control_edit_button.focus_mode = Control.FOCUS_NONE
	layer.add_child(control_edit_button)
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
	if is_instance_valid(control_edit_button):
		control_edit_button.add_theme_font_size_override("font_size",16)
		control_edit_button.add_theme_color_override("font_color",Color(0.94,0.88,0.74))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04,0.035,0.032,0.58)
		style.border_color = Color(0.68,0.50,0.26,0.36)
		style.set_border_width_all(2)
		style.corner_radius_top_left = 7
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_left = 7
		style.corner_radius_bottom_right = 7
		control_edit_button.add_theme_stylebox_override("normal",style)

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(left_stick):
		return
	var screen_size := get_viewport_rect().size
	var short_side := minf(screen_size.x,screen_size.y)
	var pad_side := clampf(short_side*0.40,250.0,326.0)
	var margin_x := clampf(screen_size.x*0.020,16.0,36.0)
	var margin_bottom := clampf(screen_size.y*0.014,10.0,22.0)
	left_stick.size = Vector2(pad_side,pad_side)
	right_stick.size = left_stick.size
	left_stick.stick_radius = pad_side*0.34
	right_stick.stick_radius = left_stick.stick_radius
	left_stick.knob_radius = pad_side*0.14
	right_stick.knob_radius = left_stick.knob_radius
	if _has_saved_center(_saved_left_center):
		left_stick.position = _position_from_saved_center(_saved_left_center,left_stick.size)
	else:
		left_stick.position = Vector2(margin_x,screen_size.y-pad_side-margin_bottom)
	if _has_saved_center(_saved_right_center):
		right_stick.position = _position_from_saved_center(_saved_right_center,right_stick.size)
	else:
		right_stick.position = Vector2(screen_size.x-pad_side-margin_x,screen_size.y-pad_side-margin_bottom)
	if is_instance_valid(control_edit_button):
		control_edit_button.size = Vector2(168.0,42.0)
		control_edit_button.position = Vector2(screen_size.x-184.0,96.0)
	if is_instance_valid(boss_hud):
		var width := clampf(screen_size.x*0.44,500.0,760.0)
		boss_hud.size = Vector2(width,72.0)
		boss_hud.position = Vector2(screen_size.x*0.5-width*0.5,screen_size.y-88.0)

func _physics_process(delta: float) -> void:
	if _editing_controls:
		if is_instance_valid(player):
			player.move_input = Vector2.ZERO
			player.aim_input = Vector2.ZERO
		return
	super._physics_process(delta)

func _toggle_control_edit_mode() -> void:
	_editing_controls = not _editing_controls
	left_stick.set_edit_mode(_editing_controls)
	right_stick.set_edit_mode(_editing_controls)
	control_edit_button.text = "GUARDAR" if _editing_controls else "MOVER CONTROLES"
	if _editing_controls:
		status_label.text = "ARRASTRA LOS STICKS A DONDE QUIERAS"
		reward_label.text = "Pulsa GUARDAR cuando termines"
	else:
		_store_control_centers()
		_save_control_layout()
		status_label.text = "CONTROLES GUARDADOS"
		reward_label.text = ""

func _on_control_layout_changed() -> void:
	if not _editing_controls:
		return
	_store_control_centers()
	_save_control_layout()

func _store_control_centers() -> void:
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	_saved_left_center = (left_stick.position + left_stick.size*0.5) / screen_size
	_saved_right_center = (right_stick.position + right_stick.size*0.5) / screen_size

func _save_control_layout() -> void:
	var config := ConfigFile.new()
	config.set_value("controls","left_center",_saved_left_center)
	config.set_value("controls","right_center",_saved_right_center)
	config.save(CONTROL_LAYOUT_PATH)

func _load_control_layout() -> void:
	var config := ConfigFile.new()
	if config.load(CONTROL_LAYOUT_PATH) != OK:
		return
	_saved_left_center = config.get_value("controls","left_center",Vector2(-1.0,-1.0))
	_saved_right_center = config.get_value("controls","right_center",Vector2(-1.0,-1.0))

func _apply_saved_control_positions() -> void:
	if is_instance_valid(left_stick):
		_layout_touch_ui()

func _has_saved_center(center: Vector2) -> bool:
	return center.x >= 0.0 and center.x <= 1.0 and center.y >= 0.0 and center.y <= 1.0

func _position_from_saved_center(center: Vector2, control_size: Vector2) -> Vector2:
	var screen_size := get_viewport_rect().size
	var pos := center*screen_size-control_size*0.5
	pos.x = clampf(pos.x,0.0,maxf(0.0,screen_size.x-control_size.x))
	pos.y = clampf(pos.y,0.0,maxf(0.0,screen_size.y-control_size.y))
	return pos

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
