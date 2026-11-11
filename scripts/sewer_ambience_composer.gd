extends RefCounted
class_name IsmaelSewerAmbienceComposer

# Exploracion 12.3.7: rock cavernoso original a medio tiempo,
# con punteos de guitarra, power-chords suaves y bajo subterráneo.
const RockSynth = preload("res://scripts/rock_music_synth.gd")
const SAMPLE_RATE := 22050
const DURATION := 10.0
const MYSTERY_DEGREES: Array[int] = [0,3,7,6,3,1,8,7,0,3,10,7]

static func ambience_name(floor_number: int) -> String:
	match clampi(floor_number,1,5):
		1: return "Acordes bajo tierra"
		2: return "La fosa resuena"
		3: return "Sombras de acero"
		4: return "Cuerdas del sepulcro"
		_: return "Ecos del ultimo piso"

static func mystery_note_frequency(floor_number: int, note_index: int) -> float:
	var base_midi: int = int([53,50,48,46,43][clampi(floor_number,1,5)-1])
	var degree: int = MYSTERY_DEGREES[posmod(note_index,MYSTERY_DEGREES.size())]
	return 440.0*pow(2.0,float(base_midi+degree-69)/12.0)

static func compose(floor_number: int) -> AudioStreamWAV:
	return RockSynth.compose(floor_number,false)
