extends RefCounted
class_name IsmaelCleanSfxComposer

# Efectos 8-bit originales, cada interacción con una firma clara.
# Sin WAV de terceros ni capas idénticas reutilizadas en todos los eventos.
const SAMPLE_RATE := 22050

static func duration(kind: String) -> float:
	match kind:
		"shoot": return 0.085
		"enemy_shot": return 0.115
		"enemy_hit": return 0.085
		"hit": return 0.16
		"bomb": return 0.63
		"door": return 0.28
		"room_transition": return 0.39
		"chest": return 0.46
		"chest_locked": return 0.58
		"pickup": return 0.15
		"room_clear": return 0.40
		"boss_phase": return 0.68
		"boss_death": return 0.91
		"floor": return 0.84
		_: return 0.16

static func voice_priority(kind: String) -> int:
	match kind:
		"boss_death","boss_phase","floor","chest","chest_locked": return 3
		"bomb","hit","room_transition","door","room_clear": return 2
		"pickup","enemy_hit","enemy_shot": return 1
		_: return 0

static func _noise(index: int) -> float:
	# Ruido determinista bipolar, sin procesos aleatorios por frame.
	var value := sin(float(index)*12.9898+float(index%29)*78.233)
	return value*0.72+sin(float(index)*37.71)*0.28

static func _envelope(time: float,duration_seconds: float,attack_seconds: float,release_power: float) -> float:
	var attack := clampf(time/maxf(0.001,attack_seconds),0.0,1.0)
	var release := pow(clampf(1.0-time/duration_seconds,0.0,1.0),release_power)
	return attack*release

static func _square(phase: float,duty: float = 0.25) -> float:
	return 1.0 if fposmod(phase/TAU,1.0)<duty else -1.0

static func _triangle(phase: float) -> float:
	return 1.0-4.0*absf(fposmod(phase/TAU,1.0)-0.5)

static func _chime(time: float,start: float,freq: float,length: float) -> float:
	var dt := time-start
	if dt < 0.0 or dt > length:
		return 0.0
	var env := minf(1.0,dt*90.0)*pow(1.0-dt/length,1.6)
	return (sin(TAU*freq*dt)*0.80+sin(TAU*freq*2.008*dt)*0.20)*env

static func create(kind: String,intensity: float = 1.0) -> AudioStreamWAV:
	var total_time := duration(kind)
	var samples := maxi(64,int(ceil(total_time*float(SAMPLE_RATE))))
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	var phase := 0.0
	var previous_noise := 0.0
	var amp := clampf(0.66+0.17*intensity,0.54,0.98)
	for i in range(samples):
		var time := float(i)/float(SAMPLE_RATE)
		var progress := clampf(time/total_time,0.0,1.0)
		var n := _noise(i)
		var hiss := (n-previous_noise)*0.45
		previous_noise = n
		var envelope := _envelope(time,total_time,0.003,2.0)
		var tone := 0.0
		match kind:
			"shoot":
				# Preciso y suave: lágrima aguda breve sin cola molesta.
				var hz := lerpf(620.0,350.0,pow(progress,0.65))
				phase += TAU*hz/float(SAMPLE_RATE)
				tone = _triangle(phase)*0.76+hiss*0.10
				envelope = _envelope(time,total_time,0.002,3.9)
			"enemy_shot":
				var hz := lerpf(230.0,490.0,progress)
				phase += TAU*hz/float(SAMPLE_RATE)
				tone = _square(phase,0.32)*0.44+_triangle(phase)*0.25+hiss*0.12
				envelope = _envelope(time,total_time,0.003,2.7)
			"enemy_hit":
				phase += TAU*lerpf(390.0,120.0,progress)/float(SAMPLE_RATE)
				tone = _triangle(phase)*0.56+hiss*0.27
				envelope = _envelope(time,total_time,0.001,4.4)
			"hit":
				phase += TAU*lerpf(205.0,75.0,progress)/float(SAMPLE_RATE)
				tone = _triangle(phase)*0.48+hiss*0.35
				envelope = _envelope(time,total_time,0.002,3.0)
			"bomb":
				# Ataque explosivo y retumbo, sin clipping ni ruido continuo.
				var hz := 145.0*exp(-progress*2.25)+35.0
				phase += TAU*hz/float(SAMPLE_RATE)
				var impact := exp(-time*36.0)*hiss*0.65
				var rubble := (n*0.28+hiss*0.12)*exp(-time*6.8)
				tone = _triangle(phase)*0.69*exp(-progress*1.6)+impact+rubble
				envelope = _envelope(time,total_time,0.002,1.5)
			"door":
				# Cerrojo + madera moviéndose, más corto que cambio de sala.
				phase += TAU*lerpf(185.0,84.0,progress)/float(SAMPLE_RATE)
				var latch := exp(-time*68.0)*hiss*0.53
				tone = _triangle(phase)*0.42+n*0.11+latch
				envelope = _envelope(time,total_time,0.001,1.8)
			"room_transition":
				# Desplazamiento de aire, golpe lejano y caída sutil.
				phase += TAU*lerpf(250.0,82.0,progress)/float(SAMPLE_RATE)
				var sweep := sin(progress*PI)*hiss*0.31
				tone = _triangle(phase)*0.36+sweep+exp(-time*23.0)*n*0.12
				envelope = _envelope(time,total_time,0.009,1.4)
			"chest","chest_locked":
				# Chasquido del cierre seguido por 3 campanas afinadas.
				var sparkle := _chime(time,0.045,523.25,0.26)*0.38
				sparkle += _chime(time,0.135,659.25,0.29)*0.37
				sparkle += _chime(time,0.238,783.99,0.29)*0.33
				var latch := exp(-time*76.0)*hiss*0.36
				var metal := 0.0
				if kind == "chest_locked":
					metal = _chime(time,0.0,311.13,0.20)*0.19
				tone = sparkle+latch+metal
				envelope = _envelope(time,total_time,0.001,0.5)
			"pickup":
				tone = _chime(time,0.0,587.33,0.15)*0.65+_chime(time,0.054,783.99,0.095)*0.27
				envelope = _envelope(time,total_time,0.001,0.55)
			"room_clear":
				tone = _chime(time,0.015,392.0,0.31)*0.46+_chime(time,0.16,523.25,0.24)*0.50
				envelope = _envelope(time,total_time,0.001,0.6)
			"boss_phase":
				phase += TAU*lerpf(92.0,260.0,progress)/float(SAMPLE_RATE)
				var ominous := sin(TAU*3.0*time)*0.11
				tone = _triangle(phase)*0.40+sin(phase*1.5)*0.22+hiss*0.075+ominous
				envelope = _envelope(time,total_time,0.012,1.3)
			"boss_death":
				phase += TAU*lerpf(145.0,32.0,progress)/float(SAMPLE_RATE)
				tone = _triangle(phase)*0.50+sin(phase*0.5)*0.23+n*0.12
				envelope = _envelope(time,total_time,0.005,1.65)
			"floor":
				phase += TAU*lerpf(64.0,235.0,progress)/float(SAMPLE_RATE)
				tone = _triangle(phase)*0.40+sin(phase*0.5)*0.15+n*0.065
				envelope = _envelope(time,total_time,0.04,1.6)
			_:
				phase += TAU*lerpf(305.0,180.0,progress)/float(SAMPLE_RATE)
				tone = _triangle(phase)*0.52
		var fade_in := minf(1.0,time*550.0)
		var pcm := int(round(clampf(tone*envelope*amp*fade_in,-0.94,0.94)*32767.0))
		if pcm < 0:
			pcm += 65536
		bytes[i*2] = pcm&255
		bytes[i*2+1] = (pcm>>8)&255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
