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
var _draw_elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Imprescindible en vista compacta: jamás dibujar salas fuera
	# del minimapa, sobre textos, puertas o botones superiores.
	clip_contents = true
	set_process(true)

func _process(delta: float) -> void:
	_flash_age += delta
	_draw_elapsed += delta
	# Mapa estático en compacto; pulso expandido a 15 Hz.
	if expanded and _draw_elapsed >= 1.0/15.0:
		_draw_elapsed = 0.0
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

	var padding := Vector2(16,14) if expanded else Vector2(8,7)
	var usable := size-padding*2.0
	if expanded:
		usable.y -= 29.0 # Reserva la leyenda inferior.
	var pitch := Vector2(52,44) if expanded else Vector2(36,31)
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
			minf(52.0,usable.x/float(span_x)),
			minf(44.0,usable.y/float(span_y))
		)
		center -= Vector2(float(min_cell.x+max_cell.x)*pitch.x,float(min_cell.y+max_cell.y)*pitch.y)*0.5
	else:
		# El compactado funciona como cámara centrada en Ismael.
		center -= Vector2(float(current_cell.x)*pitch.x,float(current_cell.y)*pitch.y)
	var cell_size := Vector2(pitch.x*0.80,pitch.y*0.82)
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
		_draw_legend()

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

# Cada símbolo es una figura legible, no un glifo diminuto dependiente
# de la fuente del teléfono. Contraste alto incluso en modo compacto.
func _draw_marker(marker: String,center: Vector2,room_size: Vector2) -> void:
	var r := minf(room_size.x,room_size.y)*0.34
	var line := maxf(1.4,r*0.24)
	match marker:
		"player":
			draw_circle(center,r*0.92,Color(0.18,0.23,0.20,0.91))
			draw_colored_polygon(PackedVector2Array([
				center+Vector2(0,-r*1.12),
				center+Vector2(r*0.82,r*0.97),
				center+Vector2(0,r*0.37),
				center+Vector2(-r*0.82,r*0.97)
			]),SELECTED)
		"boss","elite":
			draw_circle(center,r*1.06,Color(0.28,0.09,0.10,0.96))
			draw_circle(center+Vector2(0,-r*0.12),r*0.74,RED)
			draw_rect(Rect2(center+Vector2(-r*0.47,r*0.19),Vector2(r*0.94,r*0.57)),RED)
			for eye_x in [-0.31,0.31]:
				draw_circle(center+Vector2(r*eye_x,-r*0.18),r*0.17,Color(0.97,0.94,0.86))
			for tooth_x in [-0.23,0.0,0.23]:
				draw_line(center+Vector2(r*tooth_x,r*0.37),center+Vector2(r*tooth_x,r*0.65),Color(0.98,0.91,0.83),1.25)
		"treasure":
			# Cofre dorado: tapa arqueada, base y cerradura.
			draw_rect(Rect2(center+Vector2(-r,-r*0.39),Vector2(r*2,r*1.28)),GOLD)
			draw_rect(Rect2(center+Vector2(-r,-r*0.39),Vector2(r*2,r*1.28)),Color(0.17,0.12,0.05),false,1.25)
			draw_line(center+Vector2(-r,-r*0.36),center+Vector2(r,-r*0.36),Color(0.99,0.89,0.54),line)
			draw_rect(Rect2(center+Vector2(-r*0.19,r*0.12),Vector2(r*0.38,r*0.47)),Color(0.20,0.14,0.08))
		"shop":
			# Moneda con símbolo de compra. La base oscura da lectura.
			draw_circle(center,r*1.05,Color(0.20,0.15,0.06))
			draw_circle(center,r*0.88,GOLD)
			draw_circle(center,r*0.63,Color(0.71,0.45,0.10),false,1.6)
			_draw_symbol("$",center,Color(0.16,0.11,0.07),r)
		"secret":
			draw_circle(center,r*1.04,Color(0.22,0.11,0.33))
			_draw_symbol("?",center,Color(0.96,0.85,1.0),r)
		"library":
			# Libro abierto con lomo y dos páginas.
			draw_rect(Rect2(center+Vector2(-r,-r*0.78),Vector2(r*2,r*1.65)),Color(0.11,0.32,0.51))
			draw_line(center+Vector2(0,-r*0.8),center+Vector2(0,r*0.9),Color(0.94,0.95,0.91),line)
			draw_line(center+Vector2(-r*0.76,-r*0.39),center+Vector2(-r*0.22,-r*0.39),Color(0.93,0.91,0.83),1.5)
			draw_line(center+Vector2(r*0.22,-r*0.39),center+Vector2(r*0.76,-r*0.39),Color(0.93,0.91,0.83),1.5)
		"sacrifice":
			# Gota de sangre: diferente del ícono de combate.
			var drop := PackedVector2Array([
				center+Vector2(0,-r*1.20),center+Vector2(r*0.89,r*0.27),
				center+Vector2(r*0.66,r*0.9),center+Vector2(-r*0.66,r*0.9),
				center+Vector2(-r*0.89,r*0.27)
			])
			draw_colored_polygon(drop,RED)
			draw_circle(center+Vector2(-r*0.27,r*0.18),r*0.17,Color(1.0,0.74,0.69))
		"challenge":
			draw_rect(Rect2(center-Vector2.ONE*r*0.95,Vector2.ONE*r*1.9),Color(0.57,0.23,0.13))
			_draw_symbol("!",center,Color(1.0,0.91,0.70),r)
		"pact":
			# Marca ritual en forma de X.
			draw_circle(center,r,Color(0.29,0.15,0.37))
			draw_line(center+Vector2(-r*0.58,-r*0.58),center+Vector2(r*0.58,r*0.58),VIOLET,line)
			draw_line(center+Vector2(r*0.58,-r*0.58),center+Vector2(-r*0.58,r*0.58),VIOLET,line)
		"event":
			draw_colored_polygon(PackedVector2Array([
				center+Vector2(0,-r),center+Vector2(r,0),
				center+Vector2(0,r),center+Vector2(-r,0)
			]),BLUE)
			draw_circle(center,r*0.27,Color(0.93,1.0,1.0))
		"start":
			draw_circle(center,r*0.79,Color(0.61,0.88,0.62),false,line)
			draw_circle(center,r*0.27,Color(0.65,0.95,0.69))

func _draw_symbol(symbol: String,center: Vector2,color: Color,radius: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := maxi(12,int(radius*2.6))
	var width := font.get_string_size(symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,center+Vector2(-width*0.5,float(font_size)*0.34),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_legend() -> void:
	var baseline := size.y-16.0
	var font := ThemeDB.fallback_font
	var columns := [
		{"label":"JEFE","color":RED},
		{"label":"TIENDA","color":GOLD},
		{"label":"TESORO","color":Color(1.0,0.87,0.47)},
		{"label":"SECRETO","color":VIOLET}
	]
	var cell_w := (size.x-22.0)/4.0
	for i in range(columns.size()):
		var x := 12.0+float(i)*cell_w
		var ink: Color = columns[i]["color"]
		draw_circle(Vector2(x,baseline-2.0),3.6,ink)
		draw_string(font,Vector2(x+8.0,baseline+1.2),String(columns[i]["label"]),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.95,0.93,0.85,0.94))
