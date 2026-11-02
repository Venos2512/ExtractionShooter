class_name WorldView
extends Node2D
## Paints everything that changes on the gameplay plane, redrawn each frame. The
## static map lives in the Background, Walls, Floors and Foreground nodes.

const PLAYER_LANE := 2
const LANE_PX := 3.0

var game: Game
var t: Tuning
var v: View
var font: Font
var lanes: Array = []


func setup(g: Game) -> void:
	game = g
	t = g.t
	v = g.view
	font = ThemeDB.fallback_font
	lanes.resize(Bug.LANES)
	for i in Bug.LANES:
		lanes[i] = []


func _draw() -> void:
	if game == null:
		return
	_draw_room_shade()
	_draw_doors()
	for f in t.floors + 1:
		_draw_decals(f)
	if not game.sample_mode:
		_draw_early_exit()
		_draw_beacon()
	for c in game.level.crates:
		_draw_crate(c)
	for p in game.pickups:
		_draw_pickup(p)
	_fill_lanes()
	for i in Bug.LANES:
		for bug: Bug in lanes[i]:
			_draw_bug(bug)
		if i == PLAYER_LANE:
			_draw_player(game.player)
	for n in game.player.drones:
		_draw_drone(game.weapons.drone_pos(n))
	for g in game.weapons.grenades:
		_draw_grenade(g)
	_draw_particles()
	_draw_bullets()
	if not game.sample_mode:
		_draw_heli()
		_draw_guides()
	_draw_numbers()


func lit(c: Color, b: float) -> Color:
	return Color(c.r * b, c.g * b, c.b * b, c.a)


## Rooms the hero is not in sit under a dark veil, including the city behind them.
func _draw_room_shade() -> void:
	for r in game.level.rooms:
		if r.kind == Level.Kind.GOAL or r.bright >= 0.995:
			continue
		var a := (1.0 - r.bright) * 0.72
		var top := v.pt(r.x0, t.room_h, r.f)
		draw_rect(Rect2(top, Vector2(r.x1 - r.x0, t.room_h)), Color(0.02, 0.01, 0.03, a))


func _draw_doors() -> void:
	for d in game.level.doors:
		if d.broken:
			continue
		var b := maxf(d.room_a.bright, d.room_b.bright)
		var damaged := 1.0 - d.hp / d.max_hp
		var col := Color(0.42, 0.36, 0.28).lerp(Color(0.55, 0.20, 0.10), damaged)
		var bottom := d.open * t.door_height * 0.92
		var a := v.pt(d.x, t.door_height, d.f)
		var size := Vector2(12.0, t.door_height - bottom)
		draw_rect(Rect2(a.x - 6.0, a.y, size.x, size.y), lit(col, b))
		draw_rect(Rect2(a.x - 6.0, a.y, 3.0, size.y), lit(col.lightened(0.2), b))
		draw_rect(Rect2(a.x - 6.0, a.y + size.y - 6.0, size.x, 6.0), lit(Color(0.72, 0.58, 0.2), b))


func _draw_decals(f: int) -> void:
	var blob := game.art.blob
	for d: Effects.FloorMark in game.fx.decals[f]:
		var p := v.pt(d.x, 0.0, f)
		var size := Vector2(d.r * 2.0, maxf(d.r * 0.4, 8.0))
		draw_texture_rect(blob, Rect2(p + Vector2(-size.x * 0.5, -size.y * 0.25), size), false, d.color)


## A strip of light on the floor band marks a zone you stand in.
func _floor_zone(x: float, f: int, r: float, col: Color) -> void:
	var p := v.pt(x, 0.0, f)
	draw_rect(Rect2(p.x - r, p.y + 2.0, r * 2.0, 8.0), Color(col, col.a * 0.45))
	draw_rect(Rect2(p.x - r - 4.0, p.y - 2.0, 4.0, 14.0), col)
	draw_rect(Rect2(p.x + r, p.y - 2.0, 4.0, 14.0), col)


func _progress_bar(x: float, h: float, f: int, u: float, col: Color) -> void:
	var p := v.pt(x, h, f)
	draw_rect(Rect2(p.x - 40.0, p.y, 80.0, 8.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(p.x - 38.0, p.y + 2.0, 76.0 * clampf(u, 0.0, 1.0), 4.0), col)


func _draw_early_exit() -> void:
	var x := game.exit_x
	var col := Color(0.25, 1.0, 0.45)
	_floor_zone(x, 0, 56.0, Color(col, 0.85))
	var p := v.pt(x, 0.0, 0)
	draw_rect(Rect2(p.x - 30.0, p.y - 44.0, 60.0, 44.0), Color(0.15, 0.15, 0.14))
	draw_rect(Rect2(p.x - 25.0, p.y - 39.0, 50.0, 39.0), Color(0.02, 0.02, 0.03))
	draw_rect(Rect2(p.x - 30.0, p.y - 50.0, 60.0, 6.0), col)
	if game.exit_hold > 0.0:
		_progress_bar(x, 70.0, 0, game.exit_hold / t.early_exit_hold, Color(0.5, 1.0, 0.6))


func _draw_beacon() -> void:
	var f := 0
	var col := Color(0.3, 0.8, 1.0)
	if game.rescue == Game.Rescue.LANDED:
		col = Color(0.4, 1.0, 0.5)
	elif game.rescue == Game.Rescue.CALLING:
		col = Color(1.0, 0.45, 0.25)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	_floor_zone(game.beacon_x, f, 70.0, Color(col, 0.55 + 0.4 * pulse))
	var p := v.pt(game.beacon_x, 0.0, f)
	draw_rect(Rect2(p.x - 3.0, p.y - 52.0, 6.0, 52.0), Color(0.3, 0.3, 0.32))
	draw_rect(Rect2(p.x - 7.0, p.y - 60.0, 14.0, 10.0), col)
	if game.rescue == Game.Rescue.NONE and game.rescue_hold > 0.0:
		_progress_bar(game.beacon_x, 80.0, f, game.rescue_hold / t.rescue_call_hold, col)


func _fill_lanes() -> void:
	for s: Array in lanes:
		s.clear()
	for bug in game.horde.list:
		if not bug.dead:
			lanes[bug.lane].append(bug)


func _bright_at(f: int, x: float) -> float:
	return game.level.room_at(f, x).bright


func _shadow(x: float, f: int, width: float, alpha: float, ground := 0.0) -> void:
	var p := v.pt(x, ground, f)
	var size := Vector2(width, width * 0.22)
	draw_texture_rect(game.art.blob, Rect2(p + Vector2(-size.x * 0.5, 4.0 - size.y * 0.5), size), false, Color(0, 0, 0, alpha))


## Draws a sprite with its feet at (x, h). Pixels stay on one shared grid.
func _sprite(tex: Texture2D, x: float, h: float, f: int, drop: float, flip: float, lean: float, sq: float, tint: Color, overlay: Texture2D = null, overlay_a := 0.0) -> void:
	var s := t.pixel_scale
	var p := v.pt(x, h - drop, f)
	var w := float(tex.get_width())
	var ht := float(tex.get_height())
	draw_set_transform(p, lean, Vector2(flip * s * sq, s / sq))
	var dst := Rect2(-w * 0.5, -ht, w, ht)
	draw_texture_rect(tex, dst, false, tint)
	if overlay != null and overlay_a > 0.0:
		draw_texture_rect(overlay, dst, false, Color(1, 1, 1, overlay_a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hp_bar(bug: Bug) -> void:
	var p := v.pt(bug.x, bug.h + bug.top + 4.0, bug.f)
	var w := bug.radius * 2.0
	draw_rect(Rect2(p.x - w * 0.5, p.y, w, 4.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(p.x - w * 0.5, p.y, w * bug.hp / bug.max_hp, 4.0), Color(0.95, 0.5, 0.12))


## The alien itself is drawn by AlienView, over this layer.
func _draw_alien_marks(bug: Bug) -> void:
	if bug.rig.cloak > 0.5:
		return
	if bug.rig.on_floor_side():
		_shadow(bug.x, bug.f, bug.radius * 4.0, 0.35, game.arena.ground_at(bug.x))
	if bug.hp < bug.max_hp and bug != game.horde.boss:
		_hp_bar(bug)


func _draw_bug(bug: Bug) -> void:
	if bug.falling:
		_draw_falling(bug)
		return
	if bug.rig != null:
		_draw_alien_marks(bug)
		return
	var b := _bright_at(bug.f, bug.x)
	var anim: Sprites.Anim = game.art.bugs[bug.kind]
	var frame := int(bug.anim) % anim.frames.size()
	var drop := bug.lane * LANE_PX
	if bug.h <= 0.0 and bug.climb_dir == 0:
		_shadow(bug.x, bug.f, bug.radius * 3.2, 0.5 * clampf(b + 0.3, 0.0, 1.0))
	elif bug.airborne:
		_shadow(bug.x, bug.f, bug.radius * 2.0, 0.3)
	if bug.kind == Bug.Kind.CHARGER and bug.boss_state == 1:
		_draw_telegraph(bug)
	var lean := sin(bug.anim * 1.6) * 0.03
	var sq := 1.0
	if bug.windup > 0.0:
		# A crouch you can read before the leap.
		sq = 1.0 + (1.0 - bug.windup / Horde.LEAP_WINDUP) * 0.28
		lean = -0.08
	elif bug.airborne:
		sq = 0.9
		lean = -0.3 if bug.vh > 0.0 else 0.25
	elif bug.kind == Bug.Kind.CHARGER and bug.boss_state == 1:
		sq = 1.14
		lean = 0.05 * sin(Time.get_ticks_msec() * 0.05)
	var flash_a := clampf(bug.flash / t.hit_flash_time, 0.0, 1.0)
	_sprite(anim.frames[frame], bug.x, bug.h, bug.f, drop, bug.facing, lean * bug.facing, sq, lit(Color.WHITE, b), anim.flash[frame], flash_a)
	if bug.hp < bug.max_hp and bug.kind != Bug.Kind.CHARGER:
		_hp_bar(bug)


## A burning shard with the bug inside it, coming down on the landing zone.
func _draw_falling(bug: Bug) -> void:
	_shadow(bug.x, bug.f, 56.0 * clampf(1.0 - bug.h / 860.0, 0.3, 1.0), 0.45)
	var p := v.pt(bug.x, bug.h + 20.0, bug.f)
	var tail := p + Vector2(0.0, -130.0)
	draw_line(tail, p, Color(1.0, 0.4, 0.12, 0.45), 20.0)
	draw_line(tail.lerp(p, 0.5), p, Color(1.0, 0.75, 0.3, 0.8), 9.0)
	var tex := game.art.shard
	var size := Vector2(tex.get_width(), tex.get_height()) * t.pixel_scale
	draw_texture_rect(tex, Rect2(p - size * 0.5, size), false)


func _draw_telegraph(bug: Bug) -> void:
	var length := 760.0 * 0.55
	var start := v.pt(bug.x, 0.0, bug.f)
	var ex := clampf(bug.x + bug.charge_dir * length, 0.0, game.level.width)
	var pulse := 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.03)
	var x0 := minf(start.x, ex)
	draw_rect(Rect2(x0, start.y - 2.0, absf(ex - start.x), 12.0), Color(1.0, 0.12, 0.08, pulse))


func _draw_player(p: Player) -> void:
	var blink := p.iframes > 0.3 and int(Time.get_ticks_msec() * 0.02) % 2 == 0
	var moving := absf(p.vx) > 20.0
	var anim := game.art.player if moving else game.art.player_idle
	var frame := int(p.anim) % anim.frames.size()
	var drop := PLAYER_LANE * LANE_PX
	if not p.is_climbing():
		_shadow(p.x, p.f, 60.0, 0.55, p.h)
	if p.dash_t > 0.0:
		for i in 3:
			var ghost := Color(0.5, 0.8, 1.0, 0.3 - i * 0.08)
			_sprite(anim.frames[frame], p.x - p.vx * 0.02 * (i + 1), p.h, p.f, drop, p.facing, 0.0, 1.0, ghost)
	var sq := 1.0 if moving else 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.012
	var tint := Color(1, 1, 1, 0.55) if blink else Color.WHITE
	var flash_a := clampf(p.flash / 0.12, 0.0, 1.0)
	_sprite(anim.frames[frame], p.x, p.h, p.f, drop, p.facing, 0.0, sq, tint, anim.flash[frame], flash_a)
	if p.is_climbing():
		return
	_draw_gun(p, drop)
	if p.dash_cd > 0.0:
		var tip := v.pt(p.x, p.h, p.f)
		var w := 44.0
		draw_rect(Rect2(tip.x - w * 0.5, tip.y + 14.0, w, 4.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(tip.x - w * 0.5, tip.y + 14.0, w * (1.0 - p.dash_cd / p.dash_cooldown), 4.0), Color(0.5, 0.85, 1.0))


func _draw_gun(p: Player, drop: float) -> void:
	var weapons := game.weapons
	var from := v.pt(p.x, p.h + Weapons.MUZZLE_H - drop, p.f)
	var to := from + Vector2(p.facing * 40.0, 0.0)
	if weapons.target != null and not weapons.target.dead and weapons.target.f == p.f:
		to = v.pt(weapons.target.aim_x(), weapons.target.aim_h(), p.f)
	var dir := (to - from).normalized()
	var back := dir * -weapons.recoil
	var a := from + back
	var b := from + back + dir * 34.0
	draw_line(a, b, Sprites.OUTLINE, 9.0)
	draw_line(a + dir * 4.0, b - dir, Color(0.46, 0.50, 0.55), 4.0)
	if weapons.muzzle_flash > 0.0:
		var side := Vector2(-dir.y, dir.x)
		var m := b + dir * 4.0
		draw_colored_polygon(PackedVector2Array([m + side * 9.0, m + dir * 26.0, m - side * 9.0, m - dir * 2.0]), Color(1.0, 0.92, 0.55))


func _draw_crate(c: Level.Crate) -> void:
	var b := maxf(c.room.bright, 0.3)
	var tex := game.art.crate_open if c.opened else game.art.crate
	_shadow(c.x, c.f, 66.0, 0.4 * b)
	_sprite(tex, c.x, 0.0, c.f, 0.0, 1.0, 0.0, 1.0, lit(Color.WHITE, b))
	if c.opened:
		return
	var band: Color = Game.RARITY_COLORS[c.rarity]
	var p := v.pt(c.x, 30.0, c.f)
	draw_rect(Rect2(p.x - 5.0, p.y, 10.0, 30.0), lit(band, b))
	if c.progress > 0.0:
		_progress_bar(c.x, 54.0, c.f, c.progress, band)


func _draw_pickup(p: Game.Pickup) -> void:
	var pos := v.pt(p.x, p.h, p.f)
	_shadow(p.x, p.f, 22.0, 0.35)
	if p.coin:
		draw_rect(Rect2(pos.x - 5.0, pos.y - 5.0, 10.0, 10.0), Color(0.55, 0.38, 0.05))
		draw_rect(Rect2(pos.x - 3.0, pos.y - 5.0, 6.0, 8.0), Color(1.0, 0.86, 0.3))
	else:
		var col: Color = Game.RARITY_COLORS[p.rarity]
		draw_rect(Rect2(pos.x - 10.0, pos.y - 10.0, 20.0, 20.0), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(pos.x - 8.0, pos.y - 8.0, 16.0, 16.0), col)


func _draw_grenade(g: Weapons.Grenade) -> void:
	_shadow(g.x, g.f, 22.0, 0.45)
	var pos := v.pt(g.x, g.h, g.f)
	draw_circle(pos, 7.0, Color(0.16, 0.26, 0.14))
	draw_circle(pos + Vector2(cos(g.spin), sin(g.spin)) * 5.0, 2.0, Color(1.0, 0.45, 0.2))


func _draw_drone(pos: Vector2) -> void:
	var p := v.pt(pos.x, pos.y, game.player.f)
	draw_rect(Rect2(p.x - 10.0, p.y - 4.0, 20.0, 8.0), Color(0.2, 0.22, 0.26))
	draw_line(p + Vector2(-15.0, -7.0), p + Vector2(15.0, -7.0), Color(0.8, 0.85, 0.95, 0.7), 2.0)
	draw_circle(p + Vector2(0.0, 1.0), 2.5, Color(0.4, 1.0, 0.8))


func _draw_particles() -> void:
	for p in game.fx.particles:
		var pos := v.pt(p.x, p.h, p.f)
		var col := p.color
		col.a *= clampf(p.life / p.max_life * 2.0, 0.0, 1.0)
		draw_rect(Rect2(pos.x - p.size * 0.5, pos.y - p.size * 0.5, p.size, p.size), col)


func _draw_bullets() -> void:
	for b in game.weapons.bullets:
		var a := v.pt(b.px, b.ph, b.f)
		var c := v.pt(b.x, b.h, b.f)
		draw_line(a, c, Color(1.0, 0.86, 0.5, 0.5), 5.0)
		draw_line(a, c, Color(1.0, 1.0, 0.85), 2.0)


func _draw_heli() -> void:
	if game.rescue != Game.Rescue.CALLING and game.rescue != Game.Rescue.LANDED:
		return
	if game.heli_h >= 880.0:
		return
	var f := 0
	var x := game.beacon_x
	var h := game.heli_h
	_shadow(x, f, 220.0 * clampf(1.0 - h / 900.0, 0.2, 1.0), 0.4)
	_sprite(game.art.heli, x + 40.0, h, f, 0.0, 1.0, 0.0, 1.0, Color.WHITE)
	# A side-on rotor reads as a bar that keeps changing length.
	var spin := Time.get_ticks_msec() * 0.05
	var top := v.pt(x - 8.0, h + 92.0, f)
	var reach := 40.0 + absf(cos(spin)) * 110.0
	draw_line(top + Vector2(-reach, 0.0), top + Vector2(reach, 0.0), Color(0.05, 0.05, 0.06, 0.8), 5.0)


func _draw_numbers() -> void:
	for n in game.fx.numbers:
		var pos := v.pt(n.x, n.h, n.f)
		var u := n.life / t.number_time
		var pop := 1.0 + clampf((u - 0.8) * 3.0, 0.0, 0.5)
		var col := n.color
		col.a = clampf(u * 2.0, 0.0, 1.0)
		var fs := int(n.size * pop)
		draw_string_outline(font, pos + Vector2(-20.0, 0.0), n.text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, fs, 5, Color(0, 0, 0, col.a))
		draw_string(font, pos + Vector2(-20.0, 0.0), n.text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, fs, col)


func _draw_guides() -> void:
	var p := game.player
	if p.is_climbing():
		return
	var pos := v.pt(p.x, 0.0, p.f)
	var step := game.guide_step()
	if step != null:
		_guide_step(pos, step, Color(0.45, 0.85, 1.0), "Đích")
		return
	if game.rescue == Game.Rescue.NONE:
		_guide_point(pos, v.pt(game.beacon_x, 0.0, 0), Color(0.45, 0.85, 1.0), "Gọi cứu hộ")
	_guide_point(pos, v.pt(game.exit_x, 0.0, 0), Color(0.4, 1.0, 0.55), "Hầm thoát")


## Once at the foot of a ladder, the arrow turns to point up or down it.
func _guide_step(from: Vector2, step: Level.Step, col: Color, label: String) -> void:
	var to := v.pt(step.x, 0.0, game.player.f)
	if step.ladder != null and absf(game.player.x - step.x) < 60.0:
		to = from + Vector2(0.0, -120.0 if step.going_up else 120.0)
	_guide_point(from, to, col, label)


func _guide_point(from: Vector2, to: Vector2, col: Color, label: String) -> void:
	var delta := to - from
	if delta.length() < 60.0:
		return
	var dir := delta.normalized()
	var c := from + Vector2(0.0, -50.0) + dir * 74.0
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 15.0, c + side * 10.0, c - side * 10.0]), col)
	draw_string_outline(font, c + Vector2(-70.0, -14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 17, 4, Color(0, 0, 0, 0.8))
	draw_string(font, c + Vector2(-70.0, -14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 17, col)
