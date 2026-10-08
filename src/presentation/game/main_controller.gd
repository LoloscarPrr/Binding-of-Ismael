extends "res://scripts/main.gd"

const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const EconomyService = preload("res://src/application/economy/economy_service.gd")
const RewardService = preload("res://src/application/rewards/reward_service.gd")
const BuildState = preload("res://src/domain/items/build_state.gd")

var _clean_inventory = RunInventory.new()
var _economy_service = EconomyService.new(_clean_inventory)
var _reward_service = RewardService.new()
var _build_state = BuildState.new()

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
