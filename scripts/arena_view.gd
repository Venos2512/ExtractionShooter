class_name ArenaView
extends Node2D
## Paints the test lab as three rooms cut open at the front, in fake 3D (see Depth):
## back wall, floor, ceiling and the side of every wall and divider facing the camera,
## turning as the camera moves. Flat and quiet on purpose: the walls are the one thing
## here with presence, so the hero and the alien stand out against them.

const SOLID := Color("24344a")
const BACK_WALL := Color("6d8197")
const WAINSCOT := Color("63778d")
const PANEL_LINE := Color("607489")
const FLOOR_FRONT := Color("8798ab")
const FLOOR_BACK := Color("76899e")
const FLOOR_LINE := Color("6f8398")
const WALL_FRONT := Color("52667c")
const WALL_BACK := Color("63778d")
const CEILING_FRONT := Color("3a4c62")
const CEILING_BACK := Color("53667c")
const LIGHT := Color("9fb3c6")
const CORNER_LINE := Color("4f6379")
const EDGE := Color("a9bdd0")
const EDGE_WIDTH := 5.0
const PANEL_STEP := 182.0
const WAINSCOT_H := 110.0
const MARGIN := 1600.0

var arena: Arena
## How big the back wall is against the front, 1 for flat.
var back := 0.78
var cam := Vector2.INF
var faces: Array[Depth.Face] = []


func setup(a: Arena, back_scale: float) -> void:
	arena = a
	back = back_scale
	faces.clear()
	var n := arena.polygon.size()
	for i in n:
		var p := arena.polygon[i]
		var q := arena.polygon[(i + 1) % n]
		var d := p.direction_to(q)
		var inward := Vector2(d.y, -d.x)
		if inward.y < -0.5:
			faces.append(Depth.Face.new(p, q, inward, FLOOR_FRONT, FLOOR_BACK))
		elif inward.y > 0.5:
			faces.append(Depth.Face.new(p, q, inward, CEILING_FRONT, CEILING_BACK))
		else:
			faces.append(Depth.Face.new(p, q, inward, WALL_FRONT, WALL_BACK))
	cam = Vector2.INF


func _process(_dt: float) -> void:
	var c := get_viewport().get_camera_2d()
	if arena == null or c == null:
		return
	var now := c.get_screen_center_position()
	if now.distance_squared_to(cam) > 0.01:
		cam = now
		queue_redraw()


func _draw() -> void:
	if arena == null or cam == Vector2.INF:
		return
	var room := arena.polygon
	draw_rect(Rect2(-MARGIN, -Arena.HEIGHT - MARGIN, Arena.WIDTH + MARGIN * 2.0, Arena.HEIGHT + MARGIN * 2.0), SOLID)
	_draw_back_wall(room)
	var shown: Array[Depth.Face] = []
	for f in faces:
		if Depth.faces_camera(f, cam):
			shown.append(f)
	Depth.sort_far_first(shown, cam)
	for f in shown:
		Depth.draw_face(self, f, cam, back, room)
		_dress(f, room)
	# The fold where two surfaces meet, from each corner back to the back wall.
	for p in room:
		Depth.draw_line_clipped(self, p, Depth.project(p, cam, back), room, CORNER_LINE, 2.0)
	var closed := room.duplicate()
	closed.append(room[0])
	draw_polyline(closed, EDGE, EDGE_WIDTH, true)


func _draw_back_wall(room: PackedVector2Array) -> void:
	var far := Depth.project_all(room, cam, back)
	for piece in Geometry2D.intersect_polygons(far, room):
		if not Depth.drawable(piece):
			continue
		draw_colored_polygon(piece, BACK_WALL)
		_dress_back(piece)


## Lower panels and seams, all pushed back with the wall.
func _dress_back(piece: PackedVector2Array) -> void:
	var x := 0.0
	while x < Arena.WIDTH:
		var band := PackedVector2Array([Vector2(x, 0.0), Vector2(x + Arena.ROOM_W, 0.0), Vector2(x + Arena.ROOM_W, -WAINSCOT_H), Vector2(x, -WAINSCOT_H)])
		Depth.draw_clipped(self, Depth.project_all(band, cam, back), piece, WAINSCOT)
		x += Arena.ROOM_W
	x = PANEL_STEP
	while x < Arena.WIDTH:
		var top := Depth.project(Vector2(x, -Arena.HEIGHT), cam, back)
		var bottom := Depth.project(Vector2(x, 0.0), cam, back)
		Depth.draw_line_clipped(self, bottom, top, piece, PANEL_LINE, 3.0)
		x += PANEL_STEP
	var rail_l := Depth.project(Vector2(0.0, -WAINSCOT_H), cam, back)
	var rail_r := Depth.project(Vector2(Arena.WIDTH, -WAINSCOT_H), cam, back)
	Depth.draw_line_clipped(self, rail_l, rail_r, piece, PANEL_LINE, 3.0)


## Tiles on the floor and a light panel down the middle of each ceiling.
func _dress(f: Depth.Face, room: PackedVector2Array) -> void:
	if f.inward.y < -0.5:
		Depth.draw_seams_in(self, f, cam, back, 91.0, room, FLOOR_LINE, 2.0)
		Depth.draw_seams_across(self, f, cam, back, [0.34, 0.67], room, FLOOR_LINE, 2.0)
	elif f.inward.y > 0.5 and f.a.distance_to(f.b) > 300.0:
		Depth.draw_clipped(self, Depth.patch(f, 0.3, 0.7, 0.25, 0.75, cam, back), room, LIGHT)
