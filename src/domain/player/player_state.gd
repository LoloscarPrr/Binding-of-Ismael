extends RefCounted
class_name IsmaelPlayerState

var move_speed := 280.0
var fire_rate := 0.18
var max_health := 6
var health := 6
var projectile_speed := 760.0
var projectile_damage := 1
var homing_strength := 0.0
var projectile_pierce := 0
var burst_count := 1
var room_heal_interval := 0
var floor_shield_enabled := false
var floor_shield_charges := 0
var _rooms_since_heal := 0

func heal(amount: int) -> bool:
	if amount <= 0 or health <= 0:
		return false
	var before := health
	health = mini(max_health,health+amount)
	return health != before

func add_max_health(amount: int) -> bool:
	if amount <= 0:
		return false
	max_health += amount
	health = mini(max_health,health+amount)
	return true

func take_damage(amount: int) -> bool:
	if amount <= 0 or health <= 0:
		return false
	health = maxi(0,health-amount)
	return true

func consume_floor_shield() -> bool:
	if floor_shield_charges <= 0:
		return false
	floor_shield_charges -= 1
	return true

func notify_room_cleared() -> bool:
	if room_heal_interval <= 0 or health <= 0:
		return false
	_rooms_since_heal += 1
	if _rooms_since_heal < room_heal_interval:
		return false
	_rooms_since_heal = 0
	return heal(1)

func refill_floor_shield() -> bool:
	if not floor_shield_enabled:
		return false
	floor_shield_charges = 1
	return true

func reset_health() -> void:
	health = max_health
	_rooms_since_heal = 0

func is_defeated() -> bool:
	return health <= 0
