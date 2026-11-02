class_name Level
extends RefCounted
## Random map, rebuilt every run. A route is carved across a grid from the first
## column to the landing zone in the last one and never steps left. Side rooms
## then grow off it. Bugs path over the room graph with a next-hop table.

enum Kind {NORMAL, STORE, NEST, GOAL, SAMPLE}

class Room:
	var id := 0
	var f := 0
	var c0 := 0
	var c1 := 0
	var x0 := 0.0
	var x1 := 0.0
	var kind := Kind.NORMAL
	var on_route := false
	var explored := false
	var bright := 0.42
	var wall := Color.GRAY
	var trim := Color.DIM_GRAY
	## How much of the back wall survived: 0 mostly whole, 2 mostly gone.
	var wall_damage := 1
	var window_x := -1.0
	var lamp_x := 0.0
	var flicker := 0.0
	var door_l: Door
	var door_r: Door
	var exits: Array[Step] = []

class Door:
	var f := 0
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
	var low_room: Room
	var high_room: Room

class Prop:
	var x0 := 0.0
	var x1 := 0.0
	var h1 := 0.0
	var kind := 0
	var color := Color.GRAY
	var room: Room

class Crate:
	var x := 0.0
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

const THEMES := [
	{"wall": Color(0.33, 0.27, 0.25), "trim": Color(0.20, 0.15, 0.14)},
	{"wall": Color(0.25, 0.30, 0.31), "trim": Color(0.15, 0.19, 0.21)},
	{"wall": Color(0.29, 0.25, 0.32), "trim": Color(0.17, 0.14, 0.20)},
	{"wall": Color(0.31, 0.29, 0.22), "trim": Color(0.19, 0.17, 0.12)},
]
const FURNITURE := [
	Color(0.36, 0.29, 0.22), Color(0.22, 0.27, 0.30), Color(0.33, 0.21, 0.19),
	Color(0.38, 0.38, 0.36), Color(0.23, 0.29, 0.22),
]
const PROP_KINDS := 4
## The landing zone is one open stretch this many columns wide.
const GOAL_COLS := 2
const CELL_SIDE := 1
const CELL_ROUTE := 2
## Columns the arena's one room spans: Arena.WIDTH is three room widths.
const ARENA_COLS := 3

var t: Tuning
var rooms: Array[Room] = []
var doors: Array[Door] = []
var ladders: Array[Ladder] = []
var props: Array[Prop] = []
var crates: Array[Crate] = []
var grid: Array[Room] = []
var route: Array[int] = []
var start_room: Room
var goal_room: Room
var width := 0.0
var rng := RandomNumberGenerator.new()

var _cells := PackedInt32Array()
var _door_links: Dictionary = {}
var _hall_links: Dictionary = {}
## Lower cell of each ladder, to where it stands across the column (0 to 1).
var _ladder_links: Dictionary = {}


func _init(tuning: Tuning, level_seed: int, arena := false) -> void:
	t = tuning
	rng.seed = level_seed
	width = t.cols * t.room_w
	_cells.resize(t.floors * t.cols)
	grid.resize(t.floors * t.cols)
	if arena:
		_build_arena_room()
		return
	_carve_route()
	_add_side_rooms()
	_merge_halls()
	_build_rooms()
	_build_links()
	_build_furniture()
	_build_crates()


## The test build is one lit room with no doors. Its shape lives in Arena.
func _build_arena_room() -> void:
	width = ARENA_COLS * t.room_w
	_add_room(0, 0, ARENA_COLS - 1)
	start_room = rooms[0]
	goal_room = start_room
	start_room.kind = Kind.SAMPLE
	start_room.bright = 1.0


## Rooms and doors point at each other, so reference counting alone never frees them.
func release() -> void:
	for r in rooms:
		r.door_l = null
		r.door_r = null
		r.exits.clear()


func _cell(f: int, c: int) -> int:
	return f * t.cols + c


func _is_open(f: int, c: int) -> bool:
	return f >= 0 and f < t.floors and c >= 0 and c < t.cols and _cells[_cell(f, c)] != 0


func _open_route(f: int, c: int) -> void:
	_cells[_cell(f, c)] = CELL_ROUTE
	route.append(_cell(f, c))


## Walks one column at a time and may change floor inside a column, so every step
## goes right or straight up or down. Ladders in one column stand in travel order.
func _carve_route() -> void:
	var last := t.cols - GOAL_COLS
	var f := 0
	var climbed := false
	for c in last:
		_open_route(f, c)
		var to_f := f
		if c == last - 1:
			to_f = 0
		elif c > 0 and (rng.randf() < t.route_turn_chance or (c == last - 2 and not climbed)):
			to_f = _next_floor(f)
		climbed = climbed or to_f > f
		var u := rng.randf_range(0.25, 0.4)
		while f != to_f:
			var next := f + signi(to_f - f)
			_open_route(next, c)
			_ladder_links[_cell(mini(f, next), c)] = u
			u += rng.randf_range(0.2, 0.3)
			f = next
		_door_links[_cell(f, c)] = true
	for c in range(last, t.cols):
		_open_route(0, c)
		if c > last:
			_hall_links[_cell(0, c - 1)] = true


func _next_floor(f: int) -> int:
	if f == 0:
		return 1
	if f == t.floors - 1:
		return f - 1
	return f + (1 if rng.randf() < 0.5 else -1)


## Side rooms attach to anything already open. Most are dead ends worth the
## detour; some also open forward and make a second way through.
func _add_side_rooms() -> void:
	var last := t.cols - GOAL_COLS
	for c in range(1, last):
		for f in t.floors:
			if _is_open(f, c) or rng.randf() > t.side_room_chance:
				continue
			var left := _is_open(f, c - 1)
			var below := _is_open(f - 1, c)
			var above := _is_open(f + 1, c)
			if not left and not below and not above:
				continue
			_cells[_cell(f, c)] = CELL_SIDE
			if left:
				_door_links[_cell(f, c - 1)] = true
			elif below:
				_ladder_links[_cell(f - 1, c)] = _side_ladder_u(c)
			else:
				_ladder_links[_cell(f, c)] = _side_ladder_u(c)
			if c + 1 < last and _is_open(f, c + 1) and rng.randf() < 0.6:
				_door_links[_cell(f, c)] = true


## Stands right of every other ladder in the column, so going through two of them
## in a row never means stepping back to the left.
func _side_ladder_u(c: int) -> float:
	var lowest := 0.55
	for f in t.floors - 1:
		lowest = maxf(lowest, float(_ladder_links.get(_cell(f, c), 0.0)) + 0.1)
	return rng.randf_range(lowest, maxf(lowest, 0.85))


func _merge_halls() -> void:
	for f in t.floors:
		for c in range(1, t.cols - GOAL_COLS - 1):
			var cell := _cell(f, c)
			if _door_links.has(cell) and not _hall_links.has(_cell(f, c - 1)) and rng.randf() < t.hall_chance:
				_door_links.erase(cell)
				_hall_links[cell] = true


func _build_rooms() -> void:
	for f in t.floors:
		var c := 0
		while c < t.cols:
			if not _is_open(f, c):
				c += 1
				continue
			var c1 := c
			while _hall_links.has(_cell(f, c1)):
				c1 += 1
			_add_room(f, c, c1)
			c = c1 + 1
	start_room = grid[_cell(0, 0)]
	goal_room = grid[_cell(0, t.cols - 1)]
	goal_room.kind = Kind.GOAL
	goal_room.bright = 0.95
	start_room.kind = Kind.NORMAL


func _add_room(f: int, c0: int, c1: int) -> void:
	var r := Room.new()
	r.id = rooms.size()
	r.f = f
	r.c0 = c0
	r.c1 = c1
	r.x0 = c0 * t.room_w
	r.x1 = (c1 + 1) * t.room_w
	for c in range(c0, c1 + 1):
		grid[_cell(f, c)] = r
		r.on_route = r.on_route or _cells[_cell(f, c)] == CELL_ROUTE
	var roll := rng.randf()
	if not r.on_route:
		r.kind = Kind.STORE if roll < 0.45 else (Kind.NEST if roll < 0.75 else Kind.NORMAL)
	elif c0 >= 3 and roll < 0.15:
		r.kind = Kind.NEST
	var theme: Dictionary = THEMES[rng.randi() % THEMES.size()]
	r.wall = (theme.wall as Color).lightened(rng.randf_range(0.0, 0.06))
	r.trim = theme.trim
	# A nest needs a wall left for the hive to grow on.
	r.wall_damage = rng.randi() % (2 if r.kind == Kind.NEST else 3)
	r.lamp_x = lerpf(r.x0, r.x1, rng.randf_range(0.35, 0.65))
	if r.wall_damage < 2 and rng.randf() < 0.6:
		r.window_x = lerpf(r.x0, r.x1, rng.randf_range(0.3, 0.7))
	r.flicker = rng.randf() * 10.0
	rooms.append(r)


func _build_links() -> void:
	for cell: int in _door_links:
		var c := cell % t.cols
		var d := Door.new()
		d.f = cell / t.cols
		d.x = (c + 1) * t.room_w
		d.room_a = grid[cell]
		d.room_b = grid[cell + 1]
		d.room_a.door_r = d
		d.room_b.door_l = d
		doors.append(d)
		_add_exit(d.room_a, d.room_b, d.x + t.wall_margin + 26.0, d, null, false)
		_add_exit(d.room_b, d.room_a, d.x - t.wall_margin - 26.0, d, null, false)
	for cell: int in _ladder_links:
		var l := Ladder.new()
		l.low_f = cell / t.cols
		l.x = (cell % t.cols + float(_ladder_links[cell])) * t.room_w
		l.low_room = grid[cell]
		l.high_room = grid[cell + t.cols]
		ladders.append(l)
		_add_exit(l.low_room, l.high_room, l.x, null, l, true)
		_add_exit(l.high_room, l.low_room, l.x, null, l, false)


func _add_exit(from: Room, to: Room, x: float, door: Door, ladder: Ladder, going_up: bool) -> void:
	var s := Step.new()
	s.to_room = to.id
	s.door = door
	s.ladder = ladder
	s.going_up = going_up
	s.x = x
	from.exits.append(s)


func _build_furniture() -> void:
	for r in rooms:
		if r.kind == Kind.GOAL:
			continue
		var x := r.x0 + 34.0
		while x < r.x1 - 90.0:
			var w := rng.randf_range(44.0, 92.0)
			var near_ladder := false
			for l in ladders:
				if (l.low_f == r.f or l.low_f == r.f - 1) and absf(l.x - (x + w * 0.5)) < w * 0.5 + 40.0:
					near_ladder = true
			if not near_ladder and rng.randf() < 0.55:
				var p := Prop.new()
				p.x0 = x
				p.x1 = x + w
				p.h1 = rng.randf_range(36.0, 120.0)
				p.kind = rng.randi() % PROP_KINDS
				p.color = FURNITURE[rng.randi() % FURNITURE.size()]
				p.room = r
				props.append(p)
			x += w + rng.randf_range(14.0, 40.0)


## Loot gets better toward the goal and off the route, so detours are a real choice.
func _build_crates() -> void:
	for r in rooms:
		if r == start_room or r.kind == Kind.GOAL:
			continue
		var count := 1 if rng.randf() < 0.7 else 0
		if r.kind == Kind.STORE:
			count = rng.randi_range(2, 3)
		elif r.kind == Kind.NEST:
			count = 1
		for i in count:
			var roll := rng.randf() + progress_at(r.x0) * 0.45
			if not r.on_route:
				roll += 0.2
			if r.kind == Kind.NEST:
				roll += 0.3
			add_crate(r, 2 if roll > 1.0 else (1 if roll > 0.55 else 0))


func add_crate(r: Room, rarity: int) -> Crate:
	var cr := Crate.new()
	cr.room = r
	cr.f = r.f
	cr.x = lerpf(r.x0, r.x1, rng.randf_range(0.18, 0.82))
	cr.rarity = rarity
	crates.append(cr)
	return cr


## 0 at the start of the map, 1 at the far end.
func progress_at(x: float) -> float:
	return clampf(x / width, 0.0, 1.0)


func room_in_cell(f: int, c: int) -> Room:
	return grid[_cell(f, c)]


func col_at(x: float) -> int:
	return clampi(int(x / t.room_w), 0, t.cols - 1)


## A point just past an outer wall counts as the nearest room on that floor.
func room_at(f: int, x: float) -> Room:
	var c := col_at(x)
	var r := grid[_cell(f, c)]
	if r != null:
		return r
	for d in range(1, t.cols):
		for side: int in [c - d, c + d]:
			if side >= 0 and side < t.cols and grid[_cell(f, side)] != null:
				return grid[_cell(f, side)]
	return start_room


func door_passable(d: Door) -> bool:
	return d.broken or d.open > 0.55


## Clamps a horizontal move against walls and closed doors.
func resolve_x(f: int, from_x: float, to_x: float) -> float:
	var m := t.wall_margin
	var r := room_at(f, from_x)
	var lo := r.x0 + m
	var hi := r.x1 - m
	if r.door_l != null and door_passable(r.door_l):
		lo = r.x0 - m
	if r.door_r != null and door_passable(r.door_r):
		hi = r.x1 + m
	return clampf(to_x, lo, hi)


## True when nothing but open doors stands between two points on a floor.
func clear_line(f: int, x0: float, x1: float) -> bool:
	var r := room_at(f, minf(x0, x1))
	var end := room_at(f, maxf(x0, x1))
	while r != end:
		if r.door_r == null or not door_passable(r.door_r):
			return false
		r = r.door_r.room_b
	return true


## True when a solid wall, which no door pierces, stands between two points.
func walled_off(f: int, x0: float, x1: float) -> bool:
	var r := room_at(f, minf(x0, x1))
	var end := room_at(f, maxf(x0, x1))
	while r != end:
		if r.door_r == null:
			return true
		r = r.door_r.room_b
	return false


func ladder_up_near(f: int, x: float, reach: float) -> Ladder:
	for l in ladders:
		if l.low_f == f and absf(x - l.x) < reach:
			return l
	return null


func ladder_down_near(f: int, x: float, reach: float) -> Ladder:
	for l in ladders:
		if l.low_f == f - 1 and absf(x - l.x) < reach:
			return l
	return null


## Breadth-first search outward from the target. Result[room id] is the Step to
## take from that room, or null for the target room itself.
func build_field(target: int) -> Array:
	var field: Array = []
	field.resize(rooms.size())
	var seen: Dictionary = {target: true}
	var queue: Array[int] = [target]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for out in rooms[cur].exits:
			if seen.has(out.to_room):
				continue
			seen[out.to_room] = true
			field[out.to_room] = _step_between(out.to_room, cur)
			queue.append(out.to_room)
	return field


func _step_between(from_id: int, to_id: int) -> Step:
	for s in rooms[from_id].exits:
		if s.to_room == to_id:
			return s
	return null
