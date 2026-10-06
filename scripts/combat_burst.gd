extends Node2D
class_name IsmaelCombatBurst

var strong := false
var _age := 0.0
var _duration := 0.34
var _seed := 0

func configure(is_strong: bool = false) -> void:
	strong = is_strong
	_duration = 0.46 if strong else 0.30
	_seed = get_instance_id()

func _ready() -> void:
	z_index = 8
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _duration:
		queue_free()

func _draw() -> void:
	var t := clampf(_age/_duration,0.0,1.0)
	var eased := 1.0-pow(1.0-t,2.0)
	var alpha := 1.0-t
	var radius := lerpf(12.0,62.0 if strong else 42.0,eased)
	draw_circle(Vector2.ZERO,radius*0.42,Color(0.52,0.035,0.045,0.18*alpha))
	draw_arc(Vector2.ZERO,radius,0.0,TAU,32,Color(0.92,0.18,0.12,0.80*alpha),4.0 if strong else 3.0)
	var count := 10 if strong else 7
	for i in range(count):
		var angle := TAU*float(i)/float(count)+float(_seed%17)*0.037
		var dir := Vector2.RIGHT.rotated(angle)
		var start := dir*radius*0.28
		var finish := dir*radius*(0.72+0.08*float(i%3))
		draw_line(start,finish,Color(0.78,0.08,0.07,0.72*alpha),3.0)
