class_name Player
extends RefCounted
## Movement, dash and ladders for the hero. Stats here are changed by cards.

var game: Game
var t: Tuning

var x := 0.0
var z := 0.0
var f := 0
var h := 0.0
var vx := 0.0
var vz := 0.0
var facing := 1.0
var anim := 0.0
var flash := 0.0
var hp := 100.0
var max_hp := 100.0
var iframes := 0.0
var god_mode := false

var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT

var climb_dir := 0
var climb_u := 0.0
var climb_low := 0
var climb_x := 0.0
var climb_z := 0.0
var climb_lock := 0.0

var fire_rate := 6.0
var damage := 10.0
var crit := 0.05
var pierce := 0
var bounces := 0
var grenades := 0
var drones := 0
var lasers := 0
var chain_chance := 0.0
var blast_radius := 90.0
var pickup_radius := 70.0
var dash_cooldown := 6.0


func _init(g: Game) -> void:
	game = g
	t = g.t
	hp = t.max_hp
	max_hp = t.max_hp
	fire_rate = t.fire_rate
	damage = t.bullet_damage
	dash_cooldown = t.dash_cooldown


func update(dt: float, input: Vector2, wants_dash: bool) -> void:
	flash = maxf(flash - dt, 0.0)
	iframes = maxf(iframes - dt, 0.0)
	dash_cd = maxf(dash_cd - dt, 0.0)
	climb_lock = maxf(climb_lock - dt, 0.0)
	if climb_dir != 0:
		_update_climb(dt)
		return
	if wants_dash and dash_cd <= 0.0:
		dash_cd = dash_cooldown
		dash_t = t.dash_time
		iframes = maxf(iframes, t.dash_iframes)
		dash_dir = input.normalized() if input.length() > 0.2 else Vector2(facing, 0.0)
		game.sfx.play("dash")
		game.fx.spray(x, 10.0, z, f, 6, Color(0.8, 0.8, 0.7, 0.8), 120.0, 3.0, 400.0)
	var accel := t.move_speed / maxf(t.accel_time, 0.001)
	if dash_t > 0.0:
		dash_t -= dt
		vx = dash_dir.x * t.dash_speed
		vz = -dash_dir.y * t.dash_speed * t.depth_speed_ratio
	else:
		vx = move_toward(vx, input.x * t.move_speed, accel * dt)
		vz = move_toward(vz, -input.y * t.move_speed * t.depth_speed_ratio, accel * dt)
	if absf(input.x) > 0.1:
		facing = signf(input.x)
	var new_x := game.level.resolve_x(f, x, x + vx * dt, z)
	x = new_x
	z = game.level.resolve_z(f, x, z + vz * dt)
	var speed := Vector2(vx, vz).length()
	anim += speed * dt * 0.05
	if climb_lock <= 0.0:
		_try_ladders(input)


func _try_ladders(input: Vector2) -> void:
	var up := game.level.ladder_up(f)
	if up != null and input.y < -0.5 and absf(x - up.x) < 30.0 and z > up.z - 28.0:
		_start_climb(up, 1)
		return
	var down := game.level.ladder_down(f)
	if down != null and input.y > 0.6 and absf(input.x) < 0.5 and absf(x - down.x) < 30.0 and z > down.z - 28.0:
		_start_climb(down, -1)


func _start_climb(l: Level.Ladder, dir: int) -> void:
	climb_dir = dir
	climb_low = l.low_f
	climb_u = 0.0 if dir > 0 else 1.0
	climb_x = l.x
	climb_z = l.z
	vx = 0.0
	vz = 0.0
	x = l.x
	z = l.z


func _update_climb(dt: float) -> void:
	climb_u += float(climb_dir) * dt / t.climb_time
	anim += dt * 8.0
	var done := climb_u >= 1.0 or climb_u <= 0.0
	climb_u = clampf(climb_u, 0.0, 1.0)
	var pose := game.climb_pose(climb_low, climb_u)
	f = pose.x
	h = pose.y
	if done:
		climb_dir = 0
		h = 0.0
		climb_lock = 0.3


func is_climbing() -> bool:
	return climb_dir != 0


func hurt(amount: float, from_x: float) -> void:
	if iframes > 0.0 or god_mode:
		return
	hp -= amount
	iframes = 0.25
	flash = 0.12
	vx += signf(x - from_x) * 120.0
	game.fx.number(x, 90.0, z, f, str(int(amount)), Color(1.0, 0.35, 0.3), 26)
	game.fx.add_trauma(0.35)
	game.fx.spray(x, 40.0, z, f, 5, Color(0.8, 0.12, 0.1), 150.0)
	game.sfx.play("hurt")
	if hp <= 0.0:
		hp = 0.0
		game.on_player_down()
