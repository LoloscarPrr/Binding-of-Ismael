extends RefCounted
class_name IsmaelRunInventory

var coins := 0
var bombs := 0
var keys := 0
var coin_bonus_per_clear := 0

func add_coins(amount: int) -> void:
	coins = maxi(0,coins+amount)

func add_bombs(amount: int) -> void:
	bombs = maxi(0,bombs+amount)

func add_keys(amount: int) -> void:
	keys = maxi(0,keys+amount)

func can_spend_coins(amount: int) -> bool:
	return amount >= 0 and coins >= amount

func spend_coins(amount: int) -> bool:
	if not can_spend_coins(amount):
		return false
	coins -= amount
	return true

func can_spend_keys(amount: int) -> bool:
	return amount >= 0 and keys >= amount

func spend_keys(amount: int) -> bool:
	if not can_spend_keys(amount):
		return false
	keys -= amount
	return true

func snapshot() -> Dictionary:
	return {
		"coins":coins,
		"bombs":bombs,
		"keys":keys,
		"coin_bonus_per_clear":coin_bonus_per_clear
	}
