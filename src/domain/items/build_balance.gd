extends RefCounted
class_name IsmaelBuildBalance

# Fase 11.4: las builds de muchos objetos siguen siendo espectaculares,
# pero se amortigua la cadencia cuando generan decenas de lágrimas.
const PRIMARY_PROJECTILE_LIMIT := 140
const TOTAL_PROJECTILE_LIMIT := 160

static func effective_fire_interval(base_rate: float, volley: int, burst: int, splits: int) -> float:
	var emissions := maxi(1,volley)*maxi(1,burst)
	var baseline := base_rate
	if emissions >= 6:
		baseline = maxf(baseline,0.10)
	elif emissions >= 4:
		baseline = maxf(baseline,0.085)
	var pressure := maxi(0,emissions-3)
	var spread_pressure := 1.0+minf(0.37,float(pressure)*0.07)
	if splits > 0 and emissions >= 4:
		spread_pressure += 0.07
	return baseline*spread_pressure

static func available_primary_shots(active_count: int, desired: int) -> int:
	return mini(maxi(0,desired),maxi(0,PRIMARY_PROJECTILE_LIMIT-active_count))

static func reward_score(id: String, owned: Dictionary, synergies: Dictionary, catalog) -> float:
	var copies := maxi(0,int(owned.get(id,0)))
	var weight := 5.0/(1.0+float(copies)*2.2)
	if copies == 0:
		weight += 2.0
	# Objetos que pueden completar una sinergia importan más que otra
	# mejora plana, sin regalar sinergias ni prohibir duplicados.
	for key in synergies.keys():
		var definition: Dictionary = synergies[key]
		var required: Array = definition.get("requires_items",[])
		if not required.has(id):
			continue
		var already_owned := 0
		for item in required:
			if int(owned.get(String(item),0)) > 0:
				already_owned += 1
		if copies == 0 and already_owned >= 1 and already_owned == required.size()-1:
			weight += 5.0
		elif copies == 0 and already_owned > 0:
			weight += 1.5
	var tags: Array[String] = catalog.reward_tags(id)
	if tags.has("supervivencia") and copies == 0:
		weight += 0.6
	return maxf(0.18,weight)

static func choose_two(pool: Array[String], owned: Dictionary, synergies: Dictionary, catalog, avoid_id: String, seed_value: int) -> Array[String]:
	var choices: Array[String] = []
	var candidates: Array[String] = []
	for id in pool:
		if not candidates.has(id) and (id != avoid_id or pool.size() < 3):
			candidates.append(id)
	if candidates.size() < 2:
		candidates.clear()
		for id in pool:
			if not candidates.has(id):
				candidates.append(id)
	if candidates.size() < 2:
		return candidates
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value)
	while choices.size() < 2 and not candidates.is_empty():
		var total := 0.0
		var scores: Array[float] = []
		for id in candidates:
			var weight := reward_score(id,owned,synergies,catalog)
			if not choices.is_empty():
				var left: Array[String] = catalog.reward_tags(choices[0])
				var right: Array[String] = catalog.reward_tags(id)
				for tag in right:
					if left.has(tag):
						weight *= 0.68
			scores.append(weight)
			total += weight
		var pick := rng.randf()*total
		var index := candidates.size()-1
		for i in range(candidates.size()):
			pick -= scores[i]
			if pick <= 0.0:
				index = i
				break
		choices.append(candidates[index])
		candidates.remove_at(index)
	return choices
