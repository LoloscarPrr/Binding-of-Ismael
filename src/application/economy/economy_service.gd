extends RefCounted
class_name IsmaelEconomyService

const RunInventory = preload("res://src/domain/run/run_inventory.gd")
const CLEAR_ROOM_COIN_REWARD := 3

var inventory

func _init(inventory_ref = null) -> void:
	inventory = inventory_ref if inventory_ref != null else RunInventory.new()

func collect_pickup(kind: String, player: Node) -> bool:
	match kind:
		"heart":
			if is_instance_valid(player) and player.has_method("heal"):
				player.call("heal",2)
				return true
		"coin":
			inventory.add_coins(1)
			return true
		"bomb":
			inventory.add_bombs(1)
			return true
		"key":
			inventory.add_keys(1)
			return true
	return false

func grant_room_clear() -> int:
	var amount := CLEAR_ROOM_COIN_REWARD+int(inventory.coin_bonus_per_clear)
	inventory.add_coins(amount)
	return amount

func spend_coins(amount: int) -> bool:
	return inventory.spend_coins(amount)

func spend_keys(amount: int) -> bool:
	return inventory.spend_keys(amount)
