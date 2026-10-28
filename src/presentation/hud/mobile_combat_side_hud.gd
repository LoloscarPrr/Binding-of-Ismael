extends "res://scripts/combat_side_hud.gd"

# Presentation-only HUD for the Mobile Combat Frame.
# Reads run/player state and never mutates gameplay.

func set_layout(rect: Rect2, screen_size: Vector2) -> void:
	combat_rect = rect
	viewport_size = screen_size
	position = Vector2.ZERO
	size = screen_size

	# Keep the side columns narrow and centered inside the real exterior gutters.
	# On ultra-wide Redmi layouts the extra width remains breathing room instead of
	# stretching VIDA / STATS into oversized panels.
	var left_gutter := maxf(1.0,rect.position.x)
	var right_gutter := maxf(1.0,screen_size.x-rect.end.x)
	var left_width := clampf(left_gutter-20.0,112.0,184.0)
	var right_width := clampf(right_gutter-20.0,112.0,184.0)
	var left_x := maxf(6.0,(left_gutter-left_width)*0.5)
	var right_x := rect.end.x+maxf(6.0,(right_gutter-right_width)*0.5)
	var panel_inset_y := clampf(rect.size.y*0.035,12.0,22.0)
	var panel_y := rect.position.y+panel_inset_y
	var panel_h := maxf(190.0,rect.size.y-panel_inset_y*2.0)
	left_panel = Rect2(Vector2(left_x,panel_y),Vector2(left_width,panel_h))
	right_panel = Rect2(Vector2(right_x,panel_y),Vector2(right_width,panel_h))
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player) or combat_rect.size.x <= 1.0:
		return
	_draw_panel(left_panel,Color(0.52,0.30,0.18,0.52))
	_draw_panel(right_panel,Color(0.30,0.40,0.40,0.50))
	_draw_resources(left_panel)
	_draw_stats(right_panel)

# En las puertas laterales se conserva una franja completamente vacía.
# Sin fondos opacos ni marcos cruzando el umbral del cuarto.
func _door_clearance() -> float:
	return clampf(combat_rect.size.y*0.15,48.0,68.0)

func _door_upper_edge() -> float:
	return combat_rect.get_center().y-_door_clearance()

func _door_lower_edge() -> float:
	return combat_rect.get_center().y+_door_clearance()

func _draw_panel(rect: Rect2, accent: Color) -> void:
	var ink := Color(accent.r,accent.g,accent.b,0.38)
	var upper := minf(_door_upper_edge()-10.0,rect.end.y)
	var lower := maxf(_door_lower_edge()+10.0,rect.position.y)
	# El fondo es 100% transparente: solo dos marcas discretas en
	# los bordes superiores e inferiores del HUD, fuera de las puertas.
	draw_line(rect.position+Vector2(0,1),Vector2(rect.end.x,rect.position.y+1),ink,1.0)
	draw_line(Vector2(rect.position.x,upper),Vector2(rect.position.x,rect.position.y),ink,1.0)
	draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.end.x,upper),ink,1.0)
	draw_line(Vector2(rect.position.x,lower),Vector2(rect.position.x,rect.end.y),ink,1.0)
	draw_line(Vector2(rect.end.x,lower),Vector2(rect.end.x,rect.end.y),ink,1.0)
	draw_line(Vector2(rect.position.x,rect.end.y),rect.end,ink,1.0)

func _draw_resources(rect: Rect2) -> void:
	var width := rect.size.x
	var font_size := int(clampf(width*0.115,12.0,16.0))
	var value_size := int(clampf(width*0.155,15.0,21.0))
	_draw_text("VIDA %d/%d" % [player.health,player.max_health],Vector2(rect.position.x+9.0,rect.position.y+24.0),font_size,Color(0.94,0.80,0.73))

	var hearts_top := rect.position.y+54.0
	var hearts_bottom := minf(_door_upper_edge()-24.0,rect.position.y+174.0)
	_draw_hearts_fitted(rect,hearts_top,hearts_bottom)

	var inventory: Dictionary = {}
	if is_instance_valid(game) and game.has_method("get_run_inventory_snapshot"):
		inventory = game.call("get_run_inventory_snapshot")
	var coins := int(inventory.get("coins",0))
	var bombs := int(inventory.get("bombs",0))
	var keys := int(inventory.get("keys",0))
	var first_y := _door_lower_edge()+24.0
	var step := clampf((rect.end.y-first_y-20.0)/2.0,28.0,43.0)
	_draw_resource_row("coin",coins,rect,first_y,value_size)
	_draw_resource_row("bomb",bombs,rect,first_y+step,value_size)
	_draw_resource_row("key",keys,rect,first_y+step*2.0,value_size)

func _draw_hearts_fitted(rect: Rect2, top_y: float, bottom_y: float) -> void:
	var columns := 2 if rect.size.x < 108.0 else 3
	var gap_x := minf(34.0,(rect.size.x-22.0)/float(columns))
	var start_x := rect.get_center().x-gap_x*float(columns-1)*0.5
	var available_h := maxf(18.0,bottom_y-top_y)
	var max_rows := maxi(1,int(floor(available_h/23.0))+1)
	var shield_slots := mini(2,maxi(0,player.floor_shield_charges))
	var capacity := maxi(columns,columns*max_rows)
	var visible_red := mini(player.max_health,maxi(0,capacity-shield_slots))
	var count := visible_red+shield_slots
	var rows := maxi(1,int(ceil(float(count)/float(columns))))
	var gap_y := minf(26.0,available_h/float(maxi(1,rows-1))) if rows>1 else 0.0
	var heart_scale := clampf(minf(gap_x/38.0,gap_y/28.0 if rows>1 else 0.78),0.45,0.77)
	for i in range(count):
		var col := i%columns
		var row := i/columns
		var p := Vector2(start_x+col*gap_x,top_y+float(row)*gap_y)
		if i < visible_red:
			_draw_heart_scaled(p,i<player.health,heart_scale)
		else:
			_draw_temporary_heart(p,heart_scale)
	if player.max_health>visible_red:
		_draw_text("+%d" % (player.max_health-visible_red),Vector2(rect.position.x+9.0,bottom_y+15.0),10,Color(0.87,0.68,0.63))

func _draw_heart_scaled(p: Vector2, filled: bool, scale: float) -> void:
	var c := Color(0.78,0.06,0.08) if filled else Color(0.18,0.09,0.09)
	var edge := Color(0.98,0.40,0.38,0.76) if filled else Color(0.38,0.24,0.22,0.62)
	var lobe_offset := 6.5*scale
	var lobe_radius := 7.5*scale
	draw_circle(p+Vector2(-lobe_offset,-2.5*scale),lobe_radius,c)
	draw_circle(p+Vector2(lobe_offset,-2.5*scale),lobe_radius,c)
	draw_colored_polygon(PackedVector2Array([
		p+Vector2(-13.0*scale,0),
		p+Vector2(13.0*scale,0),
		p+Vector2(0,15.0*scale)
	]),c)
	draw_arc(p+Vector2(0,scale),16.0*scale,0.0,TAU,20,edge,maxf(1.0,1.4*scale))

# La protección es salud temporal AZUL, no una armadura dibujada
# alrededor del jugador. Su consumo no reduce los corazones rojos.
func _draw_temporary_heart(p: Vector2, scale: float) -> void:
	var fill := Color(0.18,0.62,0.96,0.98)
	var lobe := 7.5*scale
	draw_circle(p+Vector2(-6.5*scale,-2.5*scale),lobe,fill)
	draw_circle(p+Vector2(6.5*scale,-2.5*scale),lobe,fill)
	draw_colored_polygon(PackedVector2Array([
		p+Vector2(-13.0*scale,0.0),p+Vector2(13.0*scale,0.0),
		p+Vector2(0.0,15.0*scale)
	]),fill)
	draw_arc(p+Vector2(0,scale),16.0*scale,0.0,TAU,20,Color(0.75,0.95,1.0,0.94),1.6)
	draw_circle(p+Vector2(-4.5*scale,-4.0*scale),2.7*scale,Color(0.95,0.99,1.0,0.92))

func _draw_resource_row(kind: String, value: int, rect: Rect2, y: float, font_size: int) -> void:
	var icon_pos := Vector2(rect.position.x+23.0,y)
	match kind:
		"coin": _draw_coin(icon_pos)
		"bomb": _draw_bomb(icon_pos)
		"key": _draw_key(icon_pos)
	_draw_text("%02d" % value,Vector2(rect.position.x+46.0,y+7.0),font_size,Color(0.96,0.86,0.62))

func _draw_stats(rect: Rect2) -> void:
	var width := rect.size.x
	var font_size := int(clampf(width*0.112,12.0,16.0))
	var value_size := int(clampf(width*0.145,15.0,20.0))
	_draw_text("STATS",Vector2(rect.position.x+9.0,rect.position.y+24.0),font_size,Color(0.79,0.91,0.90))

	var damage_display := float(player.projectile_damage)*3.50
	var tears_display := 1.0/maxf(player.fire_rate,0.01)
	var shot_display := player.projectile_speed/760.0
	var move_display := player.move_speed/280.0
	var range_display := 6.50*(player.projectile_speed/760.0)
	var rows := [
		["damage",damage_display],["tears",tears_display],
		["shot",shot_display],["move",move_display],["range",range_display]
	]
	# Dos parámetros arriba, tres abajo; el área central de la
	# puerta lateral permanece libre de textos e iconos.
	var upper_step := clampf((_door_upper_edge()-rect.position.y-89.0)*0.68,31.0,41.0)
	for i in range(2):
		var entry = rows[i]
		_draw_stat_row(String(entry[0]),float(entry[1]),rect,rect.position.y+69.0+float(i)*upper_step,value_size)
	var first_lower := _door_lower_edge()+22.0
	var lower_step := clampf((rect.end.y-first_lower-24.0)/2.0,29.0,42.0)
	for i in range(2,rows.size()):
		var entry = rows[i]
		_draw_stat_row(String(entry[0]),float(entry[1]),rect,first_lower+float(i-2)*lower_step,value_size)
	var passive_entries := _passive_entries()
	if not passive_entries.is_empty():
		var line := String(passive_entries[0][0])
		if line.length() > 23:
			line = line.substr(0,21)+"…"
		_draw_text(line,Vector2(rect.position.x+9.0,rect.position.y+42.0),maxi(10,font_size-3),Color(0.90,0.77,0.47))

func _passive_entries() -> Array:
	var entries: Array = []
	if is_instance_valid(game) and game.has_method("get_build_summary"):
		var summary := String(game.call("get_build_summary"))
		if not summary.is_empty() and summary!="SIN BUILD":
			entries.append([summary,Color(0.86,0.76,0.42)])
	if player.volley_count>1:
		entries.append(["VOL x%d" % player.volley_count,Color(0.60,0.78,0.92)])
	if player.burst_count>1:
		entries.append(["RÁF x%d" % player.burst_count,Color(0.78,0.54,0.34)])
	if player.homing_strength>0.0:
		entries.append(["OJO",Color(0.62,0.75,0.42)])
	if player.projectile_pierce>0:
		entries.append(["AGUJA",Color(0.78,0.78,0.72)])
	if player.projectile_split_count>0:
		entries.append(["FRAG x%d" % player.projectile_split_count,Color(0.72,0.62,0.90)])
	if is_instance_valid(game) and game.has_method("get_active_synergy_names"):
		var names: Array = game.call("get_active_synergy_names")
		for i in range(mini(2,names.size())):
			entries.append(["★ "+String(names[i]),Color(0.94,0.68,0.30)])
	if entries.size()>6:
		entries.resize(6)
	return entries

func _draw_stat_row(kind: String, value: float, rect: Rect2, y: float, font_size: int) -> void:
	var icon := Vector2(rect.position.x+22.0,y)
	match kind:
		"damage": _draw_eye(icon)
		"tears": _draw_clock(icon)
		"shot": _draw_tear(icon)
		"move": _draw_boot(icon)
		"range": _draw_range(icon)
	_draw_text("%.2f" % value,Vector2(rect.position.x+44.0,y+7.0),font_size,Color(0.90,0.88,0.78))
	draw_line(Vector2(rect.position.x+9.0,y+27.0),Vector2(rect.end.x-9.0,y+27.0),Color(0.70,0.76,0.74,0.10),1.0)