class_name ForegroundLayer
extends Node2D
## Dark silhouettes between the camera and the action. Each piece is a Parallax2D
## pinned to a spot in a room: it sits there when the camera is on that spot and
## slides past faster than the play plane. Backdrop adds embers and rubble on top.

const PX := 3
const COLOR := Color(0.05, 0.04, 0.055)
const COLOR_L := Color(0.12, 0.09, 0.10)
const GLOW := Color(0.95, 0.48, 0.12)
const PILLAR_CHANCE := 0.18
const GIRDER_CHANCE := 0.2
const WIRES_CHANCE := 0.45
const HEAP_CHANCE := 0.7
## See-through enough that the hero and bugs stay readable behind a tall piece.
const TALL_ALPHA := 0.72
## How far a heap rises above the floor line, so it only ever hides feet.
const HEAP_RISE := 18.0

var game: Game
var t: Tuning
var pieces: Array[Parallax2D] = []
var rng := RandomNumberGenerator.new()
var half_screen := Vector2.ZERO
var pillar: Texture2D
var girder: Texture2D
var wires: Texture2D
var heap: Texture2D


func setup(g: Game) -> void:
	game = g
	t = g.t
	rng.seed = g.level.rng.seed + 2
	half_screen = g.get_viewport_rect().size * 0.5
	pillar = _paint_pillar()
	girder = _paint_girder()
	wires = _paint_wires()
	heap = _paint_heap()
	for r in g.level.rooms:
		_dress_room(r)


func _dress_room(r: Level.Room) -> void:
	var fy := game.view.floor_y(r.f)
	var indoors := r.kind != Level.Kind.GOAL
	if rng.randf() < HEAP_CHANCE:
		_add(heap, r, fy + heap.get_height() * PX - HEAP_RISE, 1.0)
	if indoors and rng.randf() < WIRES_CHANCE:
		_add(wires, r, fy - t.room_h + wires.get_height() * PX, 1.0)
	if indoors and rng.randf() < PILLAR_CHANCE:
		_add(pillar, r, fy + t.slab, TALL_ALPHA)
	elif indoors and rng.randf() < GIRDER_CHANCE:
		_add(girder, r, fy + t.slab, TALL_ALPHA)


## bottom_y is the world height the texture's bottom edge sits at.
func _add(tex: Texture2D, r: Level.Room, bottom_y: float, alpha: float) -> void:
	var x := lerpf(r.x0, r.x1, rng.randf_range(0.1, 0.9))
	var cam_at := Vector2(x, game.view.floor_y(r.f) - t.camera_lift)
	var layer := Parallax2D.new()
	layer.name = "Front%d" % pieces.size()
	layer.scroll_scale = Vector2(t.scroll_front, t.scroll_front)
	layer.scroll_offset = -(cam_at - half_screen) * (1.0 - t.scroll_front)
	layer.modulate.a = alpha
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.flip_h = rng.randf() < 0.5
	s.scale = Vector2(PX, PX)
	s.position = Vector2(x - tex.get_width() * PX * 0.5, bottom_y - tex.get_height() * PX)
	layer.add_child(s)
	add_child(layer)
	pieces.append(layer)


## A broken structural column, torn off above head height so it never reads as a wall.
func _paint_pillar() -> Texture2D:
	var p := Paint.new(16, 110)
	for x in range(2, 14):
		var top := 6 + int(absf(x - 7.0)) + rng.randi_range(0, 5)
		p.rect(x, top, 1, p.h - top, COLOR)
		p.dot(x, top, COLOR_L)
	p.rect(2, 8, 2, p.h - 8, COLOR_L)
	p.rect(2, 44, 12, 1, COLOR_L)
	p.rect(2, 78, 12, 1, COLOR_L)
	p.line(Vector2(5, 8), Vector2(3, 0), COLOR)
	p.line(Vector2(10, 8), Vector2(13, 1), COLOR)
	return p.texture()


func _paint_girder() -> Texture2D:
	var p := Paint.new(70, 52)
	p.line(Vector2(3, 49), Vector2(64, 6), COLOR, 3)
	p.line(Vector2(3, 47), Vector2(64, 4), COLOR_L)
	for i in range(1, 6):
		var a := Vector2(3, 49).lerp(Vector2(64, 6), float(i) / 6.0)
		p.line(a, a + Vector2(3, 4), COLOR)
	p.rect(0, 46, 16, 6, COLOR)
	return p.texture()


## Cables and hive strands hanging from the ceiling.
func _paint_wires() -> Texture2D:
	var p := Paint.new(60, 26)
	for i in 4:
		var pos := Vector2(rng.randf_range(4.0, 56.0), 0.0)
		var drop := rng.randf_range(10.0, 24.0)
		while pos.y < drop:
			var next := pos + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(3.0, 6.0))
			p.line(pos, next, COLOR)
			pos = next
		if i % 2 == 1:
			p.disc(pos.x, pos.y, 1.5, 2.0, GLOW)
	return p.texture()


## Loose rubble with a broken top edge. Most of it sits below the floor line.
func _paint_heap() -> Texture2D:
	var p := Paint.new(60, 18)
	var x := 1
	while x < p.w - 1:
		var u := float(x) / p.w
		var top := int(sin(u * PI) * 7.0) + rng.randi_range(0, 3)
		var bw := rng.randi_range(2, 5)
		var y := p.h - 10 - top
		p.rect(x, y, bw, p.h - y, COLOR)
		p.rect(x, y, bw, 1, COLOR_L)
		x += bw
	p.line(Vector2(20, 7), Vector2(16, 1), COLOR)
	p.line(Vector2(40, 8), Vector2(45, 2), COLOR)
	return p.texture()
