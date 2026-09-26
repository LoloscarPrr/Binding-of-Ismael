extends RefCounted
class_name IsmaelRewardService

func apply(reward_id: String, player: Node, inventory) -> Dictionary:
	var result := {"changed":true,"reveal_map":false}
	match reward_id:
		"vida":
			player.call("add_max_health",1)
		"curacion":
			player.set("room_heal_interval",3)
			player.call("heal",1)
		"movimiento":
			player.set("move_speed",float(player.get("move_speed"))+24.0)
		"cadencia":
			player.set("fire_rate",maxf(0.09,float(player.get("fire_rate"))-0.022))
		"proyectil":
			player.set("projectile_speed",float(player.get("projectile_speed"))+120.0)
		"dano":
			player.set("projectile_damage",int(player.get("projectile_damage"))+1)
		"buscadora":
			player.set("homing_strength",maxf(float(player.get("homing_strength")),4.8))
		"perforante":
			player.set("projectile_pierce",maxi(int(player.get("projectile_pierce")),1))
		"escudo":
			player.set("floor_shield_enabled",true)
			player.call("refill_floor_shield")
		"rafaga":
			player.set("burst_count",maxi(int(player.get("burst_count")),3))
		"mapa":
			result["reveal_map"] = true
		"monedero":
			inventory.add_coins(5)
			inventory.coin_bonus_per_clear = maxi(int(inventory.coin_bonus_per_clear),1)
		_:
			result["changed"] = false
	return result
