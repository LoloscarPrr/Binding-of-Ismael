extends "res://scripts/main_v2.gd"

const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const EconomyService = preload("res://src/application/economy/economy_service.gd")
const RewardService = preload("res://src/application/rewards/reward_service.gd")
const BuildState = preload("res://src/domain/items/build_state.gd")
const ControlLayoutRepository = preload("res://src/infrastructure/persistence/control_layout_repository.gd")
const ItemAssetView = preload("res://src/presentation/items/item_asset_view.gd")
const MobileCombatSideHud = preload("res://src/presentation/hud/mobile_combat_side_hud.gd")

var _clean_inventory = RunInventory.new()
var _economy_service = EconomyService.new(_clean_inventory)
var _reward_service = RewardService.new()
var _build_state = BuildState.new()
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
		hud_center_card.modulate.a = 0.88

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

# Presentation owns the mobile combat viewport geometry. The gameplay systems
# keep consuming the same room_rect contract, while this controller reserves
# real exterior space for side HUD, thumbs and the lower run-information shelf.
func _update_room_rect() -> void:
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		room_rect = Rect2()
		return

	var top_edge := clampf(screen_size.y*0.09,60.0,86.0)
	var bottom_reserved := clampf(screen_size.y*0.30,205.0,250.0)
	var bottom_edge := screen_size.y-bottom_reserved
	var combat_height := maxf(1.0,bottom_edge-top_edge)

	# Keep substantial gutters at 1280x720, while aspect-limiting the room on
	# wider Redmi-class screens so extra width becomes useful HUD space.
	var minimum_gutter := clampf(screen_size.x*0.14,184.0,340.0)
	var available_width := maxf(1.0,screen_size.x-minimum_gutter*2.0)
	var preferred_width := screen_size.x*0.74
	var aspect_limited_width := combat_height*2.65
	var combat_width := minf(available_width,minf(preferred_width,aspect_limited_width))
	var left_edge := screen_size.x*0.5-combat_width*0.5
	room_rect = Rect2(Vector2(left_edge,top_edge),Vector2(combat_width,combat_height))

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(hud_top_map_card):
		return
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 1.0 or screen_size.y <= 1.0:
		return

	# The old cards stay hidden. The dedicated side HUD owns the vertical gutters.
	if is_instance_valid(hud_left_card):
		hud_left_card.visible = false
	if is_instance_valid(hud_right_card):
		hud_right_card.visible = false

	# The default layout still starts in the lower shelf, but edit mode is fully
	# free: either stick may be dragged anywhere on screen. The only constraint is
	# keeping the complete Control rect inside the physical viewport.
	if is_instance_valid(left_stick) and is_instance_valid(right_stick):
		var short_side := minf(screen_size.x,screen_size.y)
		var pad_side := clampf(short_side*0.265,186.0,216.0)
		var stick_size := Vector2(pad_side,pad_side)
		left_stick.size = stick_size
		right_stick.size = stick_size
		left_stick.stick_radius = pad_side*0.355
		right_stick.stick_radius = left_stick.stick_radius
		left_stick.knob_radius = pad_side*0.155
		right_stick.knob_radius = left_stick.knob_radius

		var free_min := Vector2(pad_side*0.5+4.0,pad_side*0.5+4.0)
		var free_max := Vector2(
			screen_size.x-pad_side*0.5-4.0,
			screen_size.y-pad_side*0.5-4.0
		)
		var free_zone := Rect2(free_min,Vector2(
			maxf(1.0,free_max.x-free_min.x),
			maxf(1.0,free_max.y-free_min.y)
		))
		_left_touch_zone = free_zone
		_right_touch_zone = free_zone
		left_stick.set_edit_center_bounds(free_zone)
		right_stick.set_edit_center_bounds(free_zone)

		var default_y := free_max.y
		if _has_saved_center(_saved_left_center):
			left_stick.position = _position_from_saved_center(_saved_left_center,left_stick.size,true)
		else:
			var left_center := Vector2(
				clampf(room_rect.position.x+pad_side*0.34,free_min.x,free_max.x),
				default_y
			)
			left_stick.position = _position_from_center(left_center,left_stick.size,true)
		if _has_saved_center(_saved_right_center):
			right_stick.position = _position_from_saved_center(_saved_right_center,right_stick.size,false)
		else:
			var right_center := Vector2(
				clampf(room_rect.end.x-pad_side*0.34,free_min.x,free_max.x),
				default_y
			)
			right_stick.position = _position_from_center(right_center,right_stick.size,false)

	if is_instance_valid(combat_side_hud):
		combat_side_hud.visible = not _run_complete
		combat_side_hud.set_layout(room_rect,screen_size)

	# PISO / SALA now belongs to the lower shelf between both sticks, exactly where
	# the thumbs do not need to travel. This frees the top edge for context + map.
	var run_card_w := clampf(room_rect.size.x*0.40,300.0,390.0)
	var run_card_h := 58.0
	var run_card_y := minf(screen_size.y-run_card_h-18.0,room_rect.end.y+62.0)
	var run_card_x := screen_size.x*0.5-run_card_w*0.5
	if is_instance_valid(hud_center_card):
		hud_center_card.position = Vector2(run_card_x,run_card_y)
		hud_center_card.size = Vector2(run_card_w,run_card_h)
		hud_center_card.visible = not _run_complete

	var half_run := run_card_w*0.5
	room_label.position = Vector2(run_card_x+8.0,run_card_y+16.0)
	room_label.size = Vector2(half_run-12.0,30.0)
	floor_label.position = Vector2(run_card_x+half_run+4.0,run_card_y+16.0)
	floor_label.size = Vector2(half_run-12.0,30.0)
	room_label.add_theme_font_size_override("font_size",18)
	floor_label.add_theme_font_size_override("font_size",18)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Top strip: contextual text on the left/center, horizontal minimap on the
	# upper-right edge of the combat frame, and MOVER CONTROLES in the outer gutter.
	var top_y := 6.0
	var button_w := 152.0
	var button_h := 36.0
	var button_x := screen_size.x-button_w-14.0
	var compact_map_w := clampf(room_rect.size.x*0.38,300.0,420.0)
	var compact_map_h := clampf(screen_size.y*0.075,52.0,58.0)
	var compact_map_x := room_rect.end.x-compact_map_w

	var map_w := compact_map_w
	var map_h := compact_map_h
	var map_x := compact_map_x
	if _minimap_expanded:
		map_w = clampf(screen_size.x*0.46,500.0,720.0)
		map_w = minf(map_w,maxf(300.0,room_rect.size.x*0.78))
		map_h = clampf(screen_size.y*0.30,210.0,285.0)
		map_x = room_rect.end.x-map_w
	map_x = minf(map_x,button_x-map_w-12.0)
	map_x = maxf(12.0,map_x)

	hud_top_map_card.position = Vector2(map_x,top_y)
	hud_top_map_card.size = Vector2(map_w,map_h)
	hud_top_map_card.visible = not _run_complete
	hud_top_map_card.modulate.a = 0.96 if _minimap_expanded else 0.46

	minimap_label.position = hud_top_map_card.position+Vector2(8.0,5.0)
	minimap_label.size = hud_top_map_card.size-Vector2(16.0,10.0)
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

	# Reserved message lane above the room. It is physically outside room_rect,
	# therefore SALA LIMPIA, SANTUARIO OCULTO and subtitles cannot cover the door.
	var context_x := room_rect.position.x+10.0
	var context_right := map_x-14.0
	var context_w := maxf(250.0,context_right-context_x)
	if context_x+context_w > map_x-8.0:
		context_w = maxf(220.0,map_x-context_x-12.0)
	status_label.position = Vector2(context_x,top_y+2.0)
	status_label.size = Vector2(context_w,27.0)
	status_label.add_theme_font_size_override("font_size",18 if not _minimap_expanded else 16)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.position = Vector2(context_x,top_y+29.0)
	reward_label.size = Vector2(context_w,21.0)
	reward_label.add_theme_font_size_override("font_size",12)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if is_instance_valid(boss_hud):
		var boss_width := clampf(room_rect.size.x*0.58,430.0,620.0)
		boss_hud.size = Vector2(boss_width,46.0)
		boss_hud.position = Vector2(screen_size.x*0.5-boss_width*0.5,room_rect.end.y+7.0)

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
	var newly_active := _build_state.register_item(
		reward,
		ItemCatalog.reward_tags(reward),
		ItemCatalog.synergy_definitions()
	)
	_apply_new_synergies(newly_active)
	_refresh_projectile_build()
	_sync_legacy_from_inventory()
	if bool(result.get("reveal_map",false)):
		_map_reveal_active = true
		if _dungeon != null:
			_dungeon.reveal_public_rooms()
			_update_minimap()
	_update_pickup_hud()
	if not newly_active.is_empty() and is_instance_valid(reward_label):
		var names: Array[String] = []
		for synergy_id in newly_active:
			names.append(ItemCatalog.synergy_title(synergy_id))
		reward_label.text = "SINERGIA ACTIVADA — %s" % " + ".join(names)

func _apply_new_synergies(synergy_ids: Array[String]) -> void:
	for synergy_id in synergy_ids:
		var definition := ItemCatalog.synergy_definition(synergy_id)
		var bonus: Dictionary = definition.get("bonus",{})
		if bonus.has("move_speed"):
			player.move_speed += float(bonus["move_speed"])
		if bonus.has("fire_rate_delta"):
			player.fire_rate = maxf(0.075,player.fire_rate+float(bonus["fire_rate_delta"]))
		if bonus.has("projectile_speed"):
			player.projectile_speed += float(bonus["projectile_speed"])
		if bonus.has("projectile_damage"):
			player.projectile_damage += int(bonus["projectile_damage"])
		if bonus.has("max_health"):
			player.add_max_health(int(bonus["max_health"]))
		if bonus.has("coins"):
			_clean_inventory.add_coins(int(bonus["coins"]))
	if is_instance_valid(player) and player.has_method("sync_domain_state_from_runtime"):
		player.sync_domain_state_from_runtime()

func _refresh_projectile_build() -> void:
	if not is_instance_valid(player):
		return
	var snapshot := _build_state.snapshot()
	var owned: Dictionary = snapshot.get("owned_items",{})
	var synergies: Dictionary = snapshot.get("active_synergies",{})

	player.projectile_style = "tear"
	player.projectile_size_scale = 1.0
	player.projectile_split_count = 0
	player.projectile_split_spread = 0.0
	player.projectile_split_homing = false
	player.burst_fan_enabled = false

	if int(owned.get("proyectil",0))>0 or int(owned.get("lente",0))>0:
		player.projectile_style = "glass"
		player.projectile_size_scale = 1.06
	if int(owned.get("buscadora",0))>0:
		player.projectile_style = "moth"
	if int(owned.get("perforante",0))>0:
		player.projectile_style = "needle"
	if bool(synergies.get("ojo_hueco",false)):
		player.projectile_style = "void"
		player.homing_strength = maxf(player.homing_strength,6.2)
		player.projectile_pierce = maxi(player.projectile_pierce,2)
		player.projectile_size_scale = 1.10

	if bool(synergies.get("tormenta_de_lagrimas",false)):
		player.volley_count = maxi(player.volley_count,3)
		player.volley_spread = 0.13
	elif int(owned.get("doble",0))>0:
		player.volley_count = maxi(player.volley_count,2)
		player.volley_spread = maxf(player.volley_spread,0.18)

	if bool(synergies.get("hemorragia_de_vidrio",false)):
		player.projectile_split_count = maxi(player.projectile_split_count,3)
		player.projectile_split_spread = maxf(player.projectile_split_spread,0.34)
		player.projectile_style = "glass"
		player.projectile_size_scale = maxf(player.projectile_size_scale,1.12)
	if bool(synergies.get("enjambre_de_polilla",false)):
		player.projectile_split_count = maxi(player.projectile_split_count,2)
		player.projectile_split_spread = maxf(player.projectile_split_spread,0.46)
		player.projectile_split_homing = true
		player.projectile_style = "moth"
	if bool(synergies.get("gemelo_nervioso",false)):
		player.burst_fan_enabled = true
		player.volley_count = maxi(player.volley_count,2)

	if int(owned.get("dano",0))+int(owned.get("lente",0))>=2:
		player.projectile_size_scale = maxf(player.projectile_size_scale,1.16)

	player.sync_domain_state_from_runtime()

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

func get_build_snapshot() -> Dictionary:
	return _build_state.snapshot()

func has_active_synergy(synergy_id: String) -> bool:
	return _build_state.has_synergy(synergy_id)

func get_active_synergy_names() -> Array[String]:
	var names: Array[String] = []
	var snapshot := _build_state.snapshot()
	var active: Dictionary = snapshot.get("active_synergies",{})
	for synergy_id in active.keys():
		if bool(active[synergy_id]):
			names.append(ItemCatalog.synergy_title(String(synergy_id)))
	names.sort()
	return names

func get_build_summary() -> String:
	var snapshot := _build_state.snapshot()
	var tags: Dictionary = snapshot.get("tag_counts",{})
	if tags.is_empty():
		return "SIN BUILD"
	var ranked: Array = []
	for tag in tags.keys():
		ranked.append([String(tag),int(tags[tag])])
	ranked.sort_custom(func(a,b): return int(a[1])>int(b[1]))
	var labels := {
		"ofensiva":"OFENSIVA","proyectil":"LÁGRIMAS","cadencia":"CADENCIA",
		"multitiro":"MULTITIRO","precision":"PRECISIÓN","penetracion":"PERFORA",
		"supervivencia":"AGUANTE","defensa":"DEFENSA","movilidad":"MOVILIDAD",
		"economia":"FORTUNA","exploracion":"EXPLORA","explosivos":"BOMBAS"
	}
	var parts: Array[String] = []
	for i in range(mini(2,ranked.size())):
		var row = ranked[i]
		parts.append(String(labels.get(String(row[0]),String(row[0]).to_upper())))
	return " + ".join(parts)

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
