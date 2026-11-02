class_name SampleLevel
extends RefCounted
## The test level: waves of the sample alien in the arena until they are all dead or the
## hero is. Each one spawned has its own frenzy, so calm and frantic ones can be compared.

## Who comes in each wave.
const WAVES: Array[Array] = [
	[Bug.Kind.ALIEN, Bug.Kind.ALIEN, Bug.Kind.ALIEN_BOMBER],
	[Bug.Kind.ALIEN, Bug.Kind.ALIEN_BOMBER, Bug.Kind.ALIEN_LEAPER, Bug.Kind.ALIEN_LEAPER],
	[Bug.Kind.ALIEN_STALKER, Bug.Kind.ALIEN_STALKER, Bug.Kind.ALIEN_LEAPER, Bug.Kind.ALIEN_BOMBER, Bug.Kind.ALIEN],
	[Bug.Kind.ALIEN_CHARGER, Bug.Kind.ALIEN_BOMBER, Bug.Kind.ALIEN],
]
const FIRST_WAVE_DELAY := 1.5
const WAVE_GAP := 2.5
## The aliens of a wave arrive this far apart.
const SPAWN_GAP := 0.45
## A new wave gives back this share of the hero's health.
const WAVE_HEAL := 0.4
## They appear at least this far from the hero, which is about the edge of the screen.
const SPAWN_CLEAR := 380.0
const SPAWN_TRIES := 24
const SPAWN_MARGIN := 90.0
## Ground this far to either side has to be just as flat, to stay clear of ledges and slopes.
const SPAWN_FLAT := 70.0
## The base alien has less than one fought alone, since here there are several at once.
const ALIEN_HP := 150.0
## It takes a moment to notice the hero after appearing.
const NOTICE_MIN := 0.2
const NOTICE_MAX := 0.8

var game: Game
## The next wave to begin, counted from 0.
var wave := 0
## The kind and the frenzy of each alien of this wave that has yet to appear.
var pending: Array[Array] = []
var wait_t := FIRST_WAVE_DELAY
var resting := true


func _init(g: Game) -> void:
	game = g


func update(dt: float) -> void:
	wait_t -= dt
	if wait_t > 0.0:
		return
	if not pending.is_empty():
		var next: Array = pending.pop_back()
		_spawn(next[0], next[1])
		wait_t = SPAWN_GAP
	elif resting:
		resting = false
		if wave < WAVES.size():
			_begin_wave()
		else:
			game.finish(true, false)
	elif game.horde.list.is_empty():
		resting = true
		wait_t = WAVE_GAP


func status() -> String:
	var left := game.horde.list.size() + pending.size()
	return "Đợt %d/%d  ·  Còn %d con  ·  Hạ: %d" % [wave, WAVES.size(), left, game.kills]


func _begin_wave() -> void:
	var kinds: Array = WAVES[wave]
	var count := kinds.size()
	pending.clear()
	# One from each slice of 0 to 1, so every wave shows the whole range.
	var slices: Array[int] = []
	for i in count:
		slices.append(i)
	slices.shuffle()
	for i in count:
		pending.append([kinds[i], (slices[i] + game.rng.randf()) / count])
	pending.shuffle()
	if wave > 0:
		var p := game.player
		p.hp = minf(p.hp + p.max_hp * WAVE_HEAL, p.max_hp)
	wave += 1
	game.show_toast("Đợt %d/%d" % [wave, WAVES.size()])
	game.sfx.play("alarm", -14.0)


func _spawn(kind: Bug.Kind, frenzy: float) -> void:
	# The heavy and the explosive start on the floor, where they stay.
	var at := _spawn_s(kind != Bug.Kind.ALIEN_CHARGER and kind != Bug.Kind.ALIEN_BOMBER)
	var bug := game.horde.spawn(kind, 0.0, 0, true)
	if kind == Bug.Kind.ALIEN:
		bug.max_hp = ALIEN_HP
		bug.hp = ALIEN_HP
	var rig := bug.rig
	rig.place(at, bug)
	rig.set_frenzy(frenzy)
	rig.hunting = true
	rig.notice_t = game.rng.randf_range(NOTICE_MIN, NOTICE_MAX)
	rig.alpha = 0.0
	if kind == Bug.Kind.ALIEN_STALKER:
		rig.cloak = 1.0
	if kind == Bug.Kind.ALIEN_CHARGER:
		game.show_toast("Boss: bọ húc")
	if kind != Bug.Kind.ALIEN_STALKER:
		game.fx.spray(bug.x, bug.h + bug.mid, bug.f, 8, Game.BILE, 200.0, 3.5)
		game.sfx.play("door", -14.0, 0.1)


## Somewhere flat on the floor or the ceiling, out of the hero's way. If nowhere turns up,
## the far end of the floor.
func _spawn_s(may_hang: bool) -> float:
	var arena := game.arena
	var p := game.player
	var hero := game.view.pt(p.x, p.h + Horde.HERO_MID, p.f)
	for i in SPAWN_TRIES:
		var x := game.rng.randf_range(SPAWN_MARGIN, Arena.WIDTH - SPAWN_MARGIN)
		var s := arena.floor_s(x) if not may_hang or game.rng.randf() < 0.5 else arena.above_s(x, -Arena.HEIGHT * 0.5)
		if _flat_at(s) and arena.at.distance_to(hero) >= SPAWN_CLEAR:
			return s
	return arena.floor_s(Arena.WIDTH - SPAWN_MARGIN if p.x < Arena.WIDTH * 0.5 else SPAWN_MARGIN)


func _flat_at(s: float) -> bool:
	var arena := game.arena
	arena.pose(fposmod(s - SPAWN_FLAT, arena.length))
	var before := arena.normal
	arena.pose(fposmod(s + SPAWN_FLAT, arena.length))
	var after := arena.normal
	arena.pose(s)
	return absf(arena.normal.y) > 0.95 and arena.normal.dot(before) > 0.95 and arena.normal.dot(after) > 0.95
