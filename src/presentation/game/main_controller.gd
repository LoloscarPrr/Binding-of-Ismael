extends "res://scripts/main.gd"

const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const EconomyService = preload("res://src/application/economy/economy_service.gd")
const RewardService = preload("res://src/application/rewards/reward_service.gd")

var _clean_inventory = RunInventory.new()
var _economy_service = EconomyService.new(_clean_inventory)
var _reward_service = RewardService.new()

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
