extends Area2D
class_name IsmaelBossMechanicZone

# Amenaza de suelo anunciada: las colisiones solo hacen daño después
# del aviso visual, y cada marca puede dañar a Ismael una sola vez.
const ALLOWED_KINDS := ["grillete","mordida","mirada","tumba","vacio"]

var mechanic_kind := "grillete"
var telegraph_time := 0.92
var active_time := 0.78
var area_radius := 46.0
var beam_length := 370.0
var beam_width := 49.0
var _clock := 0.0
var _did_damage := false
var _shape: CollisionShape2D

func configure(kind_id: String, warning_seconds: float = 0.92, active_seconds: float = 0.78, beam_direction: Vector2 = Vector2.RIGHT) -> void:
	mechanic_kind = kind_id if ALLOWED_KINDS.has(kind_id) else "grillete"
	telegraph_time = maxf(0.70,warning_seconds)
	active_time = maxf(0.35,active_seconds)
	rotation = beam_direction.angle() if beam_direction.length_squared() > 0.01 else 0.0
	match mechanic_kind:
		"grillete": area_radius = 48.0
		"mordida": area_radius = 57.0
		"tumba": area_radius = 52.0
		"vacio": area_radius = 60.0
		"mirada": area_radius = 32.0
	queue_redraw()

func _ready() -> void:
	add_to_group("boss_mechanics")
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true
	z_index = 3
	_shape = CollisionShape2D.new()
	if mechanic_kind == "mirada":
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(beam_length,beam_width)
		_shape.shape = rectangle
	else:
		var circle := CircleShape2D.new()
		circle.radius = area_radius
		_shape.shape = circle
	add_child(_shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock >= telegraph_time+active_time:
		queue_free()
		return
	if _clock >= telegraph_time and not _did_damage:
		for body in get_overlapping_bodies():
			if body is IsmaelPlayer:
				_did_damage = true
				body.take_contact_damage(1,global_position)
				break
	queue_redraw()

func _zone_color() -> Color:
	match mechanic_kind:
		"grillete": return Color(0.90,0.32,0.22)
		"mordida": return Color(1.0,0.52,0.17)
		"mirada": return Color(0.64,0.49,0.98)
		"tumba": return Color(0.37,0.78,0.81)
		_: return Color(0.86,0.28,0.67)

func _draw() -> void:
	var active := _clock >= telegraph_time
	var fraction := clampf(_clock/telegraph_time,0.0,1.0)
	var base := _zone_color()
	var opacity := (0.19+0.16*fraction) if not active else 0.42
	var fill := Color(base.r,base.g,base.b,opacity*0.43)
	var outline := Color(base.r,base.g,base.b,opacity+0.25)
	if mechanic_kind == "mirada":
		var rect := Rect2(-beam_length*0.5,-beam_width*0.5,beam_length,beam_width)
		draw_rect(rect,fill)
		draw_rect(rect,outline,false,3.6 if active else 2.4)
		for index in range(7):
			var x := -beam_length*0.5+float(index)*beam_length/6.0
			draw_line(Vector2(x,-beam_width*0.5),Vector2(x+14.0,beam_width*0.5),Color(base.r,base.g,base.b,opacity*0.62),1.5)
	else:
		draw_circle(Vector2.ZERO,area_radius,fill)
		draw_arc(Vector2.ZERO,area_radius,0.0,TAU,44,outline,4.0 if active else 2.5)
		var p := 0.5+sin(_clock*10.0)*0.5
		draw_arc(Vector2.ZERO,area_radius*(0.35+fraction*0.55),0,TAU,32,Color(base.r,base.g,base.b,0.12+p*opacity*0.5),2.0)
		match mechanic_kind:
			"grillete":
				for x in [-21.0,0.0,21.0]:
					draw_line(Vector2(x,-33),Vector2(x,33),outline,2.6)
			"mordida":
				for x in [-28.0,-10.0,10.0,28.0]:
					draw_line(Vector2(x,-29),Vector2(x+9,-7),outline,2.5)
					draw_line(Vector2(x,29),Vector2(x+9,7),outline,2.5)
			"tumba":
				draw_line(Vector2(-26,0),Vector2(26,0),outline,3.0)
				draw_line(Vector2(0,-26),Vector2(0,26),outline,3.0)
			"vacio":
				draw_circle(Vector2.ZERO,19.0,Color(0.04,0.012,0.07,0.51))
	if active:
		draw_circle(Vector2.ZERO,5.0,outline)
