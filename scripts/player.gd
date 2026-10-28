extends CharacterBody2D
class_name IsmaelPlayer

signal health_changed(current: int, maximum: int)
signal died

const PlayerState = preload("res://src/domain/player/player_state.gd")
const MotionTrail = preload("res://scripts/motion_trail.gd")
const VisualSprites = preload("res://scripts/visual_sprite_atlas.gd")
const BuildBalance = preload("res://src/domain/items/build_balance.gd")
const BODY_RADIUS := 28.0

@export var move_speed := 280.0
@export var fire_rate := 0.18
@export var max_health := 6
@export var invulnerability_time := 0.75
@export var projectile_speed := 760.0
@export var projectile_damage := 1
@export var contact_knockback := 460.0
@export var movement_acceleration := 2350.0
@export var movement_deceleration := 3100.0

var homing_strength := 0.0
var projectile_pierce := 0
var burst_count := 1
var volley_count := 1
var volley_spread := 0.16
var projectile_style := "tear"
var projectile_size_scale := 1.0
var projectile_split_count := 0
var projectile_split_spread := 0.0
var projectile_split_homing := false
var burst_fan_enabled := false
var room_heal_interval := 0
var floor_shield_enabled := false
var floor_shield_charges := 0

var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO
var health := 6
var movement_bounds := Rect2(54.0,82.0,1172.0,584.0)
var is_dead := false
var _state = PlayerState.new()
var _shoot_cooldown := 0.0
var _invulnerability := 0.0
var _knockback_velocity := Vector2.ZERO
var _movement_velocity := Vector2.ZERO
var _damage_recoil := 0.0
var _last_aim := Vector2.RIGHT
var _shoot_pose := 0.0
var _visual_recoil := 0.0
var _anim_time := 0.0
var _shot_generation := 0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 10
	health = max_health
	sync_domain_state_from_runtime()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)
	health_changed.emit(health,max_health)
	var trail := MotionTrail.new()
	trail.follow(self,"player")
	get_tree().current_scene.add_child(trail)
	queue_redraw()

func sync_domain_state_from_runtime() -> void:
	_state.move_speed = move_speed
	_state.fire_rate = fire_rate
	_state.max_health = max_health
	_state.health = clampi(health,0,max_health)
	_state.projectile_speed = projectile_speed
	_state.projectile_damage = projectile_damage
	_state.homing_strength = homing_strength
	_state.projectile_pierce = projectile_pierce
	_state.burst_count = burst_count
	_state.room_heal_interval = room_heal_interval
	_state.floor_shield_enabled = floor_shield_enabled
	_state.floor_shield_charges = floor_shield_charges

func _sync_runtime_from_domain() -> void:
	move_speed = _state.move_speed
	fire_rate = _state.fire_rate
	max_health = _state.max_health
	health = _state.health
	projectile_speed = _state.projectile_speed
	projectile_damage = _state.projectile_damage
	homing_strength = _state.homing_strength
	projectile_pierce = _state.projectile_pierce
	burst_count = _state.burst_count
	room_heal_interval = _state.room_heal_interval
	floor_shield_enabled = _state.floor_shield_enabled
	floor_shield_charges = _state.floor_shield_charges

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	_anim_time += delta
	_shoot_cooldown = maxf(0.0,_shoot_cooldown-delta)
	_invulnerability = maxf(0.0,_invulnerability-delta)
	_shoot_pose = maxf(0.0,_shoot_pose-delta)
	_visual_recoil = move_toward(_visual_recoil,0.0,70.0*delta)
	_damage_recoil = maxf(0.0,_damage_recoil-delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO,1500.0*delta)
	var desired_movement := move_input.limit_length(1.0)*move_speed
	var movement_rate := movement_acceleration if desired_movement.length_squared()>0.01 else movement_deceleration
	_movement_velocity = _movement_velocity.move_toward(desired_movement,movement_rate*delta)
	velocity = _movement_velocity+_knockback_velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is IsmaelEnemy:
			take_contact_damage(1,collider.global_position)
	clamp_to_bounds()
	if aim_input.length()>0.25 and _shoot_cooldown<=0.0:
		shoot(aim_input.normalized())
		_shoot_cooldown = _effective_fire_interval()
	queue_redraw()

func _effective_fire_interval() -> float:
	return BuildBalance.effective_fire_interval(fire_rate,volley_count,burst_count,projectile_split_count)

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds
	clamp_to_bounds()

func clamp_to_bounds() -> void:
	position.x = clampf(position.x,movement_bounds.position.x+BODY_RADIUS,movement_bounds.position.x+movement_bounds.size.x-BODY_RADIUS)
	position.y = clampf(position.y,movement_bounds.position.y+BODY_RADIUS,movement_bounds.position.y+movement_bounds.size.y-BODY_RADIUS)

func shoot(direction: Vector2) -> void:
	_last_aim = direction.normalized()
	_play_audio_sfx("shoot")
	_visual_recoil = 4.0
	_shoot_pose = 0.13
	_fire_volley(direction.normalized())
	if burst_count>1:
		_fire_burst_followups(direction.normalized(),burst_count-1)

func _fire_volley(direction: Vector2) -> void:
	# Cuenta una sola vez por volea: limitar hijos y disparos principales
	# evita sobrecargar Android con 30–40 objetos sin quitar sinergias.
	var active_count := get_tree().get_nodes_in_group("player_projectiles").size()
	var count := BuildBalance.available_primary_shots(active_count,maxi(1,volley_count))
	if count <= 0:
		return
	if count == 1:
		_spawn_projectile(direction)
		return
	var total_spread := volley_spread*float(count-1)
	for i in range(count):
		var t := 0.5 if count == 1 else float(i)/float(count-1)
		var angle := lerpf(-total_spread*0.5,total_spread*0.5,t)
		_spawn_projectile(direction.rotated(angle))

func _spawn_projectile(direction: Vector2) -> void:
	if is_dead:
		return
	var projectile := IsmaelProjectile.new()
	projectile.position = global_position+direction.normalized()*28.0
	projectile.direction = direction.normalized()
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.homing_strength = homing_strength
	projectile.pierce_remaining = projectile_pierce
	projectile.visual_style = projectile_style
	projectile.size_scale = projectile_size_scale
	projectile.void_synergy = homing_strength>0.0 and projectile_pierce>0
	projectile.split_count = projectile_split_count
	projectile.split_spread = projectile_split_spread
	projectile.split_homing = projectile_split_homing
	get_tree().current_scene.add_child(projectile)

func _fire_burst_followups(direction: Vector2, count: int) -> void:
	var generation := _shot_generation
	for i in count:
		# process_always=false: la ráfaga se detiene al pausar el SceneTree.
		await get_tree().create_timer(0.055,false).timeout
		if is_dead or generation != _shot_generation or not is_inside_tree():
			return
		var resolved_direction := direction
		if burst_fan_enabled:
			var sign_value := -1.0 if i%2==0 else 1.0
			resolved_direction = direction.rotated(sign_value*0.10)
		_fire_volley(resolved_direction)

func cancel_queued_shots() -> void:
	_shot_generation += 1
	_shoot_pose = 0.0
	_shoot_cooldown = 0.0

# Protege al entrar a un jefe mientras termina su presentación.
# Se suma a otras ventanas de invulnerabilidad, nunca las acorta.
func grant_room_entry_protection(seconds: float) -> void:
	if not is_dead:
		_invulnerability = maxf(_invulnerability,maxf(0.0,seconds))
		queue_redraw()

func take_contact_damage(amount: int, source_position: Vector2) -> void:
	if is_dead or _invulnerability>0.0:
		return
	var away := source_position.direction_to(global_position)
	if away.length_squared()<0.01:
		away = Vector2.DOWN
	_knockback_velocity = away.normalized()*contact_knockback
	take_damage(amount)

func take_damage(amount: int) -> void:
	if is_dead or _invulnerability>0.0:
		return
	sync_domain_state_from_runtime()
	if _state.consume_floor_shield():
		_sync_runtime_from_domain()
		_invulnerability = minf(invulnerability_time,0.40)
		queue_redraw()
		return
	if not _state.take_damage(amount):
		return
	_sync_runtime_from_domain()
	_invulnerability = invulnerability_time
	_damage_recoil = 0.16
	health_changed.emit(health,max_health)
	if _state.is_defeated():
		is_dead = true
		move_input = Vector2.ZERO
		aim_input = Vector2.ZERO
		velocity = Vector2.ZERO
		_movement_velocity = Vector2.ZERO
		_knockback_velocity = Vector2.ZERO
		died.emit()

func heal(amount: int) -> void:
	if is_dead:
		return
	sync_domain_state_from_runtime()
	if _state.heal(amount):
		_sync_runtime_from_domain()
		health_changed.emit(health,max_health)

func add_max_health(amount: int) -> void:
	sync_domain_state_from_runtime()
	if _state.add_max_health(amount):
		_sync_runtime_from_domain()
		health_changed.emit(health,max_health)

func notify_room_cleared() -> void:
	if is_dead:
		return
	sync_domain_state_from_runtime()
	if _state.notify_room_cleared():
		_sync_runtime_from_domain()
		health_changed.emit(health,max_health)

func refill_floor_shield() -> void:
	sync_domain_state_from_runtime()
	if _state.refill_floor_shield():
		_sync_runtime_from_domain()
		queue_redraw()

func reset_health() -> void:
	is_dead = false
	sync_domain_state_from_runtime()
	_state.reset_health()
	_sync_runtime_from_domain()
	_invulnerability = 0.0
	_movement_velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	_damage_recoil = 0.0
	health_changed.emit(health,max_health)

func _play_audio_sfx(kind: String, intensity: float = 1.0) -> void:
	var audio := get_tree().get_first_node_in_group("audio_director")
	if is_instance_valid(audio) and audio.has_method("play_sfx"):
		audio.call("play_sfx",kind,intensity)

func _draw() -> void:
	var pose_strength := clampf(_shoot_pose/0.13,0.0,1.0)
	var moving_strength := clampf(velocity.length()/maxf(move_speed,1.0),0.0,1.0)
	var stride := sin(_anim_time*11.5)*moving_strength
	var bob := absf(stride)*2.7-1.1*moving_strength+sin(_anim_time*2.1)*0.55
	var lean := clampf(velocity.x/maxf(move_speed,1.0),-1.0,1.0)*0.043
	var visual_offset := -_last_aim*_visual_recoil+Vector2(0,bob)
	var damage_strength := clampf(_damage_recoil/0.16,0.0,1.0)
	var pose_scale := Vector2(
		1.0+0.025*pose_strength+0.07*damage_strength,
		1.0-0.035*pose_strength-0.06*damage_strength
	)
	visual_offset += -_last_aim*(3.0*damage_strength)
	draw_set_transform(visual_offset,lean+_last_aim.x*0.035*pose_strength,pose_scale)
	# Arte original importado como textura, no formas provisionales.
	# Las tres poses siguen la zancada y se transforman con el retroceso.
	var art := VisualSprites.player_texture(moving_strength>0.20,_anim_time)
	var tint := Color(1.0,0.88,0.87,0.95) if _invulnerability > 0.0 and int(_invulnerability*12.0)%2==0 else Color.WHITE
	draw_texture_rect(art,VisualSprites.player_draw_rect(),false,tint)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	if floor_shield_charges>0:
		draw_arc(Vector2.ZERO,34.0,-PI*0.92,PI*0.92,34,Color(0.78,0.84,0.88,0.72),3.5)
		draw_circle(Vector2(25,-20),4.2,Color(0.88,0.78,0.48,0.90))
	if pose_strength > 0.0:
		var muzzle := _last_aim.normalized()
		var glow_position := Vector2(0,-12) + muzzle*31.0
		draw_arc(glow_position,10.0+5.0*pose_strength,0.0,TAU,26,Color(0.51,0.85,1.0,pose_strength*0.40),2.0)
		for direction_index in [-1,1]:
			var spark := muzzle.rotated(float(direction_index)*0.52)
			draw_line(glow_position+spark*8.0,glow_position+spark*(13.0+pose_strength*12.0),Color(0.78,0.93,1.0,pose_strength*0.61),2.0)
	if _shoot_pose>0.0:
		var emission_progress := 1.0-pose_strength
		var tear_origin := Vector2(0,-12)+_last_aim*(10.0+emission_progress*16.0)
		draw_circle(tear_origin+Vector2(1.5,2.0),6.3,Color(0.02,0.08,0.13,0.40))
		draw_circle(tear_origin,5.4,Color(0.34,0.72,0.96,0.92))
		draw_circle(tear_origin+Vector2(-1.8,-1.8),1.7,Color(0.92,0.98,1.0,0.95))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU*float(i)/24.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)
