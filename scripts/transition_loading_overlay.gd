extends CanvasLayer
class_name IsmaelTransitionLoadingOverlay

# Superposicion ligera, visible ANTES de tareas pesadas de pisos y salas.
# No depende de texturas ni fuentes externas; mantiene la estetica oscura.
var _screen: Control
var _title: Label
var _subtitle: Label
var _detail: Label
var _animation_time := 0.0
var _detail_base := ""

func _ready() -> void:
	layer = 90
	_screen = Control.new()
	_screen.name = "LoadingScreen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)

	var shade := ColorRect.new()
	shade.name = "DarkVeil"
	shade.color = Color(0.021,0.018,0.028,0.985)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(center)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation",15)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)

	var emblem := Label.new()
	emblem.text = "◆   I S M A E L   ◆"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_color_override("font_color",Color(0.64,0.49,0.37))
	emblem.add_theme_font_size_override("font_size",19)
	stack.add_child(emblem)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color",Color(0.95,0.88,0.73))
	_title.add_theme_font_size_override("font_size",30)
	stack.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color",Color(0.73,0.67,0.63))
	_subtitle.add_theme_font_size_override("font_size",16)
	stack.add_child(_subtitle)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_color_override("font_color",Color(0.55,0.48,0.45))
	_detail.add_theme_font_size_override("font_size",14)
	stack.add_child(_detail)
	hide_loading()

func show_room(floor_number: int, room_number: int, special_kind: String) -> void:
	_title.text = "CRUZANDO EL UMBRAL"
	_subtitle.text = "PISO %d  ·  SALA %d" % [floor_number,room_number]
	_detail_base = "Preparando el encuentro" if special_kind in ["jefe","minijefe","combate","desafio","emboscada"] else "Abriendo la camara"
	_activate()

func show_floor(floor_number: int, floor_name: String) -> void:
	_title.text = "DESCENDIENDO AL PISO %d" % floor_number
	_subtitle.text = floor_name.to_upper()
	_detail_base = "El siguiente nivel toma forma"
	_activate()

func _activate() -> void:
	_animation_time = 0.0
	_detail.text = _detail_base
	_screen.visible = true
	set_process(true)

func hide_loading() -> void:
	_screen.visible = false
	set_process(false)

func is_loading() -> bool:
	return is_instance_valid(_screen) and _screen.visible

func _process(delta: float) -> void:
	_animation_time += delta
	var dots: Array[String] = [".","..","..."]
	_detail.text = _detail_base+dots[int(_animation_time*3.0)%dots.size()]
