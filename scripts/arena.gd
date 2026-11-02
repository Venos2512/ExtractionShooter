class_name Arena
extends RefCounted
## The big test room: three lab rooms side by side, each as wide as a room of the old
## map, inside one closed outline of floor, walls, ceiling and the terrain built into
## them. Aliens crawl a loop just inside the outline. All of it is in world space,
## where height is -y, on floor 0.

const WIDTH := 1638.0
const HEIGHT := 560.0
const ROOM_W := 546.0
## Heights above the floor. Runs along the floor to the right, up the right wall, back
## along the ceiling and round the two dividing walls, which hang down to the top of a
## doorway, then down the left wall. Slopes are shallow enough for the hero to walk,
## the floor under each doorway is flat, and every doorway and ledge clears his head,
## because he cannot jump.
const OUTLINE: Array[Vector2] = [
	Vector2(0, 0), Vector2(680, 0), Vector2(780, 100), Vector2(880, 100), Vector2(980, 0),
	Vector2(1240, 0), Vector2(1330, 70), Vector2(1420, 70), Vector2(1510, 0), Vector2(1638, 0),
	Vector2(1638, 250), Vector2(1500, 250), Vector2(1500, 290), Vector2(1638, 290),
	Vector2(1638, 560), Vector2(1112, 560), Vector2(1112, 260), Vector2(1072, 260), Vector2(1072, 560),
	Vector2(566, 560), Vector2(566, 260), Vector2(526, 260), Vector2(526, 560),
	Vector2(0, 560), Vector2(0, 300), Vector2(140, 300), Vector2(140, 260), Vector2(0, 260),
]
const FLOOR_POINTS := 10
const CORNER := 26.0

var polygon := PackedVector2Array()
var loop := PackedVector2Array()
var marks := PackedFloat32Array()
var length := 0.0
## Written by pose().
var at := Vector2.ZERO
var normal := Vector2.UP


func _init(ride: float) -> void:
	for p in OUTLINE:
		polygon.append(Vector2(p.x, -p.y))
	_build_loop(ride)


func _build_loop(ride: float) -> void:
	var inner: PackedVector2Array = Geometry2D.offset_polygon(polygon, -ride, Geometry2D.JOIN_ROUND)[0]
	var points := _rounded(inner)
	# +s must run with the room on the left of travel as seen on screen: rightward on the floor.
	var mid := (points[0] + points[1]) * 0.5
	if not Geometry2D.is_point_in_polygon(mid + _surface_normal(points[0], points[1]) * ride * 0.5, polygon):
		points.reverse()
	loop = points
	marks.resize(loop.size() + 1)
	var total := 0.0
	for i in loop.size():
		marks[i] = total
		total += loop[i].distance_to(loop[(i + 1) % loop.size()])
	marks[loop.size()] = total
	length = total


## Cuts every corner with a short curve, so the body turns rather than snaps.
func _rounded(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n:
		var prev := points[(i - 1 + n) % n]
		var here := points[i]
		var next := points[(i + 1) % n]
		var a := prev.direction_to(here)
		var b := here.direction_to(next)
		if a.dot(b) > 0.995:
			out.append(here)
			continue
		var cut_in := minf(CORNER, here.distance_to(prev) * 0.5)
		var cut_out := minf(CORNER, here.distance_to(next) * 0.5)
		var p0 := here - a * cut_in
		var p2 := here + b * cut_out
		for k in 7:
			var u := k / 6.0
			out.append(p0.lerp(here, u).lerp(here.lerp(p2, u), u))
	return out


func _surface_normal(a: Vector2, b: Vector2) -> Vector2:
	var d := a.direction_to(b)
	return Vector2(d.y, -d.x)


## Writes the point on the loop and the way out of the surface there.
func pose(s: float) -> void:
	var wrapped := fposmod(s, length)
	var i := clampi(marks.bsearch(wrapped, false) - 1, 0, loop.size() - 1)
	var a := loop[i]
	var b := loop[(i + 1) % loop.size()]
	var span := maxf(marks[i + 1] - marks[i], 0.001)
	at = a.lerp(b, (wrapped - marks[i]) / span)
	normal = _surface_normal(a, b)


## Signed shortest way around the loop from one point to another.
func gap(from_s: float, to_s: float) -> float:
	var ahead := fposmod(to_s - from_s, length)
	return ahead if ahead <= length * 0.5 else ahead - length


## The loop point under a spot on the ground.
func floor_s(x: float) -> float:
	return _s_on_run(x, true, -INF)


## The nearest loop point overhead: ceiling, or the underside of something hanging.
func above_s(x: float, y: float) -> float:
	return _s_on_run(x, false, y)


func _s_on_run(x: float, floor_side: bool, y: float) -> float:
	var best := -1.0
	var best_y := -INF
	for i in loop.size():
		var a := loop[i]
		var b := loop[(i + 1) % loop.size()]
		var runs_right := b.x > a.x
		if runs_right != floor_side or x < minf(a.x, b.x) or x > maxf(a.x, b.x) or a.x == b.x:
			continue
		var u := (x - a.x) / (b.x - a.x)
		var here := lerpf(a.y, b.y, u)
		if not floor_side and here > y:
			continue
		if here > best_y:
			best_y = here
			best = marks[i] + (marks[i + 1] - marks[i]) * u
	if best >= 0.0:
		return best
	return nearest_s(Vector2(x, y if not floor_side else 0.0))


## The loop point closest to anywhere.
func nearest_s(p: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	for i in loop.size():
		var a := loop[i]
		var b := loop[(i + 1) % loop.size()]
		var c := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = marks[i] + a.distance_to(c)
	return best


## Walkable height at x.
func ground_at(x: float) -> float:
	var clamped := clampf(x, 0.0, WIDTH)
	for i in FLOOR_POINTS - 1:
		var a := OUTLINE[i]
		var b := OUTLINE[i + 1]
		if clamped <= b.x:
			return lerpf(a.y, b.y, (clamped - a.x) / (b.x - a.x))
	return 0.0


func contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, polygon)


## First point of the outline along a ray, or INF when nothing is in reach.
func raycast(origin: Vector2, dir: Vector2, reach: float) -> Vector2:
	var end := origin + dir * reach
	var best := Vector2.INF
	var best_d := INF
	var n := polygon.size()
	for i in n:
		var hit: Variant = Geometry2D.segment_intersects_segment(origin, end, polygon[i], polygon[(i + 1) % n])
		if hit == null:
			continue
		var d: float = origin.distance_squared_to(hit)
		if d < best_d:
			best_d = d
			best = hit
	return best


## True when nothing solid stands between two points.
func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := polygon.size()
	for i in n:
		if Geometry2D.segment_intersects_segment(a, b, polygon[i], polygon[(i + 1) % n]) != null:
			return false
	return true


func closest_point(p: Vector2) -> Vector2:
	var best := p
	var best_d := INF
	var n := polygon.size()
	for i in n:
		var c := Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % n])
		var d := c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = c
	return best
