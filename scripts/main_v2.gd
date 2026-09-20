extends "res://scripts/main.gd"

const CONTROL_LAYOUT_PATH := "user://control_layout.cfg"

var room_visual: IsmaelRoomVisual
var boss_hud: IsmaelBossHud
var control_edit_button: Button
var hud_left_card: Panel
var hud_center_card: Panel
var hud_right_card: Panel
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

func _begin_room(entry_direction: Vector2i = Vector2i.ZERO) -> void:
	if is_instance_valid(boss_hud):
		boss_hud.hide_boss()
	super._begin_room(entry_direction)
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
	_create_hud_cards(layer)
	control_edit_button = Button.new()
	control_edit_button.text = "MOVER CONTROLES"
	control_edit_button.pressed.connect(_toggle_control_edit_mode)
	control_edit_button.focus_mode = Control.FOCUS_NONE
	layer.add_child(control_edit_button)
	_polish_hud()

func _create_hud_cards(layer: CanvasLayer) -> void:
	hud_left_card = Panel.new()
	hud_left_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_left_card.z_index = -1
	layer.add_child(hud_left_card)
	hud_center_card = Panel.new()
	hud_center_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_center_card.z_index = -1
	layer.add_child(hud_center_card)
	hud_right_card = Panel.new()
	hud_right_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_right_card.z_index = -1
	layer.add_child(hud_right_card)

func _hud_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.016,0.015,0.72)
	style.border_color = accent
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0,0.0,0.0,0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0,4)
	return style

func _polish_hud() -> void:
	if not is_instance_valid(hud_backdrop):
		return
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.0,0.0,0.0,0.0)
	hud_style.border_color = Color(0.0,0.0,0.0,0.0)
	hud_backdrop.add_theme_stylebox_override("panel",hud_style)
	if is_instance_valid(hud_left_card):
		hud_left_card.add_theme_stylebox_override("panel",_hud_card_style(Color(0.44,0.25,0.16,0.64)))
	if is_instance_valid(hud_center_card):
		hud_center_card.add_theme_stylebox_override("panel",_hud_card_style(Color(0.54,0.39,0.20,0.58)))
	if is_instance_valid(hud_right_card):
		hud_right_card.add_theme_stylebox_override("panel",_hud_card_style(Color(0.30,0.38,0.38,0.58)))
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
	var card_y := 12.0
	var left_card_w := clampf(screen_size.x*0.30,360.0,470.0)
	var right_card_w := clampf(screen_size.x*0.26,320.0,420.0)
	var center_card_w := clampf(screen_size.x*0.22,260.0,340.0)
	if is_instance_valid(hud_left_card):
		hud_left_card.position = Vector2(14.0,card_y)
		hud_left_card.size = Vector2(left_card_w,76.0)
	if is_instance_valid(hud_right_card):
		hud_right_card.position = Vector2(screen_size.x-right_card_w-14.0,card_y)
		hud_right_card.size = Vector2(right_card_w,76.0)
	if is_instance_valid(hud_center_card):
		hud_center_card.position = Vector2(screen_size.x*0.5-center_card_w*0.5,card_y)
		hud_center_card.size = Vector2(center_card_w,66.0)
	health_hud.position = Vector2(28.0,18.0)
	health_hud.size = Vector2(left_card_w-40.0,32.0)
	health_hud.icon_size = 25.0
	health_hud.icon_gap = 5.0
	pickup_label.position = Vector2(28.0,48.0)
	pickup_label.size = Vector2(left_card_w-40.0,28.0)
	pickup_label.add_theme_font_size_override("font_size",18)
	minimap_label.position = Vector2(screen_size.x-right_card_w+8.0,15.0)
	minimap_label.size = Vector2(right_card_w-44.0,58.0)
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minimap_label.add_theme_font_size_override("font_size",13)
	var half_center := center_card_w*0.5
	floor_label.position = Vector2(screen_size.x*0.5-center_card_w*0.5+8.0,20.0)
	floor_label.size = Vector2(half_center-12.0,26.0)
	room_label.position = Vector2(screen_size.x*0.5+4.0,20.0)
	room_label.size = Vector2(half_center-12.0,26.0)
	floor_label.add_theme_font_size_override("font_size",17)
	room_label.add_theme_font_size_override("font_size",17)
	status_label.position = Vector2(screen_size.x*0.5-300.0,78.0)
	status_label.size = Vector2(600.0,38.0)
	status_label.add_theme_font_size_override("font_size",24)
	if is_instance_valid(reward_left) and is_instance_valid(reward_right):
		var reward_size := Vector2(clampf(screen_size.x*0.19,250.0,310.0),clampf(screen_size.y*0.34,210.0,250.0))
		var reward_gap := clampf(screen_size.x*0.055,54.0,84.0)
		reward_left.size = reward_size
		reward_right.size = reward_size
		reward_left.position = Vector2(screen_size.x*0.5-reward_gap*0.5-reward_size.x,screen_size.y*0.29)
		reward_right.position = Vector2(screen_size.x*0.5+reward_gap*0.5,screen_size.y*0.29)
		reward_label.position = Vector2(screen_size.x*0.5-260.0,screen_size.y*0.235)
		reward_label.size = Vector2(520.0,32.0)
		reward_label.add_theme_font_size_override("font_size",15)
	if is_instance_valid(control_edit_button):
		control_edit_button.size = Vector2(146.0,36.0)
		control_edit_button.position = Vector2(screen_size.x-160.0,94.0)
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
	if not is_instance_valid(minimap_label) or _dungeon == null:
		return
	minimap_label.text = _dungeon.minimap_text(_current_cell)

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
