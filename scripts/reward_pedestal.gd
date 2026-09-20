extends Button
class_name IsmaelRewardPedestal

var reward_id := ""
var reward_title := "OFRENDA"
var reward_effect := ""
var accent := Color(0.78,0.62,0.26)
var _age := 0.0
var _title_label: Label
var _effect_label: Label

func _ready() -> void:
	flat = true
	clip_text = false
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(true)
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size",20)
	_title_label.add_theme_color_override("font_color",Color(0.96,0.91,0.79))
	_title_label.add_theme_color_override("font_outline_color",Color(0.03,0.02,0.018,0.96))
	_title_label.add_theme_constant_override("outline_size",4)
	add_child(_title_label)
	_effect_label = Label.new()
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_label.add_theme_font_size_override("font_size",15)
	_effect_label.add_theme_color_override("font_color",Color(0.80,0.70,0.52))
	_effect_label.add_theme_color_override("font_outline_color",Color(0.03,0.02,0.018,0.94))
	_effect_label.add_theme_constant_override("outline_size",3)
	add_child(_effect_label)
	_refresh_labels()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()
		queue_redraw()

func configure_reward(id: String) -> void:
	reward_id = id
	match id:
		"movimiento":
			reward_title = "PASO LIGERO"
			reward_effect = "+ MOVIMIENTO"
			accent = Color(0.72,0.76,0.58)
		"cadencia":
			reward_title = "PULSO RÁPIDO"
			reward_effect = "+ CADENCIA"
			accent = Color(0.64,0.76,0.86)
		"vida":
			reward_title = "CORAZÓN VOTIVO"
			reward_effect = "+ VIDA MÁXIMA"
			accent = Color(0.84,0.18,0.20)
		"curacion":
			reward_title = "VENDA RITUAL"
			reward_effect = "+ CURACIÓN"
			accent = Color(0.84,0.72,0.54)
		"proyectil":
			reward_title = "IMPULSO"
			reward_effect = "+ VELOCIDAD DE LÁGRIMA"
			accent = Color(0.34,0.68,0.90)
		"dano":
			reward_title = "MARCA ROJA"
			reward_effect = "+ DAÑO"
			accent = Color(0.76,0.10,0.12)
		_:
			reward_title = id.to_upper()
			reward_effect = ""
			accent = Color(0.78,0.62,0.26)
	_refresh_labels()
	queue_redraw()

func _refresh_labels() -> void:
	if is_instance_valid(_title_label):
		_title_label.text = reward_title
	if is_instance_valid(_effect_label):
		_effect_label.text = reward_effect
	_layout_labels()

func _layout_labels() -> void:
	if not is_instance_valid(_title_label) or not is_instance_valid(_effect_label):
		return
	var w := size.x
	var h := size.y
	_title_label.position = Vector2(8.0,h*0.78)
	_title_label.size = Vector2(w-16.0,30.0)
	_effect_label.position = Vector2(8.0,h*0.89)
	_effect_label.size = Vector2(w-16.0,25.0)

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w*0.5,h*0.34)
	var bob := sin(_age*2.6+float(get_instance_id()%7))*3.0
	var pulse := 0.5+0.5*sin(_age*3.0)
	var active := is_hovered() or is_pressed()
	var glow_alpha := 0.055+0.035*pulse
	if active:
		glow_alpha += 0.08
	# sombra del pedestal
	draw_ellipse(Vector2(w*0.5,h*0.70),Vector2(w*0.24,h*0.040),Color(0.0,0.0,0.0,0.36))
	# pedestal simple de piedra
	var foot := Rect2(w*0.31,h*0.64,w*0.38,h*0.095)
	draw_rect(Rect2(foot.position+Vector2(4,5),foot.size),Color(0.01,0.008,0.007,0.34))
	draw_rect(foot,Color(0.18,0.15,0.13))
	draw_rect(foot,Color(0.40,0.33,0.27),false,3.0)
	var column := Rect2(w*0.38,h*0.49,w*0.24,h*0.17)
	draw_rect(column,Color(0.21,0.18,0.15))
	draw_line(column.position+Vector2(3,2),Vector2(column.end.x-3,column.position.y+2),Color(0.48,0.40,0.31,0.54),2.0)
	var slab := PackedVector2Array([
		Vector2(w*0.27,h*0.46),
		Vector2(w*0.73,h*0.46),
		Vector2(w*0.67,h*0.53),
		Vector2(w*0.33,h*0.53)
	])
	draw_colored_polygon(slab,Color(0.32,0.27,0.22))
	draw_polyline(PackedVector2Array([slab[0],slab[1],slab[2],slab[3],slab[0]]),Color(0.52,0.43,0.32),3.0,true)
	draw_line(Vector2(w*0.31,h*0.47),Vector2(w*0.69,h*0.47),accent,3.0)
	# objeto como protagonista
	draw_circle(center+Vector2(0,bob),minf(w,h)*0.17,Color(accent,glow_alpha))
	draw_set_transform(Vector2(0,bob),0.0,Vector2.ONE)
	_draw_reward_icon(center,minf(w,h)*0.11)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if active:
		draw_arc(center+Vector2(0,bob),minf(w,h)*0.145,0.0,TAU,32,Color(accent,0.38),3.0)

func _draw_reward_icon(center: Vector2, radius: float) -> void:
	match reward_id:
		"vida":
			_draw_heart(center,radius)
		"curacion":
			_draw_bandage(center,radius)
		"proyectil":
			_draw_tear(center,radius)
		"dano":
			_draw_mark(center,radius)
		"cadencia":
			_draw_pulse(center,radius)
		"movimiento":
			_draw_step(center,radius)
		_:
			draw_circle(center,radius*0.58,accent)

func _draw_heart(center: Vector2, radius: float) -> void:
	var c := Color(0.78,0.055,0.08)
	draw_circle(center+Vector2(-radius*0.34,-radius*0.18),radius*0.42,c)
	draw_circle(center+Vector2(radius*0.34,-radius*0.18),radius*0.42,c)
	draw_colored_polygon(PackedVector2Array([
		center+Vector2(-radius*0.72,-radius*0.05),
		center+Vector2(radius*0.72,-radius*0.05),
		center+Vector2(0,radius*0.86)
	]),c)
	draw_circle(center+Vector2(-radius*0.33,-radius*0.28),radius*0.12,Color(1.0,0.70,0.66,0.72))

func _draw_bandage(center: Vector2, radius: float) -> void:
	var angle := -0.58
	var long := radius*1.40
	var thick := radius*0.48
	var dir := Vector2(cos(angle),sin(angle))
	var perp := Vector2(-dir.y,dir.x)
	var pts := PackedVector2Array([
		center-dir*long*0.5-perp*thick*0.5,
		center+dir*long*0.5-perp*thick*0.5,
		center+dir*long*0.5+perp*thick*0.5,
		center-dir*long*0.5+perp*thick*0.5
	])
	draw_colored_polygon(pts,Color(0.82,0.70,0.51))
	draw_circle(center-dir*long*0.32,radius*0.11,Color(0.54,0.39,0.27))
	draw_circle(center+dir*long*0.32,radius*0.11,Color(0.54,0.39,0.27))
	draw_rect(Rect2(center-Vector2(radius*0.22,radius*0.16),Vector2(radius*0.44,radius*0.32)),Color(0.91,0.82,0.65))

func _draw_tear(center: Vector2, radius: float) -> void:
	var pts := PackedVector2Array([
		center+Vector2(0,-radius),
		center+Vector2(radius*0.66,radius*0.12),
		center+Vector2(radius*0.46,radius*0.66),
		center+Vector2(0,radius*0.88),
		center+Vector2(-radius*0.46,radius*0.66),
		center+Vector2(-radius*0.66,radius*0.12)
	])
	draw_colored_polygon(pts,Color(0.25,0.62,0.91))
	draw_circle(center+Vector2(-radius*0.22,-radius*0.05),radius*0.16,Color(0.80,0.94,1.0,0.78))

func _draw_mark(center: Vector2, radius: float) -> void:
	draw_circle(center,radius*0.72,Color(0.24,0.025,0.035))
	draw_circle(center,radius*0.42,Color(0.78,0.065,0.08))
	draw_line(center+Vector2(-radius*0.78,0),center+Vector2(radius*0.78,0),Color(0.94,0.65,0.22),3.0)
	draw_line(center+Vector2(0,-radius*0.78),center+Vector2(0,radius*0.78),Color(0.94,0.65,0.22),3.0)

func _draw_pulse(center: Vector2, radius: float) -> void:
	draw_arc(center,radius*0.72,-2.7,2.7,28,Color(0.66,0.82,0.92),5.0)
	draw_line(center,center+Vector2(radius*0.48,-radius*0.30),Color(0.98,0.75,0.30),4.0)
	draw_circle(center,radius*0.10,Color(0.98,0.88,0.58))

func _draw_step(center: Vector2, radius: float) -> void:
	var pts := PackedVector2Array([
		center+Vector2(-radius*0.72,radius*0.32),
		center+Vector2(-radius*0.16,-radius*0.64),
		center+Vector2(radius*0.04,-radius*0.28),
		center+Vector2(radius*0.54,-radius*0.72),
		center+Vector2(radius*0.28,radius*0.22),
		center+Vector2(radius*0.70,radius*0.42),
		center+Vector2(-radius*0.12,radius*0.48)
	])
	draw_colored_polygon(pts,Color(0.74,0.70,0.48))
	draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[4],pts[5],pts[6],pts[0]]),Color(0.33,0.29,0.19),3.0,true)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
