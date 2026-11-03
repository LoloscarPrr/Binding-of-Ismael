extends RefCounted
class_name IsmaelSewerAmbienceComposer

# Paisajes sonoros originales para exploración. No hay melodías de
# otros juegos: aire subterráneo, tuberías, agua y resonancias largas.
const SAMPLE_RATE := 22050
const DURATION := 12.0
const DRIP_TIMES: Array[float] = [0.72,1.82,3.11,4.04,5.48,6.97,8.18,9.56,10.87]
const DRIP_PITCHES: Array[float] = [810.0,690.0,960.0,720.0,880.0,760.0,1010.0,730.0,830.0]

static func ambience_name(floor_number: int) -> String:
	match clampi(floor_number,1,5):
		1: return "Agua bajo las tablas"
		2: return "Drenajes olvidados"
		3: return "Conductos sin luz"
		4: return "La piedra respira"
		_: return "Bajo el último pozo"

static func _droplet(elapsed: float,pitch: float) -> float:
	if elapsed < 0.0 or elapsed > 0.23:
		return 0.0
	var envelope := exp(-elapsed*24.0)
	var chirp := pitch*(1.0-0.29*minf(1.0,elapsed/0.18))
	var tone := sin(TAU*chirp*elapsed)
	var overtone := sin(TAU*chirp*1.49*elapsed)*0.23
	return (tone+overtone)*envelope

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
		# Goteos en distintos lugares, cada uno con dos ecos más
		# bajos y retardados, como un desagüe de piedra.
		var drops := 0.0
		for k in DRIP_TIMES.size():
			var start := DRIP_TIMES[k]+float(floor_id-1)*0.043
			var frequency := DRIP_PITCHES[k]*(0.91+0.025*floor_id)
			drops += _droplet(t-start,frequency)*0.58
			drops += _droplet(t-start-0.19,frequency*0.88)*0.19
			drops += _droplet(t-start-0.41,frequency*0.75)*0.09
		# Sonido metálico de tubería muy lejano, no efectos fuertes
		# que compitan con disparos y alertas del combate.
		var pipe := 0.0
		for moment in [2.1,7.5]:
			var dt := t-float(moment)-float(floor_id)*0.07
			if dt >= 0.0 and dt < 1.7:
				var waver := sin(TAU*(102.0+13.0*sin(dt*1.3))*dt)
				pipe += waver*exp(-dt*1.7)*sin(PI*minf(dt/0.18,1.0))*0.18
		var output := drone*0.31+drops*0.23+pipe*0.29
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
