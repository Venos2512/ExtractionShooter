class_name Horde
extends RefCounted
## Updates every bug and answers "who is near this point" through a spatial
## hash, which keeps 150 bugs and hundreds of bullets cheap.

const CELL := 48.0
const CELL_KEY := 100000
const LEAP_MIN := 80.0
const LEAP_MAX := 270.0
const LEAP_TIME := 0.55
const LEAP_WINDUP := 0.35
## Close enough to wake it, and still on screen, so its rest can be seen first.
const ALIEN_AGGRO := 340.0
## It keeps resting this long after the hero comes near, so he sees it before it moves.
const ALIEN_NOTICE := 1.0
## Past this it loses interest and settles down again.
const ALIEN_LOSE := 760.0
## A leap lands this far short of the hero, not on top of him.
const ALIEN_LAND_SHORT := 62.0
const ALIEN_REACH := 78.0
const ALIEN_WINDUP := 0.32
const ALIEN_STRIKE := 0.24
const ALIEN_HIT_AT := 0.08
const ALIEN_RECOVER := 0.5
const ALIEN_LEAP_WINDUP := 0.42
const ALIEN_LEAP_TIME := 0.62
const ALIEN_LEAP_HIT := 90.0
const ALIEN_LEAP_MIN := 120.0
const ALIEN_LEAP_RANGE := 540.0
const ALIEN_LAND_RECOVER := 0.8
## Heads this far under the alien count as below it, worth leaping down on.
const ALIEN_LEAP_DROP := 40.0
const ALIEN_GRAVITY := 0.8
## Choosing a route: the odds of going high, and how long it sticks with the choice.
const ALIEN_HIGH_BIAS := 0.15
const ALIEN_STAY_HIGH := 0.2
const ALIEN_HIGH_MIN := 0.25
const ALIEN_HIGH_MAX := 0.8
const ALIEN_ROUTE_MIN := 5.0
const ALIEN_ROUTE_MAX := 8.0
## The bomber: how long its fuse burns once it is on him. He can run clear of the blast.
const BOMB_FUSE := 0.7
## The leaper: it leaps from any surface, from this close, this often.
const LEAPER_RANGE := 420.0
const LEAPER_CD_MIN := 1.2
const LEAPER_CD_MAX := 2.2
const LEAPER_RECOVER := 0.35
## The stalker: how long it backs off after a strike, and how much it likes the high road.
const STALKER_RETREAT := 1.4
const STALKER_HIGH_BIAS := 0.35
## The charger. It walks for a while, braces behind its shields, runs past where the hero
## was, and stands open to fire for a moment after, longer if it ran into a wall.
const CHARGER_WALK_MIN := 3.0
const CHARGER_WALK_MAX := 5.0
const CHARGER_BRACE := 0.9
const CHARGER_BASH_WINDUP := 0.5
const CHARGER_BASH_RECOVER := 0.7
const CHARGER_SPEED := 620.0
const CHARGER_ACCEL := 1800.0
## It has to be at least this far off to bother.
const CHARGER_MIN_DIST := 260.0
const CHARGER_RUNS_PAST := 260.0
## It stops this far from a wall, which keeps its shields in the room, and still reaches.
const CHARGER_WALL_MARGIN := 190.0
const CHARGER_STUN := 1.5
const CHARGER_WALL_STUN := 2.4
const CHARGER_HIT_GAIN := 1.5
const CHARGER_KNOCK := 340.0
## The hero's body, up from his feet, which is what attacks aim for.
const HERO_MID := 38.0

var game: Game
var t: Tuning
var list: Array[Bug] = []
## Dead aliens still playing their death.
var corpses: Array[Bug] = []
var alien_picked_high := 0
var alien_picked_ground := 0
var grid: Dictionary = {}
var boss: Bug = null
var rng := RandomNumberGenerator.new()
var door_sfx_cd := 0.0


func _init(g: Game) -> void:
	game = g
	t = g.t
	rng.randomize()


func spawn(kind: Bug.Kind, x: float, f: int, awake: bool) -> Bug:
	var bug := Bug.new()
	var danger_scale := pow(t.bug_hp_per_danger, game.danger - 1)
	bug.setup(kind, danger_scale)
	bug.x = x
	bug.f = f
	bug.awake = awake
	list.append(bug)
	if kind == Bug.Kind.CHARGER or kind == Bug.Kind.ALIEN_CHARGER:
		boss = bug
	if Bug.STATS[kind].has("art"):
		bug.rig = AlienRig.new(game.arena, game.art.alien_art(kind), t.gravity, bug)
	return bug


func count_kind(kind: Bug.Kind) -> int:
	var n := 0
	for bug in list:
		if bug.kind == kind and not bug.dead:
			n += 1
	return n


func update(dt: float) -> void:
	door_sfx_cd = maxf(door_sfx_cd - dt, 0.0)
	_rebuild_grid()
	var p := game.player
	var player_room := game.level.room_at(p.f, p.x)
	var i := list.size() - 1
	while i >= 0:
		var bug := list[i]
		if bug.dead:
			list.remove_at(i)
		else:
			_update_one(bug, dt, p, player_room)
		i -= 1
	_update_corpses(dt)


func _rebuild_grid() -> void:
	grid.clear()
	for bug in list:
		if bug.dead:
			continue
		var key := bug.f * CELL_KEY + int(bug.x / CELL)
		if not grid.has(key):
			grid[key] = []
		grid[key].append(bug)


func _update_one(bug: Bug, dt: float, p: Player, player_room: Level.Room) -> void:
	bug.flash = maxf(bug.flash - dt, 0.0)
	bug.attack_t = maxf(bug.attack_t - dt, 0.0)
	if bug.rig != null:
		_update_alien(bug, dt, p)
		return
	if bug.falling:
		bug.h -= bug.fall_speed * dt
		if bug.h <= 0.0:
			_land_shard(bug)
		return
	if bug.climb_dir != 0:
		_update_climb(bug, dt)
		return
	if bug.kind == Bug.Kind.CHARGER:
		_update_boss(bug, dt, p)
		return
	var my_room := game.level.room_at(bug.f, bug.x)
	if not bug.awake:
		if my_room == player_room:
			bug.awake = true
		else:
			return
	if bug.kind == Bug.Kind.LEAPER and _update_leap(bug, dt, p, my_room == player_room):
		return
	var tx := p.x
	if my_room != player_room:
		var step: Level.Step = game.field[my_room.id]
		if step == null:
			return
		tx = step.x
		if step.ladder != null:
			if absf(bug.x - tx) < 12.0:
				_start_climb(bug, step)
				return
		elif not game.level.door_passable(step.door) and absf(bug.x - step.door.x) < t.wall_margin + 8.0:
			_bash_door(bug, step.door, dt)
	var dx := tx - bug.x
	if absf(dx) > 1.0:
		var move_x := signf(dx) * bug.speed + bug.knock
		bug.knock = move_toward(bug.knock, 0.0, 900.0 * dt)
		bug.x = game.level.resolve_x(bug.f, bug.x, bug.x + (move_x + _separation(bug)) * dt)
		bug.anim += bug.speed * dt * 0.12
		if absf(dx) > 2.0:
			bug.facing = signf(dx)
	if my_room == player_room and _touches(bug, p):
		_attack(bug, p)


func _touches(bug: Bug, p: Player) -> bool:
	if p.is_climbing() or p.f != bug.f:
		return false
	return absf(p.x - bug.x) < bug.radius + 20.0 and p.h < bug.h + bug.top and bug.h < p.h + 70.0


## Keeps the swarm spread along the floor, but lets it pile up on the hero.
func _separation(bug: Bug) -> float:
	var key := bug.f * CELL_KEY + int(bug.x / CELL)
	var cell: Array = grid.get(key, [])
	var out := 0.0
	var checked := 0
	for other: Bug in cell:
		if other == bug or other.dead:
			continue
		var d := bug.x - other.x
		var want := (bug.radius + other.radius) * 0.4
		if absf(d) < want:
			var side := signf(d) if d != 0.0 else (1.0 if bug.lane % 2 == 0 else -1.0)
			out += side * (want - absf(d)) * 6.0
		checked += 1
		if checked >= 6:
			break
	return out


func _bash_door(bug: Bug, d: Level.Door, dt: float) -> void:
	var power := 3.0 if bug.kind == Bug.Kind.WARRIOR else 1.0
	d.hp -= 6.0 * power * dt
	if door_sfx_cd <= 0.0:
		door_sfx_cd = 0.5
		game.sfx.play("door", -8.0)
	if d.hp <= 0.0 and not d.broken:
		d.broken = true
		game.fx.spray(d.x, 60.0, d.f, 14, Color(0.5, 0.42, 0.32), 240.0, 5.0)
		game.fx.add_trauma(0.2)
		game.sfx.play("door")


func _attack(bug: Bug, p: Player) -> void:
	if bug.kind == Bug.Kind.BLOATER:
		game.kill_bug(bug, true)
		return
	if bug.attack_t <= 0.0:
		bug.attack_t = 0.75
		p.hurt(bug.dmg, bug.x)


func _land_shard(bug: Bug) -> void:
	bug.h = 0.0
	bug.falling = false
	game.fx.spray(bug.x, 6.0, bug.f, 7, Color(0.35, 0.3, 0.3), 200.0, 4.0)
	game.fx.spray(bug.x, 6.0, bug.f, 5, Game.BILE, 170.0, 3.0)
	game.fx.glow(bug.x, 16.0, bug.f, 80.0, Color(1.0, 0.55, 0.2, 0.7), 0.18)
	game.fx.decal(bug.x, bug.f, 26.0, Color(0.03, 0.03, 0.03, 0.8))
	game.fx.add_trauma(0.12, 0.3)


## Leapers crouch, then jump in an arc that lands on the hero. Returns true while
## the leap owns the bug's movement.
func _update_leap(bug: Bug, dt: float, p: Player, same_room: bool) -> bool:
	bug.leap_cd -= dt
	if bug.airborne:
		bug.vh -= t.gravity * dt
		bug.h += bug.vh * dt
		bug.x = game.level.resolve_x(bug.f, bug.x, bug.x + bug.vx * dt)
		bug.anim += dt * 12.0
		if _touches(bug, p):
			_attack(bug, p)
		if bug.h <= 0.0:
			bug.h = 0.0
			bug.airborne = false
			bug.leap_cd = rng.randf_range(2.0, 4.0)
		return true
	if bug.windup > 0.0:
		bug.windup -= dt
		if bug.windup <= 0.0:
			bug.airborne = true
			bug.vx = (p.x - bug.x) / LEAP_TIME
			bug.vh = 0.5 * t.gravity * LEAP_TIME
			bug.h = 0.01
		return true
	var dist := absf(p.x - bug.x)
	if same_room and bug.leap_cd <= 0.0 and dist > LEAP_MIN and dist < LEAP_MAX and not p.is_climbing():
		bug.windup = LEAP_WINDUP
		bug.facing = signf(p.x - bug.x)
		return true
	return false


func _start_climb(bug: Bug, step: Level.Step) -> void:
	bug.climb_dir = 1 if step.going_up else -1
	bug.climb_low = step.ladder.low_f
	bug.climb_u = 0.0 if step.going_up else 1.0
	bug.x = step.x


func _update_climb(bug: Bug, dt: float, time := 0.9) -> void:
	bug.climb_u += float(bug.climb_dir) * dt / time
	bug.anim += dt * 6.0
	var done := bug.climb_u >= 1.0 or bug.climb_u <= 0.0
	bug.climb_u = clampf(bug.climb_u, 0.0, 1.0)
	var pose := game.climb_pose(bug.climb_low, bug.climb_u)
	bug.f = int(pose.x)
	bug.h = pose.y
	if done:
		bug.climb_dir = 0
		bug.h = 0.0


## The sample alien: rests until the hero is near or it is shot, then picks a way to
## him along the floor or up over the walls and ceiling. Anything in reach it strikes
## from whatever it is standing on. From high up it can also leap down on him.
func _update_alien(bug: Bug, dt: float, p: Player) -> void:
	var rig := bug.rig
	rig.state_t += dt
	bug.leap_cd -= dt
	var center := game.view.pt(p.x, p.h + HERO_MID, p.f)
	var dist := rig.pos.distance_to(center)
	if bug.kind == Bug.Kind.ALIEN_STALKER:
		_update_cloak(bug, dt)
	if bug.kind == Bug.Kind.ALIEN_CHARGER and rig.state != AlienRig.State.IDLE:
		_update_charger(bug, dt, p, center, dist)
		_finish_alien_frame(bug, dt)
		return
	match rig.state:
		AlienRig.State.IDLE:
			rig.crouch = move_toward(rig.crouch, 0.0, dt * 5.0)
			rig.face_toward(center)
			if bug.hp < bug.max_hp:
				rig.notice_t = minf(rig.notice_t, 0.0)
			elif dist < ALIEN_AGGRO or rig.hunting:
				rig.notice_t -= dt
			if rig.notice_t <= 0.0:
				rig.notice_t = ALIEN_NOTICE
				_alien_choose_route(bug, center)
				rig.set_state(AlienRig.State.CRAWL)
		AlienRig.State.CRAWL:
			_alien_crawl(bug, dt, center, dist)
		AlienRig.State.WINDUP:
			var time := ALIEN_WINDUP if rig.melee_next else ALIEN_LEAP_WINDUP
			rig.crouch = 1.0
			if bug.kind == Bug.Kind.ALIEN_BOMBER:
				if _burn_fuse(bug):
					return
			elif rig.state_t >= time:
				if rig.melee_next:
					rig.set_state(AlienRig.State.STRIKE)
				else:
					_alien_leap(bug, p)
		AlienRig.State.STRIKE:
			_alien_strike(bug, dist, p)
		AlienRig.State.LEAP:
			_alien_fly(bug, dt, p, dist)
		AlienRig.State.RECOVER:
			rig.crouch = move_toward(rig.crouch, 0.0, dt * 4.0)
			rig.swipe = move_toward(rig.swipe, 0.0, dt * 5.0)
			if rig.state_t >= bug.windup:
				_alien_choose_route(bug, center)
				rig.set_state(AlienRig.State.CRAWL)
	_finish_alien_frame(bug, dt)


func _finish_alien_frame(bug: Bug, dt: float) -> void:
	var rig := bug.rig
	rig.update(bug, dt)
	if rig.plants > 0 and rig.cloak < 0.5:
		game.sfx.play("tick", -20.0, 0.04)


## Swells and blinks faster and faster, and then goes off. Returns true once it has.
func _burn_fuse(bug: Bug) -> bool:
	var rig := bug.rig
	var u := rig.state_t / BOMB_FUSE
	rig.swell = minf(u, 1.0)
	if fposmod(rig.state_t * (5.0 + u * 14.0), 1.0) < 0.5:
		bug.flash = t.hit_flash_time
	if u < 1.0:
		return false
	game.kill_bug(bug, true)
	return true


## It shows itself to strike or leap, and for a while after being shot. Otherwise it fades.
func _update_cloak(bug: Bug, dt: float) -> void:
	var rig := bug.rig
	rig.reveal_t = maxf(rig.reveal_t - dt, 0.0)
	rig.retreat_t = maxf(rig.retreat_t - dt, 0.0)
	var attacking := rig.state == AlienRig.State.WINDUP or rig.state == AlienRig.State.STRIKE or rig.state == AlienRig.State.LEAP or rig.state == AlienRig.State.RECOVER
	var shown := attacking or rig.reveal_t > 0.0
	rig.cloak = move_toward(rig.cloak, 0.0 if shown else 1.0, dt * (9.0 if shown else 3.0))


## Walks up, and either bashes with its shields or braces behind them and charges.
func _update_charger(bug: Bug, dt: float, p: Player, center: Vector2, dist: float) -> void:
	var rig := bug.rig
	var arena := rig.arena
	match rig.state:
		AlienRig.State.CRAWL:
			rig.guard = 0.0
			rig.crouch = move_toward(rig.crouch, 0.0, dt * 5.0)
			rig.route_t -= dt
			if dist < bug.reach:
				rig.melee_next = true
				rig.face_toward(center)
				rig.set_state(AlienRig.State.WINDUP)
			elif rig.route_t <= 0.0 and dist > CHARGER_MIN_DIST:
				rig.set_state(AlienRig.State.BRACE)
			else:
				var gap := arena.gap(rig.s, arena.floor_s(clampf(center.x, CHARGER_WALL_MARGIN, Arena.WIDTH - CHARGER_WALL_MARGIN)))
				rig.face_toward(center)
				if absf(gap) > 1.0:
					rig.s = fposmod(rig.s + signf(gap) * minf(bug.speed * rig.dart(dt) * dt, absf(gap)), arena.length)
		AlienRig.State.WINDUP:
			rig.crouch = 1.0
			if rig.state_t >= CHARGER_BASH_WINDUP:
				rig.set_state(AlienRig.State.STRIKE)
		AlienRig.State.STRIKE:
			_alien_strike(bug, dist, p)
		AlienRig.State.RECOVER:
			rig.crouch = move_toward(rig.crouch, 0.0, dt * 4.0)
			rig.swipe = move_toward(rig.swipe, 0.0, dt * 5.0)
			if rig.state_t >= bug.windup:
				_charger_walk(bug)
		AlienRig.State.BRACE:
			rig.guard = 1.0
			rig.crouch = 0.6
			rig.face_toward(center)
			if rig.state_t >= CHARGER_BRACE:
				_charger_set_off(bug, center)
		AlienRig.State.CHARGE:
			_charger_run(bug, dt, p, dist)
		AlienRig.State.STUN:
			rig.guard = 0.0
			rig.crouch = move_toward(rig.crouch, 0.0, dt * 3.0)
			if rig.state_t >= rig.stun_for:
				_charger_walk(bug)


func _charger_walk(bug: Bug) -> void:
	bug.rig.route_t = rng.randf_range(CHARGER_WALK_MIN, CHARGER_WALK_MAX)
	bug.rig.set_state(AlienRig.State.CRAWL)


func _charger_set_off(bug: Bug, center: Vector2) -> void:
	var rig := bug.rig
	var arena := rig.arena
	rig.charge_dir = signf(center.x - rig.pos.x) if absf(center.x - rig.pos.x) > 1.0 else rig.side
	var wants := center.x + rig.charge_dir * CHARGER_RUNS_PAST
	var stops := clampf(wants, CHARGER_WALL_MARGIN, Arena.WIDTH - CHARGER_WALL_MARGIN)
	rig.charge_hits_wall = stops != wants
	rig.charge_left = absf(arena.gap(rig.s, arena.floor_s(stops)))
	rig.charge_speed = 0.0
	rig.want_face = rig.charge_dir
	bug.attack_t = 0.0
	rig.set_state(AlienRig.State.CHARGE)
	game.sfx.play("dash", -4.0)


func _charger_run(bug: Bug, dt: float, p: Player, dist: float) -> void:
	var rig := bug.rig
	rig.guard = 1.0
	rig.crouch = 0.3
	rig.charge_speed = move_toward(rig.charge_speed, CHARGER_SPEED, CHARGER_ACCEL * dt)
	var step := minf(rig.charge_speed * dt, rig.charge_left)
	rig.s = fposmod(rig.s + rig.charge_dir * step, rig.arena.length)
	rig.charge_left -= step
	rig.want_face = rig.charge_dir
	if dist < bug.radius + 40.0 and bug.attack_t <= 0.0:
		bug.attack_t = ALIEN_LEAP_TIME
		rig.hits += 1
		p.hurt(bug.dmg * CHARGER_HIT_GAIN, bug.x)
		p.vx += rig.charge_dir * CHARGER_KNOCK
	if rig.charge_left <= 0.0:
		rig.stun_for = CHARGER_WALL_STUN if rig.charge_hits_wall else CHARGER_STUN
		rig.set_state(AlienRig.State.STUN)
		if rig.charge_hits_wall:
			game.fx.add_trauma(0.5)
			game.fx.spray(bug.x + rig.charge_dir * bug.radius, bug.h + bug.mid, bug.f, 14, Color(0.7, 0.65, 0.55), 260.0, 4.0)
			game.sfx.play("boom", -8.0, 0.1)


func _alien_crawl(bug: Bug, dt: float, center: Vector2, dist: float) -> void:
	var rig := bug.rig
	var arena := rig.arena
	if dist > ALIEN_LOSE and bug.hp >= bug.max_hp and not rig.hunting:
		rig.set_state(AlienRig.State.IDLE)
		return
	rig.crouch = move_toward(rig.crouch, 0.0, dt * 5.0)
	rig.route_t -= dt
	if rig.route_t <= 0.0:
		_alien_choose_route(bug, center)
	var clear := arena.clear_line(rig.pos, center)
	if dist < bug.reach and clear and rig.retreat_t <= 0.0:
		rig.melee_next = true
		rig.face_toward(center)
		rig.set_state(AlienRig.State.WINDUP)
		return
	var below := center.y - rig.pos.y > ALIEN_LEAP_DROP
	var may_leap := bug.kind != Bug.Kind.ALIEN_BOMBER and not rig.on_floor_side() and below and dist < ALIEN_LEAP_RANGE
	if bug.kind == Bug.Kind.ALIEN_LEAPER:
		may_leap = dist < LEAPER_RANGE
	if may_leap and bug.leap_cd <= 0.0 and clear and dist > ALIEN_LEAP_MIN and rig.retreat_t <= 0.0:
		rig.melee_next = false
		rig.face_toward(center)
		rig.set_state(AlienRig.State.WINDUP)
		return
	var want := arena.above_s(center.x, center.y) if rig.high_route else arena.floor_s(center.x)
	var gap := arena.gap(rig.s, want)
	if rig.retreat_t > 0.0:
		gap = -signf(gap) * Arena.WIDTH if gap != 0.0 else Arena.WIDTH
	if absf(gap) > 1.0:
		rig.s = fposmod(rig.s + signf(gap) * minf(bug.speed * rig.dart(dt) * dt, absf(gap)), arena.length)
		rig.want_face = signf(gap)


## Picks a way to the hero by chance, weighted toward the shorter one, so both happen
## often and it stays hard to predict. Once up high it tends to stay up there.
func _alien_choose_route(bug: Bug, center: Vector2) -> void:
	var rig := bug.rig
	var arena := rig.arena
	var ground := absf(arena.gap(rig.s, arena.floor_s(center.x)))
	var high := absf(arena.gap(rig.s, arena.above_s(center.x, center.y)))
	var chance := ground / maxf(ground + high, 1.0) + ALIEN_HIGH_BIAS
	if not rig.on_floor_side():
		chance += ALIEN_STAY_HIGH
	if bug.kind == Bug.Kind.ALIEN_STALKER:
		chance += STALKER_HIGH_BIAS
	rig.high_route = bug.kind != Bug.Kind.ALIEN_BOMBER and rng.randf() < clampf(chance, ALIEN_HIGH_MIN, ALIEN_HIGH_MAX)
	rig.route_t = rng.randf_range(ALIEN_ROUTE_MIN, ALIEN_ROUTE_MAX)
	if rig.high_route:
		alien_picked_high += 1
	else:
		alien_picked_ground += 1


func _alien_strike(bug: Bug, dist: float, p: Player) -> void:
	var rig := bug.rig
	var u := rig.state_t / ALIEN_STRIKE
	rig.crouch = 0.0
	rig.swipe = 1.0 if u < 0.5 else 0.0
	if rig.state_t >= ALIEN_HIT_AT and bug.attack_t <= 0.0:
		bug.attack_t = ALIEN_STRIKE + 0.1
		if dist < bug.reach + 16.0:
			rig.hits += 1
			p.hurt(bug.dmg, bug.x)
	if u >= 1.0:
		_alien_recover(bug, CHARGER_BASH_RECOVER if bug.kind == Bug.Kind.ALIEN_CHARGER else ALIEN_RECOVER)
		if bug.kind == Bug.Kind.ALIEN_STALKER:
			rig.retreat_t = STALKER_RETREAT


func _alien_recover(bug: Bug, time: float) -> void:
	bug.windup = time
	bug.rig.set_state(AlienRig.State.RECOVER)


## Springs off the wall or ceiling on an arc that comes down on the hero's feet.
func _alien_leap(bug: Bug, p: Player) -> void:
	var rig := bug.rig
	rig.set_state(AlienRig.State.LEAP)
	bug.attack_t = 0.0
	var landing := p.x - signf(p.x - bug.x) * ALIEN_LAND_SHORT
	bug.vx = (landing - bug.x) / ALIEN_LEAP_TIME
	var g := t.gravity * ALIEN_GRAVITY
	var target_h := rig.arena.ground_at(landing)
	bug.vh = (target_h - bug.h + 0.5 * g * ALIEN_LEAP_TIME * ALIEN_LEAP_TIME) / ALIEN_LEAP_TIME
	rig.want_face = signf(bug.vx) if absf(bug.vx) > 1.0 else rig.want_face
	bug.leap_cd = rng.randf_range(LEAPER_CD_MIN, LEAPER_CD_MAX) if bug.kind == Bug.Kind.ALIEN_LEAPER else rng.randf_range(2.5, 4.5)


func _alien_fly(bug: Bug, dt: float, p: Player, dist: float) -> void:
	var rig := bug.rig
	rig.crouch = 0.0
	bug.vh -= t.gravity * ALIEN_GRAVITY * dt
	var next_x := bug.x + bug.vx * dt
	if not rig.arena.contains(game.view.pt(next_x, bug.h + bug.mid, bug.f)):
		bug.vx = 0.0
		next_x = bug.x
	bug.x = next_x
	bug.h += bug.vh * dt
	if dist < ALIEN_LEAP_HIT and bug.attack_t <= 0.0:
		bug.attack_t = ALIEN_LEAP_TIME
		rig.hits += 1
		p.hurt(bug.dmg, bug.x)
	var ground := rig.arena.ground_at(bug.x)
	if bug.vh < 0.0 and bug.h <= ground:
		bug.h = ground
		_alien_recover(bug, LEAPER_RECOVER if bug.kind == Bug.Kind.ALIEN_LEAPER else ALIEN_LAND_RECOVER)
		rig.land(bug)
		# It comes down swinging.
		if bug.kind == Bug.Kind.ALIEN_LEAPER and dist < bug.reach + 30.0:
			bug.attack_t = 0.0
			rig.set_state(AlienRig.State.STRIKE)
		game.fx.spray(bug.x, ground + 6.0, bug.f, 6, Color(0.5, 0.45, 0.4), 150.0, 3.0)
		game.fx.add_trauma(0.1, 0.3)


func aliens_to_draw() -> Array:
	var out: Array = corpses.duplicate()
	for bug in list:
		if bug.rig != null and not bug.dead:
			out.append(bug)
	return out


func add_corpse(bug: Bug) -> void:
	bug.rig.die(bug)
	corpses.append(bug)


func _update_corpses(dt: float) -> void:
	var i := corpses.size() - 1
	while i >= 0:
		var bug := corpses[i]
		bug.flash = maxf(bug.flash - dt, 0.0)
		if bug.rig.update_corpse(bug, dt):
			corpses.remove_at(i)
		i -= 1


## Boss loop: walk, telegraph a charge along the floor for 0.8 s, charge, rest.
## Jump over the charge or dash through it.
func _update_boss(bug: Bug, dt: float, p: Player) -> void:
	bug.boss_t -= dt
	bug.anim += dt * 3.0
	if p.f != bug.f or p.is_climbing() or game.level.walled_off(bug.f, bug.x, p.x):
		# Follow the player through the map like any other bug.
		var my_room := game.level.room_at(bug.f, bug.x)
		var step: Level.Step = game.field[my_room.id]
		if step != null and step.ladder != null and absf(bug.x - step.x) < 14.0:
			_start_climb(bug, step)
			return
		if step != null:
			bug.x = move_toward(bug.x, step.x, bug.speed * 1.5 * dt)
			if step.door != null and absf(bug.x - step.door.x) < 30.0:
				step.door.broken = true
		return
	var dx := p.x - bug.x
	match bug.boss_state:
		0:
			if absf(dx) > 1.0:
				bug.x = _boss_x(bug, bug.x + signf(dx) * bug.speed * dt)
				bug.facing = signf(dx)
			if _touches(bug, p) and bug.attack_t <= 0.0:
				bug.attack_t = 1.0
				p.hurt(bug.dmg * 0.6, bug.x)
			if bug.boss_t <= 0.0:
				bug.boss_state = 1
				bug.boss_t = 0.8
				bug.charge_dir = signf(dx) if absf(dx) > 1.0 else bug.facing
				bug.facing = bug.charge_dir
				game.sfx.play("alarm", -10.0)
		1:
			if bug.boss_t <= 0.0:
				bug.boss_state = 2
				bug.boss_t = 0.55
				game.fx.add_trauma(0.3)
		2:
			bug.x = _boss_x(bug, bug.x + bug.charge_dir * 760.0 * dt)
			bug.anim += dt * 12.0
			if _touches(bug, p):
				p.hurt(bug.dmg, bug.x)
			if bug.boss_t <= 0.0:
				bug.boss_state = 3
				bug.boss_t = 0.7
				game.fx.add_trauma(0.4)
				game.sfx.play("boom", -6.0)
				game.fx.spray(bug.x, 10.0, bug.f, 10, Color(0.6, 0.6, 0.6, 0.8), 200.0, 4.0)
		3:
			if bug.boss_t <= 0.0:
				bug.boss_state = 0
				bug.boss_t = rng.randf_range(3.0, 5.0)


## The boss smashes doors but stops at solid walls.
func _boss_x(bug: Bug, to_x: float) -> float:
	var r := game.level.room_at(bug.f, bug.x)
	var m := t.wall_margin
	if to_x > r.x1 - m:
		if r.door_r == null:
			return r.x1 - m
		r.door_r.broken = true
	elif to_x < r.x0 + m:
		if r.door_l == null:
			return r.x0 + m
		r.door_l.broken = true
	return to_x


## Calls fn on bugs near a point. fn returns true to stop early.
func query(x: float, f: int, reach: float, fn: Callable) -> void:
	var lo := int((x - reach) / CELL)
	var hi := int((x + reach) / CELL)
	for c in range(lo, hi + 1):
		var cell: Array = grid.get(f * CELL_KEY + c, [])
		for bug: Bug in cell:
			if not bug.dead and fn.call(bug):
				return


func count_awake() -> int:
	return list.size()
