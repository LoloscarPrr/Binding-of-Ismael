extends RefCounted
class_name IsmaelRunProgress

const SAVE_PATH := "user://run_progress.cfg"

var max_floor_reached := 1
var runs_completed := 0
var pacts_sealed := 0
var events_resolved := 0
var endings: Dictionary = {}
var unlocks: Dictionary = {}

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_refresh_unlocks()
		return
	max_floor_reached = maxi(1,int(cfg.get_value("progress","max_floor_reached",1)))
	runs_completed = maxi(0,int(cfg.get_value("progress","runs_completed",0)))
	pacts_sealed = maxi(0,int(cfg.get_value("progress","pacts_sealed",0)))
	events_resolved = maxi(0,int(cfg.get_value("progress","events_resolved",0)))
	var saved_endings = cfg.get_value("progress","endings",{})
	if saved_endings is Dictionary:
		endings = saved_endings.duplicate(true)
	_refresh_unlocks()

func save_profile() -> void:
	_refresh_unlocks()
	var cfg := ConfigFile.new()
	cfg.set_value("progress","max_floor_reached",max_floor_reached)
	cfg.set_value("progress","runs_completed",runs_completed)
	cfg.set_value("progress","pacts_sealed",pacts_sealed)
	cfg.set_value("progress","events_resolved",events_resolved)
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

func record_completion(ending_id: String) -> void:
	runs_completed += 1
	endings[ending_id] = int(endings.get(ending_id,0))+1
	save_profile()

func has_unlock(id: String) -> bool:
	_refresh_unlocks()
	return bool(unlocks.get(id,false))

func _refresh_unlocks() -> void:
	unlocks["reliquias_archivo"] = max_floor_reached >= 3
	unlocks["eventos_profundos"] = events_resolved >= 3 or runs_completed >= 1
	unlocks["pacto_profundo"] = pacts_sealed >= 4 or runs_completed >= 2
	unlocks["marca_del_hueco"] = endings.size() >= 2 or runs_completed >= 3

func summary_text() -> String:
	return "MÁX P%d · RUNS %d · PACTOS %d · EVENTOS %d · FINALES %d/3" % [
		max_floor_reached,runs_completed,pacts_sealed,events_resolved,endings.size()
	]
