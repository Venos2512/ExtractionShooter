class_name Horde
extends RefCounted
## Updates every zombie and answers "who is near this point" through a spatial
## hash, which keeps 150 zombies and hundreds of bullets cheap.

const CELL := 48.0
const CELL_KEY := 100000

var game: Game
var t: Tuning
var list: Array[Zombie] = []
var grid: Dictionary = {}
var boss: Zombie = null
var rng := RandomNumberGenerator.new()
var door_sfx_cd := 0.0


func _init(g: Game) -> void:
	game = g
	t = g.t
	rng.randomize()


func spawn(kind: Zombie.Kind, x: float, z: float, f: int, awake: bool) -> Zombie:
	var zb := Zombie.new()
	var danger_scale := pow(t.zombie_hp_per_danger, game.danger - 1)
	zb.setup(kind, danger_scale)
	zb.x = x
	zb.z = z
	zb.f = f
	zb.awake = awake
	list.append(zb)
	if kind == Zombie.Kind.BOSS:
		boss = zb
	return zb


func update(dt: float) -> void:
	door_sfx_cd = maxf(door_sfx_cd - dt, 0.0)
	_rebuild_grid()
	var p := game.player
	var player_room := game.level.room_at(p.f, p.x)
	var i := list.size() - 1
	while i >= 0:
		var zb := list[i]
		if zb.dead:
			list.remove_at(i)
		else:
			_update_one(zb, dt, p, player_room)
		i -= 1


func _rebuild_grid() -> void:
	grid.clear()
	for zb in list:
		if zb.dead:
			continue
		var key := zb.f * CELL_KEY + int(zb.x / CELL)
		if not grid.has(key):
			grid[key] = []
		grid[key].append(zb)


func _update_one(zb: Zombie, dt: float, p: Player, player_room: Level.Room) -> void:
	zb.flash = maxf(zb.flash - dt, 0.0)
	zb.attack_t = maxf(zb.attack_t - dt, 0.0)
	if zb.falling:
		zb.h -= zb.fall_speed * dt
		if zb.h <= 0.0:
			zb.h = 0.0
			zb.falling = false
			game.fx.spray(zb.x, 4.0, zb.z, zb.f, 4, Color(0.7, 0.7, 0.7, 0.7), 90.0, 3.0, 400.0)
		return
	if zb.climb_dir != 0:
		_update_climb(zb, dt)
		return
	if zb.kind == Zombie.Kind.BOSS:
		_update_boss(zb, dt, p)
		return
	var my_room := game.level.room_at(zb.f, zb.x)
	if not zb.awake:
		if my_room == player_room:
			zb.awake = true
		else:
			return
	var tx := p.x
	var tz := p.z
	if my_room != player_room:
		var step: Level.Step = game.field[my_room.id]
		if step == null:
			return
		if step.ladder != null:
			tx = step.x
			tz = step.z
			if absf(zb.x - tx) < 12.0 and absf(zb.z - tz) < 14.0:
				zb.climb_dir = 1 if step.going_up else -1
				zb.climb_low = step.ladder.low_f
				zb.climb_u = 0.0 if step.going_up else 1.0
				zb.x = tx
				zb.z = tz
				return
		else:
			tx = step.x
			tz = t.depth * 0.5
			if not game.level.door_passable(step.door, zb.z) and absf(zb.x - step.door.x) < t.wall_margin + 8.0 and game.level.door_z_ok(zb.z):
				_bash_door(zb, step.door, dt)
	var dx := tx - zb.x
	var dz := tz - zb.z
	var dist := Vector2(dx, dz).length()
	if dist > 1.0:
		var move_x := dx / dist * zb.speed
		var move_z := dz / dist * zb.speed * 0.8
		move_x += zb.knock
		zb.knock = move_toward(zb.knock, 0.0, 900.0 * dt)
		var push := _separation(zb)
		zb.x = game.level.resolve_x(zb.f, zb.x, zb.x + (move_x + push.x) * dt, zb.z)
		zb.z = game.level.resolve_z(zb.f, zb.x, zb.z + (move_z + push.y) * dt)
		zb.anim += zb.speed * dt * 0.06
		if absf(dx) > 2.0:
			zb.facing = signf(dx)
	if my_room == player_room and not p.is_climbing() and p.f == zb.f and dist < zb.radius + 20.0:
		_attack(zb, p)


func _separation(zb: Zombie) -> Vector2:
	var key := zb.f * CELL_KEY + int(zb.x / CELL)
	var cell: Array = grid.get(key, [])
	var out := Vector2.ZERO
	var checked := 0
	for other: Zombie in cell:
		if other == zb or other.dead:
			continue
		var d := Vector2(zb.x - other.x, zb.z - other.z)
		var l := d.length()
		var want := (zb.radius + other.radius) * 0.7
		if l < want and l > 0.01:
			out += d / l * (want - l) * 6.0
		checked += 1
		if checked >= 6:
			break
	return out


func _bash_door(zb: Zombie, d: Level.Door, dt: float) -> void:
	var power := 3.0 if zb.kind == Zombie.Kind.BRUTE else 1.0
	d.hp -= 6.0 * power * dt
	if door_sfx_cd <= 0.0:
		door_sfx_cd = 0.5
		game.sfx.play("door", -8.0)
	if d.hp <= 0.0 and not d.broken:
		d.broken = true
		game.fx.spray(d.x, 60.0, t.depth * 0.5, d.f, 14, Color(0.5, 0.42, 0.32), 240.0, 5.0)
		game.fx.add_trauma(0.2)
		game.sfx.play("door")


func _attack(zb: Zombie, p: Player) -> void:
	if zb.kind == Zombie.Kind.EXPLODER:
		game.kill_zombie(zb, true)
		return
	if zb.attack_t <= 0.0:
		zb.attack_t = 0.75
		p.hurt(zb.dmg, zb.x)


func _update_climb(zb: Zombie, dt: float) -> void:
	zb.climb_u += float(zb.climb_dir) * dt / 0.9
	zb.anim += dt * 6.0
	var done := zb.climb_u >= 1.0 or zb.climb_u <= 0.0
	zb.climb_u = clampf(zb.climb_u, 0.0, 1.0)
	var pose := game.climb_pose(zb.climb_low, zb.climb_u)
	zb.f = pose.x
	zb.h = pose.y
	if done:
		zb.climb_dir = 0
		zb.h = 0.0


## Boss loop: walk, telegraph a charge along a floor lane for 0.8 s, charge, rest.
func _update_boss(zb: Zombie, dt: float, p: Player) -> void:
	zb.boss_t -= dt
	zb.anim += dt * 3.0
	if p.f != zb.f or p.is_climbing():
		# Follow the player through the building like any other zombie.
		var my_room := game.level.room_at(zb.f, zb.x)
		var step: Level.Step = game.field[my_room.id]
		if step != null and step.ladder != null and absf(zb.x - step.x) < 14.0:
			zb.climb_dir = 1 if step.going_up else -1
			zb.climb_low = step.ladder.low_f
			zb.climb_u = 0.0 if step.going_up else 1.0
			return
		if step != null:
			zb.x = move_toward(zb.x, step.x, zb.speed * 1.5 * dt)
			zb.z = move_toward(zb.z, step.z, zb.speed * dt)
			if step.door != null and absf(zb.x - step.door.x) < 30.0:
				step.door.broken = true
		return
	match zb.boss_state:
		0:
			var d := Vector2(p.x - zb.x, p.z - zb.z)
			if d.length() > 1.0:
				var v := d.normalized() * zb.speed
				zb.x = _boss_x(zb, zb.x + v.x * dt)
				zb.z = clampf(zb.z + v.y * 0.8 * dt, 10.0, t.depth - 12.0)
				zb.facing = signf(d.x) if absf(d.x) > 2.0 else zb.facing
			if d.length() < zb.radius + 24.0 and zb.attack_t <= 0.0:
				zb.attack_t = 1.0
				p.hurt(zb.dmg * 0.6, zb.x)
			if zb.boss_t <= 0.0:
				zb.boss_state = 1
				zb.boss_t = 0.8
				zb.charge = d.normalized() if d.length() > 1.0 else Vector2(zb.facing, 0.0)
				zb.facing = signf(zb.charge.x) if absf(zb.charge.x) > 0.05 else zb.facing
				game.sfx.play("alarm", -10.0)
		1:
			if zb.boss_t <= 0.0:
				zb.boss_state = 2
				zb.boss_t = 0.55
				game.fx.add_trauma(0.3)
		2:
			zb.x = _boss_x(zb, zb.x + zb.charge.x * 760.0 * dt)
			zb.z = clampf(zb.z + zb.charge.y * 620.0 * dt, 10.0, t.depth - 12.0)
			zb.anim += dt * 12.0
			if Vector2(p.x - zb.x, p.z - zb.z).length() < zb.radius + 18.0:
				p.hurt(zb.dmg, zb.x)
			if zb.boss_t <= 0.0:
				zb.boss_state = 3
				zb.boss_t = 0.7
				game.fx.add_trauma(0.4)
				game.sfx.play("boom", -6.0)
				game.fx.spray(zb.x, 10.0, zb.z, zb.f, 10, Color(0.6, 0.6, 0.6, 0.8), 200.0, 4.0)
		3:
			if zb.boss_t <= 0.0:
				zb.boss_state = 0
				zb.boss_t = rng.randf_range(3.0, 5.0)


## The boss smashes doors but stays inside the building.
func _boss_x(zb: Zombie, to_x: float) -> float:
	if zb.f < t.floors:
		var c := game.level.col_at(zb.x)
		var c2 := game.level.col_at(to_x)
		if c != c2:
			game.level.door_at(zb.f, mini(c, c2)).broken = true
	return clampf(to_x, t.wall_margin, game.level.width - t.wall_margin)


## Calls fn on zombies near a point. fn returns true to stop early.
func query(x: float, f: int, reach: float, fn: Callable) -> void:
	var lo := int((x - reach) / CELL)
	var hi := int((x + reach) / CELL)
	for c in range(lo, hi + 1):
		var cell: Array = grid.get(f * CELL_KEY + c, [])
		for zb: Zombie in cell:
			if not zb.dead and fn.call(zb):
				return


func count_awake() -> int:
	return list.size()
