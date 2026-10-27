extends Control
class_name IsmaelGameShell

const BossSeals = preload("res://src/domain/run/boss_seal_catalog.gd")

# Capa de navegación móvil. El juego se pausa realmente: enemigos, bombas,
# proyectiles y transiciones no siguen avanzando detrás del menú.
var _game
var _progress
var _audio: Node
var _started := false
var _page := "inicio"
var _modal: Control
var _shade: ColorRect
var _panel: Panel
var _pause_button: Button
var _heading: Label
var _subheading: Label
var _footer: Label
var _history: RichTextLabel
var _ambient_slider: HSlider
var _effects_slider: HSlider
var _ambient_label: Label
var _effects_label: Label
var _page_buttons: Dictionary = {}
var _audio_ready := false
var _total_paused_msec := 0
var _paused_at_msec := -1

func configure(game: Node, progress, audio: Node) -> void:
	_game = game
	_progress = progress
	_audio = audio

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 70
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_button = _make_button(self, "II  PAUSA", _open_pause)
	_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_modal = Control.new()
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.color = Color(0.018,0.014,0.019,0.975)
	_modal.add_child(_shade)
	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.095,0.050,0.052,0.98)
	surface.border_color = Color(0.66,0.35,0.21,0.95)
	surface.set_border_width_all(2)
	surface.set_corner_radius_all(15)
	_panel.add_theme_stylebox_override("panel",surface)
	_modal.add_child(_panel)
	_heading = _make_label(36,Color(1.0,0.85,0.61))
	_subheading = _make_label(16,Color(0.82,0.74,0.65))
	_footer = _make_label(14,Color(0.74,0.73,0.69))
	_history = RichTextLabel.new()
	_history.mouse_filter = Control.MOUSE_FILTER_STOP
	_history.scroll_active = true
	_history.add_theme_font_size_override("normal_font_size",17)
	_history.add_theme_color_override("default_color",Color(0.91,0.83,0.73))
	_modal.add_child(_history)
	_ambient_label = _make_label(19,Color(0.93,0.83,0.66))
	_effects_label = _make_label(19,Color(0.93,0.83,0.66))
	_ambient_slider = _make_slider()
	_effects_slider = _make_slider()
	_page_buttons["inicio"] = [
		_make_button(_modal,"COMENZAR DESCENSO",_start_or_resume),
		_make_button(_modal,"CRÓNICAS DEL DESCENSO",func(): _navigate("cronicas")),
		_make_button(_modal,"CÓDICE DE LOS CINCO SELLOS",func(): _navigate("codice")),
		_make_button(_modal,"AJUSTES DE AUDIO",func(): _navigate("ajustes"))
	]
	_page_buttons["pausa"] = [
		_make_button(_modal,"CONTINUAR",_start_or_resume),
		_make_button(_modal,"CRÓNICAS DEL DESCENSO",func(): _navigate("cronicas")),
		_make_button(_modal,"CÓDICE DE LOS CINCO SELLOS",func(): _navigate("codice")),
		_make_button(_modal,"AJUSTES DE AUDIO",func(): _navigate("ajustes")),
		_make_button(_modal,"VOLVER AL MENÚ",func(): _navigate("inicio"))
	]
	_page_buttons["codice"] = [
		_make_button(_modal,"VOLVER",_go_back)
	]
	_page_buttons["cronicas"] = [
		_make_button(_modal,"VOLVER",_go_back)
	]
	_page_buttons["ajustes"] = [
		_make_button(_modal,"VOLVER",_go_back)
	]
	if is_instance_valid(_audio):
		_ambient_slider.value = float(_audio.get("ambience_level")) * 100.0
		_effects_slider.value = float(_audio.get("sfx_level")) * 100.0
	_ambient_slider.value_changed.connect(_on_audio_changed)
	_effects_slider.value_changed.connect(_on_audio_changed)
	_audio_ready = true
	resized.connect(_layout)
	_paused_at_msec = Time.get_ticks_msec()
	_navigate("inicio")
	get_tree().paused = true
	_layout()

func _make_label(font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",ink)
	label.add_theme_color_override("font_outline_color",Color(0.015,0.009,0.012))
	label.add_theme_constant_override("outline_size",4)
	_modal.add_child(label)
	return label

func _make_button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",19)
	button.add_theme_color_override("font_color",Color(0.98,0.90,0.77))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.19,0.095,0.084,0.99)
	style.border_color = Color(0.59,0.36,0.26)
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	style.set_content_margin_all(11)
	button.add_theme_stylebox_override("normal",style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color(0.34,0.15,0.11,1.0)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _make_slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = 100
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(slider)
	return slider

func _navigate(target: String) -> void:
	_page = target
	_modal.visible = true
	_pause_button.visible = false
	if target == "inicio":
		var buttons: Array = _page_buttons["inicio"]
		buttons[0].text = "CONTINUAR DESCENSO" if _started else "COMENZAR DESCENSO"
	match target:
		"inicio":
			_heading.text = "BINDING OF ISMAEL"
			_subheading.text = "CINCO PISOS · TRES DESTINOS · UNA VIDA"
		"pausa":
			_heading.text = "DESCENSO INTERRUMPIDO"
			_subheading.text = "El sótano puede esperar."
		"cronicas":
			_heading.text = "CRÓNICAS DEL DESCENSO"
			_subheading.text = "Cada caída deja una marca."
		"codice":
			_heading.text = "CÓDICE DE LOS CINCO SELLOS"
			_subheading.text = "Derrota guardianes para revelar sus secretos."
		_:
			_heading.text = "AJUSTES DE AUDIO"
			_subheading.text = "Los ajustes se guardan automáticamente."
	_footer.text = _progress.summary_text() if _progress != null else ""
	for name in _page_buttons.keys():
		for button in _page_buttons[name]:
			button.visible = name == target
	_history.visible = target in ["cronicas","codice"]
	_ambient_slider.visible = target == "ajustes"
	_effects_slider.visible = target == "ajustes"
	_ambient_label.visible = target == "ajustes"
	_effects_label.visible = target == "ajustes"
	if target == "cronicas":
		_refresh_history()
	if target == "codice":
		_refresh_codex()
	if target == "ajustes":
		_refresh_audio_labels()
	_layout()
	get_tree().paused = true

func _refresh_history() -> void:
	if _progress == null:
		_history.text = "SIN HISTORIAL DISPONIBLE"
		return
	var content: String = _progress.records_text() + "\n\n"
	if _progress.recent_runs.is_empty():
		content += "AÚN NO HAY PARTIDAS REGISTRADAS.\n¡EMPIEZA UN DESCENSO!"
	else:
		content += "ÚLTIMOS RECORRIDOS\n\n"
		var entries: Array = _progress.recent_runs
		for i in range(entries.size()-1,-1,-1):
			var run: Dictionary = entries[i]
			var seconds := maxi(0,int(run.get("seconds",0)))
			content += "%s  ·  P%d  ·  %02d:%02d  ·  %d bajas  ·  %d salas\n" % [
				String(run.get("result","PARTIDA")),
				int(run.get("floor",1)),int(seconds/60),seconds%60,
				int(run.get("kills",0)),int(run.get("rooms",0))
			]
	content += "\nECOS DE LOS GUARDIANES · %d/5 PISOS VENCIDOS\n" % _progress.guardian_echo_floors_completed()
	for floor_number in range(1,6):
		var record := int(_progress.guardian_echo_victories.get(str(floor_number),0))
		if record > 0:
			content += "P%d · %d PRUEBAS SUPERADAS\n" % [floor_number,record]
	content += "\nSECRETOS DE LA FASE 11.5\n"
	content += "CRIPTAS REVELADAS · %d\n" % _progress.secret_vaults_opened
	content += "ANOMALÍAS SUPERADAS · %d\n" % _progress.anomalies_cleared
	content += "\nDESBLOQUEOS DEL DESCENSO\n"
	var milestones: Array[Dictionary] = [
		{"id":"santuario_eco","title":"CÁMARA DEL ECO","requirement":"Completa un recorrido"},
		{"id":"eco_fragil","title":"ESQUIRLA DEL ECO","requirement":"Llega al piso 3"},
		{"id":"reloj_ceniza","title":"RELOJ DE CENIZA","requirement":"Resuelve 2 eventos"},
		{"id":"colmillo_ritual","title":"COLMILLO RITUAL","requirement":"Sella 3 pactos"},
		{"id":"corona_del_eco","title":"CORONA DEL ECO","requirement":"Supera 3 pruebas del Eco"},
		{"id":"testigo_cinco_ecos","title":"TESTIGO DE LOS CINCO ECOS","requirement":"Vence a los Ecos de los cinco pisos · +1 llave al iniciar"},
		{"id":"criptas_ocultas","title":"CRIPTAS DEL DESCENSO","requirement":"Completa un recorrido para descubrir criptas ocultas"},
		{"id":"anomalias_del_descenso","title":"ANOMALÍAS","requirement":"Completa un recorrido para activar desafíos variables"},
		{"id":"sello_del_cartografo","title":"SELLO DEL CARTÓGRAFO","requirement":"Revela 3 criptas y supera 3 anomalías · +1 bomba al iniciar"}
	]
	for milestone in milestones:
		var is_unlocked: bool = _progress.has_unlock(String(milestone["id"]))
		content += ("%s " % ("[LISTO]" if is_unlocked else "[CERRADO]"))
		content += String(milestone["title"])
		if not is_unlocked:
			content += " · " + String(milestone["requirement"])
		content += "\n"
	_history.text = content

func _refresh_codex() -> void:
	if _progress == null:
		_history.text = "NO HAY PERFIL DISPONIBLE"
		return
	var text_value := "LOS CINCO SELLOS · %d/5 DESCUBIERTOS\n\n" % _progress.boss_seals_discovered()
	for floor_number in range(1,6):
		text_value += BossSeals.codex_entry(floor_number,_progress.boss_defeat_count(floor_number))
		text_value += "\n"
	if _progress.has_unlock("cronicas_cinco_sellos"):
		text_value += "LOS CINCO SELLOS HAN SIDO ROTOS.\n"
		text_value += "Ya conoces a los custodios del Abismo.\n"
	_history.text = text_value

func _on_audio_changed(_value: float) -> void:
	if not _audio_ready:
		return
	if is_instance_valid(_audio):
		_audio.call("set_audio_levels",_ambient_slider.value / 100.0,_effects_slider.value / 100.0)
	_refresh_audio_labels()

func _refresh_audio_labels() -> void:
	_ambient_label.text = "AMBIENTE  %d%%" % int(_ambient_slider.value)
	_effects_label.text = "EFECTOS  %d%%" % int(_effects_slider.value)

func _start_or_resume() -> void:
	_finish_pause_interval()
	_started = true
	_modal.visible = false
	_pause_button.visible = true
	get_tree().paused = false

func _finish_pause_interval() -> void:
	if _paused_at_msec >= 0:
		_total_paused_msec += maxi(0,Time.get_ticks_msec()-_paused_at_msec)
		_paused_at_msec = -1

func get_paused_duration_msec() -> int:
	var running := maxi(0,Time.get_ticks_msec()-_paused_at_msec) if _paused_at_msec >= 0 else 0
	return _total_paused_msec + running

func _open_pause() -> void:
	if not _started or not is_instance_valid(_game):
		return
	if bool(_game.get("_game_over")) or bool(_game.get("_run_complete")):
		return
	var actor = _game.get("player")
	if is_instance_valid(actor):
		actor.set("move_input",Vector2.ZERO)
		actor.set("aim_input",Vector2.ZERO)
	for control_name in ["left_stick","right_stick"]:
		var control = _game.get(control_name)
		if is_instance_valid(control) and control.has_method("reset"):
			control.call("reset")
	_paused_at_msec = Time.get_ticks_msec()
	_navigate("pausa")

func _go_back() -> void:
	_navigate("pausa" if _started else "inicio")

func hide_for_game_end() -> void:
	_finish_pause_interval()
	_modal.visible = false
	_pause_button.visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not _modal.visible:
				_open_pause()
			elif _page in ["ajustes","cronicas","codice"]:
				_go_back()
			elif _page == "pausa":
				_start_or_resume()
			get_viewport().set_input_as_handled()

func _layout() -> void:
	if not is_instance_valid(_panel):
		return
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	_shade.position = Vector2.ZERO
	_shade.size = s
	var px := s.x*0.16
	var py := s.y*0.065
	var pw := s.x*0.68
	var ph := s.y*0.87
	_panel.position = Vector2(px,py)
	_panel.size = Vector2(pw,ph)
	_heading.position = Vector2(px+24,py+ph*0.075)
	_heading.size = Vector2(pw-48,ph*0.12)
	_subheading.position = Vector2(px+24,py+ph*0.19)
	_subheading.size = Vector2(pw-48,ph*0.065)
	_footer.position = Vector2(px+22,py+ph*0.91)
	_footer.size = Vector2(pw-44,ph*0.06)
	_pause_button.position = Vector2(12,12)
	_pause_button.size = Vector2(116,38)
	_pause_button.add_theme_font_size_override("font_size",16)
	var button_w := minf(430.0,pw*0.70)
	var bx := px+(pw-button_w)*0.5
	if _page == "inicio" or _page == "pausa":
		var buttons: Array = _page_buttons[_page]
		var button_h := clampf(ph*0.085,33.0,50.0)
		var gap := maxf(6.0,ph*0.018)
		var y := py+ph*0.31
		for button in buttons:
			button.position = Vector2(bx,y)
			button.size = Vector2(button_w,button_h)
			y += button_h+gap
	elif _page == "ajustes":
		_ambient_label.position = Vector2(bx,py+ph*0.34)
		_ambient_label.size = Vector2(button_w,38)
		_ambient_slider.position = Vector2(bx,py+ph*0.415)
		_ambient_slider.size = Vector2(button_w,40)
		_effects_label.position = Vector2(bx,py+ph*0.54)
		_effects_label.size = Vector2(button_w,38)
		_effects_slider.position = Vector2(bx,py+ph*0.615)
		_effects_slider.size = Vector2(button_w,40)
		var back: Button = _page_buttons["ajustes"][0]
		back.position = Vector2(bx,py+ph*0.765)
		back.size = Vector2(button_w,55)
	elif _page in ["cronicas","codice"]:
		_history.position = Vector2(px+pw*0.105,py+ph*0.31)
		_history.size = Vector2(pw*0.79,ph*0.44)
		var back: Button = _page_buttons[_page][0]
		back.position = Vector2(bx,py+ph*0.785)
		back.size = Vector2(button_w,55)

func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
