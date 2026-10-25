extends Node2D
class_name IsmaelMotionTrail

# Una sola estela liviana por actor. Se dibuja en espacio mundial para que
# los rastros permanezcan sobre el suelo cuando el actor se mueve.
var actor: Node2D
var trail_kind := "player"
var _marks: Array[Dictionary] = []
var _sample_clock := 0.0
var _age := 0.0

func follow(subject: Node2D, kind: String) -> void:
	actor = subject
	trail_kind = kind
	z_index = -1

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		queue_free()
		return
	_age += delta
	_sample_clock += delta
	var speed_value := actor.velocity.length() if actor is CharacterBody2D else 0.0
	var interval := 0.055 if trail_kind == "player" else 0.075
	if _sample_clock >= interval and speed_value > (55.0 if trail_kind == "player" else 115.0):
		_sample_clock = 0.0
		_marks.append({"position":actor.global_position,"life":0.30 if trail_kind == "boss" else 0.20})
	for i in range(_marks.size()-1,-1,-1):
		var mark: Dictionary = _marks[i]
		mark["life"] = float(mark["life"])-delta
		if float(mark["life"]) <= 0.0:
			_marks.remove_at(i)
		else:
			_marks[i] = mark
	while _marks.size() > 6:
		_marks.remove_at(0)
	queue_redraw()

func _draw() -> void:
	var ink := Color(0.29,0.73,0.91) if trail_kind == "player" else (
		Color(0.90,0.24,0.14) if trail_kind == "dash" else Color(0.59,0.20,0.58)
	)
	var max_life := 0.30 if trail_kind == "boss" else 0.20
	for mark in _marks:
		var t := clampf(float(mark["life"])/max_life,0.0,1.0)
		var center: Vector2 = mark["position"] - global_position
		var radius := (18.0 if trail_kind == "boss" else 11.0)*t
		draw_circle(center,radius,Color(ink.r,ink.g,ink.b,0.09*t))
		draw_arc(center,radius+3.0,0.20,PI-0.20,15,Color(ink.r,ink.g,ink.b,0.24*t),1.8)
		if trail_kind == "player":
			draw_circle(center+Vector2(0,16),3.0*t,Color(0.65,0.57,0.49,0.20*t))
