class_name Game
extends Node2D
## Run flow: intro, timers, waves, loot, the two extraction routes, and scoring.

enum State {INTRO, PLAY, CARD, REVIVE, RESULT}
enum Rescue {NONE, CALLING, HELI_IN, LANDED}

const ITEMS := [
	[{"name": "Đồ hộp", "value": 15, "slots": 1}, {"name": "Hộp thuốc", "value": 20, "slots": 1}, {"name": "Băng đạn", "value": 25, "slots": 1}],
	[{"name": "Linh kiện", "value": 45, "slots": 1}, {"name": "Pin quân dụng", "value": 70, "slots": 2}],
	[{"name": "Mẫu dịch bọ", "value": 160, "slots": 2}, {"name": "Mảnh thiên thạch", "value": 220, "slots": 3}],
]
const RARITY_COLORS := [Color(0.55, 0.85, 1.0), Color(0.76, 0.5, 1.0), Color(1.0, 0.76, 0.25)]
const BILE := Color(1.0, 0.62, 0.12)
## The intro camera looks at the sky high above the building.
const INTRO_CAM_Y := -1600.0
const ALIEN_RESPAWN := 1.2
## A bomber's blast: how far, and what it does to the aliens around it.
const BLAST_RADIUS := 120.0
const BLAST_DAMAGE := 60.0

class Pickup:
	var x := 0.0
	var x_min := 0.0
	var x_max := 0.0
	var f := 0
	var h := 30.0
	var vh := 180.0
	var vx := 0.0
	var coin := false
	var value := 0
	var item: Dictionary = {}
	var rarity := 0
	var delay := 0.35

## The story plays once per launch; restarts go straight back into a run.
static var intro_seen := false

@export var tuning: Tuning

var t: Tuning
var view: View
var level: Level
var player: Player
var horde: Horde
var weapons: Weapons
var fx: Effects
var art: Sprites
var field: Array = []
var goal_field: Array = []
var pickups: Array[Pickup] = []
var rng := RandomNumberGenerator.new()

var state := State.PLAY
var intro_t := 0.0
var impact_t := -1.0
var impact_flash := 0.0
var run_t := 0.0
var danger := 1
var next_wave_t := 0.0
var spawn_queue := 0
var spawn_timer := 0.0
var hitstop := 0.0
var last_room := -1
var boss_spawned := false
var result_text := ""
var explored_count := 0
var sample_mode := false
var arena: Arena = null
var respawn_t := 0.0
## The test level. Tests of a single alien run without it.
var sample_level: SampleLevel = null

var xp := 0
var xp_next := 5
var level_no := 1
var pending_levelups := 0
var cards_taken: Dictionary = {}
var card_offer: Array = []
var free_reroll := true
var revive_left := 1

var cash := 0
var backpack: Array = []
var kills := 0

var rescue := Rescue.NONE
var rescue_hold := 0.0
var rescue_spawn_t := 0.0
var rescue_left := 0.0
var heli_h := 900.0
var exit_hold := 0.0
var exit_x := 0.0
var beacon_x := 0.0

var input_override := Vector2.ZERO
var input_override_on := false
var dash_requested := false
var toast := ""
var toast_t := 0.0

@onready var backdrop: Backdrop = $Background
@onready var walls: WallLayer = $Walls
@onready var floors: FloorLayer = $Floors
@onready var arena_view: ArenaView = $ArenaView
@onready var world: WorldView = $WorldView
@onready var alien_view: AlienView = $AlienView
@onready var fx_view: FxView = $FxView
@onready var foreground: ForegroundLayer = $Foreground
@onready var camera: Camera2D = $Camera
@onready var sfx: Sfx = $Sfx
@onready var hud: Hud = $Hud


func _ready() -> void:
	t = tuning
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	var level_seed := rng.randi()
	for a in args:
		if a.begins_with("--seed="):
			level_seed = int(a.trim_prefix("--seed="))
	sample_mode = t.sample_build and not args.has("--oldmap")
	view = View.new(t)
	level = Level.new(t, level_seed, sample_mode)
	if sample_mode:
		arena = Arena.new(AlienRig.RIDE)
		revive_left = 0
	art = Sprites.new()
	fx = Effects.new(t)
	player = Player.new(self)
	horde = Horde.new(self)
	weapons = Weapons.new(self)
	player.x = level.start_room.x0 + 160.0
	view.cam = Vector2(player.x, view.floor_y(0) - _camera_lift())
	camera.zoom = Vector2.ONE * t.camera_zoom
	camera.make_current()
	beacon_x = lerpf(level.goal_room.x0, level.goal_room.x1, 0.5)
	exit_x = level.goal_room.x1 - 110.0
	goal_field = level.build_field(level.goal_room.id)
	next_wave_t = t.danger_interval
	if sample_mode:
		backdrop.visible = false
		arena_view.setup(arena, t.scroll_walls)
	else:
		_seed_idle_bugs()
		foreground.setup(self)
		backdrop.setup(self, floors, foreground)
		walls.setup(self)
		floors.setup(self)
	world.setup(self)
	alien_view.setup(t.hit_flash_time, horde.aliens_to_draw)
	fx_view.setup(self)
	hud.setup(self)
	if not sample_mode:
		backdrop.sky_fx.big_landed.connect(_on_big_landed)
	var intro_test := args.has("--introtest")
	var testing := intro_test or args.has("--bot") or args.has("--stress") or args.has("--joytest") or args.has("--parallaxtest") or args.has("--maptest") or args.has("--alientest") or args.has("--samplerun") or args.has("--leveltest")
	if sample_mode:
		state = State.PLAY
		hud.hide_intro()
		if testing and not args.has("--leveltest"):
			_spawn_alien()
		else:
			sample_level = SampleLevel.new(self)
			alien_view.show_frenzy = true
	elif intro_seen or args.has("--no-intro") or (testing and not intro_test):
		begin_run()
	else:
		_begin_intro()
	if testing:
		var bot: Node = load("res://scripts/debug_bot.gd").new()
		add_child(bot)
		bot.call("setup", self, args)


func _exit_tree() -> void:
	level.release()


func _begin_intro() -> void:
	state = State.INTRO
	view.cam = Vector2(player.x, INTRO_CAM_Y)
	backdrop.meteor_layer.visible = false
	backdrop.sky_fx.fall_big()
	sfx.play("alarm", -14.0)
	hud.show_intro()


func _on_big_landed() -> void:
	impact_t = intro_t
	impact_flash = 1.0
	backdrop.meteor_layer.visible = true
	fx.add_trauma(1.0)
	sfx.play("impact")


## Hands over to the player. The camera then sweeps down through every parallax
## layer on its way to the hero.
func begin_run() -> void:
	state = State.PLAY
	intro_seen = true
	backdrop.meteor_layer.visible = true
	backdrop.sky_fx.big_t = -1.0
	backdrop.sky_fx.ambient_on = true
	hud.hide_intro()


## Sleeping bugs get tougher kinds toward the goal, and nests are packed.
func _seed_idle_bugs() -> void:
	for r in level.rooms:
		if r == level.start_room or r.kind == Level.Kind.GOAL:
			continue
		var depth := level.progress_at(r.x0)
		var n := rng.randi_range(2, 3)
		if r.kind == Level.Kind.NEST:
			n = rng.randi_range(4, 6)
		for i in n:
			horde.spawn(_idle_kind(depth), rng.randf_range(r.x0 + 40.0, r.x1 - 40.0), r.f, false)


## Starts at rest far from the hero, on the floor or hanging from open ceiling, clear of
## the ledges, where it would stand all tangled up until the hero came along.
func _spawn_alien() -> void:
	var far_side := player.x < Arena.WIDTH * 0.5
	var bug := horde.spawn(Bug.Kind.ALIEN, Arena.WIDTH - 140.0 if far_side else 300.0, 0, true)
	if rng.randf() < 0.5:
		var hang_x := Arena.WIDTH - 310.0 if far_side else 300.0
		bug.rig.place(arena.above_s(hang_x, -Arena.HEIGHT * 0.5), bug)


func _idle_kind(depth: float) -> Bug.Kind:
	var roll := rng.randf()
	if depth > 0.7 and roll < 0.06:
		return Bug.Kind.WARRIOR
	if depth > 0.55 and roll < 0.14:
		return Bug.Kind.BLOATER
	if depth > 0.25 and roll < 0.32:
		return Bug.Kind.LEAPER
	return Bug.Kind.WORKER


func _process(dt: float) -> void:
	if state == State.INTRO:
		intro_t += dt
	elif state == State.PLAY:
		if hitstop > 0.0:
			hitstop -= dt
		else:
			_step(dt)
	impact_flash = maxf(impact_flash - dt * 1.1, 0.0)
	fx.update_shake(dt)
	_update_camera(dt)
	world.queue_redraw()
	alien_view.queue_redraw()
	fx_view.queue_redraw()
	hud.refresh()


## The test build: just the hero and the aliens.
func _step_sample(dt: float) -> void:
	run_t += dt
	player.update(dt, _read_input(), dash_requested)
	dash_requested = false
	horde.update(dt)
	weapons.update(dt)
	fx.update(dt)
	toast_t = maxf(toast_t - dt, 0.0)
	if sample_level != null:
		sample_level.update(dt)
	elif horde.list.is_empty() and horde.corpses.is_empty():
		respawn_t -= dt
		if respawn_t <= 0.0:
			respawn_t = ALIEN_RESPAWN
			_spawn_alien()


func _step(dt: float) -> void:
	if sample_mode:
		_step_sample(dt)
		return
	run_t += dt
	_update_timers(dt)
	var room := level.room_at(player.f, player.x)
	if room.id != last_room:
		last_room = room.id
		field = level.build_field(room.id)
		if not room.explored:
			room.explored = true
			explored_count += 1
	player.update(dt, _read_input(), dash_requested)
	dash_requested = false
	_update_doors(dt)
	_update_rooms(dt)
	horde.update(dt)
	weapons.update(dt)
	_update_crates(dt)
	_update_pickups(dt)
	_update_extraction(dt)
	fx.update(dt)
	if pending_levelups > 0 and state == State.PLAY:
		pending_levelups -= 1
		_open_cards()
	toast_t = maxf(toast_t - dt, 0.0)


func _read_input() -> Vector2:
	if input_override_on:
		return input_override
	var v := hud.joy_vector()
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.limit_length(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		dash_requested = true


func _camera_lift() -> float:
	return t.arena_camera_lift if sample_mode else t.camera_lift


func _update_camera(dt: float) -> void:
	if state != State.INTRO:
		# Jumps stay out of the camera so the hop reads and the floor stays still.
		var rise := player.h if player.is_climbing() else 0.0
		var target := Vector2(player.x + player.facing * 30.0, view.floor_y(player.f) - rise - _camera_lift())
		target.x = clampf(target.x, 240.0, level.width - 240.0)
		view.cam = view.cam.lerp(target, 1.0 - exp(-dt * 6.0))
	camera.position = view.cam + fx.shake_offset


func _update_timers(dt: float) -> void:
	var new_danger := 1 + int(run_t / t.danger_interval)
	if new_danger != danger:
		danger = new_danger
	next_wave_t -= dt
	if next_wave_t <= 0.0:
		next_wave_t = t.danger_interval
		spawn_queue += t.wave_size(danger)
		sfx.play("alarm", -4.0)
		fx.add_trauma(0.15)
		_drop_supply_crate()
		backdrop.sky_fx.shower(4 + danger)
		show_toast("Mưa thiên thạch! Bầy bọ tràn tới, có thùng hàng mới")
	if spawn_queue > 0:
		spawn_timer -= dt
		if spawn_timer <= 0.0:
			spawn_timer = 0.12
			if horde.list.size() < t.max_bugs:
				_spawn_wave_bug()
			spawn_queue -= 1
	if not boss_spawned and run_t >= t.boss_at:
		boss_spawned = true
		_spawn_boss()


## Staying longer pays: every wave drops a crate up ahead, and the odds improve
## with Danger.
func _drop_supply_crate() -> void:
	var options := _rooms_near(false)
	if options.is_empty():
		return
	var room: Level.Room = options[rng.randi() % options.size()]
	var roll := rng.randf() + danger * 0.1
	level.add_crate(room, 2 if roll > 1.0 else (1 if roll > 0.5 else 0))


## Rooms within two columns of the hero, either behind or ahead. Not the current
## room, and not the landing zone.
func _rooms_near(behind: bool) -> Array[Level.Room]:
	var reach := t.room_w * 2.0
	var out: Array[Level.Room] = []
	for r in level.rooms:
		if r.kind == Level.Kind.GOAL or r.id == last_room:
			continue
		if behind and r.x1 <= player.x and player.x - r.x1 < reach:
			out.append(r)
		elif not behind and r.x0 >= player.x and r.x0 - player.x < reach:
			out.append(r)
	return out


func _wave_kind() -> Bug.Kind:
	var roll := rng.randf()
	if danger >= 6:
		if roll < 0.10:
			return Bug.Kind.WARRIOR
		if roll < 0.22:
			return Bug.Kind.BLOATER
	if danger >= 3 and roll < 0.40:
		return Bug.Kind.LEAPER
	return Bug.Kind.WORKER


func _spawn_wave_bug() -> void:
	var kind := _wave_kind()
	var goal := level.goal_room
	if level.room_at(player.f, player.x) == goal:
		# In the open they ride meteor shards down out of the sky.
		var bug := horde.spawn(kind, rng.randf_range(goal.x0 + 40.0, goal.x1 - 40.0), 0, true)
		bug.falling = true
		bug.h = rng.randf_range(620.0, 860.0)
		return
	# Most come from behind, which keeps the hero pushing right.
	var behind := _rooms_near(true)
	var ahead := _rooms_near(false)
	var candidates := behind if (rng.randf() < 0.7 and not behind.is_empty()) or ahead.is_empty() else ahead
	if candidates.is_empty():
		return
	var room: Level.Room = candidates[rng.randi() % candidates.size()]
	var x := rng.randf_range(room.x0 + 30.0, room.x1 - 30.0)
	horde.spawn(kind, x, room.f, true)
	# They burst up through the floor from the tunnels below.
	fx.spray(x, 4.0, room.f, 4, Color(0.4, 0.3, 0.25), 150.0, 3.0)


func _spawn_boss() -> void:
	var r := level.room_at(player.f, player.x)
	var bx := r.x0 + 80.0 if player.x > (r.x0 + r.x1) * 0.5 else r.x1 - 80.0
	if r.door_l != null:
		bx = (r.door_l.room_a.x0 + r.door_l.room_a.x1) * 0.5
	var bug := horde.spawn(Bug.Kind.CHARGER, bx, player.f, true)
	bug.boss_t = 2.0
	sfx.play("alarm")
	fx.add_trauma(0.5)
	show_toast("BỌ HÚC xuất hiện! Nhảy hoặc lướt để né")


func _update_doors(dt: float) -> void:
	for d in level.doors:
		if d.broken:
			d.open = 1.0
			continue
		var near := d.f == player.f and absf(player.x - d.x) < 74.0 and not player.is_climbing()
		var was := d.open
		d.open = move_toward(d.open, 1.0 if near else 0.0, dt / 0.18)
		if was == 0.0 and d.open > 0.0:
			sfx.play("door", -14.0, 0.2)


func _update_rooms(dt: float) -> void:
	for r in level.rooms:
		if r.kind == Level.Kind.GOAL:
			continue
		var goal := 1.0 if r.id == last_room else (0.74 if r.explored else 0.42)
		r.bright = move_toward(r.bright, goal, dt * 2.0)


func _update_crates(dt: float) -> void:
	for c in level.crates:
		if c.opened or c.f != player.f or player.is_climbing():
			continue
		if absf(c.x - player.x) < 56.0:
			c.progress += dt / t.crate_open_times[c.rarity]
			if c.progress >= 1.0:
				_open_crate(c)
		else:
			c.progress = maxf(c.progress - dt, 0.0)


func _open_crate(c: Level.Crate) -> void:
	c.opened = true
	sfx.play("card", -6.0)
	fx.glow(c.x, 40.0, c.f, 110.0, Color(RARITY_COLORS[c.rarity], 0.8), 0.3)
	_drop_item(c.x, c.f, c.rarity)
	if rng.randf() < 0.4:
		_drop_item(c.x, c.f, maxi(c.rarity - 1, 0))
	for i in 3:
		_drop_coin(c.x, c.f)


func _drop_item(x: float, f: int, rarity: int) -> void:
	var p := _new_pickup(x, f)
	p.rarity = rarity
	var table: Array = ITEMS[rarity]
	p.item = table[rng.randi() % table.size()]
	p.vx = rng.randf_range(-110.0, 110.0)
	p.vh = rng.randf_range(160.0, 260.0)
	pickups.append(p)


func _drop_coin(x: float, f: int) -> void:
	var p := _new_pickup(x, f)
	p.coin = true
	p.value = rng.randi_range(2, 5)
	p.vx = rng.randf_range(-90.0, 90.0)
	p.vh = rng.randf_range(120.0, 220.0)
	pickups.append(p)


## Pickups stay in the room they dropped in, so loot never lands somewhere unreachable.
func _new_pickup(x: float, f: int) -> Pickup:
	var room := level.room_at(f, x)
	var p := Pickup.new()
	p.x = x
	p.f = f
	p.x_min = room.x0 + 8.0
	p.x_max = room.x1 - 8.0
	return p


func _update_pickups(dt: float) -> void:
	var i := pickups.size() - 1
	while i >= 0:
		var p := pickups[i]
		p.delay -= dt
		p.vh -= 700.0 * dt
		p.h += p.vh * dt
		if p.h < 8.0:
			p.h = 8.0
			p.vh *= -0.35
			p.vx *= 0.5
		p.x = clampf(p.x + p.vx * dt, p.x_min, p.x_max)
		if p.delay <= 0.0 and p.f == player.f and not player.is_climbing():
			var dx := player.x - p.x
			var dist := absf(dx)
			if dist < player.pickup_radius:
				p.x += signf(dx) * lerpf(500.0, 150.0, dist / player.pickup_radius) * dt
			if dist < 22.0 and _collect(p):
				pickups.remove_at(i)
		i -= 1


func _collect(p: Pickup) -> bool:
	if p.coin:
		cash += p.value
		sfx.play("pick", -14.0, 0.04)
		return true
	if not add_to_backpack(p.item):
		return false
	sfx.play("pick", -4.0)
	fx.number(player.x, player.h + 100.0, player.f, String(p.item.name), RARITY_COLORS[p.rarity], 24)
	return true


func backpack_used() -> int:
	var used := 0
	for it in backpack:
		used += int(it.slots)
	return used


func backpack_value() -> int:
	var v := 0
	for it in backpack:
		v += int(it.value)
	return v


## A full backpack keeps the best value per slot, swapping out the worst items.
func add_to_backpack(item: Dictionary) -> bool:
	var slots := int(item.slots)
	while backpack_used() + slots > t.backpack_slots:
		var worst := -1
		var worst_density := float(item.value) / slots
		for i in backpack.size():
			var density := float(backpack[i].value) / float(backpack[i].slots)
			if density < worst_density:
				worst_density = density
				worst = i
		if worst < 0:
			show_toast("Ba lô đầy")
			return false
		show_toast("Bỏ " + String(backpack[worst].name))
		backpack.remove_at(worst)
	backpack.append(item)
	return true


func _update_extraction(dt: float) -> void:
	_update_rescue(dt)
	if player.f == 0 and absf(player.x - exit_x) < 56.0:
		exit_hold += dt
		if exit_hold >= t.early_exit_hold:
			finish(true, false)
	else:
		exit_hold = maxf(exit_hold - dt * 2.0, 0.0)


func _update_rescue(dt: float) -> void:
	var on_beacon := player.f == 0 and absf(player.x - beacon_x) < 70.0
	match rescue:
		Rescue.NONE:
			if on_beacon:
				rescue_hold += dt
				if rescue_hold >= t.rescue_call_hold:
					rescue = Rescue.CALLING
					rescue_left = t.rescue_time
					sfx.play("alarm")
					show_toast("Đã gọi cứu hộ! Cầm cự!")
					next_wave_t = minf(next_wave_t, 3.0)
			else:
				rescue_hold = maxf(rescue_hold - dt, 0.0)
		Rescue.CALLING:
			rescue_left -= dt
			# Rescue is the climax: shards keep raining in during the wait.
			rescue_spawn_t -= dt
			if rescue_spawn_t <= 0.0:
				rescue_spawn_t = 0.5
				spawn_queue += 1
			if rescue_left <= 6.0:
				heli_h = lerpf(10.0, 900.0, maxf(rescue_left, 0.0) / 6.0)
			if rescue_left <= 0.0:
				rescue = Rescue.LANDED
				sfx.play("win", -6.0)
				show_toast("Trực thăng đã đến! Vào vùng đón!")
		Rescue.LANDED:
			if on_beacon:
				finish(true, true)


## Position along a ladder: (floor, height). Switches floor partway up so the
## actor counts as on the upper floor once its head is through the hatch.
func climb_pose(low_f: int, u: float) -> Vector2:
	var total := view.spacing
	if u < 0.6:
		return Vector2(low_f, u * total)
	return Vector2(low_f + 1, (u - 1.0) * total)


func damage_bug(bug: Bug, dmg: float, crit: bool, knock_dir: float) -> void:
	if bug.dead:
		return
	bug.hp -= dmg
	bug.flash = t.hit_flash_time
	bug.awake = true
	if knock_dir != 0.0 and bug.kind != Bug.Kind.CHARGER and bug.rig == null:
		bug.knock = knock_dir * (40.0 if bug.kind == Bug.Kind.WARRIOR else 90.0)
	if bug.rig != null:
		bug.rig.flinch(knock_dir)
	var col := Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1)
	fx.number(bug.x, bug.h + bug.top + 8.0, bug.f, str(int(dmg)), col, 28 if crit else 21)
	fx.spray(bug.x, bug.h + bug.mid, bug.f, 2, BILE, 130.0, 2.5)
	sfx.play("hit", -16.0, 0.06)
	if bug.kind == Bug.Kind.CHARGER:
		hitstop = maxf(hitstop, 0.008)
	if bug.hp <= 0.0:
		kill_bug(bug, false)


func kill_bug(bug: Bug, suicide: bool) -> void:
	if bug.dead:
		return
	bug.dead = true
	kills += 1
	if bug.rig != null:
		_kill_alien(bug, suicide)
		return
	fx.spray(bug.x, bug.h + bug.mid, bug.f, 9, BILE, 240.0, 4.0)
	fx.spray(bug.x, bug.h + bug.mid, bug.f, 4, Sprites.CHITIN_D, 180.0, 4.0)
	fx.decal(bug.x, bug.f, bug.radius * 1.5, Color(0.55, 0.28, 0.05, 0.8))
	sfx.play("die", -10.0, 0.05)
	add_xp(bug.xp)
	if rng.randf() < 0.3:
		_drop_coin(bug.x, bug.f)
	if bug.kind == Bug.Kind.BLOATER:
		explode(bug.x, bug.f, 95.0, 25.0, suicide)
	elif player.chain_chance > 0.0 and rng.randf() < player.chain_chance:
		explode(bug.x, bug.f, 70.0, 22.0)
	if bug.kind == Bug.Kind.CHARGER:
		horde.boss = null
		hitstop = maxf(hitstop, 0.12)
		fx.add_trauma(0.9)
		sfx.play("boom")
		show_toast("Đã hạ Bọ húc!")
		for i in 4:
			_drop_item(bug.x, bug.f, 2 if i == 0 else 1)
		for i in 10:
			_drop_coin(bug.x, bug.f)


func _kill_alien(bug: Bug, suicide: bool) -> void:
	respawn_t = ALIEN_RESPAWN
	if bug.kind == Bug.Kind.ALIEN_BOMBER:
		_alien_blast(bug, suicide)
		return
	fx.spray(bug.x, bug.h + bug.mid, bug.f, 12, BILE, 240.0, 4.0)
	fx.add_trauma(0.2)
	sfx.play("die", -6.0, 0.05)
	horde.add_corpse(bug)
	if horde.boss == bug:
		horde.boss = null
		hitstop = maxf(hitstop, 0.12)
		fx.add_trauma(0.9)
		sfx.play("boom")


## Shot down, it only hurts its own kind, so shooting one in a crowd pays off. Only one
## that got close enough to light its own fuse can hurt the hero.
func _alien_blast(bug: Bug, hurts_hero: bool) -> void:
	var at := bug.rig.pos
	var h := -at.y
	fx.add_trauma(0.45)
	hitstop = maxf(hitstop, t.hitstop_big)
	sfx.play("boom", -4.0, 0.08)
	fx.glow(at.x, h, bug.f, BLAST_RADIUS * 2.0, Color(1.0, 0.55, 0.2, 0.9), 0.22)
	fx.spray(at.x, h, bug.f, 18, Color(1.0, 0.6, 0.2), 360.0, 4.5)
	fx.spray(at.x, h, bug.f, 8, Color(0.25, 0.25, 0.25, 0.9), 200.0, 7.0, 300.0)
	var hero := view.pt(player.x, player.h + Horde.HERO_MID, player.f)
	if hurts_hero and hero.distance_to(at) < BLAST_RADIUS:
		player.hurt(bug.dmg, at.x)
	for other in horde.list:
		if other != bug and not other.dead and other.rig != null and other.rig.pos.distance_to(at) < BLAST_RADIUS + other.radius:
			damage_bug(other, BLAST_DAMAGE, false, signf(other.x - at.x))


func explode(x: float, f: int, radius: float, dmg: float, hurts_player := false) -> void:
	fx.add_trauma(0.45)
	hitstop = maxf(hitstop, t.hitstop_big)
	sfx.play("boom", -4.0, 0.08)
	fx.glow(x, 30.0, f, radius * 2.0, Color(1.0, 0.55, 0.2, 0.9), 0.22)
	fx.spray(x, 10.0, f, 16, Color(1.0, 0.6, 0.2), 340.0, 4.5)
	fx.spray(x, 10.0, f, 8, Color(0.25, 0.25, 0.25, 0.9), 200.0, 7.0, 300.0)
	fx.decal(x, f, radius * 0.7, Color(0.03, 0.03, 0.03, 0.75))
	var victims: Array[Bug] = []
	horde.query(x, f, radius + 60.0, func(bug: Bug) -> bool:
		if absf(bug.x - x) < radius + bug.radius and bug.h < radius:
			victims.append(bug)
		return false)
	for bug in victims:
		damage_bug(bug, dmg, false, signf(bug.x - x))
	if hurts_player and player.f == f and absf(player.x - x) < radius:
		player.hurt(dmg, x)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level_no += 1
		xp_next = 5 + level_no * 3
		pending_levelups += 1


func _open_cards() -> void:
	state = State.CARD
	free_reroll = true
	card_offer = Cards.offer(cards_taken, 3, rng)
	if card_offer.is_empty():
		state = State.PLAY
		return
	sfx.play("card")
	hud.show_cards()


func reroll_cards() -> void:
	if not free_reroll:
		return
	free_reroll = false
	card_offer = Cards.offer(cards_taken, 3, rng)
	hud.show_cards()


func choose_card(index: int) -> void:
	var card: Dictionary = card_offer[index]
	cards_taken[card.id] = int(cards_taken.get(card.id, 0)) + 1
	Cards.apply(card, player)
	state = State.PLAY
	sfx.play("pick")
	hud.hide_cards()


func on_player_down() -> void:
	if revive_left > 0:
		state = State.REVIVE
		hud.show_revive()
	else:
		finish(false, false)


func revive() -> void:
	revive_left -= 1
	player.hp = player.max_hp
	player.iframes = 2.0
	state = State.PLAY
	hud.hide_revive()
	explode(player.x, player.f, 150.0, 200.0)


func give_up() -> void:
	hud.hide_revive()
	finish(false, false)


func finish(survived: bool, rescued: bool) -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	if sample_mode:
		result_text = "Hạ được %d con sample trong %d giây" % [kills, int(run_t)]
		if sample_level != null and not survived:
			result_text += "\nĐến đợt %d/%d" % [sample_level.wave, SampleLevel.WAVES.size()]
		sfx.play("win" if survived else "lose")
		hud.show_result(survived, result_text)
		return
	var bag := backpack_value()
	var gold := float(cash + bag)
	var lines: Array[String] = []
	if rescued:
		var bonus := gold * t.rescue_gold_bonus
		lines.append("Được trực thăng đón ở bãi đáp")
		lines.append("Ba lô: %d  ·  Tiền: %d" % [bag, cash])
		lines.append("Thưởng cứu hộ: +%d" % int(bonus))
		gold += bonus
	elif survived:
		lines.append("Thoát qua cửa hầm")
		lines.append("Ba lô: %d  ·  Tiền: %d" % [bag, cash])
	else:
		gold = float(cash) * t.death_keep_gold
		lines.append("Bạn đã chết. Mất toàn bộ ba lô.")
		lines.append("Giữ %d%% tiền: %d" % [int(t.death_keep_gold * 100.0), int(gold)])
	lines.append("Thời gian: %d:%02d  ·  Danger: %d  ·  Diệt: %d" % [int(run_t) / 60, int(run_t) % 60, danger, kills])
	lines.append("TỔNG VÀNG: %d" % int(gold))
	result_text = "\n".join(lines)
	sfx.play("win" if survived else "lose")
	hud.show_result(survived, result_text)


func restart() -> void:
	get_tree().reload_current_scene()


func show_toast(text: String) -> void:
	toast = text
	toast_t = 2.0


func exploration_percent() -> int:
	return int(100.0 * explored_count / level.rooms.size())


## Next waypoint toward the landing zone, for the on-screen guide arrow. Null once
## the hero is there.
func guide_step() -> Level.Step:
	return goal_field[level.room_at(player.f, player.x).id]
