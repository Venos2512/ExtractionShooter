class_name WorldView
extends Node2D
## Paints the building back to front through View. Floors are drawn bottom up, so
## each floor plane covers the top of the room below it. Inside a floor, objects
## are drawn from far depth to near depth using fixed buckets instead of a sort.

const FAR_CITY_SEED := 41

var game: Game
var t: Tuning
var v: View
var font: Font
var skyline: Array = []
var dust: Array = []
var dynamic: Array = []


func setup(g: Game) -> void:
	game = g
	t = g.t
	v = g.view
	font = ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = FAR_CITY_SEED
	# Three skyline layers at different depths give parallax behind the building.
	for layer in 3:
		var z: float = [3600.0, 2200.0, 1100.0][layer]
		var col: Color = [Color(0.10, 0.11, 0.17), Color(0.08, 0.08, 0.13), Color(0.05, 0.05, 0.09)][layer]
		var x := -3000.0
		while x < 4500.0:
			var w := rng.randf_range(90.0, 240.0)
			skyline.append({"x": x, "w": w, "h": rng.randf_range(350.0, 1300.0), "z": z, "c": col})
			x += w + rng.randf_range(0.0, 60.0)
	# Dust floats in front of the building (negative depth), so it moves faster
	# than the world when the camera pans.
	for i in 26:
		dust.append(Vector3(rng.randf_range(-300.0, 1400.0), rng.randf_range(-1200.0, 260.0), rng.randf_range(-260.0, -60.0)))
	dynamic.resize(t.floors + 1)
	for f in t.floors + 1:
		var slices: Array = []
		slices.resize(Level.BUCKETS)
		for i in Level.BUCKETS:
			slices[i] = []
		dynamic[f] = slices


func _draw() -> void:
	if game == null:
		return
	_draw_sky()
	_fill_dynamic()
	for f in t.floors + 1:
		_draw_floor(f)
	_draw_guides()
	_draw_numbers()
	_draw_foreground()


# --- Primitives ---------------------------------------------------------------

func lit(c: Color, b: float) -> Color:
	return Color(c.r * b, c.g * b, c.b * b, c.a)


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([col]), PackedVector2Array())


func quad2(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col_ab: Color, col_cd: Color) -> void:
	draw_primitive(PackedVector2Array([a, b, c, d]), PackedColorArray([col_ab, col_ab, col_cd, col_cd]), PackedVector2Array())


## A real box in fake 3D: the eye decides which side face shows as the camera moves.
func box(x0: float, x1: float, z0: float, z1: float, h0: float, h1: float, f: int, col: Color) -> void:
	var ftl := v.pt(x0, h1, z0, f)
	var ftr := v.pt(x1, h1, z0, f)
	var fbl := v.pt(x0, h0, z0, f)
	var fbr := v.pt(x1, h0, z0, f)
	var btl := v.pt(x0, h1, z1, f)
	var btr := v.pt(x1, h1, z1, f)
	var bbl := v.pt(x0, h0, z1, f)
	var bbr := v.pt(x1, h0, z1, f)
	if v.cam.x < x0:
		quad(fbl, ftl, btl, bbl, col.darkened(0.38))
	elif v.cam.x > x1:
		quad(fbr, ftr, btr, bbr, col.darkened(0.38))
	quad(ftl, ftr, btr, btl, col.lightened(0.14))
	quad(fbl, fbr, ftr, ftl, col)


# --- Background ---------------------------------------------------------------

func _draw_sky() -> void:
	var half := Vector2(760.0, 1000.0)
	var c := v.cam
	var heat := clampf(float(game.danger - 1) / 10.0, 0.0, 1.0)
	if game.rescue == Game.Rescue.CALLING or game.rescue == Game.Rescue.LANDED:
		heat = 1.0
	var high := Color(0.05, 0.06, 0.13).lerp(Color(0.22, 0.03, 0.05), heat)
	var low := Color(0.24, 0.18, 0.22).lerp(Color(0.72, 0.18, 0.08), heat)
	quad2(c + Vector2(-half.x, -half.y), c + Vector2(half.x, -half.y), c + Vector2(half.x, half.y), c + Vector2(-half.x, half.y), high, low)
	for b: Dictionary in skyline:
		var a := v.far_pt(b.x, 260.0, b.z)
		var d := v.far_pt(b.x + b.w, 260.0 - b.h, b.z)
		draw_rect(Rect2(a.x, d.y, d.x - a.x, a.y - d.y + 500.0), b.c)
	var ground := v.pt(-2000.0, -t.slab, 0.0, 0)
	draw_rect(Rect2(c.x - half.x, ground.y, half.x * 2.0, 900.0), Color(0.05, 0.05, 0.06))


# --- Floors -------------------------------------------------------------------

func _draw_floor(f: int) -> void:
	_draw_slab(f)
	if f >= t.floors:
		_draw_roof_plane()
	else:
		for c in t.cols:
			_draw_room_shell(game.level.room(f, c))
	_draw_hatches(f)
	_draw_decals(f)
	if f == 0:
		_draw_early_exit()
	if f == t.floors:
		_draw_beacon()
	var fixed: Array = game.level.statics[f]
	var moving: Array = dynamic[f]
	for i in range(Level.BUCKETS - 1, -1, -1):
		for obj: Variant in fixed[i]:
			if obj is Level.Prop:
				_draw_prop(obj, f)
			else:
				_draw_door(obj, f)
		for obj: Variant in moving[i]:
			_draw_dynamic(obj, f)
	_draw_particles(f)
	_draw_bullets(f)
	if f == t.floors:
		_draw_heli()


func _draw_slab(f: int) -> void:
	# The cut edge of the concrete floor: the front face nearest to the viewer.
	var lo := -16.0
	var hi := game.level.width + 16.0
	var a := v.pt(lo, 0.0, 0.0, f)
	var b := v.pt(hi, 0.0, 0.0, f)
	var c := v.pt(hi, -t.slab, 0.0, f)
	var d := v.pt(lo, -t.slab, 0.0, f)
	quad2(a, b, c, d, Color(0.20, 0.20, 0.22), Color(0.08, 0.08, 0.09))
	for x in range(0, int(game.level.width) + 1, 120):
		var p := v.pt(float(x), 0.0, 0.0, f)
		var q := v.pt(float(x), -t.slab, 0.0, f)
		draw_line(p, q, Color(0.05, 0.05, 0.05, 0.6), 2.0)


func _draw_room_shell(r: Level.Room) -> void:
	var b := r.bright
	var f := r.f
	var D := t.depth
	# Floor: lighter near the viewer, darker near the wall for depth.
	quad2(v.pt(r.x0, 0.0, 0.0, f), v.pt(r.x1, 0.0, 0.0, f), v.pt(r.x1, 0.0, D, f), v.pt(r.x0, 0.0, D, f), lit(r.floor_a.lightened(0.08), b), lit(r.floor_b.darkened(0.25), b))
	var tile := Color(0, 0, 0, 0.14 * b + 0.05)
	var x := r.x0
	while x <= r.x1:
		draw_line(v.pt(x, 0.0, 0.0, f), v.pt(x, 0.0, D, f), tile, 1.5)
		x += 60.0
	for i in range(1, 5):
		var z := D * i / 5.0
		draw_line(v.pt(r.x0, 0.0, z, f), v.pt(r.x1, 0.0, z, f), tile, 1.5)
	# Back wall, wainscot and the contact shadow where wall meets floor.
	var top := t.room_h + t.slab
	quad2(v.pt(r.x0, 0.0, D, f), v.pt(r.x1, 0.0, D, f), v.pt(r.x1, top, D, f), v.pt(r.x0, top, D, f), lit(r.wall, b), lit(r.wall.darkened(0.45), b))
	quad(v.pt(r.x0, 0.0, D, f), v.pt(r.x1, 0.0, D, f), v.pt(r.x1, 62.0, D, f), v.pt(r.x0, 62.0, D, f), lit(r.trim, b))
	quad(v.pt(r.x0, 62.0, D, f), v.pt(r.x1, 62.0, D, f), v.pt(r.x1, 68.0, D, f), v.pt(r.x0, 68.0, D, f), lit(r.trim.lightened(0.3), b))
	quad2(v.pt(r.x0, 0.0, D - 26.0, f), v.pt(r.x1, 0.0, D - 26.0, f), v.pt(r.x1, 0.0, D, f), v.pt(r.x0, 0.0, D, f), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.4))
	if r.window_x > 0.0:
		_draw_window(r)
	# Lamp hanging from the ceiling, at mid depth.
	var lamp_top := v.pt(r.lamp_x, t.room_h, D * 0.55, f)
	var lamp := v.pt(r.lamp_x, t.room_h - 26.0, D * 0.55, f)
	draw_line(lamp_top, lamp, lit(Color(0.15, 0.15, 0.15), b), 2.0)
	draw_rect(Rect2(lamp + Vector2(-13.0, 0.0), Vector2(26.0, 6.0)), lit(Color(0.95, 0.88, 0.62), b))


func _draw_window(r: Level.Room) -> void:
	var f := r.f
	var D := t.depth
	var w := 46.0
	var cx := r.window_x
	var heat := clampf(float(game.danger - 1) / 10.0, 0.0, 1.0)
	var sky := Color(0.10, 0.16, 0.30).lerp(Color(0.55, 0.14, 0.08), heat)
	quad(v.pt(cx - w - 5.0, 92.0, D, f), v.pt(cx + w + 5.0, 92.0, D, f), v.pt(cx + w + 5.0, 197.0, D, f), v.pt(cx - w - 5.0, 197.0, D, f), lit(r.trim, r.bright))
	quad2(v.pt(cx - w, 97.0, D, f), v.pt(cx + w, 97.0, D, f), v.pt(cx + w, 192.0, D, f), v.pt(cx - w, 192.0, D, f), lit(sky.lightened(0.15), r.bright + 0.25), lit(sky, r.bright + 0.25))
	draw_line(v.pt(cx, 97.0, D, f), v.pt(cx, 192.0, D, f), lit(r.trim, r.bright), 3.0)
	draw_line(v.pt(cx - w, 145.0, D, f), v.pt(cx + w, 145.0, D, f), lit(r.trim, r.bright), 3.0)


func _draw_roof_plane() -> void:
	var f := t.floors
	var D := t.depth
	var w := game.level.width
	quad2(v.pt(-12.0, 0.0, 0.0, f), v.pt(w + 12.0, 0.0, 0.0, f), v.pt(w + 12.0, 0.0, D, f), v.pt(-12.0, 0.0, D, f), Color(0.34, 0.33, 0.35), Color(0.18, 0.18, 0.20))
	var line := Color(0, 0, 0, 0.18)
	var x := 0.0
	while x <= w:
		draw_line(v.pt(x, 0.0, 0.0, f), v.pt(x, 0.0, D, f), line, 1.5)
		x += 90.0
	draw_line(v.pt(0.0, 0.0, D * 0.5, f), v.pt(w, 0.0, D * 0.5, f), line, 1.5)


func _draw_hatches(f: int) -> void:
	var down := game.level.ladder_down(f)
	if down != null:
		var x := down.x
		var z := down.z
		var near := z - 22.0
		var far := minf(z + 18.0, t.depth - 2.0)
		var b := _bright_at(f, x)
		quad(v.pt(x - 30.0, 0.0, near, f), v.pt(x + 30.0, 0.0, near, f), v.pt(x + 30.0, 0.0, far, f), v.pt(x - 30.0, 0.0, far, f), lit(Color(0.02, 0.02, 0.03), maxf(b, 0.6)))
		draw_polyline(PackedVector2Array([v.pt(x - 30.0, 0.0, near, f), v.pt(x + 30.0, 0.0, near, f), v.pt(x + 30.0, 0.0, far, f), v.pt(x - 30.0, 0.0, far, f), v.pt(x - 30.0, 0.0, near, f)]), lit(Color(0.85, 0.72, 0.2), b), 3.0)
		_draw_ladder(down.x, down.z, f, 0.0, 34.0, b)
	var up := game.level.ladder_up(f)
	if up != null:
		_draw_ladder(up.x, up.z, f, 0.0, t.room_h + t.slab, _bright_at(f, up.x))


func _draw_ladder(x: float, z: float, f: int, h0: float, h1: float, b: float) -> void:
	var col := lit(Color(0.78, 0.68, 0.30), maxf(b, 0.25))
	draw_line(v.pt(x - 15.0, h0, z, f), v.pt(x - 15.0, h1, z, f), col, 4.0)
	draw_line(v.pt(x + 15.0, h0, z, f), v.pt(x + 15.0, h1, z, f), col, 4.0)
	var h := h0 + 16.0
	while h < h1:
		draw_line(v.pt(x - 15.0, h, z, f), v.pt(x + 15.0, h, z, f), col, 3.0)
		h += 24.0


func _draw_decals(f: int) -> void:
	var blob := game.art.blob
	for d: Effects.FloorMark in game.fx.decals[f]:
		var p := v.pt(d.x, 0.0, d.z, f)
		var s := v.s_at(d.z)
		var size := Vector2(d.r * 2.0 * s, d.r * 2.0 * s * 0.42)
		var col := d.color
		var b := _bright_at(f, d.x)
		draw_texture_rect(blob, Rect2(p - size * 0.5, size), false, lit(col, b))


func _draw_early_exit() -> void:
	var open := game.run_t >= t.early_exit_opens_at
	var x := game.exit_room_x
	var z := t.depth * 0.5
	var b := maxf(_bright_at(0, x), 0.45)
	var col := Color(0.25, 1.0, 0.45) if open else Color(0.75, 0.3, 0.2)
	box(x - 40.0, x + 40.0, z - 24.0, z + 24.0, 0.0, 5.0, 0, lit(Color(0.25, 0.26, 0.24), b))
	draw_line(v.pt(x - 28.0, 6.0, z - 12.0, 0), v.pt(x + 28.0, 6.0, z - 12.0, 0), lit(col, b), 3.0)
	draw_line(v.pt(x - 28.0, 6.0, z + 12.0, 0), v.pt(x + 28.0, 6.0, z + 12.0, 0), lit(col, b), 3.0)
	_floor_ring(x, z, 0, 56.0, Color(col, 0.65 if open else 0.25), 3.0)
	if open and game.exit_hold > 0.0:
		_floor_arc(x, z, 0, 66.0, game.exit_hold / t.early_exit_hold, Color(0.5, 1.0, 0.6), 6.0)


func _draw_beacon() -> void:
	var f := t.floors
	var col := Color(0.3, 0.8, 1.0)
	if game.rescue == Game.Rescue.LANDED:
		col = Color(0.4, 1.0, 0.5)
	elif game.rescue == Game.Rescue.CALLING:
		col = Color(1.0, 0.45, 0.25)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	_floor_ring(game.beacon_x, game.beacon_z, f, 70.0, Color(col, 0.55 + 0.4 * pulse), 4.0)
	_floor_ring(game.beacon_x, game.beacon_z, f, 40.0, Color(col, 0.35), 3.0)
	box(game.beacon_x - 10.0, game.beacon_x + 10.0, game.beacon_z - 8.0, game.beacon_z + 8.0, 0.0, 26.0, f, Color(0.3, 0.3, 0.32))
	if game.rescue == Game.Rescue.NONE and game.rescue_hold > 0.0:
		_floor_arc(game.beacon_x, game.beacon_z, f, 82.0, game.rescue_hold / t.rescue_call_hold, col, 6.0)


func _floor_ring(x: float, z: float, f: int, r: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(v.pt(x + cos(a) * r, 0.0, clampf(z + sin(a) * r, 0.0, t.depth), f))
	draw_polyline(pts, col, width, true)


func _floor_arc(x: float, z: float, f: int, r: float, u: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var steps := maxi(int(32.0 * clampf(u, 0.0, 1.0)), 1)
	for i in steps + 1:
		var a := -PI * 0.5 + TAU * clampf(u, 0.0, 1.0) * i / steps
		pts.append(v.pt(x + cos(a) * r, 0.0, clampf(z + sin(a) * r, 0.0, t.depth), f))
	draw_polyline(pts, col, width, true)


func _bright_at(f: int, x: float) -> float:
	return game.level.room_at(f, x).bright


func _draw_prop(p: Level.Prop, f: int) -> void:
	var b := p.room.bright
	if p.room2 != null:
		b = maxf(b, p.room2.bright)
	box(p.x0, p.x1, p.z0, p.z1, p.h0, p.h1, f, lit(p.color, b))


func _draw_door(d: Level.Door, f: int) -> void:
	if d.broken:
		return
	var b := maxf(d.room_a.bright, d.room_b.bright)
	var dz0 := t.depth * 0.22
	var dz1 := t.depth * 0.78
	var bottom := d.open * t.door_height * 0.92
	var damaged := 1.0 - d.hp / d.max_hp
	var col := Color(0.42, 0.34, 0.24).lerp(Color(0.5, 0.16, 0.12), damaged)
	box(d.x - 5.0, d.x + 5.0, dz0, dz1, bottom, t.door_height, f, lit(col, b))


# --- Moving things ------------------------------------------------------------

func _fill_dynamic() -> void:
	for f in t.floors + 1:
		var slices: Array = dynamic[f]
		for s: Array in slices:
			s.clear()
	var level := game.level
	dynamic[game.player.f][level.bucket_of(game.player.z)].append(game.player)
	for zb in game.horde.list:
		if not zb.dead:
			dynamic[zb.f][level.bucket_of(zb.z)].append(zb)
	for c in level.crates:
		dynamic[c.f][level.bucket_of(c.z)].append(c)
	for p in game.pickups:
		dynamic[p.f][level.bucket_of(p.z)].append(p)
	for g in game.weapons.grenades:
		dynamic[g.f][level.bucket_of(g.z)].append(g)
	var pl := game.player
	for n in pl.drones:
		var pos := game.weapons.drone_pos(n)
		dynamic[pl.f][level.bucket_of(pos.y)].append(pos)


func _draw_dynamic(obj: Variant, f: int) -> void:
	if obj is Zombie:
		_draw_zombie(obj)
	elif obj is Player:
		_draw_player(obj)
	elif obj is Level.Crate:
		_draw_crate(obj)
	elif obj is Game.Pickup:
		_draw_pickup(obj)
	elif obj is Weapons.Grenade:
		_draw_grenade(obj)
	elif obj is Vector2:
		_draw_drone(obj, f)


func _shadow(x: float, z: float, f: int, width: float, alpha: float) -> void:
	var p := v.pt(x, 0.0, z, f)
	var s := v.s_at(z)
	var size := Vector2(width * s, width * s * 0.36)
	draw_texture_rect(game.art.blob, Rect2(p - size * 0.5, size), false, Color(0, 0, 0, alpha))


## Draws a sprite standing on the floor. Negative h means the actor is coming
## through a hatch, so the part below the floor plane is cut away.
func _sprite(tex: Texture2D, x: float, h: float, z: float, f: int, size: float, flip: float, lean: float, sq: float, tint: Color, overlay: Texture2D = null, overlay_a := 0.0) -> void:
	var s := v.s_at(z) * t.actor_scale * size
	var p := v.pt(x, maxf(h, 0.0), z, f)
	var w := float(tex.get_width())
	var ht := float(tex.get_height())
	var vis := ht
	if h < 0.0:
		vis = maxf(ht + h / s, 1.0)
	draw_set_transform(p, lean, Vector2(flip * s * sq, s / sq))
	var src := Rect2(0.0, 0.0, w, vis)
	var dst := Rect2(-w * 0.5, -vis, w, vis)
	draw_texture_rect_region(tex, dst, src, tint)
	if overlay != null and overlay_a > 0.0:
		draw_texture_rect_region(overlay, dst, src, Color(1, 1, 1, overlay_a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_zombie(zb: Zombie) -> void:
	var b := _bright_at(zb.f, zb.x)
	if zb.f >= t.floors:
		b = 0.95
	var frame := int(zb.anim) % 2
	var frames: Array = game.art.zombies[zb.kind]
	var tint := lit(Color.WHITE, b)
	var lean := sin(zb.anim * 1.6) * 0.07
	if zb.falling:
		_shadow(zb.x, zb.z, zb.f, 44.0 * clampf(1.0 - zb.h / 700.0, 0.3, 1.0), 0.4)
		_draw_parachute(zb)
	elif zb.climb_dir == 0 and zb.h >= 0.0:
		_shadow(zb.x, zb.z, zb.f, 50.0 * zb.size, 0.45 * clampf(b + 0.3, 0.0, 1.0))
	if zb.kind == Zombie.Kind.BOSS and zb.boss_state == 1:
		_draw_telegraph(zb)
	var flash_a := clampf(zb.flash / t.hit_flash_time, 0.0, 1.0)
	_sprite(frames[frame], zb.x, zb.h, zb.z, zb.f, zb.size, zb.facing, lean, 1.0, tint, game.art.zombie_flash, flash_a)
	if zb.hp < zb.max_hp and zb.kind != Zombie.Kind.BOSS and b > 0.25:
		var p := v.pt(zb.x, 72.0 * zb.size + maxf(zb.h, 0.0), zb.z, zb.f)
		var w := 34.0 * zb.size * v.s_at(zb.z)
		draw_rect(Rect2(p.x - w * 0.5, p.y, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p.x - w * 0.5, p.y, w * zb.hp / zb.max_hp, 4.0), Color(0.9, 0.2, 0.15))


func _draw_parachute(zb: Zombie) -> void:
	var top := v.pt(zb.x, zb.h + 150.0, zb.z, zb.f)
	var feet := v.pt(zb.x, zb.h + 70.0, zb.z, zb.f)
	var r := 40.0 * v.s_at(zb.z)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-r, 8.0), top + Vector2(-r * 0.6, -14.0), top + Vector2(r * 0.6, -14.0), top + Vector2(r, 8.0)]), Color(0.75, 0.72, 0.65))
	draw_line(top + Vector2(-r, 8.0), feet, Color(0.2, 0.2, 0.2), 1.5)
	draw_line(top + Vector2(r, 8.0), feet, Color(0.2, 0.2, 0.2), 1.5)


func _draw_telegraph(zb: Zombie) -> void:
	var length := 760.0 * 0.55
	var ex := clampf(zb.x + zb.charge.x * length, 0.0, game.level.width)
	var ez := clampf(zb.z + zb.charge.y * length * 0.82, 0.0, t.depth)
	var side := Vector2(-zb.charge.y, zb.charge.x) * 28.0
	var pulse := 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.03)
	var col := Color(1.0, 0.12, 0.08, pulse)
	quad(v.pt(zb.x - side.x, 0.0, clampf(zb.z - side.y, 0.0, t.depth), zb.f), v.pt(zb.x + side.x, 0.0, clampf(zb.z + side.y, 0.0, t.depth), zb.f), v.pt(ex + side.x, 0.0, clampf(ez + side.y, 0.0, t.depth), zb.f), v.pt(ex - side.x, 0.0, clampf(ez - side.y, 0.0, t.depth), zb.f), col)


func _draw_player(p: Player) -> void:
	var blink := p.iframes > 0.3 and int(Time.get_ticks_msec() * 0.02) % 2 == 0
	var moving := Vector2(p.vx, p.vz).length() > 20.0
	var frame := int(p.anim) % 2 if moving else 0
	if not p.is_climbing() and p.h >= 0.0:
		_shadow(p.x, p.z, p.f, 56.0, 0.55)
	if p.dash_t > 0.0:
		for i in 3:
			var ghost := Color(0.5, 0.8, 1.0, 0.3 - i * 0.08)
			_sprite(game.art.player[0], p.x - p.vx * 0.02 * (i + 1), 0.0, p.z - p.vz * 0.02 * (i + 1), p.f, 1.0, p.facing, 0.0, 1.0, ghost)
	var sq := 1.0 + sin(p.anim * PI) * 0.04 if moving else 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.012
	var tint := Color(1, 1, 1, 0.55) if blink else Color.WHITE
	var flash_a := clampf(p.flash / 0.12, 0.0, 1.0)
	_sprite(game.art.player[frame], p.x, p.h, p.z, p.f, 1.0, p.facing, 0.0, sq, tint, game.art.player_flash, flash_a)
	if p.h >= 0.0 and not p.is_climbing():
		_draw_gun(p)
	if p.is_climbing():
		return
	var tip := v.pt(p.x, 0.0, p.z, p.f)
	if p.dash_cd > 0.0:
		var w := 44.0
		draw_rect(Rect2(tip.x - w * 0.5, tip.y + 8.0, w, 4.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(tip.x - w * 0.5, tip.y + 8.0, w * (1.0 - p.dash_cd / p.dash_cooldown), 4.0), Color(0.5, 0.85, 1.0))


func _draw_gun(p: Player) -> void:
	var weapons := game.weapons
	var from := v.pt(p.x, Weapons.MUZZLE_H - 4.0, p.z, p.f)
	var to := from + Vector2(p.facing * 40.0, 0.0)
	if weapons.target != null and not weapons.target.dead and weapons.target.f == p.f:
		to = v.pt(weapons.target.x, 40.0, weapons.target.z, p.f)
	var dir := (to - from).normalized()
	var s := v.s_at(p.z)
	var back := dir * -weapons.recoil
	var a := from + back
	var b := from + back + dir * 34.0 * s
	draw_line(a, b, Color(0.08, 0.08, 0.09), 9.0 * s)
	draw_line(a + dir * 6.0, b, Color(0.34, 0.34, 0.36), 4.0 * s)
	if weapons.muzzle_flash > 0.0:
		var side := Vector2(-dir.y, dir.x)
		var m := b + dir * 4.0
		var fl := PackedVector2Array([m + side * 9.0, m + dir * 26.0, m - side * 9.0, m - dir * 2.0])
		draw_colored_polygon(fl, Color(1.0, 0.92, 0.55))


func _draw_crate(c: Level.Crate) -> void:
	var b := maxf(c.room.bright, 0.15)
	var col := Color(0.38, 0.30, 0.20)
	if c.opened:
		col = Color(0.20, 0.17, 0.13)
	_shadow(c.x, c.z, c.f, 66.0, 0.4 * b)
	box(c.x - 24.0, c.x + 24.0, c.z - 15.0, c.z + 15.0, 0.0, 30.0, c.f, lit(col, b))
	box(c.x - 26.0, c.x + 26.0, c.z - 16.0, c.z + 16.0, 30.0, 35.0, c.f, lit(col.lightened(0.15), b))
	if not c.opened:
		var band: Color = Game.RARITY_COLORS[c.rarity]
		quad(v.pt(c.x - 5.0, 0.0, c.z - 15.0, c.f), v.pt(c.x + 5.0, 0.0, c.z - 15.0, c.f), v.pt(c.x + 5.0, 30.0, c.z - 15.0, c.f), v.pt(c.x - 5.0, 30.0, c.z - 15.0, c.f), lit(band, b))
		if c.progress > 0.0:
			_floor_arc(c.x, c.z, c.f, 44.0, c.progress, band, 5.0)


func _draw_pickup(p: Game.Pickup) -> void:
	var s := v.s_at(p.z)
	var pos := v.pt(p.x, p.h, p.z, p.f)
	_shadow(p.x, p.z, p.f, 22.0, 0.35)
	if p.coin:
		draw_circle(pos, 6.0 * s, Color(1.0, 0.84, 0.25))
		draw_circle(pos, 3.0 * s, Color(1.0, 0.95, 0.6))
	else:
		var col: Color = Game.RARITY_COLORS[p.rarity]
		var r := 10.0 * s
		draw_rect(Rect2(pos.x - r, pos.y - r, r * 2.0, r * 2.0), Color(0.05, 0.05, 0.06))
		draw_rect(Rect2(pos.x - r + 2.0, pos.y - r + 2.0, r * 2.0 - 4.0, r * 2.0 - 4.0), col)


func _draw_grenade(g: Weapons.Grenade) -> void:
	_shadow(g.x, g.z, g.f, 22.0, 0.45)
	var pos := v.pt(g.x, g.h, g.z, g.f)
	draw_circle(pos, 7.0 * v.s_at(g.z), Color(0.16, 0.26, 0.14))
	draw_circle(pos + Vector2(cos(g.spin), sin(g.spin)) * 5.0, 2.0, Color(1.0, 0.45, 0.2))


func _draw_drone(pos: Vector2, f: int) -> void:
	_shadow(pos.x, pos.y, f, 26.0, 0.35)
	var p := v.pt(pos.x, 100.0, pos.y, f)
	var s := v.s_at(pos.y)
	draw_rect(Rect2(p.x - 10.0 * s, p.y - 4.0 * s, 20.0 * s, 8.0 * s), Color(0.2, 0.22, 0.26))
	draw_line(p + Vector2(-15.0, -7.0) * s, p + Vector2(15.0, -7.0) * s, Color(0.8, 0.85, 0.95, 0.7), 2.0)
	draw_circle(p + Vector2(0.0, 1.0) * s, 2.5 * s, Color(0.4, 1.0, 0.8))


func _draw_particles(f: int) -> void:
	for p in game.fx.particles:
		if p.f != f:
			continue
		var pos := v.pt(p.x, p.h, p.z, f)
		var s := p.size * v.s_at(p.z)
		var col := p.color
		col.a *= clampf(p.life / p.max_life * 2.0, 0.0, 1.0)
		draw_rect(Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), col)


func _draw_bullets(f: int) -> void:
	for b in game.weapons.bullets:
		if b.f != f:
			continue
		var a := v.pt(b.px, b.h, b.pz, f)
		var c := v.pt(b.x, b.h, b.z, f)
		draw_line(a, c, Color(1.0, 0.86, 0.5, 0.5), 5.0)
		draw_line(a, c, Color(1.0, 1.0, 0.85), 2.0)


func _draw_heli() -> void:
	if game.rescue != Game.Rescue.CALLING and game.rescue != Game.Rescue.LANDED:
		return
	if game.heli_h >= 880.0:
		return
	var f := t.floors
	var x := game.beacon_x
	var z := t.depth * 0.82
	var h := game.heli_h
	_shadow(x, z, f, 220.0 * clampf(1.0 - h / 900.0, 0.2, 1.0), 0.4)
	var body := Color(0.27, 0.33, 0.24)
	box(x - 60.0, x + 60.0, z - 24.0, z + 24.0, h, h + 62.0, f, body)
	box(x + 60.0, x + 170.0, z - 7.0, z + 7.0, h + 34.0, h + 52.0, f, body.darkened(0.15))
	box(x - 60.0, x - 34.0, z - 19.0, z + 19.0, h + 14.0, h + 54.0, f, Color(0.45, 0.70, 0.82))
	box(x - 8.0, x + 8.0, z - 6.0, z + 6.0, h + 62.0, h + 78.0, f, Color(0.12, 0.12, 0.13))
	# The rotor spins in the depth plane, so it reads as an ellipse.
	var spin := Time.get_ticks_msec() * 0.05
	for i in 2:
		var a := spin + PI * 0.5 * i
		var dx := cos(a) * 140.0
		var dz := sin(a) * 90.0
		draw_line(v.pt(x - dx, h + 80.0, z - dz, f), v.pt(x + dx, h + 80.0, z + dz, f), Color(0.05, 0.05, 0.06, 0.65), 5.0)
	draw_line(v.pt(x - 50.0, h - 4.0, z + 22.0, f), v.pt(x + 50.0, h - 4.0, z + 22.0, f), Color(0.1, 0.1, 0.1), 4.0)
	draw_line(v.pt(x - 50.0, h - 4.0, z - 22.0, f), v.pt(x + 50.0, h - 4.0, z - 22.0, f), Color(0.1, 0.1, 0.1), 4.0)


func _draw_numbers() -> void:
	for n in game.fx.numbers:
		var pos := v.pt(n.x, n.h, n.z, n.f)
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
	var pos := v.pt(p.x, 0.0, p.z, p.f)
	var roof_step := game.guide_step(true)
	if p.f < t.floors and roof_step != null:
		_guide_arrow(pos, roof_step, Color(0.45, 0.85, 1.0), "Lên mái")
	if p.f >= t.floors and game.rescue == Game.Rescue.NONE:
		_guide_point(pos, v.pt(game.beacon_x, 0.0, game.beacon_z, p.f), Color(0.45, 0.85, 1.0), "Gọi cứu hộ")
	if game.run_t >= t.early_exit_opens_at:
		var exit_step := game.guide_step(false)
		if exit_step != null:
			_guide_arrow(pos, exit_step, Color(0.4, 1.0, 0.55), "Hầm thoát")
		elif p.f == 0:
			_guide_point(pos, v.pt(game.exit_room_x, 0.0, t.depth * 0.5, 0), Color(0.4, 1.0, 0.55), "Hầm thoát")


func _guide_arrow(from: Vector2, step: Level.Step, col: Color, label: String) -> void:
	_guide_point(from, v.pt(step.x, 0.0, step.z, game.player.f), col, label)


func _guide_point(from: Vector2, to: Vector2, col: Color, label: String) -> void:
	var delta := to - from
	if delta.length() < 60.0:
		return
	var dir := delta.normalized()
	var c := from + Vector2(0.0, -50.0) + dir * 74.0
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 15.0, c + side * 10.0, c - side * 10.0]), col)
	draw_string_outline(font, c + Vector2(-44.0, -14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 88.0, 17, 4, Color(0, 0, 0, 0.8))
	draw_string(font, c + Vector2(-44.0, -14.0), label, HORIZONTAL_ALIGNMENT_CENTER, 88.0, 17, col)


func _draw_foreground() -> void:
	# Scaffolding poles close to the eye: they slide fastest of all when panning.
	var z := -240.0
	var x := -120.0
	while x < game.level.width + 300.0:
		var a := v.far_pt(x, v.cam.y - 900.0, z)
		var b := v.far_pt(x, v.cam.y + 900.0, z)
		draw_line(a, b, Color(0.015, 0.015, 0.02, 0.8), 9.0)
		x += 560.0
	for d: Vector3 in dust:
		var drift := fmod(Time.get_ticks_msec() * 0.008 + d.x, 1700.0) - 300.0
		var p := v.far_pt(drift, d.y + sin(drift * 0.01) * 20.0, d.z)
		draw_rect(Rect2(p, Vector2.ONE * 2.5), Color(1, 1, 1, 0.1))
