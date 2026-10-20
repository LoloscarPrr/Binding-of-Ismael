extends Control
class_name IsmaelPresentationOverlay

var backdrop: ColorRect
var title_label: Label
var subtitle_label: Label
var _sequence_id := 0

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
