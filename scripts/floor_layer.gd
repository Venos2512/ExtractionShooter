class_name FloorLayer
extends Node2D
## The structure on the play plane, painted into one sprite: slabs, piers, ladders,
## furniture and the landing zone. Fixed to the world, so walls behind and the
## foreground in front slide against it. Empty map cells stay open to the city.

const PX := 2
const MARGIN := 40.0
const CREEP := Color(0.17, 0.08, 0.12)
const CREEP_L := Color(0.28, 0.13, 0.15)
const PUS := Color(1.0, 0.55, 0.12)
const RUST := Color(0.48, 0.32, 0.20)
const CONCRETE := Color(0.26, 0.25, 0.26)
const CONCRETE_L := Color(0.40, 0.38, 0.37)
const CONCRETE_D := Color(0.11, 0.10, 0.12)
const HAZARD := Color(0.85, 0.68, 0.2)

var level: Level
var t: Tuning
var spacing := 0.0
var top_y := 0.0
var p: Paint
var rng := RandomNumberGenerator.new()


func setup(g: Game) -> void:
	level = g.level
	t = g.t
	spacing = t.room_h + t.slab
	top_y = -t.floors * spacing - 140.0
	rng.seed = level.rng.seed + 1
	var w := int((level.width + MARGIN * 2.0) / PX)
	var h := int((t.slab - top_y) / PX)
	p = Paint.new(w, h)
	_supports()
	for pr in level.props:
		_prop(pr)
	for r in level.rooms:
		if r.kind != Level.Kind.GOAL:
			_creep(r)
	_slabs()
	for r in level.rooms:
		_edges(r)
	for l in level.ladders:
		_ladder(l)
	_rooflines()
	_goal_zone()
	var s := Sprite2D.new()
	s.name = "Structure"
	s.texture = p.texture()
	s.centered = false
	s.scale = Vector2(PX, PX)
	s.position = Vector2(-MARGIN, top_y)
	add_child(s)


func _px(x: float) -> int:
	return int((x + MARGIN) / PX)


func _py(y: float) -> int:
	return int((y - top_y) / PX)


## World rect given by x range and heights above floor f.
func _box(x0: float, x1: float, h0: float, h1: float, f: int, col: Color) -> void:
	var fy := -f * spacing
	p.rect(_px(x0), _py(fy - h1), int((x1 - x0) / PX), int((h1 - h0) / PX), col)


## Rooms with nothing below stand on bare pillars, with the city showing between.
func _supports() -> void:
	for f in range(1, t.floors):
		for c in t.cols:
			if level.room_in_cell(f, c) == null:
				continue
			var below := f - 1
			while below >= 0 and level.room_in_cell(below, c) == null:
				var x0 := c * t.room_w
				_pillar(x0 + 46.0, below)
				_pillar(x0 + t.room_w - 46.0, below)
				_brace(x0 + 46.0, x0 + t.room_w - 46.0, below)
				below -= 1


func _pillar(x: float, f: int) -> void:
	_box(x - 12.0, x + 12.0, 0.0, spacing, f, CONCRETE_D.lightened(0.08))
	_box(x - 12.0, x - 7.0, 0.0, spacing, f, CONCRETE)


func _brace(x0: float, x1: float, f: int) -> void:
	var y := _py(-f * spacing - t.room_h)
	p.line(Vector2(_px(x0), y), Vector2(_px(x1), _py(-f * spacing - 10.0)), CONCRETE_D, 3)


func _prop(pr: Level.Prop) -> void:
	var f := pr.room.f
	var c := pr.color
	match pr.kind:
		0:
			_box(pr.x0, pr.x1, 0.0, pr.h1, f, c)
			var h := 22.0
			while h < pr.h1 - 8.0:
				_box(pr.x0 + 4.0, pr.x1 - 4.0, h - 12.0, h, f, c.darkened(0.45))
				_box(pr.x0 + 8.0, pr.x0 + rng.randf_range(16.0, pr.x1 - pr.x0 - 8.0), h - 12.0, h - 4.0, f, c.lightened(0.15))
				h += 26.0
		1:
			_box(pr.x0, pr.x1, 0.0, pr.h1, f, c)
			var half := (pr.x0 + pr.x1) * 0.5
			_box(half - 1.0, half + 1.0, 0.0, pr.h1, f, c.darkened(0.5))
			_box(pr.x0 + 5.0, pr.x1 - 5.0, pr.h1 - 14.0, pr.h1 - 10.0, f, c.darkened(0.3))
		2:
			_box(pr.x0, pr.x1, 34.0, 42.0, f, c.lightened(0.1))
			_box(pr.x0 + 4.0, pr.x0 + 10.0, 0.0, 34.0, f, c.darkened(0.25))
			_box(pr.x1 - 10.0, pr.x1 - 4.0, 0.0, 34.0, f, c.darkened(0.25))
		3:
			# A knocked over cabinet with a slanted, ragged top.
			var x := pr.x0
			while x < pr.x1:
				var u := (x - pr.x0) / (pr.x1 - pr.x0)
				_box(x, x + PX, 0.0, lerpf(pr.h1 * 0.8, 18.0, u), f, c.darkened(0.1 + u * 0.3))
				x += PX


## Hive growth that has crept over the ruin since the impact.
func _creep(r: Level.Room) -> void:
	var fy := -r.f * spacing
	var patches := rng.randi_range(2, 4)
	if r.kind == Level.Kind.NEST:
		patches += 4
	for i in patches:
		var cx := rng.randf_range(r.x0 + 10.0, r.x1 - 10.0)
		var ceil_side := rng.randf() < 0.45
		var cy := fy - (t.room_h if ceil_side else 0.0)
		var px0 := _px(cx)
		var py0 := _py(cy)
		var size := rng.randf_range(8.0, 22.0)
		p.disc(px0, py0, size, size * 0.55, CREEP)
		p.disc(px0 - 3, py0 + (1 if ceil_side else -1), size * 0.6, size * 0.3, CREEP_L)
		for j in rng.randi_range(1, 3):
			var ox := rng.randf_range(-size * 0.7, size * 0.7)
			var oy := rng.randf_range(0.0, size * 0.35) * (1.0 if ceil_side else -1.0)
			p.disc(px0 + ox, py0 + oy, 2.0, 2.0, PUS)
			p.dot(int(px0 + ox), int(py0 + oy) - 1, Color(1.0, 0.9, 0.5))
	if rng.randf() < (0.8 if r.kind == Level.Kind.NEST else 0.3):
		_eggs(rng.randf_range(r.x0 + 30.0, r.x1 - 30.0), r.f)


func _eggs(x: float, f: int) -> void:
	var y := _py(-f * spacing)
	for i in rng.randi_range(2, 4):
		var ex := _px(x) + i * 7 + rng.randi_range(-1, 1)
		var eh := rng.randf_range(4.0, 6.0)
		p.disc(ex, y - eh, 3.5, eh, Color(0.62, 0.40, 0.18))
		p.disc(ex - 1, y - eh - 1.0, 1.5, eh * 0.5, Color(1.0, 0.72, 0.28))


## Every room needs a slab under it, and all but the landing zone one over it.
func _slabs() -> void:
	var done: Dictionary = {}
	for r in level.rooms:
		for c in range(r.c0, r.c1 + 1):
			done[Vector2i(r.f, c)] = true
			if r.kind != Level.Kind.GOAL:
				done[Vector2i(r.f + 1, c)] = true
	for key: Vector2i in done:
		_slab(key.x, key.y)


func _slab(f: int, c: int) -> void:
	var x0 := _px(c * t.room_w - 16.0)
	var w := int((t.room_w + 32.0) / PX)
	var y := _py(-f * spacing)
	var rows := int(t.slab / PX)
	p.rect(x0, y, w, rows, CONCRETE)
	# The top band is the walkable floor; swarm lanes draw on it.
	p.rect(x0, y, w, 6, CONCRETE_L)
	p.rect(x0, y + 6, w, 1, CONCRETE_D)
	p.rect(x0, y + rows - 3, w, 3, CONCRETE_D)
	var x := 0
	while x < w:
		p.rect(x0 + x, y + 7, 1, rows - 10, CONCRETE_D)
		x += rng.randi_range(18, 46)
		# Ragged underside where chunks have fallen off.
		p.rect(x0 + x, y + rows - rng.randi_range(4, 9), rng.randi_range(4, 14), 9, Paint.CLEAR)
	for i in rng.randi_range(2, 5):
		var sx := x0 + rng.randi_range(0, w)
		p.disc(sx, y + 3, rng.randf_range(6.0, 16.0), 2.0, Color(0.30, 0.17, 0.11))


func _edges(r: Level.Room) -> void:
	if r.kind != Level.Kind.GOAL or r.door_l != null:
		_edge(r.x0, r.f, r.door_l != null)
	if r.kind != Level.Kind.GOAL:
		_edge(r.x1, r.f, r.door_r != null)
	for c in range(r.c0 + 1, r.c1 + 1):
		if r.kind != Level.Kind.GOAL:
			# The beam left where a dividing wall came down to make a hall.
			var x := c * t.room_w
			_box(x - 12.0, x + 12.0, t.room_h - 20.0, t.room_h, r.f, CONCRETE)
			_box(x - 12.0, x + 12.0, t.room_h - 24.0, t.room_h - 20.0, r.f, CONCRETE_D)


func _edge(x: float, f: int, has_door: bool) -> void:
	var from := t.door_height if has_door else 0.0
	_box(x - 10.0, x + 10.0, from, t.room_h, f, CONCRETE)
	_box(x - 10.0, x - 6.0, from, t.room_h, f, CONCRETE_L)
	if has_door:
		_box(x - 14.0, x + 14.0, t.door_height - 6.0, t.door_height, f, CONCRETE_D)


func _ladder(l: Level.Ladder) -> void:
	var f := l.low_f
	var x := l.x
	# Hole through the slab above.
	_box(x - 24.0, x + 24.0, t.room_h, spacing, f, Paint.CLEAR)
	_box(x - 28.0, x - 24.0, t.room_h, spacing, f, HAZARD)
	_box(x + 24.0, x + 28.0, t.room_h, spacing, f, HAZARD)
	var col := Color(0.76, 0.62, 0.26)
	var top := spacing + 26.0
	_box(x - 17.0, x - 13.0, 0.0, top, f, col)
	_box(x + 13.0, x + 17.0, 0.0, top, f, col)
	var h := 14.0
	while h < top:
		_box(x - 13.0, x + 13.0, h, h + 4.0, f, col.darkened(0.15))
		h += 24.0


## Broken parapet and bent rebar along every exposed top, for a ragged skyline.
func _rooflines() -> void:
	for r in level.rooms:
		if r.kind == Level.Kind.GOAL:
			continue
		for c in range(r.c0, r.c1 + 1):
			if r.f + 1 < t.floors and level.room_in_cell(r.f + 1, c) != null:
				continue
			var f := r.f + 1
			var x := c * t.room_w
			var end := x + t.room_w
			while x < end:
				var bw := rng.randf_range(16.0, 70.0)
				var bh := rng.randf_range(4.0, 36.0)
				if rng.randf() < 0.6:
					_box(x, minf(x + bw, end), 0.0, bh, f, CONCRETE)
					_box(x, minf(x + bw, end), bh - 4.0, bh, f, CONCRETE_L)
				x += bw
			for i in 3:
				var bar := Vector2(_px(rng.randf_range(c * t.room_w, end)), _py(-f * spacing))
				p.line(bar, bar + Vector2(rng.randi_range(-6, 6), -rng.randi_range(10, 26)), RUST)
			if rng.randf() < 0.3:
				_eggs(rng.randf_range(c * t.room_w + 30.0, end - 30.0), f)


## The last stretch: open street, sandbags, floodlight, and the barricade at the end.
func _goal_zone() -> void:
	var r := level.goal_room
	var y := _py(0.0)
	var x := r.x0 + 30.0
	while x < r.x1:
		p.rect(_px(x), y + 1, 12, 3, HAZARD)
		x += 48.0
	var end := r.x1
	_box(end - 14.0, end + 16.0, 0.0, 170.0, 0, CONCRETE)
	_box(end - 14.0, end - 8.0, 0.0, 170.0, 0, CONCRETE_L)
	for row in 6:
		_box(end - 40.0, end - 14.0, float(row) * 22.0, float(row) * 22.0 + 10.0, 0, HAZARD)
		_box(end - 40.0, end - 14.0, float(row) * 22.0 + 10.0, float(row) * 22.0 + 22.0, 0, CONCRETE_D)
	for sand: float in [r.x0 + 54.0, r.x0 + 82.0, r.x0 + 68.0]:
		var h := 12.0 if sand == r.x0 + 68.0 else 0.0
		_box(sand - 16.0, sand + 16.0, h, h + 14.0, 0, Color(0.42, 0.36, 0.24))
		_box(sand - 16.0, sand + 16.0, h + 10.0, h + 14.0, 0, Color(0.53, 0.46, 0.31))
	var pole := r.x0 + 130.0
	_box(pole - 3.0, pole + 3.0, 0.0, 190.0, 0, CONCRETE_D)
	_box(pole - 18.0, pole + 18.0, 190.0, 202.0, 0, CONCRETE)
	_box(pole - 15.0, pole + 15.0, 186.0, 190.0, 0, Color(1.0, 0.92, 0.65))
