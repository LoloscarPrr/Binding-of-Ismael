extends Control
class_name IsmaelIsaacStyleMinimap

# Fase 12.3 · Minimapa vectorial de habitaciones, no ASCII.
# Inspirado en la lectura espacial de los roguelikes clásicos.
# Usa exclusivamente información descubierta: no revela salas secretas.
const CELL_FILL := Color(0.38,0.37,0.35,0.94)
const CLEARED_FILL := Color(0.54,0.52,0.46,0.95)
const FRONTIER_FILL := Color(0.19,0.20,0.22,0.88)
const BORDER := Color(0.84,0.80,0.69,0.90)
const CORRIDOR := Color(0.55,0.52,0.45,0.83)
const SELECTED := Color(0.96,0.97,0.90,1.0)
const GOLD := Color(0.98,0.75,0.29,1.0)
const RED := Color(0.88,0.32,0.31,1.0)
const BLUE := Color(0.45,0.77,0.94,1.0)
const VIOLET := Color(0.76,0.55,0.90,1.0)

var dungeon: IsmaelDungeonMap
var current_cell := Vector2i.ZERO
var expanded := false
var _flash_age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_flash_age += delta
	# Only the selected-room outline animates; the geometry is tiny.
	if expanded:
		queue_redraw()

func show_map(map_ref: IsmaelDungeonMap, player_cell: Vector2i) -> void:
	dungeon = map_ref
	current_cell = player_cell
	queue_redraw()

func set_expanded(value: bool) -> void:
	if expanded == value:
		return
	expanded = value
	queue_redraw()

static func visible_cells(map_ref: IsmaelDungeonMap) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map_ref == null:
		return result
	for cell in map_ref.rooms.keys():
		var coord: Vector2i = cell
		if map_ref.is_discovered(coord):
			result.append(coord)
	return result

static func room_icon(kind: String) -> String:
	match kind:
		"jefe": return "boss"
		"minijefe": return "elite"
		"recompensa": return "treasure"
		"tienda": return "shop"
		"sacrificio": return "sacrifice"
		"secreta","supersecreta": return "secret"
		"biblioteca": return "library"
		"pacto": return "pact"
		"desafio","emboscada","maldicion","anomalia","eco_guardian": return "challenge"
		"evento","santuario_eco": return "event"
		"inicio": return "start"
	return ""

static func connection_exists(map_ref: IsmaelDungeonMap, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return map_ref != null and map_ref.has_room(from_cell) and map_ref.has_room(to_cell) and map_ref.is_discovered(from_cell) and map_ref.is_discovered(to_cell) and absi(from_cell.x-to_cell.x)+absi(from_cell.y-to_cell.y) == 1

func _draw() -> void:
	if dungeon == null or size.x < 70.0 or size.y < 60.0:
		return
	var visible := visible_cells(dungeon)
	if visible.is_empty():
		return

	# Compacto: sin rectángulo negro gigante. Expandido: overlay
	# oscuro suave que se puede cerrar tocando fuera.
	var frame_rect := Rect2(Vector2(2,2),size-Vector2(4,4))
	if expanded:
		draw_rect(frame_rect,Color(0.028,0.025,0.031,0.74))
		draw_rect(frame_rect,Color(0.74,0.66,0.52,0.57),false,1.5)
	else:
		draw_rect(frame_rect,Color(0.023,0.022,0.024,0.13))
		_draw_corner_lines(frame_rect)

	var padding := Vector2(17,14) if expanded else Vector2(8,7)
	var usable := size-padding*2.0
	var pitch := Vector2(40,36) if expanded else Vector2(28,24)
	var center := size*0.5
	var min_cell := visible[0]
	var max_cell := visible[0]
	for cell in visible:
		min_cell = Vector2i(mini(min_cell.x,cell.x),mini(min_cell.y,cell.y))
		max_cell = Vector2i(maxi(max_cell.x,cell.x),maxi(max_cell.y,cell.y))
	if expanded:
		var span_x := maxi(1,max_cell.x-min_cell.x+1)
		var span_y := maxi(1,max_cell.y-min_cell.y+1)
		pitch = Vector2(
			minf(41.0,usable.x/float(span_x)),
			minf(37.0,usable.y/float(span_y))
		)
		center -= Vector2(float(min_cell.x+max_cell.x)*pitch.x,float(min_cell.y+max_cell.y)*pitch.y)*0.5
	else:
		# El compactado funciona como cámara centrada en Ismael.
		center -= Vector2(float(current_cell.x)*pitch.x,float(current_cell.y)*pitch.y)
	var cell_size := Vector2(pitch.x*0.73,pitch.y*0.72)
	var drawable := Rect2(padding,usable)
	var visible_set: Dictionary = {}
	for cell in visible:
		visible_set[cell] = true

	# 1. Pasillos bajo las salas: solo entre habitaciones descubiertas.
	for cell in visible:
		var a := _point(cell,pitch,center)
		for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
			var neighbor: Vector2i = cell+direction
			if not visible_set.has(neighbor):
				continue
			var b := _point(neighbor,pitch,center)
			var link := Rect2()
			if direction == Vector2i.RIGHT:
				link = Rect2(Vector2(a.x,a.y-cell_size.y*0.135),Vector2(b.x-a.x,cell_size.y*0.27))
			else:
				link = Rect2(Vector2(a.x-cell_size.x*0.135,a.y),Vector2(cell_size.x*0.27,b.y-a.y))
			if drawable.intersects(link):
				draw_rect(link,CORRIDOR)

	# 2. Habitaciones rectangulares y marcadores propios.
	for cell in visible:
		var at := _point(cell,pitch,center)
		var rect := Rect2(at-cell_size*0.5,cell_size)
		if not drawable.intersects(rect):
			continue
		var visited := bool(dungeon.rooms[cell].get("visited",false))
		var fill_color := CLEARED_FILL if dungeon.is_cleared(cell) else (CELL_FILL if visited else FRONTIER_FILL)
		draw_rect(rect,fill_color)
		draw_rect(rect,BORDER if visited else Color(0.53,0.54,0.51,0.83),false,1.4 if expanded else 1.1)
		if cell == current_cell:
			var glow := 0.62+0.25*sin(_flash_age*4.0) if expanded else 0.90
			draw_rect(rect.grow(2.1),Color(SELECTED.r,SELECTED.g,SELECTED.b,glow),false,2.4)
			_draw_marker("player",at,cell_size)
		else:
			_draw_marker(room_icon(dungeon.kind(cell)),at,cell_size)
	if expanded:
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(13,size.y-9),"PISO %d  ·  MAPA DESCUBIERTO" % dungeon.floor_index,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.87,0.82,0.72,0.91))

func _point(cell: Vector2i,pitch: Vector2,center: Vector2) -> Vector2:
	return center+Vector2(float(cell.x)*pitch.x,float(cell.y)*pitch.y)

func _draw_corner_lines(rect: Rect2) -> void:
	var ink := Color(0.82,0.70,0.51,0.33)
	var edge := 12.0
	for anchor in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var dx := 1.0 if anchor.x<rect.get_center().x else -1.0
		var dy := 1.0 if anchor.y<rect.get_center().y else -1.0
		draw_line(anchor,anchor+Vector2(dx*edge,0),ink,1.0)
		draw_line(anchor,anchor+Vector2(0,dy*edge),ink,1.0)

func _draw_marker(marker: String,center: Vector2,room_size: Vector2) -> void:
	var radius := minf(room_size.x,room_size.y)*0.23
	match marker:
		"player":
			draw_colored_polygon(PackedVector2Array([
				center+Vector2(0,-radius),center+Vector2(radius*0.85,radius),
				center+Vector2(0,radius*0.45),center+Vector2(-radius*0.85,radius)
			]),SELECTED)
		"boss","elite":
			draw_circle(center+Vector2(0,-radius*0.24),radius*0.73,RED)
			draw_circle(center+Vector2(-radius*0.23,-radius*0.29),radius*0.14,Color.BLACK)
			draw_circle(center+Vector2(radius*0.23,-radius*0.29),radius*0.14,Color.BLACK)
			draw_rect(Rect2(center+Vector2(-radius*0.44,radius*0.20),Vector2(radius*0.88,radius*0.38)),RED)
		"treasure":
			var star := PackedVector2Array()
			for i in range(8):
				var angle := -PI*0.5+float(i)*TAU/8.0
				var length := radius*1.3 if i%2==0 else radius*0.53
				star.append(center+Vector2.RIGHT.rotated(angle)*length)
			draw_colored_polygon(star,GOLD)
		"shop":
			draw_circle(center,radius*0.95,GOLD)
			draw_circle(center,radius*0.57,Color(0.42,0.27,0.12),false,1.3)
		"secret":
			_draw_symbol("?",center,VIOLET,radius)
		"library":
			_draw_symbol("▣",center,BLUE,radius)
		"sacrifice":
			var pts := PackedVector2Array([center+Vector2(0,-radius*1.15),center+Vector2(radius*0.75,radius*0.65),center+Vector2(0,radius),center+Vector2(-radius*0.75,radius*0.65)])
			draw_colored_polygon(pts,RED)
		"challenge":
			_draw_symbol("!",center,RED,radius)
		"pact":
			_draw_symbol("✝",center,VIOLET,radius)
		"event":
			_draw_symbol("*",center,BLUE,radius)
		"start":
			draw_circle(center,radius*0.68,Color(0.70,0.76,0.68),false,1.5)

func _draw_symbol(symbol: String,center: Vector2,color: Color,radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := maxi(10,int(radius*2.8))
	var width := font.get_string_size(symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,center+Vector2(-width*0.5,font_size*0.35),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
