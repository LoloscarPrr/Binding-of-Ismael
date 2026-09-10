extends Control
class_name IsmaelBossHud

var boss_name := "GUARDIÁN"
var current_health := 0
var max_health := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	queue_redraw()

func show_boss(name: String, health: int) -> void:
	boss_name = name
	current_health = health
	max_health = maxi(1, health)
	visible = true
	queue_redraw()

func set_health(value: int) -> void:
	current_health = maxi(0, value)
	if current_health <= 0:
		visible = false
	queue_redraw()

func hide_boss() -> void:
	visible = false
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var bar_rect := Rect2(52.0, 30.0, maxf(160.0, size.x - 104.0), 28.0)
	var ratio := clampf(float(current_health) / float(max_health), 0.0, 1.0)
	draw_rect(Rect2(bar_rect.position + Vector2(5,6), bar_rect.size), Color(0.02,0.01,0.01,0.55))
	draw_rect(bar_rect, Color(0.08,0.025,0.025))
	draw_rect(Rect2(bar_rect.position + Vector2(4,4), Vector2((bar_rect.size.x-8.0)*ratio, bar_rect.size.y-8.0)), Color(0.60,0.075,0.07))
	draw_rect(bar_rect, Color(0.73,0.52,0.33), false, 4.0)
	var skull := Vector2(31.0, 44.0)
	draw_circle(skull, 17.0, Color(0.73,0.67,0.56))
	draw_circle(skull + Vector2(-6,-2), 4.0, Color(0.06,0.04,0.035))
	draw_circle(skull + Vector2(6,-2), 4.0, Color(0.06,0.04,0.035))
	draw_rect(Rect2(skull + Vector2(-8,9), Vector2(16,6)), Color(0.06,0.04,0.035))
