class_name Game
extends Node2D
## Run flow: timers, waves, loot, the two extraction routes, and scoring.

enum State {PLAY, CARD, REVIVE, RESULT}
enum Rescue {NONE, CALLING, HELI_IN, LANDED}

const ITEMS := [
	[{"name": "Đồ hộp", "value": 15, "slots": 1}, {"name": "Hộp thuốc", "value": 20, "slots": 1}, {"name": "Băng đạn", "value": 25, "slots": 1}],
	[{"name": "Linh kiện", "value": 45, "slots": 1}, {"name": "Pin quân dụng", "value": 70, "slots": 2}],
	[{"name": "Mẫu virus", "value": 160, "slots": 2}, {"name": "Ổ dữ liệu", "value": 220, "slots": 3}],
]
const RARITY_COLORS := [Color(0.55, 0.85, 1.0), Color(0.76, 0.5, 1.0), Color(1.0, 0.76, 0.25)]

class Pickup:
	var x := 0.0
	var z := 0.0
	var f := 0
	var h := 30.0
	var vh := 180.0
	var vx := 0.0
	var vz := 0.0
	var coin := false
	var value := 0
	var item: Dictionary = {}
	var rarity := 0
	var delay := 0.35

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
var roof_field: Array = []
var exit_field: Array = []
var pickups: Array[Pickup] = []
var rng := RandomNumberGenerator.new()

var state := State.PLAY
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
var exit_room_x := 0.0
var beacon_x := 0.0
var beacon_z := 0.0

var input_override := Vector2.ZERO
var input_override_on := false
var dash_requested := false
var toast := ""
var toast_t := 0.0

@onready var world: WorldView = $WorldView
@onready var fx_view: FxView = $FxView
@onready var camera: Camera2D = $Camera
@onready var sfx: Sfx = $Sfx
@onready var hud: Hud = $Hud


func _ready() -> void:
	t = tuning
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	var level_seed := rng.randi()
	view = View.new(t)
	level = Level.new(t, level_seed)
	art = Sprites.new()
	fx = Effects.new(t)
	player = Player.new(self)
	horde = Horde.new(self)
	weapons = Weapons.new(self)
	player.x = t.room_w * 1.5
	player.z = t.depth * 0.5
	view.cam = Vector2(player.x, view.floor_y(0) - 170.0)
	camera.zoom = Vector2.ONE * t.camera_zoom
	camera.make_current()
	beacon_x = level.width * 0.5
	beacon_z = t.depth * 0.5
	exit_room_x = t.room_w * 0.5
	roof_field = level.build_field(level.roof_id)
	exit_field = level.build_field(level.room(0, 0).id)
	next_wave_t = t.danger_interval
	_seed_idle_zombies()
	world.setup(self)
	fx_view.setup(self)
	hud.setup(self)
	if args.has("--bot") or args.has("--stress") or args.has("--joytest"):
		var bot: Node = load("res://scripts/debug_bot.gd").new()
		add_child(bot)
		bot.call("setup", self, args)


func _seed_idle_zombies() -> void:
	for r in level.rooms:
		if r.id == level.roof_id or r.id == level.room(0, 1).id:
			continue
		var n := rng.randi_range(2, 4) + r.f
		for i in n:
			var kind := Zombie.Kind.NORMAL
			if r.f >= 1 and rng.randf() < 0.2:
				kind = Zombie.Kind.RUNNER
			horde.spawn(kind, rng.randf_range(r.x0 + 40.0, r.x1 - 40.0), rng.randf_range(20.0, t.depth * 0.7), r.f, false)


func _process(dt: float) -> void:
	if state == State.PLAY:
		if hitstop > 0.0:
			hitstop -= dt
		else:
			_step(dt)
	fx.update_shake(dt)
	_update_camera(dt)
	world.queue_redraw()
	fx_view.queue_redraw()
	hud.refresh()


func _step(dt: float) -> void:
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


func _update_camera(dt: float) -> void:
	var target := Vector2(player.x + player.facing * 30.0, view.floor_y(player.f) - player.h - 170.0)
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
		show_toast("Đợt zombie tới! Có thùng hàng mới")
	if spawn_queue > 0:
		spawn_timer -= dt
		if spawn_timer <= 0.0:
			spawn_timer = 0.12
			if horde.list.size() < t.max_zombies:
				_spawn_wave_zombie()
			spawn_queue -= 1
	if not boss_spawned and run_t >= t.boss_at:
		boss_spawned = true
		_spawn_boss()


## Staying longer pays: every wave drops a crate, and the odds improve with Danger.
func _drop_supply_crate() -> void:
	var options: Array[Level.Room] = []
	for r in level.rooms:
		if r.id != level.roof_id and r.id != last_room:
			options.append(r)
	var room: Level.Room = options[rng.randi() % options.size()]
	var roll := rng.randf() + danger * 0.1
	level.add_crate(room, 2 if roll > 1.0 else (1 if roll > 0.5 else 0))


func _wave_kind() -> Zombie.Kind:
	var roll := rng.randf()
	if danger >= 6:
		if roll < 0.10:
			return Zombie.Kind.BRUTE
		if roll < 0.22:
			return Zombie.Kind.EXPLODER
	if danger >= 3 and roll < 0.40:
		return Zombie.Kind.RUNNER
	return Zombie.Kind.NORMAL


func _spawn_wave_zombie() -> void:
	var kind := _wave_kind()
	if player.f >= t.floors:
		# On the roof they drop out of the sky, so the threat comes from depth too.
		var zb := horde.spawn(kind, rng.randf_range(40.0, level.width - 40.0), rng.randf_range(15.0, t.depth - 20.0), t.floors, true)
		zb.falling = true
		zb.h = rng.randf_range(420.0, 620.0)
		return
	var candidates: Array[Level.Room] = []
	for r in level.rooms:
		if r.id == level.roof_id or r.id == last_room:
			continue
		if absi(r.f - player.f) <= 1:
			candidates.append(r)
	var room: Level.Room = candidates[rng.randi() % candidates.size()]
	horde.spawn(kind, rng.randf_range(room.x0 + 30.0, room.x1 - 30.0), rng.randf_range(15.0, t.depth * 0.7), room.f, true)


func _spawn_boss() -> void:
	var c := level.col_at(player.x)
	var bx: float
	if player.f >= t.floors:
		bx = 80.0 if player.x > level.width * 0.5 else level.width - 80.0
	else:
		var other := c + 1 if c < t.cols - 1 else c - 1
		bx = (other + 0.5) * t.room_w
	var zb := horde.spawn(Zombie.Kind.BOSS, bx, t.depth * 0.5, player.f, true)
	zb.boss_t = 2.0
	sfx.play("alarm")
	fx.add_trauma(0.5)
	show_toast("BOSS xuất hiện!")


func _update_doors(dt: float) -> void:
	for d in level.doors:
		if d.broken:
			d.open = 1.0
			continue
		var near := d.f == player.f and absf(player.x - d.x) < 74.0 and not player.is_climbing()
		var was := d.open
		d.open = move_toward(d.open, 1.0 if near else 0.0, dt / 0.18)
		if was == 0.0 and d.open > 0.0 and absf(player.z - t.depth * 0.5) < t.depth * 0.45:
			sfx.play("door", -14.0, 0.2)


func _update_rooms(dt: float) -> void:
	for r in level.rooms:
		if r.id == level.roof_id:
			continue
		var goal := 1.0 if r.id == last_room else (0.5 if r.explored else 0.14)
		r.bright = move_toward(r.bright, goal, dt * 2.0)


func _update_crates(dt: float) -> void:
	for c in level.crates:
		if c.opened or c.f != player.f or player.is_climbing():
			continue
		if Vector2(c.x - player.x, c.z - player.z).length() < 56.0:
			c.progress += dt / t.crate_open_times[c.rarity]
			if c.progress >= 1.0:
				_open_crate(c)
		else:
			c.progress = maxf(c.progress - dt, 0.0)


func _open_crate(c: Level.Crate) -> void:
	c.opened = true
	sfx.play("card", -6.0)
	fx.glow(c.x, 40.0, c.z, c.f, 110.0, Color(RARITY_COLORS[c.rarity], 0.8), 0.3)
	_drop_item(c.x, c.z, c.f, c.rarity)
	if rng.randf() < 0.4:
		_drop_item(c.x, c.z, c.f, maxi(c.rarity - 1, 0))
	for i in 3:
		_drop_coin(c.x, c.z, c.f)


func _drop_item(x: float, z: float, f: int, rarity: int) -> void:
	var p := Pickup.new()
	p.x = x
	p.z = z
	p.f = f
	p.rarity = rarity
	var table: Array = ITEMS[rarity]
	p.item = table[rng.randi() % table.size()]
	p.vx = rng.randf_range(-110.0, 110.0)
	p.vz = rng.randf_range(-50.0, 50.0)
	p.vh = rng.randf_range(160.0, 260.0)
	pickups.append(p)


func _drop_coin(x: float, z: float, f: int) -> void:
	var p := Pickup.new()
	p.x = x
	p.z = z
	p.f = f
	p.coin = true
	p.value = rng.randi_range(2, 5)
	p.vx = rng.randf_range(-90.0, 90.0)
	p.vz = rng.randf_range(-40.0, 40.0)
	p.vh = rng.randf_range(120.0, 220.0)
	pickups.append(p)


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
			p.vz *= 0.5
		p.x = clampf(p.x + p.vx * dt, 8.0, level.width - 8.0)
		p.z = clampf(p.z + p.vz * dt, 6.0, t.depth - 6.0)
		if p.delay <= 0.0 and p.f == player.f and not player.is_climbing():
			var d := Vector2(player.x - p.x, player.z - p.z)
			var dist := d.length()
			if dist < player.pickup_radius:
				var speed := lerpf(500.0, 150.0, dist / player.pickup_radius)
				p.x += d.normalized().x * speed * dt
				p.z += d.normalized().y * speed * dt
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
	fx.number(player.x, 100.0, player.z, player.f, String(p.item.name), RARITY_COLORS[p.rarity], 24)
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
	var open := run_t >= t.early_exit_opens_at
	if open and player.f == 0 and Vector2(player.x - exit_room_x, player.z - t.depth * 0.5).length() < 56.0:
		exit_hold += dt
		if exit_hold >= t.early_exit_hold:
			finish(true, false)
	else:
		exit_hold = maxf(exit_hold - dt * 2.0, 0.0)


func _update_rescue(dt: float) -> void:
	var on_beacon := player.f == t.floors and Vector2(player.x - beacon_x, player.z - beacon_z).length() < 70.0
	match rescue:
		Rescue.NONE:
			if on_beacon and run_t >= t.rescue_opens_at:
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
			# Rescue is the climax: zombies keep raining in during the wait.
			rescue_spawn_t -= dt
			if rescue_spawn_t <= 0.0:
				rescue_spawn_t = 0.5
				spawn_queue += 1
			if rescue_left <= 6.0:
				heli_h = lerpf(60.0, 900.0, maxf(rescue_left, 0.0) / 6.0)
			if rescue_left <= 0.0:
				rescue = Rescue.LANDED
				sfx.play("win", -6.0)
				show_toast("Trực thăng đã đến! Vào vòng tròn!")
		Rescue.LANDED:
			if on_beacon:
				finish(true, true)


func climb_pose(low_f: int, u: float) -> Vector2:
	# Rising from the lower floor, then emerging through the hatch of the upper one.
	if u < 0.6:
		return Vector2(low_f, u / 0.6 * t.room_h)
	return Vector2(low_f + 1, -70.0 * (1.0 - (u - 0.6) / 0.4))


func damage_zombie(zb: Zombie, dmg: float, crit: bool, knock_dir: float) -> void:
	if zb.dead:
		return
	zb.hp -= dmg
	zb.flash = t.hit_flash_time
	zb.awake = true
	if knock_dir != 0.0 and zb.kind != Zombie.Kind.BOSS:
		zb.knock = knock_dir * (40.0 if zb.kind == Zombie.Kind.BRUTE else 90.0)
	var col := Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1)
	fx.number(zb.x, 62.0 * zb.size, zb.z, zb.f, str(int(dmg)), col, 28 if crit else 21)
	fx.spray(zb.x, 40.0 * zb.size, zb.z, zb.f, 2, Color(0.35, 0.75, 0.2), 130.0, 2.5)
	sfx.play("hit", -16.0, 0.06)
	if zb.kind == Zombie.Kind.BOSS:
		hitstop = maxf(hitstop, 0.008)
	if zb.hp <= 0.0:
		kill_zombie(zb, false)


func kill_zombie(zb: Zombie, suicide: bool) -> void:
	if zb.dead:
		return
	zb.dead = true
	kills += 1
	fx.spray(zb.x, 40.0, zb.z, zb.f, 9, Color(0.3, 0.68, 0.18), 240.0, 4.0)
	fx.decal(zb.x, zb.z, zb.f, 22.0 * zb.size, Color(0.14, 0.32, 0.08, 0.75))
	sfx.play("die", -10.0, 0.05)
	add_xp(zb.xp)
	if rng.randf() < 0.3:
		_drop_coin(zb.x, zb.z, zb.f)
	if zb.kind == Zombie.Kind.EXPLODER:
		explode(zb.x, zb.z, zb.f, 95.0, 25.0, suicide)
	elif player.chain_chance > 0.0 and rng.randf() < player.chain_chance:
		explode(zb.x, zb.z, zb.f, 70.0, 22.0)
	if zb.kind == Zombie.Kind.BOSS:
		horde.boss = null
		hitstop = maxf(hitstop, 0.12)
		fx.add_trauma(0.9)
		sfx.play("boom")
		show_toast("Đã hạ boss!")
		for i in 4:
			_drop_item(zb.x, zb.z, zb.f, 2 if i == 0 else 1)
		for i in 10:
			_drop_coin(zb.x, zb.z, zb.f)


func explode(x: float, z: float, f: int, radius: float, dmg: float, hurts_player := false) -> void:
	fx.add_trauma(0.45)
	hitstop = maxf(hitstop, t.hitstop_big)
	sfx.play("boom", -4.0, 0.08)
	fx.glow(x, 30.0, z, f, radius * 2.0, Color(1.0, 0.55, 0.2, 0.9), 0.22)
	fx.spray(x, 10.0, z, f, 16, Color(1.0, 0.6, 0.2), 340.0, 4.5)
	fx.spray(x, 10.0, z, f, 8, Color(0.25, 0.25, 0.25, 0.9), 200.0, 7.0, 300.0)
	fx.decal(x, z, f, radius * 0.7, Color(0.03, 0.03, 0.03, 0.75))
	var victims: Array[Zombie] = []
	horde.query(x, f, radius + 40.0, func(zb: Zombie) -> bool:
		if Vector2(zb.x - x, (zb.z - z) * 1.2).length() < radius + zb.radius:
			victims.append(zb)
		return false)
	for zb in victims:
		damage_zombie(zb, dmg, false, signf(zb.x - x))
	if hurts_player and player.f == f and Vector2(player.x - x, player.z - z).length() < radius:
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
	explode(player.x, player.z, player.f, 150.0, 200.0)


func give_up() -> void:
	hud.hide_revive()
	finish(false, false)


func finish(survived: bool, rescued: bool) -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	var bag := backpack_value()
	var gold := float(cash + bag)
	var lines: Array[String] = []
	if rescued:
		var bonus := gold * t.rescue_gold_bonus
		lines.append("Được cứu hộ trên mái")
		lines.append("Ba lô: %d  ·  Tiền: %d" % [bag, cash])
		lines.append("Thưởng cứu hộ: +%d" % int(bonus))
		gold += bonus
	elif survived:
		lines.append("Thoát sớm qua cửa hầm")
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
	return int(100.0 * explored_count / (t.floors * t.cols + 1))


## Next waypoint toward the roof or the early exit, for the on-screen guide arrows.
func guide_step(to_roof: bool) -> Level.Step:
	var f: Array = roof_field if to_roof else exit_field
	return f[level.room_at(player.f, player.x).id]
