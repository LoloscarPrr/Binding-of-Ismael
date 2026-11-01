extends RefCounted
class_name IsmaelChiptuneComposer

# Composiciones ORIGINALes de Binding of Ismael; ninguna melodía,
# grabación ni arreglo procede de otro juego.
# Tres voces chiptune: pulso, triángulo y arpegio, más percusión sintética.
const SAMPLE_RATE := 22050
const STEPS := 64
const SCALE_MINOR: Array[int] = [0,2,3,5,7,8,10,12]
const LEAD_PATTERN: Array[int] = [
	0,-1,2,3, 4,-1,3,2, 1,-1,3,5, 4,3,2,-1,
	0,2,-1,4, 5,-1,4,2, 3,2,-1,1, 0,-1,2,-1,
	2,-1,4,5, 6,-1,5,4, 3,-1,1,2, 4,3,2,-1,
	5,-1,4,3, 2,-1,0,2, 1,3,2,-1, 0,-1,0,-1
]
const BOSS_PATTERN: Array[int] = [
	0,4,3,2, 4,5,4,2, 3,5,6,4, 3,2,1,0,
	4,6,5,3, 4,6,7,5, 6,5,4,2, 3,2,0,1,
	0,3,4,6, 5,4,3,2, 4,5,6,7, 6,4,3,1,
	5,4,6,4, 7,6,5,3, 4,2,3,1, 0,2,1,0
]

static func is_original_music() -> bool:
	return true

static func tune_name(floor_number: int, boss: bool) -> String:
	if boss:
		return "La marca despierta"
	match clampi(floor_number,1,5):
		1: return "Bajo las tablas"
		2: return "La fosa respira"
		3: return "Ojo en la oscuridad"
		4: return "Piedra sin descanso"
		_: return "Donde termina la luz"

static func _hz(midi_note: int) -> float:
	return 440.0*pow(2.0,float(midi_note-69)/12.0)

static func melody_frequency(floor_number: int,boss: bool,step_index: int) -> float:
	var pattern := BOSS_PATTERN if boss else LEAD_PATTERN
	var degree: int = pattern[posmod(step_index,STEPS)]
	if degree < 0:
		return 0.0
	var root := [45,48,43,41,38][clampi(floor_number,1,5)-1]
	var offsets := [0,2,5,7][posmod(step_index/16,4)]
	return _hz(root+12+SCALE_MINOR[degree]+offsets)

static func _bass_frequency(floor_number: int,step_index: int,boss: bool) -> float:
	var root := [45,48,43,41,38][clampi(floor_number,1,5)-1]
	var chords := [0,5,3,7]
	var octave := -12 if not boss else 0
	return _hz(root+octave+chords[posmod(step_index/16,4)])

static func compose(floor_number: int,boss: bool=false) -> AudioStreamWAV:
	var bpm := float([104,112,106,98,94][clampi(floor_number,1,5)-1])+(22.0 if boss else 0.0)
	var step_seconds := 60.0/bpm/4.0
	var step_samples := maxi(128,int(round(step_seconds*float(SAMPLE_RATE))))
	var count := STEPS*step_samples
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var lead_notes: Array[float] = []
	var bass_notes: Array[float] = []
	var arp_notes: Array[float] = []
	for step_index in range(STEPS):
		lead_notes.append(melody_frequency(floor_number,boss,step_index))
		bass_notes.append(_bass_frequency(floor_number,step_index,boss))
		var minor_chord: Array[int] = [0,3,7,10]
		var root_note := [57,60,55,53,50][clampi(floor_number,1,5)-1]
		var progression := [0,5,3,7][posmod(step_index/16,4)]
		arp_notes.append(_hz(root_note+progression+minor_chord[posmod(step_index,4)]))
	var lead_phase := 0.0
	var bass_phase := 0.0
	var arp_phase := 0.0
	var total_duration := float(count)/float(SAMPLE_RATE)
	for i in range(count):
		var step_index := mini(STEPS-1,i/step_samples)
		var phase_in_step := float(i%step_samples)/float(step_samples)
		var secs := float(i)/float(SAMPLE_RATE)
		var lf: float = lead_notes[step_index]
		var bf: float = bass_notes[step_index]
		var af: float = arp_notes[step_index]
		lead_phase = fposmod(lead_phase+lf/float(SAMPLE_RATE),1.0)
		bass_phase = fposmod(bass_phase+bf/float(SAMPLE_RATE),1.0)
		arp_phase = fposmod(arp_phase+af/float(SAMPLE_RATE),1.0)
		var lead_gate := minf(1.0,phase_in_step*24.0)*clampf((0.93-phase_in_step)*10.0,0.0,1.0)
		var lead := 0.0
		if lf > 0.0:
			lead = (1.0 if lead_phase < (0.25 if boss else 0.38) else -1.0)*lead_gate
		var triangle := 1.0-4.0*absf(bass_phase-0.5)
		var bass_gate := 0.72+0.28*(1.0-phase_in_step)
		var arp := (1.0 if arp_phase < 0.15 else -1.0)*pow(1.0-phase_in_step,1.7)
		var beat := fmod(secs,60.0/bpm)
		var kick := 0.0
		var snare := 0.0
		var hat := 0.0
		if beat < 0.11:
			kick = sin(TAU*(62.0-29.0*beat/0.11)*beat)*exp(-beat*27.0)
		if step_index%8 == 4 and phase_in_step < 0.70:
			var noise := sin(float(i)*23.231)+sin(float(i)*61.932)
			snare = noise*0.32*pow(1.0-phase_in_step,2.1)
		if step_index%2 == 0 and phase_in_step < 0.25:
			hat = sin(float(i)*71.3)*0.10*(1.0-phase_in_step*4.0)
		var level := (lead*0.25+bass_gate*triangle*0.26+arp*0.075+
			kick*0.18+snare*0.15+hat*0.45)
		if boss:
			level = level*1.12+sin(TAU*bf*2.0*secs)*0.028
		# Atacamos y liberamos el loop sin clic audible.
		var fade := minf(1.0,minf(secs,total_duration-secs)*44.0)
		var pcm := int(round(clampf(level*fade,-0.88,0.88)*32767.0))
		if pcm < 0:
			pcm += 65536
		bytes[i*2] = pcm & 255
		bytes[i*2+1] = (pcm >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
