extends "res://scripts/main_v2.gd"

const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const EconomyService = preload("res://src/application/economy/economy_service.gd")
const RewardService = preload("res://src/application/rewards/reward_service.gd")
const ControlLayoutRepository = preload("res://src/infrastructure/persistence/control_layout_repository.gd")
const ItemAssetView = preload("res://src/presentation/items/item_asset_view.gd")
const MobileCombatSideHud = preload("res://src/presentation/hud/mobile_combat_side_hud.gd")

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

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(hud_top_map_card):
		return
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return

	# Legacy top/right cards no longer own the minimap. Side stats are rendered
	# by the dedicated Presentation HUD around the Combat Safe Area.
	if is_instance_valid(hud_left_card):
		hud_left_card.visible = false
	if is_instance_valid(hud_right_card):
		hud_right_card.visible = false

	var center_card_w := clampf(screen_size.x*0.22,250.0,320.0)
	var center_card_h := 38.0
	if is_instance_valid(hud_center_card):
		hud_center_card.position = Vector2(screen_size.x*0.5-center_card_w*0.5,7.0)
		hud_center_card.size = Vector2(center_card_w,center_card_h)
		hud_center_card.visible = not _run_complete

	var half_center := center_card_w*0.5
	floor_label.position = Vector2(screen_size.x*0.5-center_card_w*0.5+8.0,14.0)
	floor_label.size = Vector2(half_center-12.0,24.0)
	room_label.position = Vector2(screen_size.x*0.5+4.0,14.0)
	room_label.size = Vector2(half_center-12.0,24.0)
	floor_label.add_theme_font_size_override("font_size",16)
	room_label.add_theme_font_size_override("font_size",16)

	var compact_map_w := clampf(screen_size.x*0.30,310.0,420.0)
	var compact_map_h := clampf(screen_size.y*0.085,60.0,72.0)
	var map_w := compact_map_w
	var map_h := compact_map_h
	var map_y := 50.0
	if _minimap_expanded:
		map_w = clampf(screen_size.x*0.52,520.0,720.0)
		map_h = clampf(screen_size.y*0.36,240.0,330.0)
	hud_top_map_card.position = Vector2(screen_size.x*0.5-map_w*0.5,map_y)
	hud_top_map_card.size = Vector2(map_w,map_h)
	hud_top_map_card.visible = not _run_complete
	hud_top_map_card.modulate.a = 0.96 if _minimap_expanded else 0.46

	minimap_label.position = hud_top_map_card.position+Vector2(10.0,7.0)
	minimap_label.size = hud_top_map_card.size-Vector2(20.0,14.0)
	minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minimap_label.add_theme_font_size_override("font_size",20 if _minimap_expanded else 11)
	minimap_label.modulate.a = 1.0 if _minimap_expanded else 0.54
	minimap_label.z_index = 3

	if is_instance_valid(minimap_touch_zone):
		minimap_touch_zone.position = hud_top_map_card.position
		minimap_touch_zone.size = hud_top_map_card.size
		minimap_touch_zone.tooltip_text = "Cerrar mapa" if _minimap_expanded else "Expandir mapa"
		minimap_touch_zone.z_index = 6

	var status_y := maxf(room_rect.position.y+4.0,hud_top_map_card.position.y+hud_top_map_card.size.y+6.0)
	status_label.position = Vector2(screen_size.x*0.5-300.0,status_y)
	status_label.size = Vector2(600.0,32.0)
	status_label.add_theme_font_size_override("font_size",20)
	reward_label.position = Vector2(screen_size.x*0.5-320.0,status_y+31.0)
	reward_label.size = Vector2(640.0,28.0)
	reward_label.add_theme_font_size_override("font_size",14)

	if is_instance_valid(control_edit_button):
		control_edit_button.size = Vector2(152.0,36.0)
		control_edit_button.position = Vector2(screen_size.x-166.0,8.0)
		control_edit_button.z_index = 7

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
