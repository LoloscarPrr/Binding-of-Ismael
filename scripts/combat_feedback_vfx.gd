extends Node2D
class_name IsmaelCombatFeedbackVfx

var mode := "hit"
var floor_variant := 1
var strength := 1.0
var _age := 0.0
var _duration := 0.24
var _seed := 0

func configure(kind: String, floor_index: int = 1, intensity: float = 1.0) -> void:
	mode = kind
	floor_variant = clampi(floor_index,1,5)
	strength = maxf(0.5,intensity)
	_seed = get_instance_id()
	match mode:
		"phase":
			_duration = 0.72
		"clear":
			_duration = 0.62
		_:
			_duration = 0.20

func _ready() -> void:
	z_index = 9
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _duration:
		queue_free()

func _accent() -> Color:
	match floor_variant:
		1: return Color(1.0,0.38,0.12)
		2: return Color(0.82,0.78,0.24)
		3: return Color(0.78,0.36,0.92)
		4: return Color(0.42,0.66,0.96)
		_: return Color(0.68,0.28,0.98)

func _draw() -> void:
	var t := clampf(_age/_duration,0.0,1.0)
	var alpha := 1.0-t
	var accent := _accent()
	match mode:
		"phase":
			var eased := 1.0-pow(1.0-t,3.0)
			var r := lerpf(34.0,138.0,eased)
			draw_circle(Vector2.ZERO,r*0.36,Color(accent.r,accent.g,accent.b,0.11*alpha))
			draw_arc(Vector2.ZERO,r,0.0,TAU,48,Color(accent.r,accent.g,accent.b,0.92*alpha),7.0)
			draw_arc(Vector2.ZERO,r*0.72,_age*5.2,_age*5.2+PI*1.45,38,Color(1.0,0.84,0.58,0.68*alpha),4.0)
			for i in range(12):
				var a := TAU*float(i)/12.0+float(_seed%13)*0.031
				var d := Vector2.RIGHT.rotated(a)
				draw_line(d*r*0.42,d*r*(0.88+0.07*float(i%3)),Color(accent.r,accent.g,accent.b,0.72*alpha),4.0)
		"clear":
			var eased := 1.0-pow(1.0-t,2.0)
			var r := lerpf(46.0,240.0,eased)
			draw_arc(Vector2.ZERO,r,0.0,TAU,60,Color(accent.r,accent.g,accent.b,0.48*alpha),5.0)
			draw_arc(Vector2.ZERO,r*0.74,0.0,TAU,54,Color(1.0,0.88,0.58,0.24*alpha),3.0)
			for i in range(8):
				var a := TAU*float(i)/8.0
				var p := Vector2.RIGHT.rotated(a)*r*0.58
				draw_circle(p,4.0+3.0*alpha,Color(accent.r,accent.g,accent.b,0.46*alpha))
		_:
			var eased := 1.0-pow(1.0-t,2.0)
			var r := lerpf(7.0,24.0+6.0*strength,eased)
			draw_circle(Vector2.ZERO,r*0.28,Color(1.0,0.92,0.72,0.44*alpha))
			draw_arc(Vector2.ZERO,r,0.0,TAU,22,Color(accent.r,accent.g,accent.b,0.88*alpha),3.0)
			for i in range(5):
				var a := TAU*float(i)/5.0+float(_seed%9)*0.07
				var d := Vector2.RIGHT.rotated(a)
				draw_line(d*r*0.22,d*r*(0.74+0.08*float(i%2)),Color(1.0,0.64,0.28,0.76*alpha),2.5)
