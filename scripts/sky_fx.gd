class_name SkyFx
extends Node2D
## Meteors falling far behind the city. Lives in its own slow parallax layer, in
## local coordinates where y = 0 is the horizon. Waves call shower(); the intro
## calls fall_big() for the impact that started it all.

signal big_landed

const BIG_TIME := 2.2
const BIG_FROM := Vector2(900.0, -1050.0)
const BIG_TO := Vector2(420.0, -186.0)

class Streak:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var size := 3.0

class Flash:
	var pos := Vector2.ZERO
	var life := 0.0
	var max_life := 0.6
	var radius := 90.0

var blob: Texture2D
var streaks: Array[Streak] = []
var flashes: Array[Flash] = []
var big_t := -1.0
var ambient_t := 3.0
var ambient_on := false
var rng := RandomNumberGenerator.new()


func setup(art: Sprites) -> void:
	blob = art.blob
	rng.randomize()


func shower(count: int) -> void:
	for i in count:
		var s := Streak.new()
		s.pos = Vector2(rng.randf_range(200.0, 1000.0), -1000.0 - rng.randf_range(0.0, 500.0))
		s.vel = Vector2(rng.randf_range(-420.0, -240.0), rng.randf_range(780.0, 1000.0))
		s.size = rng.randf_range(2.0, 5.0)
		streaks.append(s)


func fall_big() -> void:
	big_t = 0.0


func _process(dt: float) -> void:
	if ambient_on:
		ambient_t -= dt
		if ambient_t <= 0.0:
			ambient_t = rng.randf_range(4.0, 9.0)
			shower(1)
	if big_t >= 0.0:
		big_t += dt
		if big_t >= BIG_TIME:
			big_t = -1.0
			_flash(BIG_TO, 620.0, 1.4)
			big_landed.emit()
	var i := streaks.size() - 1
	while i >= 0:
		var s := streaks[i]
		s.pos += s.vel * dt
		if s.pos.y >= -10.0:
			_flash(s.pos, 40.0 + s.size * 24.0, 0.5)
			streaks.remove_at(i)
		i -= 1
	i = flashes.size() - 1
	while i >= 0:
		flashes[i].life -= dt
		if flashes[i].life <= 0.0:
			flashes.remove_at(i)
		i -= 1
	queue_redraw()


func _flash(pos: Vector2, radius: float, life: float) -> void:
	var f := Flash.new()
	f.pos = pos
	f.radius = radius
	f.life = life
	f.max_life = life
	flashes.append(f)


func _draw() -> void:
	for s in streaks:
		var tail := s.pos - s.vel * 0.16
		draw_line(tail, s.pos, Color(1.0, 0.42, 0.12, 0.45), s.size * 2.4)
		draw_line(tail.lerp(s.pos, 0.5), s.pos, Color(1.0, 0.75, 0.3, 0.9), s.size)
		draw_circle(s.pos, s.size, Color(1.0, 0.95, 0.75))
	if big_t >= 0.0:
		_draw_big(clampf(big_t / BIG_TIME, 0.0, 1.0))
	for f in flashes:
		var a := f.life / f.max_life
		var size := Vector2.ONE * f.radius * 2.0 * (1.4 - a * 0.4)
		draw_texture_rect(blob, Rect2(f.pos - size * 0.5, size), false, Color(1.0, 0.72, 0.35, a))


func _draw_big(u: float) -> void:
	var pos := BIG_FROM.lerp(BIG_TO, u * u)
	var dir := (BIG_TO - BIG_FROM).normalized()
	var r := lerpf(26.0, 120.0, u)
	var tail := pos - dir * (r * 8.0)
	var halo := Vector2.ONE * r * 5.0
	draw_texture_rect(blob, Rect2(pos - halo * 0.5, halo), false, Color(1.0, 0.5, 0.15, 0.7))
	draw_line(tail, pos, Color(1.0, 0.36, 0.08, 0.5), r * 1.9)
	draw_line(tail.lerp(pos, 0.45), pos, Color(1.0, 0.6, 0.15, 0.85), r * 1.2)
	draw_line(tail.lerp(pos, 0.75), pos, Color(1.0, 0.92, 0.55), r * 0.6)
	draw_circle(pos, r, Color(0.16, 0.11, 0.12))
	draw_circle(pos + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(0.28, 0.20, 0.20))
	draw_arc(pos, r, 0.0, TAU, 40, Color(1.0, 0.7, 0.25), maxf(r * 0.1, 2.0), true)
