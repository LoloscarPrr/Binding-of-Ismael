extends RefCounted
class_name IsmaelSewerAmbienceComposer

# Paisajes sonoros originales para exploración. No hay melodías de
# otros juegos: bajo subterráneo, melodía misteriosa y resonancias largas.
const SAMPLE_RATE := 22050
const DURATION := 12.0
# Frase original de 12 segundos, notas largas con silencios.
# Mantiene el bajo apreciado por el jugador, sin goteos ni golpes metálicos.
const MYSTERY_DEGREES: Array[int] = [0,3,7,6,3,1,8,7, 0,3,10,7]
const NOTE_LENGTH := 1.0

static func ambience_name(floor_number: int) -> String:
	match clampi(floor_number,1,5):
		1: return "El eco del umbral"
		2: return "Sombras en la fosa"
		3: return "Pasos tras el muro"
		4: return "Voces del sepulcro"
		_: return "Silencio del abismo"

static func mystery_note_frequency(floor_number: int, note_index: int) -> float:
	var base_midi: int = int([53,50,48,46,43][clampi(floor_number,1,5)-1])
	var degree: int = MYSTERY_DEGREES[posmod(note_index,MYSTERY_DEGREES.size())]
	return 440.0*pow(2.0,float(base_midi+degree-69)/12.0)

static func _mystery_tone(elapsed: float,frequency: float) -> float:
	if elapsed < 0.0 or elapsed >= 1.55:
		return 0.0
	var envelope := minf(1.0,elapsed*11.0)*exp(-elapsed*1.72)
	var wobble := sin(TAU*0.21*elapsed)*0.18
	var phase := TAU*frequency*elapsed+wobble
	var fundamental := sin(phase)*0.82
	var airy := sin(phase*1.995)*0.13
	return (fundamental+airy)*envelope

static func _write_sample(bytes: PackedByteArray,index: int,value: float) -> void:
	var sample := int(round(clampf(value,-0.90,0.90)*32767.0))
	if sample < 0:
		sample += 65536
	bytes[index*2] = sample & 255
	bytes[index*2+1] = (sample >> 8) & 255

static func compose(floor_number: int) -> AudioStreamWAV:
	var floor_id := clampi(floor_number,1,5)
	var base: float = [49.0,43.0,53.0,39.0,36.0][floor_id-1]
	var count := int(float(SAMPLE_RATE)*DURATION)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in range(count):
		var t := float(i)/float(SAMPLE_RATE)
		# Drone grave con ligeras oscilaciones que parecen venir
		# de conductos profundos. Sin ritmo ni notas de combate.
		var breath := 0.71+0.29*sin(TAU*(0.11+floor_id*0.018)*t)
		var sub := sin(TAU*base*t+sin(TAU*0.13*t)*0.34)*0.36
		var harmonic := sin(TAU*base*1.508*t+sin(TAU*0.07*t)*0.48)*0.18
		var distant := sin(TAU*base*0.503*t)*0.24
		var rustle := (sin(t*119.03)*sin(t*57.91)+sin(t*17.11)*sin(t*83.97))*0.028
		var drone := (sub+harmonic+distant)*breath+rustle
		# Motivo de misterio: intervalos menores lentos, ligeramente
		# espectrales. Ni una sola gota/agudo percusivo en exploración.
		var melody := 0.0
		var current_note := int(floor(t/NOTE_LENGTH))
		for back in range(2):
			var index := current_note-back
			if index < 0:
				continue
			var elapsed := t-float(index)*NOTE_LENGTH
			var frequency := mystery_note_frequency(floor_id,index)
			melody += _mystery_tone(elapsed,frequency)*0.42
		# Una segunda voz grave, a quintas, sostiene la sensación de
		# misterio sin convertirse en música de combate.
		var shadow_frequency := base*1.5
		var slow_vibrato := sin(TAU*0.18*t)*0.10
		var shadow := sin(TAU*shadow_frequency*t+slow_vibrato)
		var shadow_level := (0.23+0.10*sin(TAU*0.075*t))*shadow
		var output := drone*0.31+melody*0.37+shadow_level*0.13
		# Evita clic de unión, importante en auriculares.
		var fade := clampf(minf(t,DURATION-t)/0.09,0.0,1.0)
		_write_sample(bytes,i,output*fade)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
