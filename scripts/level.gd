class_name Level
extends RefCounted
## Building layout: rooms, doors, ladders, furniture, crates, and path finding
## over the room graph. Zombies use a next-hop table instead of a nav mesh.

const BUCKETS := 16

class Room:
	var id := 0
	var f := 0
	var c := 0
	var x0 := 0.0
	var x1 := 0.0
	var explored := false
	var bright := 0.16
	var wall := Color.GRAY
	var trim := Color.DIM_GRAY
	var floor_a := Color.GRAY
	var floor_b := Color.DIM_GRAY
	var window_x := -1.0
	var lamp_x := 0.0
	var flicker := 0.0

class Door:
	var f := 0
	var c := 0
	var x := 0.0
	var open := 0.0
	var hp := 60.0
	var max_hp := 60.0
	var broken := false
	var room_a: Room
	var room_b: Room

class Ladder:
	var low_f := 0
	var x := 0.0
	var z := 0.0
	var low_room: Room
	var high_room: Room

class Prop:
	var x0 := 0.0
	var x1 := 0.0
	var z0 := 0.0
	var z1 := 0.0
	var h0 := 0.0
	var h1 := 0.0
	var color := Color.GRAY
	var room: Room
	var room2: Room

class Crate:
	var x := 0.0
	var z := 0.0
	var f := 0
	var room: Room
	var progress := 0.0
	var opened := false
	var rarity := 0

## One step of a route: how to leave a room toward the next room.
class Step:
	var to_room := 0
	var door: Door
	var ladder: Ladder
	var going_up := false
	var x := 0.0
	var z := 0.0

const THEMES := [
	{"wall": Color(0.46, 0.36, 0.30), "trim": Color(0.28, 0.20, 0.17), "a": Color(0.42, 0.31, 0.23), "b": Color(0.36, 0.26, 0.19)},
	{"wall": Color(0.36, 0.48, 0.50), "trim": Color(0.20, 0.32, 0.36), "a": Color(0.42, 0.50, 0.50), "b": Color(0.36, 0.44, 0.45)},
	{"wall": Color(0.40, 0.32, 0.50), "trim": Color(0.22, 0.17, 0.32), "a": Color(0.30, 0.28, 0.36), "b": Color(0.26, 0.24, 0.31)},
]
const FURNITURE := [
	Color(0.55, 0.45, 0.32), Color(0.30, 0.38, 0.44), Color(0.50, 0.30, 0.28),
	Color(0.62, 0.62, 0.58), Color(0.32, 0.42, 0.30),
]

var t: Tuning
var rooms: Array[Room] = []
var doors: Array[Door] = []
var ladders: Array[Ladder] = []
var crates: Array[Crate] = []
## statics[f][bucket] holds Prop and Door objects, far buckets at high indices.
var statics: Array = []
var width := 0.0
var roof_id := 0
var rng := RandomNumberGenerator.new()


func _init(tuning: Tuning, level_seed: int) -> void:
	t = tuning
	rng.seed = level_seed
	width = t.cols * t.room_w
	roof_id = t.floors * t.cols
	_build_rooms()
	_build_ladders()
	_build_walls_and_doors()
	_build_furniture()
	_build_crates()


func _build_rooms() -> void:
	for f in t.floors:
		var theme: Dictionary = THEMES[f % THEMES.size()]
		for c in t.cols:
			var r := Room.new()
			r.id = f * t.cols + c
			r.f = f
			r.c = c
			r.x0 = c * t.room_w
			r.x1 = r.x0 + t.room_w
			var tint := rng.randf_range(0.0, 0.06)
			r.wall = (theme.wall as Color).lightened(tint)
			r.trim = theme.trim
			r.floor_a = theme.a
			r.floor_b = theme.b
			r.lamp_x = r.x0 + t.room_w * rng.randf_range(0.35, 0.65)
			if rng.randf() < 0.7:
				r.window_x = r.x0 + t.room_w * rng.randf_range(0.25, 0.75)
			r.flicker = rng.randf() * 10.0
			rooms.append(r)
	var roof := Room.new()
	roof.id = roof_id
	roof.f = t.floors
	roof.x1 = width
	roof.bright = 0.9
	rooms.append(roof)
	statics.resize(t.floors + 1)
	for f in t.floors + 1:
		var slices: Array = []
		slices.resize(BUCKETS)
		for i in BUCKETS:
			slices[i] = []
		statics[f] = slices


func _build_ladders() -> void:
	# Ladders alternate sides so reaching the roof crosses every floor.
	for f in t.floors:
		var c: int = t.cols - 1 if f % 2 == 0 else 0
		var l := Ladder.new()
		l.low_f = f
		l.x = (c + 0.5) * t.room_w
		l.z = t.depth * 0.84
		l.low_room = room(f, c)
		l.high_room = rooms[roof_id] if f == t.floors - 1 else room(f + 1, c)
		ladders.append(l)


func _build_walls_and_doors() -> void:
	var dz0 := t.depth * 0.22
	var dz1 := t.depth * 0.78
	for f in t.floors:
		_add_wall(f, -16.0, 0.0, 0.0, t.depth, 0.0, t.room_h + t.slab, room(f, 0), null)
		_add_wall(f, width, width + 16.0, 0.0, t.depth, 0.0, t.room_h + t.slab, room(f, t.cols - 1), null)
		for c in t.cols - 1:
			var x := (c + 1) * t.room_w
			var a := room(f, c)
			var b := room(f, c + 1)
			_add_wall(f, x - 8.0, x + 8.0, 0.0, dz0, 0.0, t.room_h + t.slab, a, b)
			_add_wall(f, x - 8.0, x + 8.0, dz1, t.depth, 0.0, t.room_h + t.slab, a, b)
			_add_wall(f, x - 8.0, x + 8.0, dz0, dz1, t.door_height, t.room_h + t.slab, a, b)
			var d := Door.new()
			d.f = f
			d.c = c
			d.x = x
			d.room_a = a
			d.room_b = b
			doors.append(d)
			statics[f][bucket_of(t.depth * 0.5)].append(d)


func _add_wall(f: int, x0: float, x1: float, z0: float, z1: float, h0: float, h1: float, a: Room, b: Room) -> void:
	var p := Prop.new()
	p.x0 = x0
	p.x1 = x1
	p.z0 = z0
	p.z1 = z1
	p.h0 = h0
	p.h1 = h1
	p.color = a.trim.lightened(0.12)
	p.room = a
	p.room2 = b
	statics[f][bucket_of((z0 + z1) * 0.5)].append(p)


func _build_furniture() -> void:
	# Furniture hugs the back wall so the middle of the floor stays a clear lane.
	for r in rooms:
		if r.id == roof_id:
			continue
		var x := r.x0 + 34.0
		while x < r.x1 - 90.0:
			var w := rng.randf_range(44.0, 92.0)
			var near_ladder := false
			for l in ladders:
				if (l.low_f == r.f or l.low_f == r.f - 1) and absf(l.x - (x + w * 0.5)) < w * 0.5 + 40.0:
					near_ladder = true
			if not near_ladder and rng.randf() < 0.65:
				var p := Prop.new()
				p.x0 = x
				p.x1 = x + w
				p.z1 = t.depth - 6.0
				p.z0 = p.z1 - rng.randf_range(26.0, 44.0)
				p.h1 = rng.randf_range(36.0, 120.0)
				p.color = FURNITURE[rng.randi() % FURNITURE.size()]
				p.room = r
				statics[r.f][bucket_of((p.z0 + p.z1) * 0.5)].append(p)
			x += w + rng.randf_range(14.0, 40.0)
	# Low walls around the roof give it edges against the sky.
	var f := t.floors
	var roof := rooms[roof_id]
	_add_roof_edge(f, 0.0, width, t.depth - 8.0, t.depth, roof)
	_add_roof_edge(f, -12.0, 0.0, 0.0, t.depth, roof)
	_add_roof_edge(f, width, width + 12.0, 0.0, t.depth, roof)


func _add_roof_edge(f: int, x0: float, x1: float, z0: float, z1: float, roof: Room) -> void:
	var p := Prop.new()
	p.x0 = x0
	p.x1 = x1
	p.z0 = z0
	p.z1 = z1
	p.h1 = 34.0
	p.color = Color(0.34, 0.33, 0.36)
	p.room = roof
	statics[f][bucket_of((z0 + z1) * 0.5)].append(p)


func _build_crates() -> void:
	for r in rooms:
		if r.id == roof_id or r.id == 1:
			continue
		var count := 1 if rng.randf() < 0.6 else 2
		for i in count:
			# Rarer loot sits deeper in the building.
			var roll := rng.randf() + r.f * 0.22
			add_crate(r, 2 if roll > 1.0 else (1 if roll > 0.55 else 0))


func add_crate(r: Room, rarity: int) -> Crate:
	var cr := Crate.new()
	cr.room = r
	cr.f = r.f
	cr.x = r.x0 + t.room_w * rng.randf_range(0.18, 0.82)
	cr.z = t.depth * rng.randf_range(0.2, 0.6)
	cr.rarity = rarity
	crates.append(cr)
	return cr


func bucket_of(z: float) -> int:
	return clampi(int(z / t.depth * BUCKETS), 0, BUCKETS - 1)


func room(f: int, c: int) -> Room:
	return rooms[f * t.cols + c]


func col_at(x: float) -> int:
	return clampi(int(x / t.room_w), 0, t.cols - 1)


func room_at(f: int, x: float) -> Room:
	if f >= t.floors:
		return rooms[roof_id]
	return rooms[f * t.cols + col_at(x)]


func door_at(f: int, c: int) -> Door:
	return doors[f * (t.cols - 1) + c]


func door_z_ok(z: float) -> bool:
	return z > t.depth * 0.22 and z < t.depth * 0.78


func door_passable(d: Door, z: float) -> bool:
	return door_z_ok(z) and (d.broken or d.open > 0.55)


## Clamps a horizontal move against walls and closed doors.
func resolve_x(f: int, from_x: float, to_x: float, z: float) -> float:
	var m := t.wall_margin
	if f >= t.floors:
		return clampf(to_x, m, width - m)
	var c := col_at(from_x)
	var lo := c * t.room_w + m
	var hi := (c + 1) * t.room_w - m
	if c > 0 and door_passable(door_at(f, c - 1), z):
		lo = c * t.room_w - m
	if c < t.cols - 1 and door_passable(door_at(f, c), z):
		hi = (c + 1) * t.room_w + m
	return clampf(to_x, lo, hi)


## Keeps depth on the floor, and inside the door frame while standing in a wall.
func resolve_z(f: int, x: float, to_z: float) -> float:
	var z := clampf(to_z, 10.0, t.depth - 12.0)
	if f >= t.floors:
		return z
	var nearest := roundf(x / t.room_w) * t.room_w
	if nearest > 0.0 and nearest < width and absf(x - nearest) < t.wall_margin:
		z = clampf(z, t.depth * 0.22 + 1.0, t.depth * 0.78 - 1.0)
	return z


func ladder_up(f: int) -> Ladder:
	return ladders[f] if f < ladders.size() else null


func ladder_down(f: int) -> Ladder:
	return ladders[f - 1] if f > 0 and f - 1 < ladders.size() else null


func neighbours(id: int) -> Array[int]:
	var out: Array[int] = []
	var r := rooms[id]
	if id != roof_id:
		if r.c > 0:
			out.append(id - 1)
		if r.c < t.cols - 1:
			out.append(id + 1)
	for l in ladders:
		if l.low_room.id == id:
			out.append(l.high_room.id)
		elif l.high_room.id == id:
			out.append(l.low_room.id)
	return out


## Breadth-first search outward from the target. Result[room id] is the Step to
## take from that room, or null for the target room itself.
func build_field(target: int) -> Array:
	var field: Array = []
	field.resize(rooms.size())
	var seen: Dictionary = {target: true}
	var queue: Array[int] = [target]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for n in neighbours(cur):
			if seen.has(n):
				continue
			seen[n] = true
			field[n] = _make_step(n, cur)
			queue.append(n)
	return field


func _make_step(from_id: int, to_id: int) -> Step:
	var a := rooms[from_id]
	var b := rooms[to_id]
	var s := Step.new()
	s.to_room = to_id
	if a.f == b.f and from_id != roof_id and to_id != roof_id:
		s.door = door_at(a.f, mini(a.c, b.c))
		s.x = s.door.x + (t.wall_margin + 26.0) * signf(b.c - a.c)
		s.z = t.depth * 0.5
	else:
		for l in ladders:
			if (l.low_room == a and l.high_room == b) or (l.low_room == b and l.high_room == a):
				s.ladder = l
				s.going_up = l.low_room == a
				s.x = l.x
				s.z = l.z
	return s
