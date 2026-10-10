extends "res://scripts/enemy.gd"
class_name IsmaelExtraEnemy

enum ExtraKind { FLYER, TURRET, LEAPER }

var extra_kind: ExtraKind = ExtraKind.FLYER
var floor_variant := 1

func configure_extra(kind_id: String, floor_index: int) -> void:
	floor_variant = maxi(1,floor_index)
	match kind_id:
		"turret":
			extra_kind = ExtraKind.TURRET
			super.configure(IsmaelEnemy.EnemyKind.ORBITER,floor_variant)
			speed = 0.0
			health = 3+floor_variant
			max_health = health
			scale = Vector2(0.86,0.86)
		"leaper":
			extra_kind = ExtraKind.LEAPER
			super.configure(IsmaelEnemy.EnemyKind.DASHER,floor_variant)
			speed = 110.0+floor_variant*7.0
			health = 3+floor_variant
			max_health = health
			scale = Vector2(0.90,0.90)
		_:
			extra_kind = ExtraKind.FLYER
			super.configure(IsmaelEnemy.EnemyKind.CHASER,floor_variant)
			speed = 160.0+floor_variant*9.0
			health = 1+int(ceil(float(floor_variant)*0.5))
			max_health = health
			scale = Vector2(0.62,0.62)

func _ready() -> void:
	super._ready()
	if extra_kind == ExtraKind.TURRET:
		_orbit_sign = 0.0
		_attack_cooldown = 0.72
	elif extra_kind == ExtraKind.LEAPER:
		_dash_timer = 0.30

func _desired_movement(to_player: Vector2, delta: float) -> Vector2:
	match extra_kind:
		ExtraKind.FLYER:
			# Flyers circle at close-medium range instead of behaving like tiny chasers.
			var distance := global_position.distance_to(target.global_position)
			var tangent_sign := -1.0 if get_instance_id()%2==0 else 1.0
			var tangent := Vector2(-to_player.y,to_player.x)*tangent_sign
			var radial := to_player*clampf((distance-185.0)/105.0,-0.72,0.82)
			var weave := tangent*(0.95+sin(_age*4.4)*0.22)
			return (weave+radial).normalized()
		ExtraKind.LEAPER:
			# Leapers sidestep before committing to the inherited explosive dash.
			var base := super._desired_movement(to_player,delta)
			if _dash_timer <= 1.30 and _dash_timer >= 0.55:
				return base
			var side := -1.0 if get_instance_id()%2==0 else 1.0
			var tangent := Vector2(-to_player.y,to_player.x)*side
			return (to_player*0.28+tangent*0.88).normalized()
		_:
			return super._desired_movement(to_player,delta)

func _fire_pending_attack() -> void:
	if extra_kind == ExtraKind.TURRET:
		_fire_turret_attack()
		return
	super._fire_pending_attack()

func _fire_turret_attack() -> void:
	if not is_instance_valid(target):
		return
	var aim := global_position.direction_to(target.global_position)
	var count := 1
	if floor_variant >= 3:
		count = 3
	if floor_variant >= 5:
		count = 5
	if count == 1:
		_spawn_enemy_shot(aim,300.0+floor_variant*14.0,0)
	else:
		var spread := 0.16+float(floor_variant)*0.018
		for i in range(count):
			var t := float(i)/float(count-1)
			_spawn_enemy_shot(aim.rotated(lerpf(-spread,spread,t)),300.0+floor_variant*14.0,0)
	_attack_cooldown = maxf(0.82,1.55-float(floor_variant)*0.10)

func _draw() -> void:
	var flash := _hit_flash>0.0
	match extra_kind:
		ExtraKind.FLYER:
			_draw_flyer(flash)
		ExtraKind.TURRET:
			_draw_turret(flash)
		ExtraKind.LEAPER:
			_draw_leaper(flash)
	_draw_attack_telegraph()

func _draw_flyer(flash: bool) -> void:
	var body := Color(0.95,0.86,0.78) if flash else Color(0.19,0.16,0.15)
	var wing := Color(0.74,0.72,0.68,0.58)
	var float_y := sin(_age*10.0)*4.0
	draw_ellipse(Vector2(0,15),Vector2(17,5),Color(0,0,0,0.22))
	draw_set_transform(Vector2(0,float_y),sin(_age*6.0)*0.08,Vector2.ONE)
	draw_ellipse(Vector2(-15,-2),Vector2(14,8),wing)
	draw_ellipse(Vector2(15,-2),Vector2(14,8),wing)
	draw_ellipse(Vector2(0,0),Vector2(13,17),Color(0.04,0.035,0.035))
	draw_ellipse(Vector2(0,-1),Vector2(10,14),body)
	draw_circle(Vector2(-5,-6),3.4,Color(0.70,0.06,0.07))
	draw_circle(Vector2(5,-6),3.4,Color(0.70,0.06,0.07))
	draw_line(Vector2(-5,11),Vector2(-10,21),Color(0.07,0.055,0.05),2.5)
	draw_line(Vector2(5,11),Vector2(10,21),Color(0.07,0.055,0.05),2.5)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_turret(flash: bool) -> void:
	var stone := Color(0.92,0.88,0.80) if flash else Color(0.27,0.24,0.22)
	var rim := Color(0.11,0.09,0.08)
	var eye := Color(0.68,0.12,0.08)
	draw_ellipse(Vector2(0,23),Vector2(27,8),Color(0,0,0,0.30))
	draw_circle(Vector2.ZERO,25.0,rim)
	draw_circle(Vector2.ZERO,21.0,stone)
	draw_circle(Vector2.ZERO,11.0,Color(0.07,0.055,0.05))
	draw_circle(Vector2.ZERO,6.5,eye)
	draw_circle(Vector2(-2,-2),2.0,Color(1.0,0.62,0.35,0.85))
	for a in range(0,360,90):
		var d := Vector2.RIGHT.rotated(deg_to_rad(float(a)))
		draw_line(d*18.0,d*31.0,rim,5.0)

func _draw_leaper(flash: bool) -> void:
	var skin := Color(1.0,0.90,0.84) if flash else Color(0.36,0.13,0.12)
	var dark := Color(0.11,0.035,0.035)
	var crouch := 1.0+sin(_age*7.0)*0.05
	draw_ellipse(Vector2(0,22),Vector2(23,7),Color(0,0,0,0.28))
	draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,crouch))
	draw_ellipse(Vector2(0,0),Vector2(23,20),dark)
	draw_ellipse(Vector2(0,-2),Vector2(19,17),skin)
	draw_circle(Vector2(-8,-7),4.0,Color.BLACK)
	draw_circle(Vector2(8,-7),4.0,Color.BLACK)
	draw_line(Vector2(-16,10),Vector2(-31,25),dark,5.0)
	draw_line(Vector2(16,10),Vector2(31,25),dark,5.0)
	draw_line(Vector2(-8,14),Vector2(-18,30),skin,6.0)
	draw_line(Vector2(8,14),Vector2(18,30),skin,6.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
