extends Control
class_name IsmaelVictorySummary

# Pantalla compartida de victoria/derrota con historial de run legible en horizontal.
var _title: Label
var _subtitle: Label
var _stats: Label
var _items: Label
var _synergies: Label
var _unlocks: Label
var _restart: Button
var _stats_text := ""
var _items_text := ""
var _synergies_text := ""
var _unlocks_text := ""
var _ending_title := ""
var _ending_subtitle := ""
var _outcome := "VICTORIA"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 55
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _make_label(34,Color(1.0,0.84,0.57),HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle = _make_label(16,Color(0.78,0.70,0.63),HORIZONTAL_ALIGNMENT_CENTER)
	_stats = _make_label(18,Color(0.97,0.89,0.78),HORIZONTAL_ALIGNMENT_CENTER)
	_items = _make_label(15,Color(0.92,0.85,0.74),HORIZONTAL_ALIGNMENT_CENTER)
	_synergies = _make_label(14,Color(0.79,0.83,0.78),HORIZONTAL_ALIGNMENT_CENTER)
	_unlocks = _make_label(16,Color(1.0,0.83,0.51),HORIZONTAL_ALIGNMENT_CENTER)
	_restart = Button.new()
	_restart.text = "NUEVO RECORRIDO"
	_restart.focus_mode = Control.FOCUS_NONE
	_restart.add_theme_font_size_override("font_size",21)
	_restart.add_theme_color_override("font_color",Color(0.99,0.93,0.82))
	_restart.add_theme_color_override("font_hover_color",Color.WHITE)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.33,0.115,0.085,0.98)
	button_style.border_color = Color(0.90,0.59,0.32,1.0)
	button_style.set_border_width_all(3)
	button_style.set_corner_radius_all(12)
	button_style.set_content_margin_all(12.0)
	_restart.add_theme_stylebox_override("normal",button_style)
	var hover_style: StyleBoxFlat = button_style.duplicate()
	hover_style.bg_color = Color(0.49,0.17,0.11,1.0)
	_restart.add_theme_stylebox_override("hover",hover_style)
	_restart.add_theme_stylebox_override("pressed",hover_style)
	add_child(_restart)
	resized.connect(_layout)
	_layout()
	modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_interval(1.95)
	reveal.tween_property(self,"modulate:a",1.0,0.65)

func _make_label(font_size: int,tint: Color,alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_color_override("font_outline_color",Color(0.035,0.015,0.015,0.95))
	label.add_theme_constant_override("outline_size",4)
	add_child(label)
	return label

func configure_summary(ending_title: String,ending_subtitle: String,stats: Dictionary,items: String,synergies: String,unlocks: String,restart_action: Callable,outcome: String = "VICTORIA") -> void:
	_outcome = outcome
	_ending_title = ending_title
	_ending_subtitle = ending_subtitle
	_stats_text = "PISO %d     SALAS %d     BAJAS %d     TIEMPO %s     OBJETOS %d" % [
		int(stats.get("floor",1)),int(stats.get("rooms",0)),int(stats.get("kills",0)),
		String(stats.get("time","--:--")),int(stats.get("items",0))
	]
	_items_text = items
	_synergies_text = synergies
	_unlocks_text = unlocks
	if is_instance_valid(_restart):
		_restart.pressed.connect(restart_action)
		_restart.text = "REINTENTAR DESCENSO" if _outcome == "DERROTA" else "NUEVO RECORRIDO"
		_refresh_text()
		_layout()

func _refresh_text() -> void:
	_title.text = _ending_title
	_title.add_theme_color_override("font_color",Color(0.99,0.43,0.38) if _outcome == "DERROTA" else Color(1.0,0.84,0.57))
	_subtitle.text = _ending_subtitle
	_stats.text = _stats_text
	_items.text = ("RELIQUIAS DEL DESCENSO\n" if _outcome == "DERROTA" else "RELIQUIAS OBTENIDAS\n") + _items_text
	_synergies.text = "SINERGIAS: " + _synergies_text
	_unlocks.text = ("CRÓNICAS DEL DESCENSO\n" if _outcome == "DERROTA" else "DESBLOQUEOS Y RÉCORDS\n") + _unlocks_text

func _layout() -> void:
	if not is_instance_valid(_restart):
		return
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var left := s.x*0.14
	var width := s.x*0.72
	_title.position = Vector2(left,s.y*0.125)
	_title.size = Vector2(width,s.y*0.088)
	_subtitle.position = Vector2(left,s.y*0.216)
	_subtitle.size = Vector2(width,s.y*0.048)
	_stats.position = Vector2(left,s.y*0.309)
	_stats.size = Vector2(width,s.y*0.074)
	_items.position = Vector2(left,s.y*0.405)
	_items.size = Vector2(width,s.y*0.166)
	_synergies.position = Vector2(left,s.y*0.578)
	_synergies.size = Vector2(width,s.y*0.060)
	_unlocks.position = Vector2(left,s.y*0.640)
	_unlocks.size = Vector2(width,s.y*0.118)
	var button_w := minf(330.0,width*0.58)
	_restart.position = Vector2((s.x-button_w)*0.5,s.y*0.793)
	_restart.size = Vector2(button_w,clampf(s.y*0.095,60.0,76.0))
	queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO,s),Color(0.020,0.012,0.018,0.96))
	var panel := Rect2(s.x*0.095,s.y*0.065,s.x*0.81,s.y*0.885)
	draw_rect(panel,Color(0.075,0.035,0.039,0.96))
	draw_rect(panel,Color(0.55,0.30,0.19,0.92),false,2.0)
	draw_line(Vector2(s.x*0.19,s.y*0.285),Vector2(s.x*0.81,s.y*0.285),Color(0.68,0.36,0.22,0.85),2.0)
	draw_line(Vector2(s.x*0.19,s.y*0.755),Vector2(s.x*0.81,s.y*0.755),Color(0.68,0.36,0.22,0.65),2.0)
	var center := Vector2(s.x*0.5,s.y*0.14)
	for i in range(3):
		draw_arc(center,56.0+float(i)*17.0,0.0,TAU,56,Color(0.77,0.33,0.19,0.12-float(i)*0.02),2.0)
