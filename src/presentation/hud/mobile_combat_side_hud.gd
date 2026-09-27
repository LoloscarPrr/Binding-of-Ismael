extends "res://scripts/combat_side_hud.gd"

# Presentation-only HUD for the Mobile Combat Frame.
# Reads run/player state and never mutates gameplay.

func set_layout(rect: Rect2, screen_size: Vector2) -> void:
	combat_rect = rect
	viewport_size = screen_size
	position = Vector2.ZERO
	size = screen_size
	var outer_gap := clampf(screen_size.x*0.0045,5.0,8.0)
	var left_width := maxf(82.0,rect.position.x-outer_gap*2.0)
	var right_width := maxf(82.0,screen_size.x-rect.end.x-outer_gap*2.0)
	var panel_y := rect.position.y+6.0
	var panel_h := maxf(190.0,rect.size.y-12.0)
	left_panel = Rect2(Vector2(outer_gap,panel_y),Vector2(left_width,panel_h))
	right_panel = Rect2(Vector2(rect.end.x+outer_gap,panel_y),Vector2(right_width,panel_h))
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player) or combat_rect.size.x <= 1.0:
		return
	_draw_panel(left_panel,Color(0.52,0.30,0.18,0.52))
	_draw_panel(right_panel,Color(0.30,0.40,0.40,0.50))
	_draw_resources(left_panel)
	_draw_stats(right_panel)

func _draw_panel(rect: Rect2, accent: Color) -> void:
	draw_rect(rect,Color(0.014,0.013,0.012,0.68))
	draw_rect(rect,accent,false,1.5)

func _draw_resources(rect: Rect2) -> void:
	var width := rect.size.x
	var font_size := int(clampf(width*0.115,12.0,16.0))
	var value_size := int(clampf(width*0.155,15.0,21.0))
	var header_y := rect.position.y+24.0
	_draw_text("VIDA %d/%d" % [player.health,player.max_health],Vector2(rect.position.x+9.0,header_y),font_size,Color(0.90,0.76,0.66))

	var shield_reserved := 48.0 if player.floor_shield_enabled else 14.0
	var row_gap := clampf(rect.size.y*0.145,56.0,64.0)
	var last_row_y := rect.end.y-shield_reserved-18.0
	var first_row_y := last_row_y-row_gap*2.0
	var hearts_top := rect.position.y+47.0
	var hearts_bottom := first_row_y-26.0
	_draw_hearts_fitted(rect,hearts_top,hearts_bottom)

	var inventory := {}
	if is_instance_valid(game) and game.has_method("get_run_inventory_snapshot"):
		inventory = game.call("get_run_inventory_snapshot")
	var coins := int(inventory.get("coins",0))
	var bombs := int(inventory.get("bombs",0))
	var keys := int(inventory.get("keys",0))
	_draw_resource_row("coin",coins,rect,first_row_y,value_size)
	_draw_resource_row("bomb",bombs,rect,first_row_y+row_gap,value_size)
	_draw_resource_row("key",keys,rect,last_row_y,value_size)

	if player.floor_shield_enabled:
		var shield_y := rect.end.y-25.0
		_draw_text("ESC",Vector2(rect.position.x+8.0,shield_y+5.0),maxi(10,font_size-2),Color(0.66,0.75,0.79))
		_draw_shield_icon(Vector2(rect.end.x-23.0,shield_y),player.floor_shield_charges>0)

func _draw_hearts_fitted(rect: Rect2, top_y: float, bottom_y: float) -> void:
	var columns := 2 if rect.size.x < 108.0 else 3
	var gap_x := minf(35.0,(rect.size.x-22.0)/float(columns))
	var start_x := rect.get_center().x-gap_x*float(columns-1)*0.5
	var available_h := maxf(24.0,bottom_y-top_y)
	var min_gap_y := 21.0
	var max_rows := maxi(1,int(floor(available_h/min_gap_y))+1)
	var capacity := maxi(columns,columns*max_rows)
	var visible_count := mini(player.max_health,capacity)
	var rows := maxi(1,int(ceil(float(visible_count)/float(columns))))
	var gap_y := minf(27.0,available_h/float(maxi(1,rows-1))) if rows>1 else 0.0
	var scale_from_y := gap_y/28.0 if rows>1 else 0.78
	var heart_scale := clampf(minf(gap_x/38.0,scale_from_y),0.48,0.78)
	for i in range(visible_count):
		var col := i%columns
		var row := i/columns
		var p := Vector2(start_x+col*gap_x,top_y+float(row)*gap_y)
		_draw_heart_scaled(p,i<player.health,heart_scale)
	if player.max_health>visible_count:
		_draw_text("+%d" % (player.max_health-visible_count),Vector2(rect.position.x+9.0,bottom_y+16.0),11,Color(0.80,0.66,0.60))

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
	_draw_text("STATS",Vector2(rect.position.x+9.0,rect.position.y+24.0),font_size,Color(0.70,0.80,0.80))

	var damage_display := float(player.projectile_damage)*3.50
	var tears_display := 1.0/maxf(player.fire_rate,0.01)
	var shot_display := player.projectile_speed/760.0
	var move_display := player.move_speed/280.0
	var range_display := 6.50*(player.projectile_speed/760.0)
	var rows := [
		["damage",damage_display],
		["tears",tears_display],
		["shot",shot_display],
		["move",move_display],
		["range",range_display]
	]

	var passive_entries := _passive_entries()
	var passive_reserved := 14.0
	if not passive_entries.is_empty():
		passive_reserved = 31.0+float(passive_entries.size())*18.0
	var first_y := rect.position.y+65.0
	var last_y := rect.end.y-passive_reserved-22.0
	var row_gap := clampf((last_y-first_y)/4.0,54.0,66.0)
	for i in range(rows.size()):
		var row = rows[i]
		_draw_stat_row(String(row[0]),float(row[1]),rect,first_y+row_gap*float(i),value_size)

	if not passive_entries.is_empty():
		var passive_y := rect.end.y-passive_reserved+13.0
		_draw_text("PASIVOS",Vector2(rect.position.x+9.0,passive_y),maxi(10,font_size-2),Color(0.62,0.70,0.68))
		passive_y += 18.0
		for entry in passive_entries:
			_draw_text(String(entry[0]),Vector2(rect.position.x+10.0,passive_y),maxi(10,font_size-3),entry[1])
			passive_y += 18.0

func _passive_entries() -> Array:
	var entries: Array = []
	if player.homing_strength>0.0:
		entries.append(["OJO",Color(0.62,0.75,0.42)])
	if player.projectile_pierce>0:
		entries.append(["AGUJA",Color(0.78,0.78,0.72)])
	if player.burst_count>1:
		entries.append(["RÁF x%d" % player.burst_count,Color(0.78,0.54,0.34)])
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
