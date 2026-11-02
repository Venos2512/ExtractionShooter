class_name Weapons
extends RefCounted
## Auto-aimed gun plus every build piece: bullets, grenades, drones and lasers.
## Shots fly in the 2D plane, so airborne leapers can be shot out of the air.

const MUZZLE_H := 40.0
const MUZZLE_OUT := 26.0
const LASER_LENGTH := 170.0
const LASER_DPS := 70.0
const DRONE_H := 100.0

class Bullet:
	var x := 0.0
	var h := 40.0
	var f := 0
	var px := 0.0
	var ph := 0.0
	var vx := 0.0
	var vh := 0.0
	var life := 0.7
	var damage := 10.0
	var pierce := 0
	var bounces := 0
	var hit_list: Array[Bug] = []

class Grenade:
	var x := 0.0
	var f := 0
	var h := 40.0
	var vx := 0.0
	var vh := 300.0
	var spin := 0.0

var game: Game
var t: Tuning
var bullets: Array[Bullet] = []
var grenades: Array[Grenade] = []
var target: Bug = null
var aim_timer := 0.0
var fire_timer := 0.0
var grenade_timer := 3.0
var drone_timer := 0.0
var drone_angle := 0.0
var laser_angle := 0.0
var laser_tick := 0.0
var recoil := 0.0
var muzzle_flash := 0.0
var rng := RandomNumberGenerator.new()


func _init(g: Game) -> void:
	game = g
	t = g.t
	rng.randomize()


func update(dt: float) -> void:
	var p := game.player
	recoil = move_toward(recoil, 0.0, dt * 60.0)
	muzzle_flash = maxf(muzzle_flash - dt, 0.0)
	aim_timer -= dt
	if aim_timer <= 0.0 or target == null or target.dead:
		aim_timer = 0.1
		target = _pick_target(p.x, p.h + MUZZLE_H, p.f)
	fire_timer -= dt
	if fire_timer <= 0.0 and target != null and p.can_shoot():
		fire_timer = 1.0 / p.fire_rate
		_fire(p)
	_update_grenades(dt, p)
	_update_drones(dt, p)
	_update_lasers(dt, p)
	_update_bullets(dt)


## Sees through open doors only. Priority: anything very close, then the boss,
## then the nearest bug.
func _pick_target(x: float, h: float, f: int) -> Bug:
	var best: Bug = null
	var best_score := INF
	for bug in game.horde.list:
		if bug.dead or bug.f != f or bug.falling or bug.climb_dir != 0:
			continue
		var d := Vector2(bug.aim_x() - x, bug.aim_h() - h).length()
		if d > t.aim_range or not game.level.clear_line(f, x, bug.x):
			continue
		# The gun will not find what cannot be seen, until it is right on top of him.
		if bug.rig != null and bug.rig.cloak > 0.5 and d > t.close_range:
			continue
		if game.arena != null and not game.arena.clear_line(game.view.pt(x, h, f), game.view.pt(bug.aim_x(), bug.aim_h(), f)):
			continue
		var score := d
		if d < t.close_range:
			score = d - 2000.0
		elif bug.kind == Bug.Kind.CHARGER:
			score = d - 1000.0
		if score < best_score:
			best_score = score
			best = bug
	return best


func _fire(p: Player) -> void:
	var muzzle_h := p.h + MUZZLE_H
	var dir := Vector2(target.aim_x() - p.x, target.aim_h() - muzzle_h)
	# The bullet starts past the muzzle, but never past something standing right on it.
	var out := minf(MUZZLE_OUT, dir.length() * 0.5)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(p.facing, 0.0)
	# A little spread makes the stream of tracers feel alive.
	dir = dir.rotated(rng.randf_range(-0.03, 0.03))
	if absf(dir.x) > 0.05:
		p.facing = signf(dir.x)
	_spawn_bullet(p.x + dir.x * out, muzzle_h + dir.y * out, p.f, dir, p.damage, p.pierce, p.bounces)
	recoil = 6.0
	muzzle_flash = 0.05
	game.fx.shell(p.x, muzzle_h, p.f, p.facing)
	game.fx.add_trauma(t.shot_trauma, 0.22)
	game.fx.glow(p.x + dir.x * 34.0, muzzle_h + dir.y * 34.0, p.f, 90.0, Color(1.0, 0.75, 0.35, 0.55), 0.05)
	game.sfx.play("shot", -8.0, 0.05)


func _spawn_bullet(x: float, h: float, f: int, dir: Vector2, damage: float, pierce: int, bounces: int) -> void:
	var b := Bullet.new()
	b.x = x
	b.h = h
	b.px = x
	b.ph = h
	b.f = f
	b.vx = dir.x * t.bullet_speed
	b.vh = dir.y * t.bullet_speed
	b.damage = damage
	b.pierce = pierce
	b.bounces = bounces
	bullets.append(b)


func _update_bullets(dt: float) -> void:
	var i := bullets.size() - 1
	while i >= 0:
		var b := bullets[i]
		if not _step_bullet(b, dt):
			bullets.remove_at(i)
		i -= 1


## Returns false when the bullet is spent.
func _step_bullet(b: Bullet, dt: float) -> bool:
	b.life -= dt
	if b.life <= 0.0:
		return false
	b.px = b.x
	b.ph = b.h
	var nx := b.x + b.vx * dt
	var nh := b.h + b.vh * dt
	var room := game.level.room_at(b.f, b.x)
	if nx >= room.x1 or nx < room.x0:
		var d := room.door_r if nx >= room.x1 else room.door_l
		if d == null or not game.level.door_passable(d) or nh > t.door_height:
			game.fx.spray(room.x1 if nx >= room.x1 else room.x0, nh, b.f, 3, Color(1.0, 0.8, 0.4), 120.0, 2.0)
			return false
	# Sweep along the bullet path so fast tracers cannot skip thin targets.
	# Two cells to either side, since the biggest bug is wider than one.
	var lo := int(minf(b.x, nx) / Horde.CELL) - 2
	var hi := int(maxf(b.x, nx) / Horde.CELL) + 2
	for c in range(lo, hi + 1):
		var cell: Array = game.horde.grid.get(b.f * Horde.CELL_KEY + c, [])
		for bug: Bug in cell:
			if bug.dead or bug.falling or b.hit_list.has(bug):
				continue
			if not _segment_hits(b.x, b.h, nx, nh, bug):
				continue
			b.hit_list.append(bug)
			if bug.rig != null and bug.rig.deflects(Vector2(b.vx, -b.vh)):
				_glance_off(b, bug)
				return true
			_on_hit(b, bug)
			if b.pierce > 0:
				b.pierce -= 1
			elif b.bounces > 0:
				if not _bounce(b, bug):
					return false
				return true
			else:
				return false
	# Terrain comes after the hit check, so a shot at something right against the floor
	# or a wall counts before the same step would take it into the surface.
	if game.arena != null and not game.arena.contains(game.view.pt(nx, nh, b.f)):
		game.fx.spray(b.x, b.h, b.f, 3, Color(1.0, 0.8, 0.4), 120.0, 2.0)
		return false
	if game.arena == null:
		if nh <= 0.0:
			game.fx.spray(nx, 2.0, b.f, 2, Color(0.7, 0.65, 0.55), 90.0, 2.0)
			return false
		if room.kind != Level.Kind.GOAL and nh >= t.room_h:
			return false
	b.x = nx
	b.h = nh
	return true


func _segment_hits(ax: float, ah: float, bx: float, bh: float, bug: Bug) -> bool:
	var seg := Vector2(bx - ax, bh - ah)
	var to := Vector2(bug.aim_x() - ax, bug.aim_h() - ah)
	var len2 := seg.length_squared()
	var u := clampf(to.dot(seg) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
	return (to - seg * u).length() < bug.radius


## Off a closed shield and away, doing nothing.
func _glance_off(b: Bullet, bug: Bug) -> void:
	var back := Vector2(-b.vx, b.vh).rotated(rng.randf_range(-0.6, 0.6))
	b.vx = back.x
	b.vh = back.y
	game.fx.spray(b.x, b.h, b.f, 5, Color(1.0, 0.8, 0.4), 220.0, 2.5)
	game.sfx.play("clink", -8.0, 0.04)


func _on_hit(b: Bullet, bug: Bug) -> void:
	var crit := rng.randf() < game.player.crit
	var dmg := b.damage * (2.0 if crit else 1.0)
	var dir := signf(b.vx) if absf(b.vx) > 1.0 else 0.0
	game.damage_bug(bug, dmg, crit, dir)


func _bounce(b: Bullet, from: Bug) -> bool:
	var next: Bug = null
	var best := 260.0
	for bug in game.horde.list:
		if bug.dead or bug == from or bug.f != b.f or bug.falling or b.hit_list.has(bug):
			continue
		var d := absf(bug.x - from.x)
		if d < best:
			best = d
			next = bug
	if next == null:
		return false
	b.bounces -= 1
	var dir := Vector2(next.x - from.x, next.h + next.mid - from.h - from.mid).normalized()
	b.x = from.x
	b.h = from.h + from.mid
	b.vx = dir.x * t.bullet_speed
	b.vh = dir.y * t.bullet_speed
	b.life = 0.4
	return true


func _update_grenades(dt: float, p: Player) -> void:
	if p.grenades > 0:
		grenade_timer -= dt
		if grenade_timer <= 0.0:
			grenade_timer = 4.0
			var throwing_at := _pick_target(p.x, p.h + MUZZLE_H, p.f)
			if throwing_at != null:
				for n in p.grenades:
					_throw(p, throwing_at, float(n))
	var i := grenades.size() - 1
	while i >= 0:
		var g := grenades[i]
		g.vh -= 800.0 * dt
		g.h += g.vh * dt
		g.x = clampf(g.x + g.vx * dt, 0.0, game.level.width)
		g.spin += dt * 12.0
		if g.h <= 0.0:
			game.explode(g.x, g.f, p.blast_radius, 45.0 * (p.damage / t.bullet_damage))
			grenades.remove_at(i)
		i -= 1


func _throw(p: Player, at: Bug, offset: float) -> void:
	var g := Grenade.new()
	g.x = p.x
	g.f = p.f
	g.h = p.h + MUZZLE_H
	var flight := 0.8
	g.vx = (at.x + offset * 40.0 - p.x) / flight
	g.vh = 0.5 * 800.0 * flight - g.h / flight
	grenades.append(g)


func _update_drones(dt: float, p: Player) -> void:
	if p.drones <= 0:
		return
	drone_angle += dt * 1.6
	drone_timer -= dt
	if drone_timer > 0.0:
		return
	drone_timer = 0.7 / p.drones
	var n := int(rng.randi() % p.drones)
	var pos := drone_pos(n)
	var at := _pick_target(pos.x, pos.y, p.f)
	if at == null:
		return
	var dir := Vector2(at.x - pos.x, at.h + at.mid - pos.y).normalized()
	_spawn_bullet(pos.x, pos.y, p.f, dir, p.damage * 0.8, 0, 0)
	game.sfx.play("shot", -16.0, 0.08)


## Drones orbit the hero in the screen plane. Returns (x, height).
func drone_pos(n: int) -> Vector2:
	var p := game.player
	var a := drone_angle + TAU * n / maxf(p.drones, 1.0)
	return Vector2(p.x + cos(a) * 62.0, p.h + DRONE_H + sin(a) * 26.0)


func _update_lasers(dt: float, p: Player) -> void:
	if p.lasers <= 0:
		return
	laser_angle += dt * 2.4
	laser_tick -= dt
	if laser_tick > 0.0:
		return
	laser_tick = 0.12
	for n in p.lasers:
		var tip := laser_tip(n)
		for bug in game.horde.list:
			if bug.dead or bug.f != p.f or bug.falling:
				continue
			if _segment_hits(p.x, p.h + MUZZLE_H, tip.x, tip.y, bug):
				game.damage_bug(bug, LASER_DPS * 0.12 * (p.damage / t.bullet_damage), false, 0.0)


## The beam sweeps around the hero and stops at the floor. Returns (x, height).
func laser_tip(n: int) -> Vector2:
	var p := game.player
	var a := laser_angle + TAU * n / maxf(p.lasers, 1.0)
	return Vector2(p.x + cos(a) * LASER_LENGTH, maxf(p.h + MUZZLE_H + sin(a) * LASER_LENGTH, 0.0))
