extends Control
class_name IsmaelPresentationOverlay

var backdrop: ColorRect
var title_label: Label
var subtitle_label: Label
var _sequence_id := 0
var _boss_seal_variant := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	visible = false

	backdrop = ColorRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01,0.008,0.012,0.78)
	add_child(backdrop)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size",38)
	title_label.add_theme_color_override("font_color",Color(0.95,0.86,0.68))
	title_label.add_theme_color_override("font_outline_color",Color(0.015,0.01,0.012,1.0))
	title_label.add_theme_constant_override("outline_size",6)
	add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size",19)
	subtitle_label.add_theme_color_override("font_color",Color(0.72,0.66,0.58))
	subtitle_label.add_theme_color_override("font_outline_color",Color(0.015,0.01,0.012,1.0))
	subtitle_label.add_theme_constant_override("outline_size",4)
	add_child(subtitle_label)

	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var s := size
	title_label.position = Vector2(s.x*0.08,s.y*0.39)
	title_label.size = Vector2(s.x*0.84,58.0)
	subtitle_label.position = Vector2(s.x*0.10,s.y*0.49)
	subtitle_label.size = Vector2(s.x*0.80,44.0)

func present(title: String, subtitle: String, duration: float = 1.15, darkness: float = 0.64) -> void:
	_boss_seal_variant = 0
	queue_redraw()
	_sequence_id += 1
	var current_id := _sequence_id
	title_label.text = title
	subtitle_label.text = subtitle
	backdrop.color = Color(0.01,0.008,0.012,darkness)
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",1.0,0.16)
	tween.tween_interval(maxf(0.18,duration-0.34))
	tween.tween_property(self,"modulate:a",0.0,0.18)
	tween.finished.connect(func() -> void:
		if current_id == _sequence_id:
			visible = false
	)

func present_boss(title: String, omen: String, floor_number: int) -> void:
	present(title,omen,1.52,0.63)
	_boss_seal_variant = clampi(floor_number,1,5)
	queue_redraw()

func _draw() -> void:
	if _boss_seal_variant <= 0 or not visible:
		return
	var center := size*Vector2(0.5,0.67)
	var palette: Array[Color] = [
		Color(0.82,0.28,0.22),Color(0.96,0.52,0.21),Color(0.62,0.46,0.88),
		Color(0.48,0.77,0.80),Color(0.79,0.33,0.65)
	]
	var pigment: Color = palette[_boss_seal_variant-1]
	draw_circle(center,34.0,Color(0.02,0.009,0.013,0.73))
	draw_arc(center,34.0,0.0,TAU,48,Color(pigment.r,pigment.g,pigment.b,0.66),2.8)
	draw_arc(center,43.0,0.30,PI*1.65,48,Color(pigment.r,pigment.g,pigment.b,0.33),1.6)
	for i in range(_boss_seal_variant+2):
		var angle := TAU*float(i)/float(_boss_seal_variant+2)-PI*0.5
		var radial := Vector2.RIGHT.rotated(angle)
		draw_line(center+radial*18.0,center+radial*32.0,Color(pigment.r,pigment.g,pigment.b,0.85),2.8)
	if _boss_seal_variant == 3:
		draw_circle(center,10.0,Color(pigment.r,pigment.g,pigment.b,0.65))
		draw_circle(center,4.0,Color(0.05,0.012,0.03))
	elif _boss_seal_variant == 5:
		draw_circle(center,12.0,Color(0.012,0.005,0.018))
		draw_arc(center,13.0,0,TAU,28,Color(pigment.r,pigment.g,pigment.b,0.78),2.0)
	else:
		draw_colored_polygon(PackedVector2Array([
			center+Vector2(-9,-11),center+Vector2(9,-11),center+Vector2(0,15)
		]),Color(pigment.r,pigment.g,pigment.b,0.66))

func present_ending(title: String = "EL HUECO HA CAÍDO", subtitle: String = "ISMAEL ROMPIÓ EL ÚLTIMO SELLO") -> void:
	_sequence_id += 1
	var current_id := _sequence_id
	title_label.text = title
	subtitle_label.text = subtitle
	backdrop.color = Color(0.008,0.004,0.012,0.88)
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",1.0,0.40)
	tween.tween_interval(1.3)
	tween.tween_property(self,"modulate:a",0.0,0.55)
	tween.finished.connect(func() -> void:
		if current_id == _sequence_id:
			visible = false
	)
