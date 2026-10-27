extends "res://scripts/advanced_enemy.gd"
class_name IsmaelGuardianEchoElite

enum EchoRole { WARDEN, HUNTER }
var echo_role: EchoRole = EchoRole.WARDEN

func configure_echo(role_id: String, floor_index: int) -> void:
	echo_role = EchoRole.HUNTER if role_id == "hunter" else EchoRole.WARDEN
	if echo_role == EchoRole.WARDEN:
		configure_advanced("brute",floor_index)
		# El custodio protege a su grupo, no es un minijefe ni una esponja.
		speed *= 0.89
	else:
		configure_advanced("spitter_elite",floor_index)
		speed *= 1.08
	echo_squad_member = true

func _ready() -> void:
	super._ready()
	if echo_role == EchoRole.WARDEN:
		add_to_group("echo_wardens")
	add_to_group("guardian_echo_elites")
	queue_redraw()

func _desired_movement(to_player: Vector2, delta: float) -> Vector2:
	if echo_role == EchoRole.WARDEN and is_instance_valid(target):
		# El custodio se interpone entre el jugador y los tiradores aliados.
		var ranged_ally: Node2D
		var nearest := INF
		for other in get_tree().get_nodes_in_group("enemies"):
			if other == self or not is_instance_valid(other) or not other is Node2D:
				continue
			if not bool(other.get("echo_squad_member")):
				continue
			var d := global_position.distance_squared_to(other.global_position)
			if d < nearest:
				nearest = d
				ranged_ally = other
		if is_instance_valid(ranged_ally):
			var defend_at := ranged_ally.global_position + ranged_ally.global_position.direction_to(target.global_position)*68.0
			if global_position.distance_to(defend_at) > 34.0:
				return global_position.direction_to(defend_at)
			return Vector2.ZERO
	return super._desired_movement(to_player,delta)

func _draw() -> void:
	super._draw()
	var pulse := 0.50+0.50*sin(_age*3.4)
	if echo_role == EchoRole.WARDEN:
		var ink := Color(0.35,0.78,0.92,0.38+pulse*0.20)
		draw_arc(Vector2.ZERO,45.0+pulse*3.0,0.0,TAU,36,ink,3.3)
		for i in range(4):
			var point := Vector2.RIGHT.rotated(TAU*float(i)/4.0+PI*0.25)*35.0
			draw_circle(point,4.0,ink)
	else:
		draw_arc(Vector2.ZERO,35.0,0.15,PI*1.85,32,Color(0.98,0.49,0.17,0.52+pulse*0.26),3.0)
		draw_line(Vector2(-12,-38),Vector2(0,-50),Color(1.0,0.65,0.25,0.80),2.5)
		draw_line(Vector2(0,-50),Vector2(12,-38),Color(1.0,0.65,0.25,0.80),2.5)
