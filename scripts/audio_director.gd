extends Node
class_name IsmaelAudioDirector

const MIX_RATE := 22050
const ChiptuneComposer = preload("res://scripts/chiptune_composer.gd")
const BossMusic = preload("res://scripts/boss_music_composer.gd")
const CleanSfx = preload("res://scripts/clean_sfx_composer.gd")
const SewerAmbience = preload("res://scripts/sewer_ambience_composer.gd")
const AUDIO_SETTINGS_PATH := "user://audio_settings.cfg"

var _ambience := AudioStreamPlayer.new()
var ambience_level := 0.65
var sfx_level := 0.85
var _floor_index := 1
var _boss_music := false
var _music_cache: Dictionary = {}
# La sintesis del rock de cuerdas pulsadas es muy costosa en Android:
# nunca renderizar una pista de audio en el hilo de jugabilidad.
var _music_queue: Array[Dictionary] = []
var _music_worker: Thread = null
var _music_busy_key := ""
var _requested_music_key := ""
var _last_sfx_ms: Dictionary = {}
var _stream_cache: Dictionary = {}
var _active_sfx: Array[AudioStreamPlayer] = []
const MAX_SFX_VOICES := 10

func _ready() -> void:
	add_to_group("audio_director")
	_load_audio_levels()
	_apply_ambience_volume()
	add_child(_ambience)
	set_floor(1)

func _load_audio_levels() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(AUDIO_SETTINGS_PATH) == OK:
		ambience_level = clampf(float(cfg.get_value("audio","ambience",0.65)),0.0,1.0)
		sfx_level = clampf(float(cfg.get_value("audio","effects",0.85)),0.0,1.0)

func set_audio_levels(ambience_value: float, effects_value: float) -> void:
	ambience_level = clampf(ambience_value,0.0,1.0)
	sfx_level = clampf(effects_value,0.0,1.0)
	_apply_ambience_volume()
	var cfg := ConfigFile.new()
	cfg.set_value("audio","ambience",ambience_level)
	cfg.set_value("audio","effects",sfx_level)
	cfg.save(AUDIO_SETTINGS_PATH)

func _apply_ambience_volume() -> void:
	# Antes el ambiente estaba a -30 dB y apenas se oía.
	# El nuevo arreglo tiene rango dinámico propio y volumen audible.
	_ambience.volume_db = -80.0 if ambience_level <= 0.0 else -7.0 + linear_to_db(ambience_level)

func _track_key(floor_number: int, boss: bool) -> String:
	return "%d:%s" % [clampi(floor_number,1,5),"jefe" if boss else "piso"]

func set_floor(floor_index: int, room_kind: String = "inicio") -> void:
	var resolved := clampi(floor_index,1,5)
	var boss_now := room_kind in ["jefe","minijefe"]
	var requested := _track_key(resolved,boss_now)
	if requested == _requested_music_key and _ambience.playing:
		return
	_floor_index = resolved
	_boss_music = boss_now
	_requested_music_key = requested
	# No reproducir audio del jefe anterior mientras se prepara el nuevo.
	if _music_cache.has(requested):
		_play_cached_track(requested)
	else:
		_ambience.stop()
		_queue_music(resolved,boss_now,true)

func music_ready_for(floor_index: int, room_kind: String = "inicio") -> bool:
	return _music_cache.has(_track_key(floor_index,room_kind in ["jefe","minijefe"]))

func warm_floor(floor_index: int) -> void:
	# Precargar exploracion y jefe del piso en segundo plano, una vez.
	if floor_index < 1 or floor_index > 5:
		return
	_queue_music(floor_index,false,false)
	_queue_music(floor_index,true,false)

func _queue_music(floor_number: int, boss: bool, priority: bool) -> void:
	var key := _track_key(floor_number,boss)
	if _music_cache.has(key) or _music_busy_key == key:
		return
	for i in range(_music_queue.size()):
		if String(_music_queue[i]["key"]) == key:
			if priority and i > 0:
				var queued: Dictionary = _music_queue[i]
				_music_queue.remove_at(i)
				_music_queue.push_front(queued)
			return
	var entry: Dictionary = {"key":key,"floor":floor_number,"boss":boss}
	if priority:
		_music_queue.push_front(entry)
	else:
		_music_queue.append(entry)
	_start_next_music()

func _start_next_music() -> void:
	if not _music_busy_key.is_empty() or _music_queue.is_empty():
		return
	var entry: Dictionary = _music_queue.pop_front()
	_music_busy_key = String(entry["key"])
	_music_worker = Thread.new()
	var error := _music_worker.start(
		Callable(self,"_render_music_worker").bind(int(entry["floor"]),bool(entry["boss"]),_music_busy_key)
	)
	if error != OK:
		# Ultimo recurso ante un dispositivo sin hilos: la pantalla
		# de carga permanece hasta terminar, nunca se cuelga el juego.
		printerr("Music thread unavailable: ",error)
		_music_worker = null
		var stream: AudioStreamWAV = BossMusic.compose(int(entry["floor"])) if bool(entry["boss"]) else SewerAmbience.compose(int(entry["floor"]))
		call_deferred("_complete_music_worker",_music_busy_key,stream)

func _render_music_worker(floor_number: int, boss: bool, key: String) -> void:
	# Ninguna llamada al SceneTree ni a nodos desde este hilo.
	var stream: AudioStreamWAV = BossMusic.compose(floor_number) if boss else SewerAmbience.compose(floor_number)
	call_deferred("_complete_music_worker",key,stream)

func _complete_music_worker(key: String, stream: AudioStreamWAV) -> void:
	if _music_worker != null:
		_music_worker.wait_to_finish()
		_music_worker = null
	_music_cache[key] = stream
	_music_busy_key = ""
	if key == _requested_music_key:
		_play_cached_track(key)
	_start_next_music()

func _play_cached_track(key: String) -> void:
	if not _music_cache.has(key):
		return
	var track: AudioStreamWAV = _music_cache[key]
	if _ambience.playing and _ambience.stream == track:
		return
	_ambience.stop()
	_ambience.stream = track
	_ambience.play()

func _exit_tree() -> void:
	if _music_worker != null and _music_worker.is_started():
		_music_worker.wait_to_finish()
		_music_worker = null

# Deja la musica de combate al terminar un jefe o minijefe.
# Conserva los SFX de victoria y la atmosfera normal del piso.
func finish_boss_fight() -> void:
	if _boss_music:
		set_floor(_floor_index,"combate")

func play_sfx(kind: String, intensity: float = 1.0) -> void:
	if sfx_level <= 0.0:
		return
	var cooldown_ms := _cooldown_for(kind)
	var now := Time.get_ticks_msec()
	var previous := int(_last_sfx_ms.get(kind,-100000))
	if now-previous < cooldown_ms:
		return
	_last_sfx_ms[kind] = now
	var cache_key := "%s:%d" % [kind,clampi(int(round(intensity*2.0)),1,6)]
	var stream: AudioStreamWAV
	if _stream_cache.has(cache_key):
		stream = _stream_cache[cache_key]
	else:
		stream = _make_sfx_stream(kind,intensity)
		_stream_cache[cache_key] = stream
	# Priorizar señales críticas frente a docenas de disparos
	# simultáneos: mezcla estable en móviles Android modestos.
	var priority: int = CleanSfx.voice_priority(kind)
	if _active_sfx.size() >= MAX_SFX_VOICES:
		var weakest: AudioStreamPlayer = null
		for voice in _active_sfx:
			if not is_instance_valid(voice):
				continue
			if weakest == null or int(voice.get_meta("sfx_priority",0)) < int(weakest.get_meta("sfx_priority",0)):
				weakest = voice
		if weakest == null or priority <= int(weakest.get_meta("sfx_priority",0)):
			return
		_active_sfx.erase(weakest)
		weakest.stop()
		weakest.queue_free()
	var player := AudioStreamPlayer.new()
	player.set_meta("sfx_priority",priority)
	player.stream = stream
	player.volume_db = _volume_for(kind) + linear_to_db(maxf(0.001,sfx_level))
	add_child(player)
	_active_sfx.append(player)
	player.finished.connect(func() -> void:
		_active_sfx.erase(player)
		player.queue_free()
	)
	player.play()

func _cooldown_for(kind: String) -> int:
	match kind:
		"shoot": return 70
		"enemy_shot": return 95
		"enemy_hit": return 100
		"hit": return 135
		"pickup": return 95
		"room_transition": return 180
		"door": return 140
		"chest","chest_locked": return 250
		"bomb": return 190
		"boss_phase","boss_death": return 250
		_: return 70

func _volume_for(kind: String) -> float:
	match kind:
		"shoot": return -15.0
		"enemy_shot": return -16.5
		"enemy_hit": return -15.0
		"hit": return -12.0
		"pickup": return -11.0
		"chest","chest_locked": return -9.0
		"door": return -10.5
		"room_transition": return -10.0
		"bomb": return -7.5
		"boss_phase": return -7.0
		"boss_death": return -6.0
		"room_clear": return -10.0
		"floor": return -7.5
		_: return -13.0

func _make_sfx_stream(kind: String, intensity: float) -> AudioStreamWAV:
	return CleanSfx.create(kind,intensity)

# Legacy entry point remains for compatibility with prior saves/tests.
func _make_ambience_stream(floor_index: int) -> AudioStreamWAV:
	return SewerAmbience.compose(floor_index)

func _build_stream(
	duration: float,
	start_hz: float,
	end_hz: float,
	noise_amount: float,
	pulse_hz: float,
	amplitude: float,
	looped: bool
) -> AudioStreamWAV:
	var count := maxi(1,int(duration*float(MIX_RATE)))
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var phase := 0.0
	for i in range(count):
		var t := float(i)/float(maxi(1,count-1))
		var hz := lerpf(start_hz,end_hz,t)
		phase += TAU*hz/float(MIX_RATE)
		var envelope := pow(1.0-t,2.1)
		var transient := exp(-t*24.0)
		var pseudo_noise := sin(float(i)*12.9898+float(i%17)*78.233)
		# Pulso + triángulo: ataque definido de consola retro.
		var pulse := 1.0 if sin(phase) > 0.15 else -1.0
		var triangle := (2.0/PI)*asin(sin(phase*0.5))
		var wave := pulse*0.52+triangle*0.28
		wave += pseudo_noise*noise_amount*(0.28+0.72*transient)
		if pulse_hz>0.0:
			wave *= 0.68+0.32*sin(TAU*pulse_hz*(float(i)/float(MIX_RATE)))
		_write_sample(bytes,i,wave*envelope*amplitude)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream

func _write_sample(bytes: PackedByteArray, index: int, value: float) -> void:
	var sample := int(round(clampf(value,-1.0,1.0)*32767.0))
	if sample < 0:
		sample += 65536
	bytes[index*2] = sample & 255
	bytes[index*2+1] = (sample >> 8) & 255
