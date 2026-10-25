extends RefCounted
class_name IsmaelRunProgress

const SAVE_PATH := "user://run_progress.cfg"

var max_floor_reached := 1
var runs_completed := 0
var runs_failed := 0
var best_clear_seconds := 0
var most_enemies_defeated := 0
var most_rooms_cleared := 0
var recent_runs: Array[Dictionary] = []
var pacts_sealed := 0
var events_resolved := 0
var echo_challenges_completed := 0
var endings: Dictionary = {}
var unlocks: Dictionary = {}

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_refresh_unlocks()
		return
	max_floor_reached = maxi(1,int(cfg.get_value("progress","max_floor_reached",1)))
	runs_completed = maxi(0,int(cfg.get_value("progress","runs_completed",0)))
	runs_failed = maxi(0,int(cfg.get_value("progress","runs_failed",0)))
	best_clear_seconds = maxi(0,int(cfg.get_value("progress","best_clear_seconds",0)))
	most_enemies_defeated = maxi(0,int(cfg.get_value("progress","most_enemies_defeated",0)))
	most_rooms_cleared = maxi(0,int(cfg.get_value("progress","most_rooms_cleared",0)))
	recent_runs.clear()
	var saved_runs = cfg.get_value("progress","recent_runs",[])
	if saved_runs is Array:
		for entry in saved_runs:
			if entry is Dictionary:
				recent_runs.append(entry.duplicate(true))
	while recent_runs.size() > 8:
		recent_runs.remove_at(0)
	pacts_sealed = maxi(0,int(cfg.get_value("progress","pacts_sealed",0)))
	events_resolved = maxi(0,int(cfg.get_value("progress","events_resolved",0)))
	echo_challenges_completed = maxi(0,int(cfg.get_value("progress","echo_challenges_completed",0)))
	var saved_endings = cfg.get_value("progress","endings",{})
	if saved_endings is Dictionary:
		endings = saved_endings.duplicate(true)
	_refresh_unlocks()

func save_profile() -> void:
	_refresh_unlocks()
	var cfg := ConfigFile.new()
	cfg.set_value("progress","max_floor_reached",max_floor_reached)
	cfg.set_value("progress","runs_completed",runs_completed)
	cfg.set_value("progress","runs_failed",runs_failed)
	cfg.set_value("progress","best_clear_seconds",best_clear_seconds)
	cfg.set_value("progress","most_enemies_defeated",most_enemies_defeated)
	cfg.set_value("progress","most_rooms_cleared",most_rooms_cleared)
	cfg.set_value("progress","recent_runs",recent_runs)
	cfg.set_value("progress","pacts_sealed",pacts_sealed)
	cfg.set_value("progress","events_resolved",events_resolved)
	cfg.set_value("progress","echo_challenges_completed",echo_challenges_completed)
	cfg.set_value("progress","endings",endings)
	cfg.set_value("progress","unlocks",unlocks)
	cfg.save(SAVE_PATH)

func record_floor(floor_index: int) -> bool:
	var before := max_floor_reached
	max_floor_reached = maxi(max_floor_reached,floor_index)
	if max_floor_reached != before:
		save_profile()
		return true
	return false

func record_pact() -> void:
	pacts_sealed += 1
	save_profile()

func record_event() -> void:
	events_resolved += 1
	save_profile()

func record_echo_challenge() -> void:
	echo_challenges_completed += 1
	save_profile()

func record_completion(ending_id: String, stats: Dictionary = {}) -> Dictionary:
	runs_completed += 1
	endings[ending_id] = int(endings.get(ending_id,0))+1
	var records := _record_run("VICTORIA",ending_id,stats)
	save_profile()
	return records

func record_defeat(stats: Dictionary = {}) -> Dictionary:
	runs_failed += 1
	var records := _record_run("DERROTA","",stats)
	save_profile()
	return records

func _record_run(outcome: String,ending_id: String,stats: Dictionary) -> Dictionary:
	var seconds := maxi(0,int(stats.get("seconds",0)))
	var kills := maxi(0,int(stats.get("kills",0)))
	var rooms := maxi(0,int(stats.get("rooms",0)))
	var new_time := outcome == "VICTORIA" and seconds > 0 and (best_clear_seconds == 0 or seconds < best_clear_seconds)
	var new_kills := kills > most_enemies_defeated
	var new_rooms := rooms > most_rooms_cleared
	if new_time:
		best_clear_seconds = seconds
	most_enemies_defeated = maxi(most_enemies_defeated,kills)
	most_rooms_cleared = maxi(most_rooms_cleared,rooms)
	recent_runs.append({
		"result":outcome,
		"ending":ending_id,
		"floor":maxi(1,int(stats.get("floor",1))),
		"seconds":seconds,
		"kills":kills,
		"rooms":rooms,
		"items":maxi(0,int(stats.get("items",0)))
	})
	while recent_runs.size() > 8:
		recent_runs.remove_at(0)
	return {"best_time":new_time,"best_kills":new_kills,"best_rooms":new_rooms}

func records_text() -> String:
	var time_text := "--:--"
	if best_clear_seconds > 0:
		time_text = "%02d:%02d" % [int(best_clear_seconds / 60),best_clear_seconds % 60]
	return "MEJOR TIEMPO %s · MÁX. BAJAS %d · SALAS %d · VICTORIAS %d · DERROTAS %d" % [
		time_text,most_enemies_defeated,most_rooms_cleared,runs_completed,runs_failed
	]

func has_unlock(id: String) -> bool:
	_refresh_unlocks()
	return bool(unlocks.get(id,false))

func _refresh_unlocks() -> void:
	unlocks["reliquias_archivo"] = max_floor_reached >= 3
	unlocks["eventos_profundos"] = events_resolved >= 3 or runs_completed >= 1
	unlocks["pacto_profundo"] = pacts_sealed >= 4 or runs_completed >= 2
	unlocks["marca_del_hueco"] = endings.size() >= 2 or runs_completed >= 3
	unlocks["santuario_eco"] = runs_completed >= 1
	unlocks["eco_fragil"] = max_floor_reached >= 3 or runs_completed >= 1
	unlocks["reloj_ceniza"] = events_resolved >= 2 or runs_completed >= 1
	unlocks["colmillo_ritual"] = pacts_sealed >= 3 or runs_completed >= 2
	unlocks["corona_del_eco"] = echo_challenges_completed >= 3

func summary_text() -> String:
	return "MÁX P%d · RUNS %d · PACTOS %d · EVENTOS %d · ECOS %d · FINALES %d/3" % [
		max_floor_reached,runs_completed,pacts_sealed,events_resolved,echo_challenges_completed,endings.size()
	]
