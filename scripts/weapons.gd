class_name Weapons
extends RefCounted
## Auto-aimed gun plus every build piece: bullets, grenades, drones and lasers.

const MUZZLE_H := 44.0
const LASER_LENGTH := 170.0
const LASER_DPS := 70.0

class Bullet:
	var x := 0.0
	var z := 0.0
	var f := 0
	var h := 44.0
	var px := 0.0
	var pz := 0.0
	var vx := 0.0
	var vz := 0.0
	var life := 0.7
	var damage := 10.0
	var pierce := 0
	var bounces := 0
	var hit_list: Array[Zombie] = []

class Grenade:
	var x := 0.0
	var z := 0.0
	var f := 0
	var h := 40.0
	var vx := 0.0
	var vz := 0.0
	var vh := 300.0
	var spin := 0.0

var game: Game
var t: Tuning
var bullets: Array[Bullet] = []
var grenades: Array[Grenade] = []
var target: Zombie = null
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
		target = _pick_target(p.x, p.z, p.f)
	fire_timer -= dt
	if fire_timer <= 0.0 and target != null and not p.is_climbing():
		fire_timer = 1.0 / p.fire_rate
		_fire(p)
	_update_grenades(dt, p)
	_update_drones(dt, p)
	_update_lasers(dt, p)
	_update_bullets(dt)


## Sees through open doors only. Priority: anything very close, then the boss,
## then the nearest zombie.
func _pick_target(x: float, z: float, f: int) -> Zombie:
	var best: Zombie = null
	var best_score := INF
	for zb in game.horde.list:
		if zb.dead or zb.f != f or zb.h > 150.0 or zb.climb_dir != 0:
			continue
		var d := Vector2(zb.x - x, (zb.z - z) * 1.2).length()
		if d > t.aim_range or not _clear_line(f, x, zb.x, z):
			continue
		var score := d
		if d < t.close_range:
			score = d - 2000.0
		elif zb.kind == Zombie.Kind.BOSS:
			score = d - 1000.0
		if score < best_score:
			best_score = score
			best = zb
	return best


func _clear_line(f: int, x0: float, x1: float, z: float) -> bool:
	if f >= t.floors:
		return true
	var c0 := game.level.col_at(x0)
	var c1 := game.level.col_at(x1)
	if c0 == c1:
		return true
	if not game.level.door_z_ok(z):
		return false
	for c in range(mini(c0, c1), maxi(c0, c1)):
		var d := game.level.door_at(f, c)
		if not d.broken and d.open < 0.55:
			return false
	return true


func _fire(p: Player) -> void:
	var dir := Vector2(target.x - p.x, target.z - p.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(p.facing, 0.0)
	# A little spread makes the stream of tracers feel alive.
	dir = dir.rotated(rng.randf_range(-0.03, 0.03))
	if absf(dir.x) > 0.05:
		p.facing = signf(dir.x)
	_spawn_bullet(p.x + dir.x * 26.0, p.z + dir.y * 26.0, p.f, MUZZLE_H, dir, p.damage, p.pierce, p.bounces)
	recoil = 6.0
	muzzle_flash = 0.05
	game.fx.shell(p.x, MUZZLE_H, p.z, p.f, p.facing)
	game.fx.add_trauma(t.shot_trauma, 0.22)
	game.fx.glow(p.x + dir.x * 34.0, MUZZLE_H, p.z + dir.y * 34.0, p.f, 90.0, Color(1.0, 0.75, 0.35, 0.55), 0.05)
	game.sfx.play("shot", -8.0, 0.05)


func _spawn_bullet(x: float, z: float, f: int, h: float, dir: Vector2, damage: float, pierce: int, bounces: int) -> void:
	var b := Bullet.new()
	b.x = x
	b.z = z
	b.px = x
	b.pz = z
	b.f = f
	b.h = h
	b.vx = dir.x * t.bullet_speed
	b.vz = dir.y * t.bullet_speed
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
	b.pz = b.z
	var nx := b.x + b.vx * dt
	var nz := b.z + b.vz * dt
	if nz < 0.0 or nz > t.depth:
		return false
	if b.f < t.floors:
		var ca := game.level.col_at(b.x)
		var cb := game.level.col_at(nx)
		if ca != cb:
			var d := game.level.door_at(b.f, mini(ca, cb))
			if not game.level.door_passable(d, nz):
				game.fx.spray(d.x, b.h, nz, b.f, 3, Color(1.0, 0.8, 0.4), 120.0, 2.0)
				return false
	if nx < 0.0 or nx > game.level.width:
		return false
	# Sweep along the bullet path so fast tracers cannot skip thin targets.
	var lo := int(minf(b.x, nx) / Horde.CELL) - 1
	var hi := int(maxf(b.x, nx) / Horde.CELL) + 1
	for c in range(lo, hi + 1):
		var cell: Array = game.horde.grid.get(b.f * Horde.CELL_KEY + c, [])
		for zb: Zombie in cell:
			if zb.dead or zb.h > 150.0 or b.hit_list.has(zb):
				continue
			if not _segment_hits(b.x, b.z, nx, nz, zb):
				continue
			b.hit_list.append(zb)
			_on_hit(b, zb)
			if b.pierce > 0:
				b.pierce -= 1
			elif b.bounces > 0:
				if not _bounce(b, zb):
					return false
				return true
			else:
				return false
	b.x = nx
	b.z = nz
	return true


func _segment_hits(ax: float, az: float, bx: float, bz: float, zb: Zombie) -> bool:
	var seg := Vector2(bx - ax, bz - az)
	var to := Vector2(zb.x - ax, zb.z - az)
	var len2 := seg.length_squared()
	var u := clampf(to.dot(seg) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
	return (to - seg * u).length() < zb.radius


func _on_hit(b: Bullet, zb: Zombie) -> void:
	var crit := rng.randf() < game.player.crit
	var dmg := b.damage * (2.0 if crit else 1.0)
	var dir := signf(b.vx) if absf(b.vx) > 1.0 else 0.0
	game.damage_zombie(zb, dmg, crit, dir)


func _bounce(b: Bullet, from: Zombie) -> bool:
	var next: Zombie = null
	var best := 260.0
	for zb in game.horde.list:
		if zb.dead or zb == from or zb.f != b.f or b.hit_list.has(zb):
			continue
		var d := Vector2(zb.x - from.x, zb.z - from.z).length()
		if d < best:
			best = d
			next = zb
	if next == null:
		return false
	b.bounces -= 1
	var dir := Vector2(next.x - from.x, next.z - from.z).normalized()
	b.x = from.x
	b.z = from.z
	b.vx = dir.x * t.bullet_speed
	b.vz = dir.y * t.bullet_speed
	b.life = 0.4
	return true


func _update_grenades(dt: float, p: Player) -> void:
	if p.grenades > 0:
		grenade_timer -= dt
		if grenade_timer <= 0.0:
			grenade_timer = 4.0
			var throwing_at := _pick_target(p.x, p.z, p.f)
			if throwing_at != null:
				for n in p.grenades:
					_throw(p, throwing_at, float(n))
	var i := grenades.size() - 1
	while i >= 0:
		var g := grenades[i]
		g.vh -= 800.0 * dt
		g.h += g.vh * dt
		g.x = clampf(g.x + g.vx * dt, 0.0, game.level.width)
		g.z = clampf(g.z + g.vz * dt, 4.0, t.depth - 4.0)
		g.spin += dt * 12.0
		if g.h <= 0.0:
			game.explode(g.x, g.z, g.f, p.blast_radius, 45.0 * (p.damage / t.bullet_damage))
			grenades.remove_at(i)
		i -= 1


func _throw(p: Player, at: Zombie, offset: float) -> void:
	var g := Grenade.new()
	g.x = p.x
	g.z = p.z
	g.f = p.f
	var flight := 0.8
	g.vx = (at.x + offset * 40.0 - p.x) / flight
	g.vz = (at.z + offset * 15.0 - p.z) / flight
	g.vh = 0.5 * 800.0 * flight - 40.0 / flight
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
	var dir := Vector2(at.x - pos.x, at.z - pos.y).normalized()
	_spawn_bullet(pos.x, pos.y, p.f, 100.0, dir, p.damage * 0.8, 0, 0)
	game.sfx.play("shot", -16.0, 0.08)


## Drones circle in the depth plane, so they pass in front of and behind the hero.
func drone_pos(n: int) -> Vector2:
	var p := game.player
	var a := drone_angle + TAU * n / maxf(p.drones, 1.0)
	return Vector2(p.x + cos(a) * 62.0, clampf(p.z + sin(a) * 48.0, 6.0, t.depth - 6.0))


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
		for zb in game.horde.list:
			if zb.dead or zb.f != p.f or zb.h > 150.0:
				continue
			if _segment_hits(p.x, p.z, tip.x, tip.y, zb):
				game.damage_zombie(zb, LASER_DPS * 0.12 * (p.damage / t.bullet_damage), false, 0.0)


func laser_tip(n: int) -> Vector2:
	var p := game.player
	var a := laser_angle + TAU * n / maxf(p.lasers, 1.0)
	return Vector2(p.x + cos(a) * LASER_LENGTH, clampf(p.z + sin(a) * LASER_LENGTH * 0.6, 2.0, t.depth - 2.0))
