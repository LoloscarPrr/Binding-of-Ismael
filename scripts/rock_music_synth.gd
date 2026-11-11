extends RefCounted
class_name IsmaelRockMusicSynth

# Motor musical original compartido. Cada cuerda usa una linea de retardo
# de Karplus-Strong, no pulsos de chip: ataque de pua, resonancia y apagado.
# Las pistas se renderizan una sola vez y el director las mantiene en cache.
const SAMPLE_RATE := 22050
const STEPS_PER_BAR := 16
const ROOTS: Array[int] = [40,43,38,41,36]
const BOSS_TEMPOS: Array[int] = [136,141,132,144,139]
const ROOM_TEMPOS: Array[int] = [96,100,94,103,98]
const BOSS_CHORDS: Array[int] = [0,-3,-5,-2,0,-3,-7,-2]
const ROOM_CHORDS: Array[int] = [0,-3,-5,-2]
const CHUG_PATTERN: Array[int] = [1,0,1,0, 1,1,0,1, 1,0,1,1, 0,1,0,0]
const ROOM_RHYTHM: Array[int] = [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0]
const ROOM_PICKING: Array[int] = [0,-1,7,-1, 10,-1,7,-1, 3,-1,5,-1, 7,-1,3,-1]
const BOSS_MELODY: Array[int] = [0,-1,-1,3, 5,-1,3,-1, 7,-1,5,3, 0,-1,-1,-1]

static func _frequency(note: int) -> float:
	return 440.0*pow(2.0,float(note-69)/12.0)

static func _pluck(frequency: float, duration: float, drive: float, palm_mute: bool) -> PackedFloat32Array:
	var delay_length := maxi(8,int(round(float(SAMPLE_RATE)/maxf(frequency,35.0))))
	var delay := PackedFloat32Array()
	delay.resize(delay_length)
	# Excitacion reproducible de cuerda pulsada, con ruido de pua.
	for n in range(delay_length):
		var random_like := sin(float(n*63+delay_length*17)*12.9898)*sin(float(n*19+11)*39.346)
		var pick_position := sin(TAU*float(n)*0.18/float(delay_length))
		delay[n] = random_like*0.85+pick_position*0.18
	var count := maxi(1,int(round(duration*float(SAMPLE_RATE))))
	var out := PackedFloat32Array()
	out.resize(count)
	var cursor := 0
	var lowpass := 0.0
	var loop_damping := 0.972 if palm_mute else 0.994
	var envelope_speed := 8.5 if palm_mute else 1.75
	for i in range(count):
		var next_cursor := (cursor+1)%delay_length
		var source: float = delay[cursor]
		delay[cursor] = (source+delay[next_cursor])*0.5*loop_damping
		cursor = next_cursor
		# La salida del amplificador redondea los picos; el
		# filtro suprime el ruido agudo antes de aplicar drive.
		lowpass += (source-lowpass)*(0.32 if drive>1.0 else 0.46)
		var analogue := lowpass*drive
		var overdrive := analogue/(1.0+absf(analogue))
		var dry := lowpass*0.26+overdrive*0.74
		var time := float(i)/float(SAMPLE_RATE)
		var attack := minf(1.0,time*170.0)
		var release := clampf((duration-time)/0.035,0.0,1.0)
		out[i] = dry*attack*exp(-time*envelope_speed)*release
	return out

static func _bass(frequency: float, duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := maxi(1,int(round(duration*float(SAMPLE_RATE))))
	out.resize(count)
	var phase := 0.0
	for i in range(count):
		var time := float(i)/float(SAMPLE_RATE)
		phase += TAU*frequency/float(SAMPLE_RATE)
		var attack := minf(1.0,time*180.0)
		var envelope := exp(-time*2.4)*attack
		out[i] = (sin(phase)*0.72+sin(phase*2.01)*0.22+sin(phase*3.015)*0.06)*envelope
	return out

static func _kick() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.20*float(SAMPLE_RATE)))
	var phase := 0.0
	for i in range(out.size()):
		var time := float(i)/float(SAMPLE_RATE)
		var freq := 55.0+95.0*exp(-time*38.0)
		phase += TAU*freq/float(SAMPLE_RATE)
		out[i] = sin(phase)*exp(-time*24.0)
	return out

static func _snare() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.16*float(SAMPLE_RATE)))
	for i in range(out.size()):
		var t := float(i)/float(SAMPLE_RATE)
		var noisy := sin(float(i)*21.43)*sin(float(i)*7.91)
		out[i] = (noisy*0.83+sin(TAU*185.0*t)*0.17)*exp(-t*25.0)
	return out

static func _hat() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.065*float(SAMPLE_RATE)))
	for i in range(out.size()):
		var t := float(i)/float(SAMPLE_RATE)
		var metal := sin(float(i)*38.3)*sin(float(i)*17.4)
		out[i] = metal*exp(-t*90.0)
	return out

static func _add(mix: PackedFloat32Array, wave: PackedFloat32Array, at: int, gain: float) -> void:
	if gain <= 0.0:
		return
	for i in range(mini(wave.size(),mix.size()-at)):
		mix[at+i] += wave[i]*gain

static func _note(cache: Dictionary, midi: int, length: float, drive: float, muted: bool) -> PackedFloat32Array:
	var key := "%d:%d:%d:%d" % [midi,int(round(length*100.0)),int(round(drive*10.0)),1 if muted else 0]
	if not cache.has(key):
		cache[key] = _pluck(_frequency(midi),length,drive,muted)
	var wave: PackedFloat32Array = cache[key]
	return wave

static func _bass_note(cache: Dictionary, midi: int, length: float) -> PackedFloat32Array:
	var key := "%d:%d" % [midi,int(round(length*100.0))]
	if not cache.has(key):
		cache[key] = _bass(_frequency(midi),length)
	var wave: PackedFloat32Array = cache[key]
	return wave

static func _finalize(mix: PackedFloat32Array, floor_number: int, combat: bool) -> AudioStreamWAV:
	var count := mix.size()
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	# Un limite suave conserva el ataque de guitarra sin tapar disparos.
	var gain := 0.67 if combat else 0.56
	var duration := float(count)/float(SAMPLE_RATE)
	var root_hz := _frequency(ROOTS[floor_number-1]-12)
	for i in range(count):
		var t := float(i)/float(SAMPLE_RATE)
		var level: float = mix[i]
		if not combat:
			# Capa de cueva tenue: sigue siendo rock, no se recuperan
			# los goteos, drones estridentes ni efectos de 8 bits.
			level += sin(TAU*root_hz*t)*0.060
			level += sin(TAU*root_hz*1.499*t)*0.032
		var softened := level/(1.0+absf(level)*0.65)
		var fade := clampf(minf(t,duration-t)/0.048,0.0,1.0)
		var sample := int(round(clampf(softened*gain*fade,-0.93,0.93)*32767.0))
		if sample < 0:
			sample += 65536
		bytes[i*2] = sample & 255
		bytes[i*2+1] = (sample>>8)&255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream

static func compose(floor_number: int, combat: bool) -> AudioStreamWAV:
	var floor_id := clampi(floor_number,1,5)
	var bpm: int = BOSS_TEMPOS[floor_id-1] if combat else ROOM_TEMPOS[floor_id-1]
	var steps := 128 if combat else 64
	var samples_per_step := maxi(64,int(round(float(SAMPLE_RATE)*60.0/float(bpm)/4.0)))
	var mix := PackedFloat32Array()
	mix.resize(steps*samples_per_step)
	var seconds_step := float(samples_per_step)/float(SAMPLE_RATE)
	var guitar_cache: Dictionary = {}
	var bass_cache: Dictionary = {}
	var kick := _kick()
	var snare := _snare()
	var hat := _hat()
	for step in range(steps):
		var at := step*samples_per_step
		var bar := int(step/STEPS_PER_BAR)
		var beat := step%STEPS_PER_BAR
		var root_note: int = ROOTS[floor_id-1]
		root_note += BOSS_CHORDS[bar] if combat else ROOM_CHORDS[bar]
		# Bajo con pulso ritmico claro; acompana los riffs, no es
		# una nota continua ni una pista vieja reproducida debajo.
		if beat%4 == 0 or (combat and beat in [7,11,14]):
			var bass_length := seconds_step*(2.3 if combat else 3.2)
			_add(mix,_bass_note(bass_cache,root_note-12,bass_length),at,0.27 if combat else 0.21)
		if combat:
			# Guitarra central: power-chords entrecortados y silencios.
			if CHUG_PATTERN[beat] == 1:
				var downstroke := beat%4 == 0
				var chug_length := seconds_step*(2.2 if downstroke else 1.2)
				var base_gain := 0.51 if downstroke else 0.37
				_add(mix,_note(guitar_cache,root_note+12,chug_length,2.7,not downstroke),at,base_gain)
				_add(mix,_note(guitar_cache,root_note+19,chug_length,2.4,not downstroke),at,base_gain*0.47)
			# La guitarra secundaria es mas grave y responde en los
			# huecos del riff principal. Es una voz independiente.
			if beat in [3,6,10,14]:
				_add(mix,_note(guitar_cache,root_note+5,seconds_step*1.9,2.3,true),at,0.34)
				_add(mix,_note(guitar_cache,root_note+12,seconds_step*1.6,1.9,true),at,0.13)
			# Frase reconocible en cada segundo compas: contraste
			# entre riff pesado y melodia corta, sin solos chillones.
			if bar%2 == 1 and BOSS_MELODY[beat] >= 0 and beat%2 == 0:
				var melodic_note := root_note+24+BOSS_MELODY[beat]
				_add(mix,_note(guitar_cache,melodic_note,seconds_step*3.7,1.35,false),at,0.24)
		else:
			# Rock atmosferico, contenido: guitarra punteada adelante,
			# acordes distorsionados suaves detras, bajo y medio tiempo.
			if ROOM_PICKING[beat] >= 0:
				var picked_note := root_note+19+ROOM_PICKING[beat]
				_add(mix,_note(guitar_cache,picked_note,seconds_step*3.5,0.55,false),at,0.39)
			if ROOM_RHYTHM[beat] == 1:
				_add(mix,_note(guitar_cache,root_note+12,seconds_step*3.5,1.3,true),at,0.24)
				_add(mix,_note(guitar_cache,root_note+19,seconds_step*3.3,1.0,true),at,0.11)
			# Nota profunda de respuesta en la segunda mitad del compas.
			if beat == 12:
				_add(mix,_note(guitar_cache,root_note+7,seconds_step*4.0,0.65,false),at,0.22)
		# Percusion nueva: salas discretas; guardianes mas intensos.
		if beat%4 == 0 or (combat and beat in [6,14]):
			_add(mix,kick,at,0.57 if combat else 0.24)
		if beat in [4,12]:
			_add(mix,snare,at,0.44 if combat else 0.16)
		if beat%2 == 0:
			_add(mix,hat,at,0.10 if combat else 0.039)
	return _finalize(mix,floor_id,combat)
