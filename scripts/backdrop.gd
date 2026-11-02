class_name Backdrop
extends Node2D
## The background: everything behind the back walls, built from Parallax2D layers.
## Every layer is one low resolution painted texture, so a layer can be replaced
## by a drawn PNG later without touching anything else. Layers are aligned so
## each one's ground line (local y = 0) meets the real ground on floor 0, and
## colors fade toward the horizon to sell the distance. It also hands the ground
## tile to the floor layer and the embers and rubble to the foreground.

const PX := 3
const TILE_W := 400
const SKY_W := 240
const SKY_H := 427
## Rows of ground fill below the horizon, enough to reach the bottom of the screen.
const BELOW := 180

const COOL_SKY := [Color(0.05, 0.05, 0.13), Color(0.13, 0.08, 0.20), Color(0.30, 0.13, 0.24), Color(0.56, 0.22, 0.20), Color(0.86, 0.45, 0.20)]
const HOT_SKY := [Color(0.14, 0.03, 0.05), Color(0.30, 0.05, 0.06), Color(0.55, 0.10, 0.06), Color(0.82, 0.22, 0.06), Color(1.0, 0.50, 0.12)]
const FAR_COLOR := Color(0.40, 0.21, 0.23)
const MID_COLOR := Color(0.26, 0.14, 0.19)
const NEAR_COLOR := Color(0.15, 0.09, 0.14)
const STREET_COLOR := Color(0.085, 0.06, 0.09)
const LIT := Color(0.86, 0.50, 0.22)
const HIVE := Color(0.30, 0.13, 0.17)
const HIVE_GLOW := Color(1.0, 0.52, 0.12)

var game: Game
var t: Tuning
var ground_y := 0.0
var layers: Array[Parallax2D] = []
var fires: Array[Sprite2D] = []
var sky_hot: Sprite2D
var meteor_layer: Parallax2D
var sky_fx: SkyFx
var add_material: CanvasItemMaterial
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()


func setup(g: Game, floors: Node2D, front: Node2D) -> void:
	game = g
	t = g.t
	# Where floor 0 sits on screen when the hero stands on it.
	ground_y = game.get_viewport_rect().size.y * 0.5 + t.camera_lift
	rng.seed = 2049
	noise.seed = 2049
	noise.frequency = 0.09
	add_material = CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_sky()
	meteor_layer = _layer(self, "Meteor", t.scroll_meteor, _paint_meteor(), 240, false)
	_build_sky_fx()
	var far := _layer(self, "Far", t.scroll_far, _paint_far(), 300)
	_haze(far, Color(0.95, 0.46, 0.22, 0.55), 420.0)
	var smog := _layer(self, "Smog", t.scroll_smog, _paint_smog(), 200)
	smog.autoscroll = Vector2(-9.0, 0.0)
	smog.modulate.a = 0.55
	var mid := _layer(self, "Mid", t.scroll_mid, _paint_mid(), 340)
	_haze(mid, Color(0.72, 0.30, 0.20, 0.5), 320.0)
	var near := _layer(self, "Near", t.scroll_near, _paint_near(), 300)
	_haze(near, Color(0.42, 0.17, 0.16, 0.5), 240.0)
	_fire(near, 260.0, -30.0, 150.0)
	_fire(near, 830.0, -18.0, 190.0)
	_embers(self, "EmbersBack", t.scroll_embers_back, 2)
	var street := _layer(self, "Street", t.scroll_street, _paint_street(), 110)
	_fire(street, 180.0, -18.0, 170.0)
	_fire(street, 720.0, -12.0, 120.0)
	_fire(street, 1040.0, -22.0, 210.0)
	_layer(floors, "Ground", 1.0, _paint_ground(), 0)
	_embers(front, "EmbersFront", t.scroll_embers_front, 3)
	_layer(front, "Rubble", t.scroll_rubble, _paint_rubble(), 0)


func _process(_dt: float) -> void:
	if game == null:
		return
	var heat := clampf(float(game.danger - 1) / 10.0, 0.0, 1.0)
	if game.rescue == Game.Rescue.CALLING or game.rescue == Game.Rescue.LANDED:
		heat = 1.0
	sky_hot.modulate.a = move_toward(sky_hot.modulate.a, heat, _dt * 0.5)
	var now := Time.get_ticks_msec() * 0.001
	for i in fires.size():
		fires[i].modulate.a = 0.42 + 0.18 * sin(now * (5.0 + i)) * sin(now * (9.0 + i * 1.7) + i)


## ground_row is the image row that lines up with the real ground.
func _layer(parent: Node2D, layer_name: String, scroll: float, tex: Texture2D, ground_row: int, repeat := true) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = layer_name
	layer.scroll_scale = Vector2(scroll, scroll)
	layer.scroll_offset = Vector2(0.0, ground_y * (1.0 - scroll))
	if repeat:
		layer.repeat_size = Vector2(tex.get_width() * PX, 0.0)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(PX, PX)
	sprite.position = Vector2(0.0, -ground_row * PX)
	layer.add_child(sprite)
	parent.add_child(layer)
	layers.append(layer)
	return layer


func _build_sky() -> void:
	var layer := Parallax2D.new()
	layer.name = "Sky"
	layer.scroll_scale = Vector2.ZERO
	add_child(layer)
	layers.append(layer)
	for hot: bool in [false, true]:
		var sprite := Sprite2D.new()
		sprite.texture = _paint_sky(HOT_SKY if hot else COOL_SKY, not hot)
		sprite.centered = false
		sprite.scale = Vector2(PX, PX)
		layer.add_child(sprite)
		if hot:
			sprite.modulate.a = 0.0
			sky_hot = sprite


func _build_sky_fx() -> void:
	var layer := Parallax2D.new()
	layer.name = "SkyFx"
	layer.scroll_scale = Vector2(t.scroll_meteor, t.scroll_meteor)
	layer.scroll_offset = Vector2(0.0, ground_y * (1.0 - t.scroll_meteor))
	sky_fx = SkyFx.new()
	sky_fx.setup(game.art)
	layer.add_child(sky_fx)
	add_child(layer)


func _haze(layer: Parallax2D, col: Color, height: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, col)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = 64
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(layer.repeat_size.x / tex.width, height / tex.height)
	sprite.position = Vector2(0.0, -height + 6.0)
	layer.add_child(sprite)


func _fire(layer: Parallax2D, x: float, y: float, radius: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = game.art.blob
	sprite.material = add_material
	sprite.modulate = Color(1.0, 0.45, 0.14, 0.5)
	sprite.position = Vector2(x, y)
	sprite.scale = Vector2.ONE * radius / 32.0
	layer.add_child(sprite)
	fires.append(sprite)


func _embers(parent: Node2D, layer_name: String, scroll: float, size: int) -> void:
	var p := Paint.new(TILE_W, 440)
	for i in 70:
		var col := Color(1.0, rng.randf_range(0.4, 0.8), 0.2, rng.randf_range(0.35, 0.9))
		p.rect(rng.randi_range(0, TILE_W - size), rng.randi_range(0, 439), size - 1 if rng.randf() < 0.5 else size, size - 1, col)
	var layer := Parallax2D.new()
	layer.name = layer_name
	layer.scroll_scale = Vector2(scroll, scroll)
	layer.repeat_size = Vector2(TILE_W * PX, 440.0 * PX)
	layer.repeat_times = 3
	layer.autoscroll = Vector2(-14.0, -38.0) * scroll
	var sprite := Sprite2D.new()
	sprite.texture = p.texture()
	sprite.centered = false
	sprite.scale = Vector2(PX, PX)
	sprite.material = add_material
	layer.add_child(sprite)
	parent.add_child(layer)
	layers.append(layer)


# --- Painted layers -----------------------------------------------------------

func _paint_sky(stops: Array, stars: bool) -> Texture2D:
	var p := Paint.new(SKY_W, SKY_H)
	var horizon := int(ground_y / PX)
	var bands := 22
	var band_h := ceili(float(horizon) / bands)
	var prev := Color.BLACK
	for i in bands:
		var u := float(i) / (bands - 1) * (stops.size() - 1)
		var a := mini(int(u), stops.size() - 2)
		var col: Color = (stops[a] as Color).lerp(stops[a + 1], u - a)
		p.rect(0, i * band_h, SKY_W, band_h, col)
		# Dither each band edge so the gradient stays pixel art rather than stripes.
		if i > 0:
			for x in range(0, SKY_W, 2):
				p.dot(x, i * band_h, prev)
				p.dot(x + 1, i * band_h + 1, prev)
		prev = col
	p.rect(0, horizon, SKY_W, SKY_H - horizon, stops[stops.size() - 1])
	if stars:
		for i in 90:
			var b := rng.randf_range(0.25, 0.8)
			p.dot(rng.randi_range(0, SKY_W - 1), rng.randi_range(0, int(horizon * 0.5)), Color(b, b, b * 1.1))
	return p.texture()


## The fallen rock, half buried, cracked open, with hive spires already growing.
## It towers over the skyline so it stays readable behind the city.
func _paint_meteor() -> Texture2D:
	var p := Paint.new(300, 280)
	var ground := 240
	var cx := 140.0
	var cy := float(ground) - 62.0
	# Smoke plume climbing out of frame.
	var y := cy - 60.0
	var x := cx
	while y > 0.0:
		var u := 1.0 - y / ground
		# Tapers near the top of the image, so the plume never ends in a flat cut.
		var r := minf(lerpf(26.0, 52.0, u), y)
		p.disc(x, y, r, r * 0.8,Color(0.13, 0.09, 0.11).lerp(Color(0.24, 0.14, 0.16), u))
		x += rng.randf_range(-3.0, 9.0)
		y -= rng.randf_range(9.0, 15.0)
	for ring: Array in [[136.0, 0.22], [116.0, 0.42], [100.0, 0.8]]:
		p.disc(cx, cy, ring[0], float(ring[0]) * 0.86, Color(1.0, 0.45, 0.12, ring[1]))
	p.disc(cx, cy, 92.0, 80.0, Color(0.13, 0.09, 0.11))
	p.disc(cx - 30.0, cy - 24.0, 46.0, 38.0, Color(0.24, 0.16, 0.18))
	p.disc(cx + 40.0, cy + 12.0, 40.0, 36.0, Color(0.09, 0.06, 0.09))
	p.disc(cx + 8.0, cy - 44.0, 34.0, 22.0, Color(0.19, 0.13, 0.15))
	for i in 11:
		var a := rng.randf_range(0.0, TAU)
		var pos := Vector2(cx, cy)
		for j in 6:
			var next := pos + Vector2(cos(a), sin(a)) * rng.randf_range(9.0, 18.0)
			p.line(pos, next, HIVE_GLOW, 3 if j < 2 else (2 if j < 4 else 1))
			pos = next
			a += rng.randf_range(-0.6, 0.6)
	p.disc(cx, cy, 13.0, 11.0, Color(1.0, 0.72, 0.28))
	p.disc(cx, cy, 6.0, 5.0, Color(1.0, 0.95, 0.65))
	_spire(p, int(cx) - 96, ground, 12, 92)
	_spire(p, int(cx) + 92, ground, 15, 116)
	_spire(p, int(cx) + 122, ground, 9, 62)
	p.rect(0, ground, p.w, p.h - ground, Color(0.2, 0.11, 0.13))
	return p.texture()


func _paint_far() -> Texture2D:
	var p := Paint.new(TILE_W, 300 + BELOW)
	_city(p, 300, {"color": FAR_COLOR, "w0": 18, "w1": 36, "h0": 60, "h1": 235, "gap": 7, "lit": 0.02, "win": 0.5, "grid": 4})
	return p.texture()


func _paint_mid() -> Texture2D:
	var p := Paint.new(TILE_W, 340 + BELOW)
	_city(p, 340, {"color": MID_COLOR, "w0": 24, "w1": 52, "h0": 80, "h1": 300, "gap": 16, "lit": 0.04, "win": 0.7, "grid": 5})
	_spire(p, 90, 340, 14, 210)
	_spire(p, 300, 340, 11, 170)
	_leaning(p, 190, 340, 22, 170, 0.28, MID_COLOR.darkened(0.1))
	return p.texture()


func _paint_near() -> Texture2D:
	var p := Paint.new(TILE_W, 300 + BELOW)
	_city(p, 300, {"color": NEAR_COLOR, "w0": 40, "w1": 78, "h0": 90, "h1": 270, "gap": 34, "lit": 0.05, "win": 0.8, "grid": 5})
	_spire(p, 150, 300, 20, 245)
	_spire(p, 345, 300, 15, 185)
	_leaning(p, 30, 300, 30, 200, -0.24, NEAR_COLOR.darkened(0.15))
	_tendrils(p, 300)
	return p.texture()


func _paint_street() -> Texture2D:
	var p := Paint.new(TILE_W, 110 + BELOW)
	var ground := 110
	p.rect(0, ground, p.w, p.h - ground, STREET_COLOR)
	# Rubble heaps along the street.
	var x := 0.0
	while x < p.w:
		var r := rng.randf_range(10.0, 34.0)
		p.disc(x, ground + 2.0, r, r * rng.randf_range(0.35, 0.7), STREET_COLOR)
		p.disc(x - r * 0.3, ground - r * 0.2, r * 0.4, r * 0.25, STREET_COLOR.lightened(0.05))
		x += r * rng.randf_range(0.6, 2.4)
	_wreck(p, 46, ground)
	_wreck(p, 262, ground)
	_lamp(p, 130, ground, 3)
	_lamp(p, 340, ground, -6)
	_carcass(p, 190, ground)
	return p.texture()


## Ground plane: cut earth with hive tunnels glowing under the street.
func _paint_ground() -> Texture2D:
	var p := Paint.new(TILE_W, BELOW)
	p.rect(0, 0, p.w, p.h, Color(0.12, 0.09, 0.09))
	p.rect(0, 0, p.w, 3, Color(0.27, 0.23, 0.22))
	p.rect(0, 3, p.w, 2, Color(0.05, 0.04, 0.05))
	for i in 150:
		var sx := rng.randi_range(0, p.w - 1)
		var sy := rng.randi_range(6, p.h - 1)
		p.rect(sx, sy, rng.randi_range(2, 8), rng.randi_range(1, 3), Color(0.16, 0.12, 0.11) if i % 2 == 0 else Color(0.085, 0.065, 0.07))
	var tunnels := [[60.0, 62.0, 28.0], [190.0, 112.0, 36.0], [330.0, 56.0, 24.0]]
	for tn: Array in tunnels:
		p.disc(tn[0], tn[1], tn[2], float(tn[2]) * 0.5, Color(0.04, 0.03, 0.04))
		p.disc(tn[0], float(tn[1]) + float(tn[2]) * 0.22, float(tn[2]) * 0.7, float(tn[2]) * 0.24, Color(0.16, 0.08, 0.09))
		for j in 3:
			var ex: float = float(tn[0]) + (j - 1) * float(tn[2]) * 0.4
			var ey: float = float(tn[1]) + float(tn[2]) * 0.2
			p.disc(ex, ey, 3.0, 4.0, Color(0.62, 0.34, 0.13))
			p.disc(ex - 1.0, ey - 1.0, 1.0, 2.0, HIVE_GLOW)
	return p.texture()


func _paint_smog() -> Texture2D:
	var p := Paint.new(TILE_W, 260)
	var col := Color(0.32, 0.16, 0.17)
	for i in 34:
		var x := rng.randf_range(0.0, TILE_W)
		var r := rng.randf_range(14.0, 44.0)
		var y := 200.0 - rng.randf_range(0.0, 70.0)
		for off: float in [-TILE_W, 0.0, TILE_W]:
			p.disc(x + off, y, r * 1.5, r * 0.5, col)
	p.rect(0, 200, TILE_W, 60, col)
	return p.texture()


## Chunks of concrete along the very bottom edge of the screen.
func _paint_rubble() -> Texture2D:
	var p := Paint.new(TILE_W, BELOW)
	var col := Color(0.03, 0.025, 0.035)
	var base := 150
	p.rect(0, base, p.w, p.h - base, col)
	var x := 0
	while x < p.w:
		var bw := rng.randi_range(6, 26)
		var bh := rng.randi_range(2, 14)
		p.rect(x, base - bh, bw, bh + 1, col)
		if rng.randf() < 0.3:
			p.line(Vector2(x + bw * 0.5, base - bh), Vector2(x + bw * 0.5 + rng.randf_range(-5.0, 5.0), base - bh - rng.randf_range(5.0, 12.0)), col)
		x += bw + rng.randi_range(0, 10)
	return p.texture()


# --- Pieces -------------------------------------------------------------------

func _city(p: Paint, ground: int, spec: Dictionary) -> void:
	var color: Color = spec.color
	var w0: int = spec.w0
	var w1: int = spec.w1
	var h0: int = spec.h0
	var h1: int = spec.h1
	var gap: int = spec.gap
	var x := rng.randi_range(0, 8)
	while x < p.w - w0:
		var bw := mini(rng.randi_range(w0, w1), p.w - x - 1)
		_tower(p, x, ground, bw, rng.randi_range(h0, h1), color.darkened(rng.randf_range(0.0, 0.14)), spec)
		x += bw + rng.randi_range(0, gap)
	p.rect(0, ground, p.w, p.h - ground, color.darkened(0.1))


func _tower(p: Paint, x: int, ground: int, bw: int, bh: int, col: Color, spec: Dictionary) -> void:
	var tops: Array[int] = []
	# A broken roofline: flat stretches and a collapse slope on one side.
	var slope := rng.randf_range(0.0, 1.3) * (1.0 if rng.randf() < 0.5 else -1.0)
	var jag := 0
	for cx in bw:
		if cx % rng.randi_range(2, 4) == 0:
			jag = rng.randi_range(0, 7)
		var cut := int(maxf(0.0, slope * (cx if slope > 0.0 else cx - bw)))
		var top := maxi(bh - jag - cut, 8)
		tops.append(top)
		p.rect(x + cx, ground - top, 1, top, col)
	p.rect(x + bw - 2, ground - bh + 12, 2, bh - 12, col.lightened(0.1))
	var grid: int = spec.grid
	var win_chance: float = spec.win
	var lit_chance: float = spec.lit
	var wy := 5
	while wy < bh - 5:
		var wx := 2
		while wx < bw - 3:
			if ground - wy - 2 >= ground - tops[wx] + 2 and rng.randf() < win_chance:
				var w_col: Color = col.darkened(0.45)
				var roll := rng.randf()
				if roll < lit_chance:
					w_col = LIT
				elif roll < lit_chance + 0.2:
					w_col = Paint.CLEAR
				p.rect(x + wx, ground - wy - 2, maxi(grid - 2, 1), maxi(grid - 2, 2), w_col)
			wx += grid
		wy += grid + 1


## A slab of tower that has toppled against its neighbours.
func _leaning(p: Paint, x: int, ground: int, bw: int, bh: int, lean: float, col: Color) -> void:
	for row in bh:
		var sx := x + int(row * lean)
		var taper := int(bw * 0.3 * float(row) / bh)
		p.rect(sx + taper, ground - row, bw - taper * 2, 1, col)
		if row % 7 < 2:
			p.rect(sx + taper + 2, ground - row, bw - taper * 2 - 4, 1, col.darkened(0.3))


## Organic hive tower, tapered and knobbly, with glowing sacs up its length.
func _spire(p: Paint, x: int, ground: int, half: int, height: int) -> void:
	var bend := rng.randf_range(-0.12, 0.12)
	for row in height:
		var u := float(row) / height
		var size := half * pow(1.0 - u, 0.7) * (1.0 + 0.3 * noise.get_noise_1d(row * 2.0))
		var cx := x + int(bend * row)
		p.rect(cx - int(size), ground - row, maxi(int(size * 2.0), 1), 1, HIVE.darkened(0.25 * (1.0 - u)))
		if row % 11 == 4:
			p.rect(cx - int(size * 0.7), ground - row, int(size * 1.4), 1, HIVE.lightened(0.14))
	for i in range(1, 4 + height / 60):
		var row := int(height * rng.randf_range(0.1, 0.8))
		var cx := x + int(bend * row) + rng.randi_range(-half / 2, half / 2)
		p.disc(cx, ground - row, 2.0, 3.0, HIVE_GLOW)
		p.dot(cx, ground - row - 1, Color(1.0, 0.9, 0.5))


func _tendrils(p: Paint, ground: int) -> void:
	for i in 4:
		var x := rng.randf_range(20.0, p.w - 20.0)
		var y := ground - rng.randf_range(40.0, 180.0)
		var pos := Vector2(x, y)
		var dir := rng.randf_range(-1.0, 1.0)
		for j in 7:
			var next := pos + Vector2(dir * rng.randf_range(4.0, 14.0), rng.randf_range(5.0, 12.0))
			p.line(pos, next, HIVE.darkened(0.3), 2)
			if rng.randf() < 0.35:
				p.disc(next.x, next.y, 1.5, 1.5, HIVE_GLOW)
			pos = next


func _wreck(p: Paint, x: int, ground: int) -> void:
	var col := STREET_COLOR.lightened(0.06)
	p.rect(x, ground - 11, 44, 8, col)
	p.rect(x + 9, ground - 18, 22, 8, col)
	p.rect(x + 12, ground - 16, 7, 4, Color(0.03, 0.02, 0.03))
	p.rect(x + 22, ground - 16, 7, 4, Color(0.03, 0.02, 0.03))
	p.disc(x + 8, ground - 3.0, 4.0, 4.0, STREET_COLOR.darkened(0.3))
	p.disc(x + 35, ground - 3.0, 4.0, 4.0, STREET_COLOR.darkened(0.3))


func _lamp(p: Paint, x: int, ground: int, tilt: int) -> void:
	var col := STREET_COLOR.lightened(0.07)
	var top := Vector2(x + tilt, ground - 72)
	p.line(Vector2(x, ground), top, col, 2)
	p.line(top, top + Vector2(14, 3), col, 2)
	p.rect(int(top.x) + 12, int(top.y) + 3, 5, 2, col.lightened(0.1))


## A dead giant bug lying in the road, ribs up.
func _carcass(p: Paint, x: int, ground: int) -> void:
	var col := Color(0.15, 0.09, 0.10)
	for i in 6:
		var rib_x := x + i * 9
		var rib_h := 26.0 - absf(i - 2.5) * 5.0
		p.line(Vector2(rib_x, ground), Vector2(rib_x + 2.0, ground - rib_h), col, 2)
		p.line(Vector2(rib_x + 2.0, ground - rib_h), Vector2(rib_x + 8.0, ground - rib_h - 3.0), col)
	p.disc(x + 58.0, ground - 7.0, 11.0, 8.0, col)
