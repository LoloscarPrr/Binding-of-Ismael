extends RefCounted
class_name IsmaelBossMusicComposer

# Rock oscuro original: riffs de guitarra de potencia, una segunda guitarra
# grave a contratiempo, bajo y bateria. Ninguna melodia comercial.
# Todas las pistas se sintetizan una sola vez y quedan cacheadas por piso.
const SAMPLE_RATE := 22050
const STEPS := 64
const ROOTS: Array[int] = [40,43,38,41,36]
const TEMPOS: Array[int] = [124,130,118,133,127]
# Cuatro compases de semicorcheas: silencios deliberados y riffs sincopados.
const MAIN_RIFF: Array[int] = [
	0,-1,0,3, 0,-1,5,-1, 0,0,-1,7, 5,-1,3,-1,
	0,-1,3,5, 0,-1,3,-1, 0,7,5,-1, 3,-1,0,-1,
	0,0,-1,3, 0,-1,5,7, 0,-1,8,-1, 7,5,3,-1,
	0,-1,0,3, 5,3,0,-1, 7,-1,5,3, 0,-1,-1,-1
]
const LOW_GUITAR: Array[int] = [
	0,-1,0,-1, 0,-1,0,0, -1,-1,0,-1, 0,-1,0,-1,
	0,-1,0,0, -1,-1,0,-1, 0,0,-1,0, -1,0,0,-1,
	0,-1,0,-1, 0,0,-1,0, -1,0,0,-1, 0,-1,0,0,
	0,-1,0,-1, 0,0,0,-1, 0,-1,0,0, -1,0,-1,-1
]
const CHORD_SHIFTS: Array[int] = [0,-2,-3,-1]

static func name_for_floor(floor_number: int) -> String:
	match clampi(floor_number,1,5):
		1: return "El hierro bajo la tierra"
		2: return "Dientes de la fosa"
		3: return "Rugido en la cripta"
		4: return "La ultima defensa"
		_: return "Riff del abismo"

static func _hz(midi_note: int) -> float:
	return 440.0*pow(2.0,float(midi_note-69)/12.0)

static func note_frequency(floor_number: int,step_index: int) -> float:
	var offset: int = MAIN_RIFF[posmod(step_index,STEPS)]
	if offset < 0:
		return 0.0
	var root: int = ROOTS[clampi(floor_number,1,5)-1]
	var shift: int = CHORD_SHIFTS[posmod(int(step_index/16),4)]
	return _hz(root+12+shift+offset)

static func _overdriven_guitar(phase: float,fifth_phase: float) -> float:
	# Multiharmonico con saturacion suave: evita el antiguo timbre de
	# onda cuadrada y da cuerpo al acorde de quinta.
	var fundamental := sin(TAU*phase)
	var upper := sin(TAU*phase*2.006)*0.42+sin(TAU*phase*3.014)*0.22
	var fifth := sin(TAU*fifth_phase)*0.57+sin(TAU*fifth_phase*2.009)*0.20
	var raw := fundamental*0.76+upper+fifth
	return raw*1.75/(1.0+absf(raw)*1.70)

static func _sample_to_bytes(bytes: PackedByteArray,index: int,level: float) -> void:
	var value := int(round(clampf(level,-0.90,0.90)*32767.0))
	if value < 0:
		value += 65536
	bytes[index*2] = value & 255
	bytes[index*2+1] = (value>>8) & 255

static func compose(floor_number: int) -> AudioStreamWAV:
	var floor_id := clampi(floor_number,1,5)
	var step_seconds := 60.0/float(TEMPOS[floor_id-1])/4.0
	var samples_step := maxi(128,int(round(step_seconds*float(SAMPLE_RATE))))
	var count := STEPS*samples_step
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var primary_notes := PackedFloat32Array()
	var low_notes := PackedFloat32Array()
	var bass_notes := PackedFloat32Array()
	primary_notes.resize(STEPS)
	low_notes.resize(STEPS)
	bass_notes.resize(STEPS)
	for step in range(STEPS):
		var chord_shift: int = CHORD_SHIFTS[int(step/16)]
		var root: int = ROOTS[floor_id-1]+chord_shift
		var riff_note: int = MAIN_RIFF[step]
		primary_notes[step] = _hz(root+12+riff_note) if riff_note >= 0 else 0.0
		# La guitarra secundaria va mas grave y responde con golpes cortos,
		# no repite el riff principal ni se mezcla con el bombo.
		low_notes[step] = _hz(root-2+LOW_GUITAR[step]) if LOW_GUITAR[step] >= 0 else 0.0
		bass_notes[step] = _hz(root-12)
	var main_phase := 0.0
	var main_fifth_phase := 0.0
	var low_phase := 0.0
	var low_fifth_phase := 0.0
	var bass_phase := 0.0
	var duration := float(count)/float(SAMPLE_RATE)
	var inv_rate := 1.0/float(SAMPLE_RATE)
	for i in range(count):
		var step: int = mini(STEPS-1,int(i/samples_step))
		var step_time := float(i%samples_step)*inv_rate
		var elapsed := float(i)*inv_rate
		var main_frequency: float = primary_notes[step]
		var low_frequency: float = low_notes[step]
		main_phase = fposmod(main_phase+main_frequency*inv_rate,1.0)
		main_fifth_phase = fposmod(main_fifth_phase+main_frequency*1.498307*inv_rate,1.0)
		low_phase = fposmod(low_phase+low_frequency*inv_rate,1.0)
		low_fifth_phase = fposmod(low_fifth_phase+low_frequency*1.498307*inv_rate,1.0)
		bass_phase = fposmod(bass_phase+float(bass_notes[step])*inv_rate,1.0)

		var main_guitar := 0.0
		if main_frequency > 0.0:
			var pick := minf(1.0,step_time*120.0)
			var decay := exp(-step_time*(6.0 if step%4 == 0 else 10.0))
			main_guitar = _overdriven_guitar(main_phase,main_fifth_phase)*pick*decay*0.30
		var rhythm_guitar := 0.0
		if low_frequency > 0.0:
			var palm_mute := minf(1.0,step_time*160.0)*exp(-step_time*17.0)
			rhythm_guitar = _overdriven_guitar(low_phase,low_fifth_phase)*palm_mute*0.23
		var bass := (sin(TAU*bass_phase)*0.83+sin(TAU*bass_phase*2.0)*0.17)*0.18

		# Bateria seca y contundente, sin goteos ni campanillas.
		var kick := 0.0
		if step%4 == 0:
			var kick_phase := TAU*(49.0*step_time+2.7*(1.0-exp(-step_time*23.0)))
			kick = sin(kick_phase)*exp(-step_time*22.0)*0.28
		var snare := 0.0
		if step%8 == 4:
			var grit := sin(float(i)*21.23)*sin(float(i)*9.77)
			snare = (grit*0.82+sin(TAU*166.0*step_time)*0.18)*exp(-step_time*28.0)*0.15
		var hat := 0.0
		if step%2 == 0:
			hat = sin(float(i)*36.47)*sin(float(i)*17.19)*exp(-step_time*51.0)*0.025

		var output := main_guitar+rhythm_guitar+bass+kick+snare+hat
		# El loop no debe hacer un golpe de volumen ni un click al repetirse.
		var fade := clampf(minf(elapsed,duration-elapsed)/0.055,0.0,1.0)
		_sample_to_bytes(bytes,i,output*fade)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
