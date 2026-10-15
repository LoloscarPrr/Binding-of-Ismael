extends "res://scripts/enemy.gd"
class_name IsmaelAdvancedEnemy

# Extra archetypes layer on top of the stable enemy movement/combat contract.
# BRUTE reuses pursuit, SPITTER keeps distance and shoots, STALKER reuses dash
# movement with a much smaller/faster body, and FLOOR_BOSS scales by floor.
enum AdvancedKind { BRUTE, SPITTER, STALKER, FLOOR_BOSS }

var advanced_kind: AdvancedKind = AdvancedKind.BRUTE
var floor_variant := 1
var elite_variant := false
var _phase_two_announced := false

func configure_advanced(kind_id: String, floor_index: int) -> void:
	floor_variant = maxi(1,floor_index)
	elite_variant = kind_id.ends_with("_elite")
	var base_kind := kind_id.replace("_elite","")
	match base_kind:
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
			var boss_health_curve: Array[int] = [110,150,195,245,305]
			health = boss_health_curve[clampi(floor_variant-1,0,boss_health_curve.size()-1)]
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
	if elite_variant:
		health = int(ceil(float(health)*1.45))
		max_health = health
		speed *= 1.08
		scale *= 1.08

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
		AdvancedKind.FLOOR_BOSS:
			return _boss_movement(to_player)
		_:
			return super._desired_movement(to_player,delta)

func _boss_movement(to_player: Vector2) -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	var distance := global_position.distance_to(target.global_position)
	var tangent := Vector2(-to_player.y,to_player.x)
	match clampi(floor_variant,1,5):
		1:
			# EL CARCELERO owns the middle distance and slides sideways like a closing gate.
			var radial := to_player*clampf((distance-225.0)/110.0,-0.85,0.85)
			return (tangent*sin(_age*1.15)*0.95+radial).normalized()
		2:
			# LA MANDÍBULA relentlessly closes space, only easing off at contact range.
			if distance<92.0:
				return (tangent*0.55-to_player*0.24).normalized()
			return (to_player+tangent*sin(_age*2.6)*0.20).normalized()
		3:
			# EL VIGÍA protects long firing lanes and rotates around Ismael.
			var radial := to_player*clampf((distance-305.0)/115.0,-1.0,0.72)
			return (tangent*0.92+radial).normalized()
		4:
			# EL SEPULTURERO drifts deliberately while keeping the player inside ring patterns.
			var radial := to_player*clampf((distance-245.0)/145.0,-0.62,0.62)
			return (tangent*sin(_age*0.72)*0.56+radial).normalized()
		_:
			# EL HUECO never settles: pursuit and orbit trade dominance continuously.
			var pulse := 0.5+0.5*sin(_age*1.35)
			return (to_player*(0.45+pulse*0.70)+tangent*sin(_age*2.0)*(0.35+0.55*(1.0-pulse))).normalized()

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	var was_above_half := health*2 > max_health
	super.take_damage(amount,source_position)
	if advanced_kind != AdvancedKind.FLOOR_BOSS or _phase_two_announced:
		return
	if was_above_half and health > 0 and health*2 <= max_health:
		_phase_two_announced = true
		_spawn_phase_two_feedback()

func _spawn_phase_two_feedback() -> void:
	if not is_inside_tree():
		return
	_play_audio_sfx("boss_phase",1.25)
	var vfx := CombatFeedbackVfx.new()
	vfx.configure("phase",floor_variant,1.0)
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position
	_hit_flash = 0.34
	_attack_windup = 0.0
	_attack_cooldown = 0.34
	queue_redraw()

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
	if elite_variant:
		angles = [-0.28,-0.14,0.0,0.14,0.28]
	for angle: float in angles:
		_spawn_enemy_shot(aim.rotated(angle),275.0+floor_variant*20.0+(28.0 if elite_variant else 0.0),0)
	_attack_cooldown = maxf(0.72 if elite_variant else 0.92,(1.34 if elite_variant else 1.62)-float(floor_variant)*0.11)

func _fire_floor_boss_attack() -> void:
	if not is_instance_valid(target):
		return
	var phase_two := health*2 <= max_health
	match clampi(floor_variant,1,5):
		1:
			_fire_jailer_pattern(phase_two)
		2:
			_fire_maw_pattern(phase_two)
		3:
			_fire_watcher_pattern(phase_two)
		4:
			_fire_gravedigger_pattern(phase_two)
		_:
			_fire_hollow_pattern(phase_two)
	_attack_sequence += 1

func _fire_jailer_pattern(phase_two: bool) -> void:
	var aim := global_position.direction_to(target.global_position)
	if _attack_sequence%2==0:
		var bars: Array[float] = [-0.48,-0.24,0.0,0.24,0.48]
		if phase_two:
			bars = [-0.60,-0.40,-0.20,0.0,0.20,0.40,0.60]
		for angle in bars:
			if not phase_two and absf(angle-0.24)<0.01:
				continue
			_spawn_enemy_shot(aim.rotated(angle),300.0+(22.0 if phase_two else 0.0),1)
	else:
		var sides: Array[float] = [-1.0,1.0]
		for side: float in sides:
			for step in range(3+(1 if phase_two else 0)):
				var angle: float = side*(0.18+float(step)*0.16)
				_spawn_enemy_shot(aim.rotated(angle),282.0+float(step)*18.0,1)
	_attack_cooldown = 0.78 if phase_two else 1.08

func _fire_maw_pattern(phase_two: bool) -> void:
	var aim := global_position.direction_to(target.global_position)
	if _attack_sequence%3!=2:
		var teeth: Array[float] = [-0.34,-0.17,0.0,0.17,0.34]
		if phase_two:
			teeth = [-0.46,-0.30,-0.15,0.0,0.15,0.30,0.46]
		for angle in teeth:
			_spawn_enemy_shot(aim.rotated(angle),360.0+(28.0 if phase_two else 0.0),1)
	else:
		var count := 10 if phase_two else 8
		for i in range(count):
			var angle := TAU*float(i)/float(count)
			_spawn_enemy_shot(Vector2.RIGHT.rotated(angle),250.0,1)
	_attack_cooldown = 0.62 if phase_two else 0.88

func _fire_watcher_pattern(phase_two: bool) -> void:
	var aim := global_position.direction_to(target.global_position)
	if _attack_sequence%2==0:
		for offset in [0.0,PI*0.5,PI,PI*1.5]:
			_spawn_enemy_shot(Vector2.RIGHT.rotated(_age*0.55+offset),315.0,1)
		if phase_two:
			for offset in [PI*0.25,PI*0.75,PI*1.25,PI*1.75]:
				_spawn_enemy_shot(Vector2.RIGHT.rotated(_age*0.55+offset),335.0,1)
	else:
		for angle in [-0.08,0.0,0.08]:
			_spawn_enemy_shot(aim.rotated(angle),430.0+(25.0 if phase_two else 0.0),1)
	_attack_cooldown = 0.70 if phase_two else 1.02

func _fire_gravedigger_pattern(phase_two: bool) -> void:
	var count := 12 if phase_two else 9
	var spiral := _age*1.08+float(_attack_sequence)*0.31
	for i in range(count):
		var angle := spiral+TAU*float(i)/float(count)
		var speed_value := 235.0+float(i%3)*34.0
		_spawn_enemy_shot(Vector2.RIGHT.rotated(angle),speed_value,1)
	if _attack_sequence%3==2:
		var aim := global_position.direction_to(target.global_position)
		for angle in [-0.42,-0.21,0.0,0.21,0.42]:
			_spawn_enemy_shot(aim.rotated(angle),300.0,1)
	_attack_cooldown = 0.74 if phase_two else 1.04

func _fire_hollow_pattern(phase_two: bool) -> void:
	match _attack_sequence%4:
		0:
			_fire_jailer_pattern(phase_two)
		1:
			_fire_maw_pattern(phase_two)
		2:
			_fire_watcher_pattern(phase_two)
		_:
			_fire_gravedigger_pattern(phase_two)
	_attack_cooldown = 0.52 if phase_two else 0.76

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
	if elite_variant:
		draw_arc(Vector2.ZERO,37.0+sin(_age*5.0)*2.0,0.0,TAU,30,Color(0.95,0.68,0.18,0.78),3.5)
		draw_circle(Vector2(0,-30),4.5,Color(1.0,0.82,0.28,0.82))

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
	match clampi(floor_variant,1,5):
		1:
			# CARCELERO: broad, squared body with prison bars.
			draw_rect(Rect2(-48,-35,96,72),dark)
			draw_rect(Rect2(-42,-31,84,64),flesh)
			for x in [-27.0,-9.0,9.0,27.0]:
				draw_line(Vector2(x,-30),Vector2(x,30),rim,5.0)
			draw_ellipse(Vector2(0,-7),Vector2(13,10),Color.BLACK)
		2:
			# MANDÍBULA: low heavy silhouette dominated by a huge toothed mouth.
			draw_ellipse(Vector2(0,3),Vector2(53,38),dark)
			draw_ellipse(Vector2(0,0),Vector2(47,33),flesh)
			draw_ellipse(Vector2(0,10),Vector2(31,16),Color(0.07,0.02,0.015))
			for x in [-20.0,-10.0,0.0,10.0,20.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(x-5,1),Vector2(x+5,1),Vector2(x,13)]),rim)
				draw_colored_polygon(PackedVector2Array([Vector2(x-5,20),Vector2(x+5,20),Vector2(x,9)]),rim)
		3:
			# VIGÍA: tall cyclopean body with rotating sight marks.
			draw_ellipse(Vector2(0,0),Vector2(39,47),dark)
			draw_ellipse(Vector2(0,-2),Vector2(34,42),flesh)
			draw_ellipse(Vector2(0,-8),Vector2(22,18),rim)
			draw_ellipse(Vector2(0,-8),Vector2(11,14),Color.BLACK)
			draw_circle(Vector2(0,-10),4.0,Color(0.92,0.28,0.22))
			for a in [0.0,PI*0.5,PI,PI*1.5]:
				draw_line(Vector2.RIGHT.rotated(a+_age*0.55)*34.0,Vector2.RIGHT.rotated(a+_age*0.55)*52.0,rim,4.0)
		4:
			# SEPULTURERO: hunched tomb-like shell and shovel-shaped crown.
			draw_ellipse(Vector2(0,5),Vector2(48,38),dark)
			draw_ellipse(Vector2(0,3),Vector2(42,33),flesh)
			draw_rect(Rect2(-24,-28,48,18),rim)
			draw_line(Vector2(0,-34),Vector2(0,-58),rim,8.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-13,-58),Vector2(13,-58),Vector2(0,-72)]),rim)
			draw_ellipse(Vector2(0,8),Vector2(18,10),Color.BLACK)
		_:
			# HUECO: asymmetric void with fragments orbiting its missing center.
			draw_ellipse(Vector2(0,0),Vector2(50,43),dark)
			draw_ellipse(Vector2(0,-1),Vector2(43,36),flesh)
			draw_ellipse(Vector2(0,-2),Vector2(24,23),Color(0.015,0.008,0.02))
			for i in range(5):
				var a := _age*0.8+TAU*float(i)/5.0
				draw_circle(Vector2(cos(a),sin(a))*48.0,6.0,rim)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	draw_arc(Vector2.ZERO,55.0+sin(_age*3.0)*2.0,0.0,TAU,44,Color(rim.r,rim.g,rim.b,0.52),4.0)
	if health*2<=max_health:
		draw_arc(Vector2.ZERO,61.0+sin(_age*6.0)*2.0,0.0,TAU,44,Color(1.0,0.20,0.12,0.56),4.0)
