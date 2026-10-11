extends "res://scripts/enemy.gd"
class_name IsmaelSpecialEnemy

enum SpecialKind { SHIELDED, BURROWER, SPLITTER }

var special_kind: SpecialKind = SpecialKind.SHIELDED
var floor_variant := 1
var _burrow_timer := 0.0
var _burrow_hidden := false
var _burrow_target := Vector2.ZERO

func configure_special(kind_id: String, floor_index: int) -> void:
	floor_variant = maxi(1,floor_index)
	match kind_id:
		"burrower":
			special_kind = SpecialKind.BURROWER
			super.configure(IsmaelEnemy.EnemyKind.CHASER,floor_variant)
			speed = 90.0+floor_variant*6.0
			health = 4+floor_variant
			max_health = health
			scale = Vector2(0.92,0.92)
			_burrow_timer = 1.8
		"splitter":
			special_kind = SpecialKind.SPLITTER
			super.configure(IsmaelEnemy.EnemyKind.CHASER,floor_variant)
			speed = 76.0+floor_variant*5.0
			health = 5+floor_variant
			max_health = health
			scale = Vector2(1.05,1.05)
		_:
			special_kind = SpecialKind.SHIELDED
			super.configure(IsmaelEnemy.EnemyKind.CHASER,floor_variant)
			speed = 68.0+floor_variant*4.0
			health = 7+floor_variant*2
			max_health = health
			scale = Vector2(1.12,1.12)

func is_splitter() -> bool:
	return special_kind == SpecialKind.SPLITTER

func _physics_process(delta: float) -> void:
	if special_kind == SpecialKind.BURROWER:
		_update_burrow(delta)
		if _burrow_hidden:
			_age += delta
			queue_redraw()
			return
	super._physics_process(delta)

func _update_burrow(delta: float) -> void:
	_burrow_timer -= delta
	if _burrow_timer > 0.0 or not is_instance_valid(target):
		return
	if not _burrow_hidden:
		_burrow_hidden = true
		visible = false
		collision_layer = 0
		collision_mask = 0
		var away := target.global_position.direction_to(global_position)
		if away.length_squared()<0.01:
			away = Vector2.RIGHT
		var side := Vector2(-away.y,away.x) * (-1.0 if get_instance_id()%2==0 else 1.0)
		_burrow_target = target.global_position + (away*110.0+side*95.0)
		_burrow_target.x = clampf(_burrow_target.x,movement_bounds.position.x+36.0,movement_bounds.end.x-36.0)
		_burrow_target.y = clampf(_burrow_target.y,movement_bounds.position.y+36.0,movement_bounds.end.y-36.0)
		_burrow_timer = 0.62
	else:
		global_position = _burrow_target
		_burrow_hidden = false
		visible = true
		collision_layer = 2
		collision_mask = 11
		spawn_grace_time = 0.34
		_burrow_timer = maxf(1.45,2.25-float(floor_variant)*0.12)

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if special_kind == SpecialKind.SHIELDED and source_position != Vector2.ZERO:
		var to_source := global_position.direction_to(source_position)
		var to_player := Vector2.ZERO
		if is_instance_valid(target):
			to_player = global_position.direction_to(target.global_position)
		if to_player.length_squared()>0.01 and to_source.dot(to_player)>0.32:
			_hit_flash = 0.08
			_impact_velocity += -to_source.normalized()*45.0
			queue_redraw()
			return
	super.take_damage(amount,source_position)

func _desired_movement(to_player: Vector2, delta: float) -> Vector2:
	match special_kind:
		SpecialKind.SHIELDED:
			var tangent := Vector2(-to_player.y,to_player.x)*sin(_age*1.8)*0.22
			return (to_player+tangent).normalized()
		SpecialKind.SPLITTER:
			var tangent := Vector2(-to_player.y,to_player.x)*sin(_age*3.1)*0.34
			return (to_player*0.72+tangent).normalized()
		_:
			return super._desired_movement(to_player,delta)

func _draw() -> void:
	var flash := _hit_flash>0.0
	match special_kind:
		SpecialKind.SHIELDED:
			_draw_shielded(flash)
		SpecialKind.BURROWER:
			_draw_burrower(flash)
		SpecialKind.SPLITTER:
			_draw_splitter(flash)
	_draw_attack_telegraph()

func _draw_shielded(flash: bool) -> void:
	var body := Color(0.95,0.88,0.80) if flash else Color(0.27,0.21,0.18)
	var rim := Color(0.08,0.06,0.055)
	draw_ellipse(Vector2(0,22),Vector2(27,8),Color(0,0,0,0.31))
	draw_ellipse(Vector2(0,0),Vector2(24,27),rim)
	draw_ellipse(Vector2(0,-1),Vector2(20,23),body)
	var facing := Vector2.UP
	if is_instance_valid(target):
		facing = global_position.direction_to(target.global_position)
	var side := Vector2(-facing.y,facing.x)
	var center := facing*21.0
	var p1 := center-side*18.0
	var p2 := center+side*18.0
	var p3 := center+facing*18.0+side*12.0
	var p4 := center+facing*18.0-side*12.0
	draw_colored_polygon(PackedVector2Array([p1,p2,p3,p4]),Color(0.22,0.25,0.27))
	draw_line(p1,p2,Color(0.54,0.60,0.62),3.0)
	draw_line(p2,p3,Color(0.54,0.60,0.62),3.0)
	draw_line(p3,p4,Color(0.36,0.40,0.42),3.0)
	draw_line(p4,p1,Color(0.36,0.40,0.42),3.0)

func _draw_burrower(flash: bool) -> void:
	var skin := Color(1.0,0.88,0.80) if flash else Color(0.45,0.24,0.12)
	var dark := Color(0.12,0.07,0.04)
	draw_ellipse(Vector2(0,20),Vector2(24,7),Color(0,0,0,0.28))
	draw_ellipse(Vector2(0,1),Vector2(22,20),dark)
	draw_ellipse(Vector2(0,-1),Vector2(18,17),skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-13,-13),Vector2(-4,-27),Vector2(0,-12)]),dark)
	draw_colored_polygon(PackedVector2Array([Vector2(13,-13),Vector2(4,-27),Vector2(0,-12)]),dark)
	draw_circle(Vector2(-6,-5),3.0,Color(0.78,0.16,0.10))
	draw_circle(Vector2(6,-5),3.0,Color(0.78,0.16,0.10))

func _draw_splitter(flash: bool) -> void:
	var flesh := Color(1.0,0.90,0.84) if flash else Color(0.42,0.10,0.18)
	var dark := Color(0.14,0.025,0.045)
	draw_ellipse(Vector2(0,22),Vector2(25,8),Color(0,0,0,0.30))
	draw_ellipse(Vector2(-9,0),Vector2(15,23),dark)
	draw_ellipse(Vector2(9,0),Vector2(15,23),dark)
	draw_ellipse(Vector2(-9,-1),Vector2(12,20),flesh)
	draw_ellipse(Vector2(9,-1),Vector2(12,20),flesh)
	draw_line(Vector2(0,-18),Vector2(0,19),Color(0.05,0.01,0.02),5.0)
	draw_circle(Vector2(-10,-7),3.5,Color.BLACK)
	draw_circle(Vector2(10,-7),3.5,Color.BLACK)
