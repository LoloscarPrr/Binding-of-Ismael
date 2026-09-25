extends Control
class_name IsmaelCombatSideHud

var game: Node
var player: IsmaelPlayer
var combat_rect := Rect2()
var viewport_size := Vector2.ZERO
var left_panel := Rect2()
var right_panel := Rect2()
var _age := 0.0

func configure(game_ref: Node, player_ref: IsmaelPlayer) -> void:
	game = game_ref
	player = player_ref
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()

func set_layout(rect: Rect2, screen_size: Vector2) -> void:
	combat_rect = rect
	viewport_size = screen_size
	position = Vector2.ZERO
	size = screen_size
	var outer_gap := 10.0
	var left_width := maxf(74.0,rect.position.x-outer_gap*2.0)
	var right_width := maxf(74.0,screen_size.x-rect.end.x-outer_gap*2.0)
	var panel_y := rect.position.y+8.0
	var panel_h := maxf(180.0,rect.size.y-16.0)
	left_panel = Rect2(Vector2(outer_gap,panel_y),Vector2(left_width,panel_h))
	right_panel = Rect2(Vector2(rect.end.x+outer_gap,panel_y),Vector2(right_width,panel_h))
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player) or combat_rect.size.x <= 1.0:
		return
	_draw_panel(left_panel,Color(0.52,0.30,0.18,0.58))
	_draw_panel(right_panel,Color(0.30,0.40,0.40,0.56))
	_draw_resources(left_panel)
	_draw_stats(right_panel)

func _draw_panel(rect: Rect2, accent: Color) -> void:
	draw_rect(rect,Color(0.018,0.016,0.015,0.76))
	draw_rect(rect,accent,false,2.0)
	draw_line(rect.position+Vector2(8,5),Vector2(rect.end.x-8,rect.position.y+5),Color(accent.r,accent.g,accent.b,0.28),2.0)
	draw_line(Vector2(rect.position.x+8,rect.end.y-5),rect.end-Vector2(8,5),Color(0,0,0,0.36),2.0)

func _draw_resources(rect: Rect2) -> void:
	var width := rect.size.x
	var font_size := int(clampf(width*0.105,13.0,18.0))
	var value_size := int(clampf(width*0.145,16.0,23.0))
	var title_pos := Vector2(rect.position.x+10.0,rect.position.y+25.0)
	_draw_text("RECURSOS",title_pos,font_size,Color(0.86,0.70,0.48))
	var y := rect.position.y+52.0
	_draw_text("VIDA",Vector2(rect.position.x+10.0,y),font_size,Color(0.88,0.76,0.64))
	y += 19.0
	_draw_hearts(rect,y)
	y += 78.0
	var coins := int(game.get("_coins")) if is_instance_valid(game) else 0
	var bombs := int(game.get("_bombs")) if is_instance_valid(game) else 0
	var keys := int(game.get("_keys")) if is_instance_valid(game) else 0
	_draw_resource_row("coin",coins,rect,y,value_size)
	y += 52.0
	_draw_resource_row("bomb",bombs,rect,y,value_size)
	y += 52.0
	_draw_resource_row("key",keys,rect,y,value_size)
	if player.floor_shield_enabled:
		y += 58.0
		_draw_text("ESCUDO",Vector2(rect.position.x+10.0,y),font_size,Color(0.70,0.78,0.82))
		_draw_shield_icon(Vector2(rect.get_center().x,y+28.0),player.floor_shield_charges>0)

func _draw_hearts(rect: Rect2, top_y: float) -> void:
	var columns := 3 if rect.size.x >= 120.0 else 2
	var gap_x := minf(40.0,(rect.size.x-24.0)/float(columns))
	var start_x := rect.get_center().x-gap_x*float(columns-1)*0.5
	var gap_y := 31.0
	for i in range(player.max_health):
		var col := i%columns
		var row := i/columns
		var p := Vector2(start_x+col*gap_x,top_y+row*gap_y)
		var filled := i < player.health
		_draw_heart(p,filled)

func _draw_resource_row(kind: String, value: int, rect: Rect2, y: float, font_size: int) -> void:
	var icon_pos := Vector2(rect.position.x+28.0,y)
	match kind:
		"coin": _draw_coin(icon_pos)
		"bomb": _draw_bomb(icon_pos)
		"key": _draw_key(icon_pos)
	_draw_text("%02d" % value,Vector2(rect.position.x+52.0,y+7.0),font_size,Color(0.96,0.86,0.62))

func _draw_stats(rect: Rect2) -> void:
	var width := rect.size.x
	var font_size := int(clampf(width*0.105,13.0,18.0))
	var value_size := int(clampf(width*0.125,15.0,21.0))
	_draw_text("STATS",Vector2(rect.position.x+10.0,rect.position.y+25.0),font_size,Color(0.70,0.80,0.80))
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
	var y := rect.position.y+65.0
	for row in rows:
		_draw_stat_row(String(row[0]),float(row[1]),rect,y,value_size)
		y += 52.0
	var passive_y := rect.end.y-116.0
	if player.homing_strength>0.0 or player.projectile_pierce>0 or player.burst_count>1:
		_draw_text("PASIVOS",Vector2(rect.position.x+10.0,passive_y),font_size,Color(0.64,0.70,0.68))
		passive_y += 28.0
		if player.homing_strength>0.0:
			_draw_text("OJO",Vector2(rect.position.x+12.0,passive_y),font_size,Color(0.62,0.75,0.42))
			passive_y += 23.0
		if player.projectile_pierce>0:
			_draw_text("AGUJA",Vector2(rect.position.x+12.0,passive_y),font_size,Color(0.78,0.78,0.72))
			passive_y += 23.0
		if player.burst_count>1:
			_draw_text("RÁFAGA x%d" % player.burst_count,Vector2(rect.position.x+12.0,passive_y),font_size,Color(0.78,0.54,0.34))

func _draw_stat_row(kind: String, value: float, rect: Rect2, y: float, font_size: int) -> void:
	var icon := Vector2(rect.position.x+28.0,y)
	match kind:
		"damage": _draw_eye(icon)
		"tears": _draw_clock(icon)
		"shot": _draw_tear(icon)
		"move": _draw_boot(icon)
		"range": _draw_range(icon)
	var decimals := 2
	_draw_text(("%.*f" % [decimals,value]),Vector2(rect.position.x+52.0,y+7.0),font_size,Color(0.90,0.88,0.78))

func _draw_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font,pos+Vector2(2,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,0.76))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_heart(p: Vector2, filled: bool) -> void:
	var c := Color(0.78,0.06,0.08) if filled else Color(0.18,0.09,0.09)
	var edge := Color(0.98,0.40,0.38,0.76) if filled else Color(0.38,0.24,0.22,0.62)
	draw_circle(p+Vector2(-7,-3),8.0,c)
	draw_circle(p+Vector2(7,-3),8.0,c)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-14,0),p+Vector2(14,0),p+Vector2(0,17)]),c)
	draw_arc(p+Vector2(0,1),18.0,0.0,TAU,24,edge,1.5)

func _draw_coin(p: Vector2) -> void:
	draw_circle(p,13.0,Color(0.91,0.66,0.12))
	draw_circle(p,8.5,Color(0.56,0.35,0.07),false,2.5)
	draw_line(p+Vector2(-2,-7),p+Vector2(-2,7),Color(1.0,0.86,0.40,0.78),2.0)

func _draw_bomb(p: Vector2) -> void:
	draw_circle(p,13.0,Color(0.10,0.105,0.12))
	draw_arc(p,13.0,0.0,TAU,24,Color(0.40,0.42,0.45),2.5)
	draw_line(p+Vector2(7,-9),p+Vector2(14,-17),Color(0.48,0.31,0.14),3.0)
	draw_circle(p+Vector2(16,-19),2.8,Color(0.92,0.38,0.08))

func _draw_key(p: Vector2) -> void:
	var c := Color(0.86,0.72,0.32)
	draw_circle(p+Vector2(-6,0),8.0,c,false,4.0)
	draw_line(p+Vector2(2,0),p+Vector2(16,0),c,5.0)
	draw_line(p+Vector2(10,0),p+Vector2(10,7),c,4.0)
	draw_line(p+Vector2(15,0),p+Vector2(15,5),c,3.0)

func _draw_eye(p: Vector2) -> void:
	var pts := PackedVector2Array([p+Vector2(-16,0),p+Vector2(-8,-8),p+Vector2(0,-11),p+Vector2(8,-8),p+Vector2(16,0),p+Vector2(8,8),p+Vector2(0,11),p+Vector2(-8,8)])
	draw_colored_polygon(pts,Color(0.82,0.76,0.68))
	draw_circle(p,6.0,Color(0.72,0.10,0.08))
	draw_circle(p,3.0,Color(0.03,0.025,0.025))

func _draw_clock(p: Vector2) -> void:
	draw_circle(p,12.0,Color(0.50,0.47,0.41))
	draw_circle(p,9.0,Color(0.10,0.10,0.10))
	draw_line(p,p+Vector2(0,-7),Color(0.94,0.72,0.26),2.5)
	draw_line(p,p+Vector2(6,3),Color(0.94,0.72,0.26),2.5)

func _draw_tear(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-15),p+Vector2(10,3),p+Vector2(7,11),p+Vector2(0,15),p+Vector2(-7,11),p+Vector2(-10,3)]),Color(0.30,0.66,0.92))
	draw_circle(p+Vector2(-3,-2),2.5,Color(0.84,0.96,1.0,0.80))

func _draw_boot(p: Vector2) -> void:
	var c := Color(0.43,0.28,0.17)
	draw_rect(Rect2(p+Vector2(-7,-14),Vector2(9,17)),c)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-7,0),p+Vector2(3,0),p+Vector2(11,9),p+Vector2(-9,9)]),c)
	draw_line(p+Vector2(-5,-6),p+Vector2(1,-6),Color(0.72,0.56,0.34),2.0)

func _draw_range(p: Vector2) -> void:
	var c := Color(0.76,0.74,0.66)
	draw_line(p+Vector2(-14,0),p+Vector2(14,0),c,2.5)
	draw_line(p+Vector2(-14,0),p+Vector2(-8,-6),c,2.5)
	draw_line(p+Vector2(-14,0),p+Vector2(-8,6),c,2.5)
	draw_line(p+Vector2(14,0),p+Vector2(8,-6),c,2.5)
	draw_line(p+Vector2(14,0),p+Vector2(8,6),c,2.5)

func _draw_shield_icon(p: Vector2, active: bool) -> void:
	var c := Color(0.74,0.82,0.86) if active else Color(0.30,0.32,0.34)
	var pts := PackedVector2Array([p+Vector2(0,-16),p+Vector2(14,-9),p+Vector2(11,7),p+Vector2(0,17),p+Vector2(-11,7),p+Vector2(-14,-9)])
	draw_colored_polygon(pts,Color(c.r,c.g,c.b,0.26))
	draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[4],pts[5],pts[0]]),c,2.5,true)
