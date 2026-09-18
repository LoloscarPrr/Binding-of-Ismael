extends Button
class_name IsmaelRewardPedestal

var accent := Color(0.78,0.62,0.26)
var _age := 0.0

func _ready() -> void:
	flat = true
	clip_text = false
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size",18)
	add_theme_color_override("font_color",Color(0.96,0.90,0.76))
	add_theme_color_override("font_hover_color",Color.WHITE)
	add_theme_color_override("font_pressed_color",Color(1.0,0.88,0.55))
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var bob := sin(_age*2.8)*3.0
	var pulse := 0.5+0.5*sin(_age*3.4)
	var base_y := h*0.74
	var glow := Color(accent,0.07+0.045*pulse)
	if is_hovered():
		glow.a += 0.09
	draw_circle(Vector2(w*0.5,h*0.47+bob),minf(w,h)*0.18,glow)
	draw_ellipse(Vector2(w*0.5,base_y+h*0.13),Vector2(w*0.27,h*0.08),Color(0,0,0,0.30))
	var base := PackedVector2Array([Vector2(w*0.28,base_y),Vector2(w*0.72,base_y),Vector2(w*0.67,h*0.91),Vector2(w*0.33,h*0.91)])
	draw_colored_polygon(base,Color(0.22,0.16,0.12))
	draw_polyline(PackedVector2Array([Vector2(w*0.28,base_y),Vector2(w*0.72,base_y),Vector2(w*0.67,h*0.91),Vector2(w*0.33,h*0.91),Vector2(w*0.28,base_y)]),Color(0.48,0.34,0.21),3.0,true)
	var slab := PackedVector2Array([Vector2(w*0.22,h*0.58),Vector2(w*0.78,h*0.58),Vector2(w*0.70,h*0.67),Vector2(w*0.30,h*0.67)])
	draw_colored_polygon(slab,Color(0.36,0.25,0.16))
	draw_line(Vector2(w*0.25,h*0.59),Vector2(w*0.75,h*0.59),accent,4.0)
	draw_set_transform(Vector2(0,bob),0.0,Vector2.ONE)
	draw_circle(Vector2(w*0.5,h*0.48),15.0,Color(0.91,0.75,0.32))
	draw_circle(Vector2(w*0.5-5,h*0.44),4.5,Color(1.0,0.93,0.64,0.84))
	draw_arc(Vector2(w*0.5,h*0.48),22.0,0.0,TAU,24,Color(accent,0.42),2.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
