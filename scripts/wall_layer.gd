class_name WallLayer
extends Node2D
## Every room as a box cut open at the front, in fake 3D (see Depth). The painted back
## wall sits deeper and shrinks toward the middle of the screen, and the two side
## walls, the floor and the ceiling run from the room's front opening back to it, so
## they turn as the camera moves. Doorways open in the side walls, and ladders through
## the floor and ceiling.

const PX := 2
const CONCRETE_D := Color(0.11, 0.10, 0.12)
const RUST := Color(0.48, 0.32, 0.20)
const HIVE := Color(0.20, 0.09, 0.13)
const HIVE_L := Color(0.31, 0.14, 0.16)
const PUS := Color(1.0, 0.55, 0.12)
const FLOOR_FRONT := Color(0.34, 0.32, 0.31)
const FLOOR_BACK := Color(0.21, 0.20, 0.21)
const CEILING_FRONT := Color(0.07, 0.06, 0.08)
const CEILING_BACK := Color(0.15, 0.14, 0.15)
const GAP := Color(0.04, 0.03, 0.05)
## Noise level above which a stretch of wall is gone, by Room.wall_damage.
const HOLE_ABOVE := [0.22, -0.08, -0.55]
## How far back, as a share of the room's depth, doorways and ladder holes reach.
const DOOR_DEPTH := 0.38
const HATCH_DEPTH := 0.3
const BASEBOARD := 26.0
const BRICK_COURSE := 24.0
## Rooms this far outside the screen are skipped.
const CULL := 120.0

class WallPanel:
	var room: Level.Room
	var texture: Texture2D
	## The room's front opening, which everything of the room is clipped to.
	var rect := Rect2()
	var clip := PackedVector2Array()
	## Floor, right wall, ceiling, left wall.
	var faces: Array[Depth.Face] = []
	## Share of each side wall's height, from the floor, that is a doorway.
	var door_l := 0.0
	var door_r := 0.0
	var hatch_up: Array[float] = []
	var hatch_down: Array[float] = []

var game: Game
var t: Tuning
var panels: Array[WallPanel] = []
var rng := RandomNumberGenerator.new()
var chips := FastNoiseLite.new()
var sections := FastNoiseLite.new()
var cam := Vector2.INF


func setup(g: Game) -> void:
	game = g
	t = g.t
	rng.seed = g.level.rng.seed
	chips.seed = int(g.level.rng.seed & 0xffff)
	chips.frequency = 0.035
	sections.seed = chips.seed + 1
	sections.frequency = 0.008
	for r in g.level.rooms:
		if r.kind != Level.Kind.GOAL:
			_add_panel(r)


func _add_panel(r: Level.Room) -> void:
	var panel := WallPanel.new()
	panel.room = r
	var fy := game.view.floor_y(r.f)
	panel.rect = Rect2(r.x0, fy - t.room_h, r.x1 - r.x0, t.room_h)
	var bottom_l := Vector2(r.x0, fy)
	var bottom_r := Vector2(r.x1, fy)
	var top_r := Vector2(r.x1, fy - t.room_h)
	var top_l := Vector2(r.x0, fy - t.room_h)
	panel.clip = PackedVector2Array([bottom_l, bottom_r, top_r, top_l])
	var side_front := r.wall.darkened(0.5)
	var side_back := r.wall.darkened(0.3)
	# Same turn as the arena outline: floor rightward, so the room is on the left of travel.
	panel.faces = [
		Depth.Face.new(bottom_l, bottom_r, Vector2.UP, FLOOR_FRONT, FLOOR_BACK),
		Depth.Face.new(bottom_r, top_r, Vector2.LEFT, side_front, side_back),
		Depth.Face.new(top_r, top_l, Vector2.DOWN, CEILING_FRONT, CEILING_BACK),
		Depth.Face.new(top_l, bottom_l, Vector2.RIGHT, side_front, side_back),
	]
	var door_share := minf(t.door_height / t.room_h, 1.0)
	panel.door_l = door_share if r.door_l != null else 0.0
	panel.door_r = door_share if r.door_r != null else 0.0
	for l in game.level.ladders:
		if l.low_room == r:
			panel.hatch_up.append(l.x)
		if l.high_room == r:
			panel.hatch_down.append(l.x)
	panel.texture = _paint(r)
	panels.append(panel)


func _process(_dt: float) -> void:
	if game == null:
		return
	var now := game.camera.get_screen_center_position()
	if now.distance_squared_to(cam) > 0.01:
		cam = now
		queue_redraw()


func _draw() -> void:
	if game == null or cam == Vector2.INF:
		return
	var half := get_viewport_rect().size / game.camera.zoom * 0.5 + Vector2(CULL, CULL)
	var view := Rect2(cam - half, half * 2.0)
	for panel in panels:
		if view.intersects(panel.rect):
			_draw_room(panel)


func _draw_room(panel: WallPanel) -> void:
	var back := t.scroll_walls
	var far := back_rect(panel)
	var shown := far.intersection(panel.rect)
	if shown.has_area():
		var src := Rect2((shown.position - far.position) / (back * PX), shown.size / (back * PX))
		draw_texture_rect_region(panel.texture, shown, src)
	for i in panel.faces.size():
		var f := panel.faces[i]
		if not Depth.faces_camera(f, cam):
			continue
		Depth.draw_face(self, f, cam, back, panel.clip)
		match i:
			0:
				_dress_floor(panel, f, back)
			1:
				_dress_side(panel, f, back, panel.door_r, true)
			2:
				_dress_ceiling(panel, f, back)
			3:
				_dress_side(panel, f, back, panel.door_l, false)
	# The folds where the surfaces meet, from each front corner back to the back wall.
	for p in panel.clip:
		Depth.draw_line_clipped(self, p, Depth.project(p, cam, back), panel.clip, CONCRETE_D, 2.0)


## Where the back wall shows: the front opening pushed back toward the camera.
func back_rect(panel: WallPanel) -> Rect2:
	var back := t.scroll_walls
	return Rect2(Depth.project(panel.rect.position, cam, back), panel.rect.size * back)


func _dress_floor(panel: WallPanel, f: Depth.Face, back: float) -> void:
	Depth.draw_seams_in(self, f, cam, back, 42.0, panel.clip, FLOOR_BACK, 1.0)
	Depth.draw_seams_across(self, f, cam, back, [0.3, 0.62], panel.clip, FLOOR_BACK, 1.0)
	for x in panel.hatch_down:
		_hatch(panel, f, (x - panel.rect.position.x) / panel.rect.size.x, back)


func _dress_ceiling(panel: WallPanel, f: Depth.Face, back: float) -> void:
	var r := panel.room
	var width := r.x1 - r.x0
	# Beams left where dividing walls came down to make a hall.
	for c in range(r.c0 + 1, r.c1 + 1):
		var at := (r.x1 - c * t.room_w) / width
		var half := 12.0 / width
		Depth.draw_clipped(self, Depth.patch(f, at - half, at + half, 0.0, 1.0, cam, back), panel.clip, CONCRETE_D.lightened(0.12))
	for x in panel.hatch_up:
		_hatch(panel, f, (r.x1 - x) / width, back)


func _hatch(panel: WallPanel, f: Depth.Face, at: float, back: float) -> void:
	var half := 24.0 / panel.rect.size.x
	Depth.draw_clipped(self, Depth.patch(f, at - half, at + half, 0.0, HATCH_DEPTH, cam, back), panel.clip, GAP)


## Brick courses running into the depth, a baseboard, and the doorway if there is one.
## The right wall's edge runs up from the floor, the left wall's down to it.
func _dress_side(panel: WallPanel, f: Depth.Face, back: float, door: float, runs_up: bool) -> void:
	var r := panel.room
	Depth.draw_seams_in(self, f, cam, back, BRICK_COURSE, panel.clip, r.wall.darkened(0.62), 1.0)
	var board := BASEBOARD / t.room_h
	var t0 := 0.0 if runs_up else 1.0 - board
	Depth.draw_clipped(self, Depth.patch(f, t0, t0 + board, 0.0, 1.0, cam, back), panel.clip, r.trim.darkened(0.25))
	if door <= 0.0:
		return
	var lintel := 0.04
	var d0 := 0.0 if runs_up else 1.0 - door
	var d1 := door if runs_up else 1.0
	Depth.draw_clipped(self, Depth.patch(f, d0, d1, 0.0, DOOR_DEPTH + 0.04, cam, back), panel.clip, r.trim.darkened(0.1))
	var h0 := d0 if runs_up else d0 + lintel
	var h1 := d1 - lintel if runs_up else d1
	Depth.draw_clipped(self, Depth.patch(f, h0, h1, 0.0, DOOR_DEPTH, cam, back), panel.clip, GAP)


## World x of the back wall's left edge, which is what the player sees moving.
func content_x(panel: WallPanel) -> float:
	return back_rect(panel).position.x


func panel_for(r: Level.Room) -> WallPanel:
	for panel in panels:
		if panel.room == r:
			return panel
	return null


func _paint(r: Level.Room) -> Texture2D:
	var p := Paint.new(int((r.x1 - r.x0) / PX), int(t.room_h / PX))
	var base := r.wall.darkened(0.12)
	var trim := r.trim.darkened(0.12)
	p.rect(0, 0, p.w, p.h, base)
	_bricks(p, base)
	var floor_row := p.h
	p.rect(0, floor_row - 13, p.w, 13, trim)
	p.rect(0, floor_row - 15, p.w, 2, trim.lightened(0.25))
	if r.kind == Level.Kind.NEST:
		_hive(p, floor_row)
	_holes(p, r, floor_row)
	if r.window_x > 0.0:
		_window(p, int((r.window_x - r.x0) / PX), floor_row, trim)
	_rebar(p, floor_row)
	return p.texture()


func _bricks(p: Paint, base: Color) -> void:
	var row := 0
	var y := 0
	while y < p.h:
		var x := -(row % 2) * 6
		while x < p.w:
			var shade := base.darkened(rng.randf_range(0.0, 0.18))
			if rng.randf() < 0.25:
				shade = base.lightened(0.07)
			p.rect(x, y, 11, 5, shade)
			x += 12
		y += 6
		row += 1


## Punch out what the impact tore away, leaving a low broken wall and a ragged top.
func _holes(p: Paint, r: Level.Room, floor_row: int) -> void:
	var above: float = HOLE_ABOVE[r.wall_damage]
	for x in p.w:
		var wx := r.x0 + x * PX
		if sections.get_noise_2d(wx, r.id * 90.0) <= above:
			continue
		var n1 := chips.get_noise_2d(wx, r.id * 50.0)
		var n2 := chips.get_noise_2d(wx, r.id * 50.0 + 400.0)
		var low := int((34.0 + (n1 + 1.0) * 30.0) / PX)
		var hang := int((14.0 + (n2 + 1.0) * 26.0) / PX)
		var y0 := hang if r.wall_damage < 2 else 0
		var y1 := floor_row - low
		p.rect(x, y0, 1, y1 - y0, Paint.CLEAR)
		p.dot(x, y0 - 1, CONCRETE_D)
		p.dot(x, y1, CONCRETE_D)


func _window(p: Paint, cx: int, floor_row: int, trim: Color) -> void:
	var top := floor_row - 99
	p.rect(cx - 26, top, 52, 55, trim)
	p.rect(cx - 23, top + 3, 46, 49, Paint.CLEAR)
	p.rect(cx - 1, top + 3, 2, 49, trim)
	p.rect(cx - 23, top + 26, 46, 2, trim)
	for i in 3:
		var gx := cx - 23 + rng.randi_range(0, 40)
		p.line(Vector2(gx, top + 3), Vector2(gx + rng.randi_range(-3, 3), top + 3 + rng.randi_range(4, 10)), Color(0.6, 0.72, 0.78, 0.8))


## Nest rooms: the hive has grown over the back wall.
func _hive(p: Paint, floor_row: int) -> void:
	for i in rng.randi_range(5, 8):
		var cx := rng.randf_range(0.0, p.w)
		var cy := float(floor_row) - rng.randf_range(4.0, 90.0)
		var size := rng.randf_range(14.0, 34.0)
		p.disc(cx, cy, size, size * 0.7, HIVE)
		p.disc(cx - 3.0, cy - 2.0, size * 0.6, size * 0.38, HIVE_L)
		for j in rng.randi_range(1, 3):
			p.disc(cx + rng.randf_range(-size, size) * 0.6, cy + rng.randf_range(-size, size) * 0.3, 2.0, 2.0, PUS)


func _rebar(p: Paint, floor_row: int) -> void:
	for i in 6:
		var a := Vector2(rng.randi_range(0, p.w - 1), floor_row - rng.randi_range(25, 45))
		p.line(a, a + Vector2(rng.randi_range(-4, 4), -rng.randi_range(6, 12)), RUST)
