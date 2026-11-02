class_name Depth
extends RefCounted
## Fake 3D for rooms cut open at the front. The play plane is the front of a room and
## its back wall sits deeper, drawn shrunk toward the middle of the screen. Between
## the two run the floor, ceiling and side walls, so a room shows both walls and its
## floor, and they turn as the camera moves. Only the drawing is 3D: gameplay stays
## on the front plane.

## A surface of the room seen from inside: its edge on the front plane and the way
## into the room from it.
class Face:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var inward := Vector2.UP
	var front := Color.WHITE
	var back := Color.BLACK

	func _init(from: Vector2, to: Vector2, into: Vector2, front_col: Color, back_col: Color) -> void:
		a = from
		b = to
		inward = into
		front = front_col
		back = back_col


## Where a front-plane point shows when pushed back to the given scale.
static func project(p: Vector2, cam: Vector2, scale: float) -> Vector2:
	return cam + (p - cam) * scale


static func project_all(points: PackedVector2Array, cam: Vector2, scale: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = cam + (points[i] - cam) * scale
	return out


## Scale a share u of the way back, 0 at the front, 1 at the back wall.
static func scale_at(u: float, back: float) -> float:
	return 1.0 / (1.0 + u * (1.0 / back - 1.0))


## A face shows only when the camera is on the room side of it.
static func faces_camera(f: Face, cam: Vector2) -> bool:
	return f.inward.dot(cam - (f.a + f.b) * 0.5) > 1.0


## Faces nearest the camera cover the ones behind them, so paint those last.
static func sort_far_first(faces: Array[Face], cam: Vector2) -> void:
	faces.sort_custom(func(p: Face, q: Face) -> bool:
		return _reach(p, cam) > _reach(q, cam))


static func _reach(f: Face, cam: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(cam, f.a, f.b).distance_squared_to(cam)


## The quad on screen from the front edge to the back wall.
static func quad(f: Face, cam: Vector2, back: float) -> PackedVector2Array:
	return PackedVector2Array([f.a, f.b, project(f.b, cam, back), project(f.a, cam, back)])


## Paints a face clipped to the room's front opening, shaded from front to back.
static func draw_face(ci: CanvasItem, f: Face, cam: Vector2, back: float, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(quad(f, cam, back), clip):
		if not drawable(piece):
			continue
		var cols := PackedColorArray()
		cols.resize(piece.size())
		for i in piece.size():
			cols[i] = f.front.lerp(f.back, depth_of(piece[i], f, cam, back))
		ci.draw_polygon(piece, cols)


## How far back, 0 to 1, a screen point on a face lies.
static func depth_of(q: Vector2, f: Face, cam: Vector2, back: float) -> float:
	var from_front := f.inward.dot(f.a - cam)
	if absf(from_front) < 0.001:
		return 0.0
	var s := maxf(f.inward.dot(q - cam) / from_front, 0.001)
	return clampf((1.0 / s - 1.0) / (1.0 / back - 1.0), 0.0, 1.0)


## A line drawn on a surface, from front points to their places further back.
static func draw_line_clipped(ci: CanvasItem, from: Vector2, to: Vector2, clip: PackedVector2Array, col: Color, width: float) -> void:
	for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([from, to]), clip):
		ci.draw_polyline(piece, col, width)


## Seams running into the depth of a face, every step along its front edge.
static func draw_seams_in(ci: CanvasItem, f: Face, cam: Vector2, back: float, step: float, clip: PackedVector2Array, col: Color, width: float) -> void:
	var length := f.a.distance_to(f.b)
	var n := int(length / step)
	if n < 1:
		return
	for k in range(1, n + 1):
		var p := f.a.lerp(f.b, k / float(n + 1))
		draw_line_clipped(ci, p, project(p, cam, back), clip, col, width)


## Seams across a face at shares of its depth.
static func draw_seams_across(ci: CanvasItem, f: Face, cam: Vector2, back: float, shares: Array, clip: PackedVector2Array, col: Color, width: float) -> void:
	for u: float in shares:
		var s := scale_at(u, back)
		draw_line_clipped(ci, project(f.a, cam, s), project(f.b, cam, s), clip, col, width)


## A patch on a face: along its front edge from t0 to t1, and into it from depth u0 to u1.
static func patch(f: Face, t0: float, t1: float, u0: float, u1: float, cam: Vector2, back: float) -> PackedVector2Array:
	var p0 := f.a.lerp(f.b, t0)
	var p1 := f.a.lerp(f.b, t1)
	var s0 := scale_at(u0, back)
	var s1 := scale_at(u1, back)
	return PackedVector2Array([project(p0, cam, s0), project(p1, cam, s0), project(p1, cam, s1), project(p0, cam, s1)])


static func draw_clipped(ci: CanvasItem, poly: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
	for piece in Geometry2D.intersect_polygons(poly, clip):
		if drawable(piece):
			ci.draw_colored_polygon(piece, col)


## Clipping a face seen almost edge on can leave slivers the renderer cannot fill.
static func drawable(piece: PackedVector2Array) -> bool:
	return piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty()
