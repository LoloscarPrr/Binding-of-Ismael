extends "res://scripts/main_v2.gd"

const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const EconomyService = preload("res://src/application/economy/economy_service.gd")
const RewardService = preload("res://src/application/rewards/reward_service.gd")
const ControlLayoutRepository = preload("res://src/infrastructure/persistence/control_layout_repository.gd")
const ItemAssetView = preload("res://src/presentation/items/item_asset_view.gd")
const MobileCombatSideHud = preload("res://src/presentation/hud/mobile_combat_side_hud.gd")

const MOBILE_COMBAT_FRAME_SCALE := 0.80

var _clean_inventory = RunInventory.new()
var _economy_service = EconomyService.new(_clean_inventory)
var _reward_service = RewardService.new()
var _control_layout_repository = ControlLayoutRepository.new()
var hud_top_map_card: Panel

func _create_touch_ui() -> void:
	super._create_touch_ui()
	var layer := hud_backdrop.get_parent()
	if not is_instance_valid(hud_top_map_card):
		hud_top_map_card = Panel.new()
		hud_top_map_card.name = "HudTopMapCard"
		hud_top_map_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_top_map_card.z_index = 1
		layer.add_child(hud_top_map_card)
	if is_instance_valid(combat_side_hud):
		combat_side_hud.queue_free()
	combat_side_hud = MobileCombatSideHud.new()
	combat_side_hud.configure(self,player)
	combat_side_hud.z_index = -1
	layer.add_child(combat_side_hud)
	_polish_hud()

func _polish_hud() -> void:
	super._polish_hud()
	if is_instance_valid(hud_left_card):
		hud_left_card.visible = false
	if is_instance_valid(hud_right_card):
		hud_right_card.visible = false
	if is_instance_valid(hud_top_map_card):
		hud_top_map_card.visible = not _run_complete
		hud_top_map_card.add_theme_stylebox_override("panel",_top_map_style())
		hud_top_map_card.modulate.a = 0.96 if _minimap_expanded else 0.46
	if is_instance_valid(minimap_label):
		minimap_label.modulate.a = 1.0 if _minimap_expanded else 0.54
	if is_instance_valid(hud_center_card):
		hud_center_card.modulate.a = 0.86

func _top_map_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012,0.013,0.013,0.82)
	style.border_color = Color(0.38,0.46,0.45,0.54)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

# Presentation owns the Mobile Combat Frame dimensions. The inherited gameplay
# systems continue consuming room_rect exactly as before; only the visible safe
# frame is uniformly reduced and moved slightly upward to free exterior HUD and
# thumb space without changing combat rules.
func _update_room_rect() -> void:
	super._update_room_rect()
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return
	var base_rect := room_rect
	var framed_size := base_rect.size*MOBILE_COMBAT_FRAME_SCALE
	var framed_center := base_rect.get_center()
	framed_center.y -= clampf(screen_size.y*0.011,7.0,12.0)
	room_rect = Rect2(framed_center-framed_size*0.5,framed_size)

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(hud_top_map_card):
		return
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return

	# Legacy cards no longer own resources or the minimap. The dedicated side HUD
	# occupies the exterior margins of the Mobile Combat Frame.
	if is_instance_valid(hud_left_card):
		hud_left_card.visible = false
	if is_instance_valid(hud_right_card):
		hud_right_card.visible = false

	# Bottom thumb zones: keep the visible sticks entirely outside room_rect while
	# preserving persisted positions by clamping them into the new safe zones.
	if is_instance_valid(left_stick) and is_instance_valid(right_stick):
		var short_side := minf(screen_size.x,screen_size.y)
		var pad_side := clampf(short_side*0.295,204.0,248.0)
		var stick_size := Vector2(pad_side,pad_side)
		left_stick.size = stick_size
		right_stick.size = stick_size
		left_stick.stick_radius = pad_side*0.385
		right_stick.stick_radius = left_stick.stick_radius
		left_stick.knob_radius = pad_side*0.17
		right_stick.knob_radius = left_stick.knob_radius

		var min_center_y := room_rect.end.y+left_stick.stick_radius+12.0
		var max_center_y := screen_size.y-pad_side*0.5-8.0
		if max_center_y < min_center_y:
			min_center_y = max_center_y
		var left_min_x := pad_side*0.5+8.0
		var left_max_x := minf(screen_size.x*0.36,room_rect.position.x+pad_side*0.45)
		var right_min_x := maxf(screen_size.x*0.64,room_rect.end.x-pad_side*0.45)
		var right_max_x := screen_size.x-pad_side*0.5-8.0
		_left_touch_zone = Rect2(
			Vector2(left_min_x,min_center_y),
			Vector2(maxf(1.0,left_max_x-left_min_x),maxf(1.0,max_center_y-min_center_y))
		)
		_right_touch_zone = Rect2(
			Vector2(right_min_x,min_center_y),
			Vector2(maxf(1.0,right_max_x-right_min_x),maxf(1.0,max_center_y-min_center_y))
		)
		left_stick.set_edit_center_bounds(_left_touch_zone)
		right_stick.set_edit_center_bounds(_right_touch_zone)

		if _has_saved_center(_saved_left_center):
			left_stick.position = _position_from_saved_center(_saved_left_center,left_stick.size,true)
		else:
			var left_center_x := clampf(room_rect.position.x*0.56,left_min_x,left_max_x)
			left_stick.position = _position_from_center(Vector2(left_center_x,max_center_y),left_stick.size,true)
		if _has_saved_center(_saved_right_center):
			right_stick.position = _position_from_saved_center(_saved_right_center,right_stick.size,false)
		else:
			var right_center_x := clampf(screen_size.x-room_rect.position.x*0.56,right_min_x,right_max_x)
			right_stick.position = _position_from_center(Vector2(right_center_x,max_center_y),right_stick.size,false)

	if is_instance_valid(combat_side_hud):
		combat_side_hud.visible = not _run_complete
		combat_side_hud.set_layout(room_rect,screen_size)

	# One coherent top strip: PISO/SALA | compact minimap | MOVER CONTROLES.
	var top_y := 7.0
	var gap := clampf(screen_size.x*0.009,10.0,14.0)
	var button_w := 152.0
	var button_h := 36.0
	var button_x := screen_size.x-button_w-14.0
	var info_w := clampf(screen_size.x*0.215,250.0,310.0)
	var compact_map_w := clampf(screen_size.x*0.30,320.0,430.0)
	var compact_map_h := clampf(screen_size.y*0.088,58.0,66.0)
	var compact_group_w := info_w+gap+compact_map_w
	var group_shift := clampf(screen_size.x*0.035,32.0,56.0)
	var group_x := screen_size.x*0.5-compact_group_w*0.5-group_shift
	group_x = clampf(group_x,14.0,maxf(14.0,button_x-gap-compact_group_w))
	var map_x := group_x+info_w+gap

	if is_instance_valid(hud_center_card):
		hud_center_card.position = Vector2(group_x,top_y+9.0)
		hud_center_card.size = Vector2(info_w,44.0)
		hud_center_card.visible = not _run_complete

	var half_info := info_w*0.5
	floor_label.position = Vector2(group_x+8.0,top_y+18.0)
	floor_label.size = Vector2(half_info-12.0,26.0)
	room_label.position = Vector2(group_x+half_info+4.0,top_y+18.0)
	room_label.size = Vector2(half_info-12.0,26.0)
	floor_label.add_theme_font_size_override("font_size",16)
	room_label.add_theme_font_size_override("font_size",16)

	var map_w := compact_map_w
	var map_h := compact_map_h
	if _minimap_expanded:
		var available_w := maxf(1.0,button_x-gap-map_x)
		map_w = minf(clampf(screen_size.x*0.46,500.0,720.0),available_w)
		map_h = clampf(screen_size.y*0.30,200.0,270.0)
	hud_top_map_card.position = Vector2(map_x,top_y)
	hud_top_map_card.size = Vector2(map_w,map_h)
	hud_top_map_card.visible = not _run_complete
	hud_top_map_card.modulate.a = 0.96 if _minimap_expanded else 0.46

	minimap_label.position = hud_top_map_card.position+Vector2(8.0,6.0)
	minimap_label.size = hud_top_map_card.size-Vector2(16.0,12.0)
	minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minimap_label.add_theme_font_size_override("font_size",17 if _minimap_expanded else 10)
	minimap_label.modulate.a = 1.0 if _minimap_expanded else 0.54
	minimap_label.z_index = 3

	if is_instance_valid(minimap_touch_zone):
		minimap_touch_zone.position = hud_top_map_card.position
		minimap_touch_zone.size = hud_top_map_card.size
		minimap_touch_zone.tooltip_text = "Cerrar mapa" if _minimap_expanded else "Expandir mapa"
		minimap_touch_zone.z_index = 6

	if is_instance_valid(control_edit_button):
		control_edit_button.size = Vector2(button_w,button_h)
		control_edit_button.position = Vector2(button_x,top_y+10.0)
		control_edit_button.z_index = 7

	# Dedicated contextual band below the top strip. It ends before room_rect, so
	# SALA LIMPIA, room names and subtitles can never land over the top doorway.
	var compact_band_bottom := top_y+compact_map_h
	var status_y := maxf(compact_band_bottom+7.0,room_rect.position.y-58.0)
	var context_w := clampf(room_rect.size.x*0.66,460.0,640.0)
	var context_x := screen_size.x*0.5-context_w*0.5
	if _minimap_expanded:
		context_w = maxf(300.0,map_x-28.0)
		context_x = 14.0
	status_label.position = Vector2(context_x,status_y)
	status_label.size = Vector2(context_w,27.0)
	status_label.add_theme_font_size_override("font_size",19)
	reward_label.position = Vector2(context_x,status_y+27.0)
	reward_label.size = Vector2(context_w,22.0)
	reward_label.add_theme_font_size_override("font_size",13)

	if is_instance_valid(boss_hud):
		var boss_width := clampf(room_rect.size.x*0.58,430.0,620.0)
		boss_hud.size = Vector2(boss_width,58.0)
		boss_hud.position = Vector2(screen_size.x*0.5-boss_width*0.5,minf(screen_size.y-66.0,room_rect.end.y+10.0))

func _apply_completion_ui() -> void:
	super._apply_completion_ui()
	if is_instance_valid(hud_top_map_card):
		hud_top_map_card.visible = false

func _make_reward_choices() -> Array[String]:
	var available: Array[String] = []
	for reward in ItemCatalog.reward_ids():
		if reward != _last_reward:
			available.append(reward)
	available.shuffle()
	if available.size() < 2:
		available = ItemCatalog.reward_ids()
	return [available[0],available[1]]

func _reward_name(reward: String) -> String:
	return ItemCatalog.reward_full_name(reward)

func _apply_reward(reward: String) -> void:
	_sync_inventory_from_legacy()
	var result := _reward_service.apply(reward,player,_clean_inventory)
	_sync_legacy_from_inventory()
	if bool(result.get("reveal_map",false)):
		_map_reveal_active = true
		if _dungeon != null:
			_dungeon.reveal_public_rooms()
			_update_minimap()
	_update_pickup_hud()

func _on_pickup_collected(kind: String) -> void:
	_sync_inventory_from_legacy()
	_economy_service.collect_pickup(kind,player)
	_sync_legacy_from_inventory()
	_update_pickup_hud()

func _mark_current_room_cleared(count_clear: bool = true) -> void:
	var cleared_before := _rooms_cleared_total
	super._mark_current_room_cleared(count_clear)
	if count_clear and _rooms_cleared_total > cleared_before:
		_sync_inventory_from_legacy()
		_economy_service.grant_room_clear()
		_sync_legacy_from_inventory()
		_update_pickup_hud()

func _update_pickup_hud() -> void:
	_sync_inventory_from_legacy()
	super._update_pickup_hud()

func _spawn_reward_pedestal(reward: String, world_position: Vector2) -> void:
	var pedestal := IsmaelWorldRewardPedestal.new()
	pedestal.configure_reward(reward,_reward_name(reward))
	pedestal.position = world_position
	pedestal.claimed.connect(_on_reward_pedestal_claimed)
	ItemAssetView.attach(pedestal,"reward",reward,72.0,Vector2(0,-10),3)
	add_child(pedestal)

func get_run_coins() -> int:
	_sync_inventory_from_legacy()
	return int(_clean_inventory.coins)

func spend_run_coins(amount: int) -> bool:
	_sync_inventory_from_legacy()
	var spent := _economy_service.spend_coins(amount)
	_sync_legacy_from_inventory()
	if spent:
		_update_pickup_hud()
	return spent

func get_run_inventory_snapshot() -> Dictionary:
	_sync_inventory_from_legacy()
	return _clean_inventory.snapshot()

func _save_control_layout() -> void:
	_control_layout_repository.save_centers(_saved_left_center,_saved_right_center)

func _load_control_layout() -> void:
	var stored := _control_layout_repository.load_centers()
	_saved_left_center = stored.get("left_center",Vector2(-1.0,-1.0))
	_saved_right_center = stored.get("right_center",Vector2(-1.0,-1.0))

func _sync_inventory_from_legacy() -> void:
	_clean_inventory.coins = maxi(0,_coins)
	_clean_inventory.bombs = maxi(0,_bombs)
	_clean_inventory.keys = maxi(0,_keys)
	_clean_inventory.coin_bonus_per_clear = maxi(0,_coin_bonus_per_clear)

func _sync_legacy_from_inventory() -> void:
	_coins = int(_clean_inventory.coins)
	_bombs = int(_clean_inventory.bombs)
	_keys = int(_clean_inventory.keys)
	_coin_bonus_per_clear = int(_clean_inventory.coin_bonus_per_clear)
