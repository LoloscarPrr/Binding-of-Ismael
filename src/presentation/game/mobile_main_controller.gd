extends "res://scripts/main_v2.gd"

const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const EconomyService = preload("res://src/application/economy/economy_service.gd")
const RewardService = preload("res://src/application/rewards/reward_service.gd")
const ControlLayoutRepository = preload("res://src/infrastructure/persistence/control_layout_repository.gd")
const ItemAssetView = preload("res://src/presentation/items/item_asset_view.gd")

var _clean_inventory = RunInventory.new()
var _economy_service = EconomyService.new(_clean_inventory)
var _reward_service = RewardService.new()
var _control_layout_repository = ControlLayoutRepository.new()

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
