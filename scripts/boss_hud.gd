extends Control
class_name IsmaelBossHud

var boss_name := "GUARDIÁN"
var current_health := 0
var max_health := 1
var boss_phase := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 20
	queue_redraw()

func show_boss(name: String, health: int) -> void:
	boss_name = name
	current_health = health
	max_health = maxi(1, health)
	boss_phase = 0
	visible = true
	queue_redraw()

func set_phase(value: int) -> void:
	boss_phase = clampi(value,0,3)
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
	var font := ThemeDB.fallback_font
	var title_font_size := 22
	var hp_font_size := 17
	var title_size := font.get_string_size(boss_name,HORIZONTAL_ALIGNMENT_LEFT,-1.0,title_font_size)

	# Panel oscuro para separar el HUD del combate.
	var panel := Rect2(0.0,0.0,size.x,size.y)
	draw_rect(panel,Color(0.012,0.008,0.010,0.86))
	draw_rect(panel,Color(0.58,0.34,0.22,0.76),false,3.0)

	draw_string(
		font,
		Vector2(size.x*0.5-title_size.x*0.5,28.0),
		boss_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		title_font_size,
		Color(0.97,0.87,0.72)
	)

	var bar_rect := Rect2(54.0,38.0,maxf(220.0,size.x-108.0),38.0)
	var ratio := clampf(float(current_health)/float(max_health),0.0,1.0)

	draw_rect(Rect2(bar_rect.position+Vector2(5,6),bar_rect.size),Color(0.0,0.0,0.0,0.58))
	draw_rect(bar_rect,Color(0.075,0.018,0.022))
	draw_rect(
		Rect2(
			bar_rect.position+Vector2(5,5),
			Vector2((bar_rect.size.x-10.0)*ratio,bar_rect.size.y-10.0)
		),
		Color(0.72,0.075,0.065)
	)
	draw_rect(bar_rect,Color(0.84,0.60,0.34),false,4.0)
	if boss_phase > 0:
		# Dos muescas persistentes: límites de las fases II y III.
		for threshold in [0.55,0.25]:
			var marker_x := bar_rect.position.x+bar_rect.size.x*threshold
			draw_line(Vector2(marker_x,bar_rect.position.y+2),Vector2(marker_x,bar_rect.end.y-2),Color(1.0,0.83,0.53,0.75),2.0)
		var stage_text := "I" if boss_phase == 1 else ("II" if boss_phase == 2 else "III")
		var stage_color := Color(1.0,0.83,0.52) if boss_phase == 1 else (
			Color(1.0,0.62,0.32) if boss_phase == 2 else Color(1.0,0.36,0.34)
		)
		draw_string(font,Vector2(size.x-75.0,27),stage_text,HORIZONTAL_ALIGNMENT_LEFT,-1.0,17,stage_color)

	var hp_text := "%d / %d" % [current_health,max_health]
	var hp_size := font.get_string_size(hp_text,HORIZONTAL_ALIGNMENT_LEFT,-1.0,hp_font_size)
	draw_string(
		font,
		Vector2(
			bar_rect.position.x+bar_rect.size.x*0.5-hp_size.x*0.5,
			bar_rect.position.y+26.0
		),
		hp_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		hp_font_size,
		Color(1.0,0.93,0.84)
	)

	var skull := Vector2(31.0,57.0)
	draw_circle(skull,18.0,Color(0.76,0.70,0.58))
	draw_circle(skull+Vector2(-6,-3),4.0,Color(0.055,0.035,0.032))
	draw_circle(skull+Vector2(6,-3),4.0,Color(0.055,0.035,0.032))
	draw_rect(Rect2(skull+Vector2(-8,9),Vector2(16,6)),Color(0.055,0.035,0.032))
