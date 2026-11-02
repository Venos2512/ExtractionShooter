class_name Player
extends RefCounted
## Movement, dash and ladders for the hero. Stats here are changed by cards.

var game: Game
var t: Tuning

var x := 0.0
var f := 0
var h := 0.0
var vx := 0.0
var facing := 1.0
var anim := 0.0
var flash := 0.0
var hp := 100.0
var max_hp := 100.0
var iframes := 0.0
var god_mode := false

var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := 1.0
## The way it last walked, which is where a dash goes with no direction held.
var heading := 1.0

var climb_dir := 0
var climb_u := 0.0
var climb_low := 0
var climb_lock := 0.0

var fire_rate := 3.0
var damage := 20.0
var crit := 0.05
var pierce := 0
var bounces := 0
var grenades := 0
var drones := 0
var lasers := 0
var chain_chance := 0.0
var blast_radius := 90.0
var pickup_radius := 70.0
var dash_cooldown := 4.0


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
		dash_dir = signf(input.x) if absf(input.x) > 0.2 else heading
		game.sfx.play("dash")
		game.fx.spray(x, 10.0, f, 6, Color(0.8, 0.8, 0.7, 0.8), 120.0, 3.0, 400.0)
	var accel := t.move_speed / maxf(t.accel_time, 0.001)
	if dash_t > 0.0:
		dash_t -= dt
		vx = dash_dir * t.dash_speed
	else:
		vx = move_toward(vx, input.x * t.move_speed, accel * dt)
	if absf(input.x) > 0.1:
		heading = signf(input.x)
	# It keeps facing what it shoots at, whichever way it walks.
	var aim := game.weapons.target
	facing = signf(aim.x - x) if aim != null and not aim.dead and absf(aim.x - x) > 4.0 else heading
	x = game.level.resolve_x(f, x, x + vx * dt)
	anim += absf(vx) * dt * 0.05
	if game.arena != null:
		h = game.arena.ground_at(x)
	if climb_lock <= 0.0:
		_try_ladders(input)


func can_shoot() -> bool:
	return climb_dir == 0


func _try_ladders(input: Vector2) -> bool:
	if input.y < -0.5:
		var up := game.level.ladder_up_near(f, x, 30.0)
		if up != null:
			_start_climb(up, 1)
			return true
	elif input.y > 0.6 and absf(input.x) < 0.5:
		var down := game.level.ladder_down_near(f, x, 30.0)
		if down != null:
			_start_climb(down, -1)
			return true
	return false


func _start_climb(l: Level.Ladder, dir: int) -> void:
	climb_dir = dir
	climb_low = l.low_f
	climb_u = 0.0 if dir > 0 else 1.0
	vx = 0.0
	x = l.x


func _update_climb(dt: float) -> void:
	climb_u += float(climb_dir) * dt / t.climb_time
	anim += dt * 8.0
	var done := climb_u >= 1.0 or climb_u <= 0.0
	climb_u = clampf(climb_u, 0.0, 1.0)
	var pose := game.climb_pose(climb_low, climb_u)
	f = int(pose.x)
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
	game.fx.number(x, h + 90.0, f, str(int(amount)), Color(1.0, 0.35, 0.3), 26)
	game.fx.add_trauma(0.35)
	game.fx.spray(x, h + 40.0, f, 5, Color(0.8, 0.12, 0.1), 150.0)
	game.sfx.play("hurt")
	if hp <= 0.0:
		hp = 0.0
		game.on_player_down()
