extends Node2D
class_name IsmaelDoorChargeIndicator

var progress := 0.0
var active := false

func set_progress(value: float) -> void:
	progress = clampf(value,0.0,1.0)
	active = progress > 0.001
	visible = active
	queue_redraw()

func reset() -> void:
	progress = 0.0
	active = false
	visible = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var center := Vector2(0,-52)
	var radius := 17.0
	draw_circle(center,radius+4.0,Color(0.02,0.015,0.012,0.72))
	draw_arc(center,radius,0.0,TAU,36,Color(0.32,0.26,0.20,0.78),4.0)
	var end_angle := -PI*0.5+TAU*progress
	draw_arc(center,radius,-PI*0.5,end_angle,36,Color(1.0,0.78,0.24,0.96),5.0)
	draw_circle(center,3.0+progress*2.0,Color(1.0,0.84,0.36,0.82))
