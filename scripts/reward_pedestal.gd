extends Button
class_name IsmaelRewardPedestal

var accent := Color(0.78,0.62,0.26)

func _ready() -> void:
	flat = true
	clip_text = false
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", Color(0.96,0.90,0.76))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color(1.0,0.88,0.55))
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var base_y := h * 0.73
	var glow := accent
	glow.a = 0.08 if not is_hovered() else 0.16
	# Halo pequeño: el objeto/pedestal debe dominar, no un círculo gigante.
	draw_circle(Vector2(w*0.5, h*0.50), minf(w,h)*0.11, glow)
	# Objeto ritual sencillo sobre el pedestal.
	draw_circle(Vector2(w*0.5, h*0.48), 13.0, Color(0.91,0.78,0.43))
	draw_circle(Vector2(w*0.5-4.0, h*0.44), 4.0, Color(1.0,0.92,0.62,0.85))
	var pedestal := Rect2(w*0.27, base_y, w*0.46, h*0.16)
	draw_rect(Rect2(pedestal.position + Vector2(5,6), pedestal.size), Color(0.02,0.015,0.012,0.45))
	draw_rect(pedestal, Color(0.24,0.19,0.15))
	draw_rect(Rect2(w*0.34, h*0.60, w*0.32, h*0.14), Color(0.31,0.24,0.18))
	draw_rect(Rect2(w*0.22, h*0.56, w*0.56, h*0.07), Color(0.38,0.29,0.20))
	draw_line(Vector2(w*0.22,h*0.56), Vector2(w*0.78,h*0.56), accent, 4.0)
	draw_rect(pedestal, Color(0.56,0.43,0.28), false, 3.0)
