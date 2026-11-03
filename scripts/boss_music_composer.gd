extends RefCounted
class_name IsmaelBossMusicComposer

# Banda sonora ORIGINAL: cinco variantes de combate oscuro.
# Pulso digital, dos voces melódicas, bajo triangular y batería contenida.
const SAMPLE_RATE := 22050
const STEPS := 64
const LEAD: Array[int] = [
	0,-1,3,5, 7,5,3,-1, 8,7,5,3, 2,-1,0,-1,
	3,5,7,10, 8,-1,7,5, 3,2,0,3, 5,-1,3,-1,
	0,3,7,8, 10,-1,8,7, 5,3,2,0, 3,-1,5,-1,
	7,8,10,7, 5,-1,3,2, 0,2,3,5, 3,-1,0,-1
]
const ANSWER: Array[int] = [
	-1,-1,0,-1, 3,-1,5,-1, 2,-1,3,-1, 0,-1,-1,-1,
	-1,5,-1,3, -1,2,-1,0, -1,3,-1,2, -1,0,-1,-1,
	-1,-1,2,-1, 5,-1,7,-1, 3,-1,2,-1, 0,-1,-1,-1,
	5,-1,3,-1, 2,-1,0,-1, 3,-1,2,-1, 0,-1,-1,-1
]
const PROGRESSION: Array[int] = [0,8,5,7]
const ROOTS: Array[int] = [45,43,41,38,36]

static func name_for_floor(floor_number: int) -> String:
	match clampi(floor_number,1,5):
		1: return "Bajo el primer sello"
		2: return "Los dientes del pozo"
		3: return "Mirada sin párpados"
		4: return "La última campana"
		_: return "El abismo tiene hambre"

static func note_frequency(floor_number: int,step_index: int) -> float:
	var note: int = LEAD[posmod(step_index,STEPS)]
	if note < 0:
		return 0.0
	var tonic: int = ROOTS[clampi(floor_number,1,5)-1]
	var section: int = PROGRESSION[posmod(step_index/16,4)]
	return 440.0*pow(2.0,float(tonic+12+section+note-69)/12.0)

static func _hz(note: int) -> float:
	return 440.0*pow(2.0,float(note-69)/12.0)

static func compose(floor_number: int) -> AudioStreamWAV:
	var floor_id := clampi(floor_number,1,5)
	var bpm := float([116,121,113,108,126][floor_id-1])
	var step_length := 60.0/bpm/4.0
	var samples_step := maxi(128,int(round(step_length*float(SAMPLE_RATE))))
	var count := STEPS*samples_step
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var notes: Array[float] = []
	var answers: Array[float] = []
	var basses: Array[float] = []
	var arps: Array[float] = []
	for step in range(STEPS):
		var tonic: int = ROOTS[floor_id-1]
		var section: int = PROGRESSION[posmod(step/16,4)]
		notes.append(note_frequency(floor_id,step))
		var answer_note: int = ANSWER[step]
		answers.append(_hz(tonic+7+section+answer_note) if answer_note >= 0 else 0.0)
		basses.append(_hz(tonic-12+section))
		var arp_offset: int = [0,3,7,10][posmod(step,4)]
		arps.append(_hz(tonic+12+section+arp_offset))
	var lead_phase := 0.0
	var answer_phase := 0.0
	var bass_phase := 0.0
	var arp_phase := 0.0
	var loop_duration := float(count)/float(SAMPLE_RATE)
	for i in range(count):
		var step := mini(STEPS-1,i/samples_step)
		var local_t := float(i%samples_step)/float(samples_step)
		var t := float(i)/float(SAMPLE_RATE)
		lead_phase = fposmod(lead_phase+notes[step]/float(SAMPLE_RATE),1.0)
		answer_phase = fposmod(answer_phase+answers[step]/float(SAMPLE_RATE),1.0)
		bass_phase = fposmod(bass_phase+basses[step]/float(SAMPLE_RATE),1.0)
		arp_phase = fposmod(arp_phase+arps[step]/float(SAMPLE_RATE),1.0)
		# Dos líneas con distinto duty, separación armónica y silencios.
		var lead := 0.0
		if notes[step] > 0.0:
			var gate := minf(1.0,local_t*36.0)*clampf((0.93-local_t)*13.0,0.0,1.0)
			lead = (1.0 if lead_phase<0.27 else -1.0)*gate*0.27
		var answer := 0.0
		if answers[step]>0.0:
			answer = (1.0 if answer_phase<0.50 else -1.0)*pow(1.0-local_t,1.7)*0.115
		var bass := (1.0-4.0*absf(bass_phase-0.5))*0.29
		var arp := (1.0 if arp_phase<0.15 else -1.0)*pow(1.0-local_t,2.8)*0.064
		# Percusión de combate con kick suave, snare granulado y
		# hi-hat discreto. Sin wall-of-noise ni saturación de 8 bits.
		var kick := 0.0
		var snare := 0.0
		var hat := 0.0
		if step%4 == 0:
			kick = sin(TAU*(53.0*t+7.0*local_t*(1.0-local_t)))*exp(-local_t*18.0)*0.20
		if step%8 == 4:
			var noise := sin(float(i)*21.13)*sin(float(i)*9.79)
			snare = noise*pow(1.0-local_t,4.4)*0.12
		if step%2 == 0:
			hat = sin(float(i)*35.17)*pow(1.0-local_t,6.2)*0.035
		var tension := 0.93+0.07*sin(TAU*t/(loop_duration/2.0))
		var output := (lead+answer+bass+arp+kick+snare+hat)*tension
		var fade := clampf(minf(t,loop_duration-t)/0.024,0.0,1.0)
		var sample := int(round(clampf(output*fade,-0.88,0.88)*32767.0))
		if sample < 0:
			sample += 65536
		bytes[i*2] = sample & 255
		bytes[i*2+1] = (sample>>8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
