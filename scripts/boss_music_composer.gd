extends RefCounted
class_name IsmaelBossMusicComposer

# Reemplazo 12.3.7: rock oscuro de guitarras de cuerda modelada.
const RockSynth = preload("res://scripts/rock_music_synth.gd")
const SAMPLE_RATE := 22050

static func name_for_floor(floor_number: int) -> String:
	match clampi(floor_number,1,5):
		1: return "Bajo el hierro"
		2: return "El guardian de ceniza"
		3: return "Garganta del abismo"
		4: return "Ritual del ultimo riff"
		_: return "La caida de los sellos"

static func note_frequency(floor_number: int, step_index: int) -> float:
	var roots: Array[int] = RockSynth.ROOTS
	var note: int = roots[clampi(floor_number,1,5)-1]+12
	var chord_step := int(posmod(step_index,128)/16)
	note += RockSynth.BOSS_CHORDS[chord_step]
	return 440.0*pow(2.0,float(note-69)/12.0)

static func compose(floor_number: int) -> AudioStreamWAV:
	return RockSynth.compose(floor_number,true)
