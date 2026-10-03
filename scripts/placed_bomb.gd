extends Node2D
class_name IsmaelPlacedBomb

signal exploded(world_position: Vector2, blast_radius: float)

const FUSE_SECONDS := 1.55
const BLAST_RADIUS := 138.0
const ENEMY_DAMAGE := 5
const PLAYER_DAMAGE := 2
const EXPLOSION_VISUAL_TIME := 0.24

var _player: IsmaelPlayer
var _time_left := FUSE_SECONDS
var _has_exploded := false
var _explosion_age := 0.0

func configure(player_ref: IsmaelPlayer) -> void:
	_player = player_ref

func _ready() -> void:
	add_to_group("room_bombs")
	z_index = 7
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _has_exploded:
		_time_left = maxf(0.0,_time_left-delta)
		if _time_left <= 0.0:
			_detonate()
	else:
		_explosion_age += delta
		if _explosion_age >= EXPLOSION_VISUAL_TIME:
			queue_free()
	queue_redraw()

func _detonate() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	_apply_blast_damage()
	exploded.emit(global_position,BLAST_RADIUS)

func _apply_blast_damage() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if global_position.distance_to(enemy.global_position) <= BLAST_RADIUS and enemy.has_method("take_damage"):
			enemy.call("take_damage",ENEMY_DAMAGE)
	if is_instance_valid(_player) and not _player.is_dead:
		if global_position.distance_to(_player.global_position) <= BLAST_RADIUS:
			_player.take_contact_damage(PLAYER_DAMAGE,global_position)

func _draw() -> void:
	if _has_exploded:
		var t := clampf(_explosion_age/EXPLOSION_VISUAL_TIME,0.0,1.0)
		var radius := lerpf(34.0,BLAST_RADIUS,t)
		var alpha := 1.0-t
		draw_circle(Vector2.ZERO,radius,Color(1.0,0.52,0.10,0.13*alpha))
		draw_arc(Vector2.ZERO,radius,0.0,TAU,64,Color(1.0,0.76,0.26,0.86*alpha),maxf(2.0,7.0*(1.0-t)))
		draw_circle(Vector2.ZERO,38.0*(1.0-t)+9.0,Color(1.0,0.92,0.62,0.86*alpha))
		return

	var urgency := 1.0-clampf(_time_left/FUSE_SECONDS,0.0,1.0)
	var blink := 0.5+0.5*sin((1.0+urgency*4.0)*TAU*(FUSE_SECONDS-_time_left))
	draw_ellipse(Vector2(0,18),Vector2(25,8),Color(0.0,0.0,0.0,0.30))
	draw_circle(Vector2.ZERO,22.0,Color(0.055,0.06,0.07))
	draw_arc(Vector2.ZERO,22.0,0.0,TAU,32,Color(0.38,0.40,0.43),3.0)
	draw_circle(Vector2(-6,-7),4.0,Color(0.18,0.20,0.22,0.75))
	draw_line(Vector2(11,-14),Vector2(22,-27),Color(0.52,0.30,0.12),5.0)
	draw_circle(Vector2(24,-29),4.0+blink*3.0,Color(1.0,0.26+blink*0.35,0.05,0.96))
	var warning_alpha := 0.08+0.12*urgency+0.10*blink
	draw_arc(Vector2.ZERO,BLAST_RADIUS,0.0,TAU,64,Color(1.0,0.32,0.10,warning_alpha),2.0)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(28):
		var angle := TAU*float(i)/28.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)
