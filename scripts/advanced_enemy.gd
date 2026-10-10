extends "res://scripts/enemy.gd"
class_name IsmaelAdvancedEnemy

# Extra archetypes layer on top of the stable enemy movement/combat contract.
# BRUTE reuses pursuit, SPITTER keeps distance and shoots, STALKER reuses dash
# movement with a much smaller/faster body, and FLOOR_BOSS scales by floor.
enum AdvancedKind { BRUTE, SPITTER, STALKER, FLOOR_BOSS }

var advanced_kind: AdvancedKind = AdvancedKind.BRUTE
var floor_variant := 1

func configure_advanced(kind_id: String, floor_index: int) -> void:
	floor_variant = maxi(1,floor_index)
	match kind_id:
		"spitter":
			advanced_kind = AdvancedKind.SPITTER
			super.configure(IsmaelEnemy.EnemyKind.ORBITER,floor_variant)
			speed = 70.0+floor_variant*3.5
			health = 4+floor_variant
			max_health = health
			scale = Vector2(0.94,0.94)
		"stalker":
			advanced_kind = AdvancedKind.STALKER
			super.configure(IsmaelEnemy.EnemyKind.DASHER,floor_variant)
			speed = 132.0+floor_variant*8.0
			health = 2+floor_variant
			max_health = health
			scale = Vector2(0.80,0.80)
		"boss":
			advanced_kind = AdvancedKind.FLOOR_BOSS
			super.configure(IsmaelEnemy.EnemyKind.BOSS,floor_variant)
			health = 20+floor_variant*7
			max_health = health
			speed = 88.0+floor_variant*5.0
			scale = Vector2(1.0+minf(0.12,float(floor_variant-1)*0.025),1.0+minf(0.12,float(floor_variant-1)*0.025))
		_:
			advanced_kind = AdvancedKind.BRUTE
			super.configure(IsmaelEnemy.EnemyKind.CHASER,floor_variant)
			speed = 62.0+floor_variant*4.0
			health = 8+floor_variant*2
			max_health = health
			scale = Vector2(1.20,1.20)

func _ready() -> void:
	super._ready()
	if advanced_kind == AdvancedKind.SPITTER:
		# Zero tangential component turns the orbiter contract into a ranged enemy
		# that backs away/approaches until it owns a firing lane at medium range.
		_orbit_sign = 0.0
	elif advanced_kind == AdvancedKind.STALKER:
		_dash_timer = 0.42

func _desired_movement(to_player: Vector2, delta: float) -> Vector2:
	match advanced_kind:
		AdvancedKind.BRUTE:
			# Heavy pressure: advances directly, but slows near the player instead
			# of skating through them. The slight sway keeps it from feeling robotic.
			var distance := global_position.distance_to(target.global_position)
			var lateral := Vector2(-to_player.y,to_player.x)*sin(_age*1.7)*0.18
			if distance < 115.0:
				return (to_player*0.34+lateral).normalized()
			return (to_player+lateral).normalized()
		AdvancedKind.STALKER:
			# Stalkers flank during recovery, then snap into the inherited dash.
			var base := super._desired_movement(to_player,delta)
			if _dash_timer <= 1.30 and _dash_timer >= 0.55:
				return base
			var flank_sign := -1.0 if get_instance_id()%2==0 else 1.0
			var tangent := Vector2(-to_player.y,to_player.x)*flank_sign
			return (to_player*0.42+tangent*0.92).normalized()
		_:
			return super._desired_movement(to_player,delta)

func _fire_pending_attack() -> void:
	if advanced_kind == AdvancedKind.SPITTER:
		_fire_spitter_attack()
		return
	if advanced_kind == AdvancedKind.FLOOR_BOSS:
		_fire_floor_boss_attack()
		return
	super._fire_pending_attack()

func _fire_spitter_attack() -> void:
	if not is_instance_valid(target):
		return
	var aim: Vector2 = global_position.direction_to(target.global_position)
	var angles: Array[float] = [0.0]
	if floor_variant >= 4:
		angles = [-0.17,0.0,0.17]
	elif floor_variant >= 3:
		angles = [-0.10,0.10]
	for angle: float in angles:
		_spawn_enemy_shot(aim.rotated(angle),275.0+floor_variant*20.0,0)
	_attack_cooldown = maxf(0.92,1.62-float(floor_variant)*0.11)

func _fire_floor_boss_attack() -> void:
	if not is_instance_valid(target):
		return
	var phase_two := health*2 <= max_health
	if _attack_sequence%2 == 0:
		var aim: Vector2 = global_position.direction_to(target.global_position)
		var shot_count := 3+mini(4,(floor_variant-1)*2)
		if phase_two:
			shot_count += 2
		var spread := 0.20+float(floor_variant)*0.045
		if shot_count <= 1:
			_spawn_enemy_shot(aim,330.0+floor_variant*12.0,1)
		else:
			for i in range(shot_count):
				var t := float(i)/float(shot_count-1)
				var angle := lerpf(-spread,spread,t)
				_spawn_enemy_shot(aim.rotated(angle),320.0+floor_variant*14.0,1)
	else:
		var ring_count := 7+floor_variant*2+(3 if phase_two else 0)
		var base_angle := _age*(0.46+float(floor_variant)*0.08)
		for i in range(ring_count):
			var angle := base_angle+TAU*float(i)/float(ring_count)
			_spawn_enemy_shot(Vector2.RIGHT.rotated(angle),260.0+floor_variant*13.0,1)
	_attack_sequence += 1
	_attack_cooldown = maxf(0.62,(0.94 if phase_two else 1.20)-float(floor_variant-1)*0.08)

func _draw() -> void:
	var flash := _hit_flash>0.0
	match advanced_kind:
		AdvancedKind.BRUTE:
			_draw_brute(flash)
		AdvancedKind.SPITTER:
			_draw_spitter(flash)
		AdvancedKind.STALKER:
			_draw_stalker(flash)
		AdvancedKind.FLOOR_BOSS:
			_draw_floor_boss(flash)
	_draw_attack_telegraph()

func _draw_brute(flash: bool) -> void:
	var outline := Color(0.055,0.045,0.04)
	var hide := Color(0.94,0.86,0.78) if flash else Color(0.30,0.25,0.22)
	var armor := Color(0.16,0.15,0.14)
	var wound := Color(0.38,0.07,0.06)
	var bob := sin(_age*4.2)*1.2
	draw_ellipse(Vector2(0,25),Vector2(31,9),Color(0.0,0.0,0.0,0.34))
	draw_set_transform(Vector2(0,bob),0.0,Vector2.ONE)
	draw_ellipse(Vector2(0,1),Vector2(31,29),outline)
	draw_ellipse(Vector2(0,0),Vector2(27,25),hide)
	draw_rect(Rect2(-25,-3,50,12),armor)
	draw_circle(Vector2(-23,-5),9.0,hide)
	draw_circle(Vector2(23,-5),9.0,hide)
	draw_ellipse(Vector2(-9,-10),Vector2(5,4),Color.BLACK)
	draw_ellipse(Vector2(9,-10),Vector2(5,4),Color.BLACK)
	draw_circle(Vector2(-8,-10),1.5,Color(0.84,0.18,0.13))
	draw_circle(Vector2(10,-10),1.5,Color(0.84,0.18,0.13))
	draw_ellipse(Vector2(0,12),Vector2(11,6),wound)
	draw_line(Vector2(-18,4),Vector2(-8,9),Color(0.48,0.44,0.39),3.0)
	draw_line(Vector2(18,4),Vector2(8,9),Color(0.48,0.44,0.39),3.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_spitter(flash: bool) -> void:
	var outline := Color(0.035,0.075,0.055)
	var body := Color(0.92,0.96,0.82) if flash else Color(0.20,0.43,0.29)
	var bile := Color(0.56,0.72,0.22)
	var float_y := sin(_age*3.7)*2.4
	draw_ellipse(Vector2(0,20),Vector2(24,7),Color(0.0,0.02,0.01,0.26))
	draw_set_transform(Vector2(0,float_y),sin(_age*1.8)*0.03,Vector2.ONE)
	draw_ellipse(Vector2(0,0),Vector2(24,25),outline)
	draw_ellipse(Vector2(0,-1),Vector2(20,21),body)
	draw_ellipse(Vector2(0,-8),Vector2(9,8),Color(0.80,0.77,0.66))
	draw_ellipse(Vector2(0,-8),Vector2(4,5.5),Color.BLACK)
	draw_circle(Vector2(-1,-10),1.4,Color(0.85,0.92,0.42))
	draw_ellipse(Vector2(0,9),Vector2(11,7),Color(0.08,0.14,0.06))
	draw_circle(Vector2(-4,8),2.6,bile)
	draw_circle(Vector2(4,10),2.1,bile)
	draw_line(Vector2(-16,1),Vector2(-29,7),body,5.0)
	draw_line(Vector2(16,1),Vector2(29,7),body,5.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_stalker(flash: bool) -> void:
	var outline := Color(0.035,0.025,0.04)
	var skin := Color(1.0,0.95,0.90) if flash else Color(0.48,0.43,0.50)
	var shadow := Color(0.14,0.09,0.17)
	var lean := sin(_age*8.0)*0.10
	draw_ellipse(Vector2(0,18),Vector2(18,6),Color(0.0,0.0,0.0,0.27))
	draw_set_transform(Vector2.ZERO,lean,Vector2.ONE)
	draw_ellipse(Vector2(0,-1),Vector2(16,23),outline)
	draw_ellipse(Vector2(0,-2),Vector2(13,20),skin)
	draw_ellipse(Vector2(0,-10),Vector2(8,7),shadow)
	draw_ellipse(Vector2(0,-10),Vector2(3.5,5.0),Color(0.78,0.16,0.18))
	draw_line(Vector2(-10,2),Vector2(-27,13),skin,4.0)
	draw_line(Vector2(10,2),Vector2(27,13),skin,4.0)
	draw_line(Vector2(-7,15),Vector2(-15,27),shadow,5.0)
	draw_line(Vector2(7,15),Vector2(15,27),shadow,5.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw_floor_boss(flash: bool) -> void:
	var palette: Array[Color] = [
		Color(0.38,0.055,0.085),
		Color(0.43,0.18,0.08),
		Color(0.28,0.12,0.42),
		Color(0.16,0.29,0.31),
		Color(0.12,0.06,0.10)
	]
	var flesh := Color(1.0,0.88,0.82) if flash else palette[clampi(floor_variant-1,0,palette.size()-1)]
	var rim := flesh.lightened(0.24)
	var dark := flesh.darkened(0.58)
	var breathe := 1.0+sin(_age*2.6)*0.028
	draw_ellipse(Vector2(0,40),Vector2(49,13),Color(0.01,0.005,0.008,0.44))
	draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,breathe))
	draw_ellipse(Vector2(0,1),Vector2(50,44),dark)
	draw_ellipse(Vector2(0,-1),Vector2(44,39),flesh)
	draw_circle(Vector2(-39,2),15.0,rim)
	draw_circle(Vector2(39,2),15.0,rim)
	draw_ellipse(Vector2(-16,-12),Vector2(9,8),Color.BLACK)
	draw_ellipse(Vector2(16,-12),Vector2(9,8),Color.BLACK)
	draw_circle(Vector2(-15,-13),2.3,Color(0.96,0.30,0.18))
	draw_circle(Vector2(17,-13),2.3,Color(0.96,0.30,0.18))
	draw_ellipse(Vector2(0,5),Vector2(11,7),dark)
	draw_ellipse(Vector2(0,21),Vector2(20,8),dark)
	for i in range(clampi(floor_variant,1,5)):
		var angle := -1.2+float(i)*0.6
		var start := Vector2(cos(angle),sin(angle))*31.0
		var finish := Vector2(cos(angle+0.16),sin(angle+0.16))*45.0
		draw_line(start,finish,rim,3.0)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	draw_arc(Vector2.ZERO,53.0+sin(_age*3.0)*2.0,0.0,TAU,44,Color(rim.r,rim.g,rim.b,0.48),4.0)
