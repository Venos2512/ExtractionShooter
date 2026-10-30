class_name Effects
extends RefCounted
## Short-lived feedback: particles, floor decals, damage numbers, glows, shake.
## Everything keeps a depth value so it scales and sorts with the fake 3D.

const MAX_PARTICLES := 320
const MAX_DECALS_PER_FLOOR := 90
const MAX_NUMBERS := 30

class Particle:
	var x := 0.0
	var z := 0.0
	var h := 0.0
	var f := 0
	var vx := 0.0
	var vz := 0.0
	var vh := 0.0
	var life := 0.0
	var max_life := 1.0
	var color := Color.WHITE
	var size := 3.0
	var gravity := 900.0

class FloorMark:
	var x := 0.0
	var z := 0.0
	var r := 10.0
	var color := Color.WHITE

class Number:
	var x := 0.0
	var z := 0.0
	var h := 0.0
	var f := 0
	var life := 0.0
	var text := ""
	var color := Color.WHITE
	var size := 22

class Glow:
	var x := 0.0
	var z := 0.0
	var h := 0.0
	var f := 0
	var radius := 40.0
	var color := Color.WHITE
	var life := 0.0
	var max_life := 0.1
	var squash := 1.0

var t: Tuning
var particles: Array[Particle] = []
var decals: Array = []
var numbers: Array[Number] = []
var glows: Array[Glow] = []
var trauma := 0.0
var shake_offset := Vector2.ZERO
var noise_t := 0.0
var rng := RandomNumberGenerator.new()


func _init(tuning: Tuning) -> void:
	t = tuning
	rng.randomize()
	decals.resize(t.floors + 1)
	for f in t.floors + 1:
		decals[f] = []


func add_trauma(amount: float, cap := 1.0) -> void:
	# Small shakes never stack past their cap, so firing cannot blur the screen.
	if trauma < cap:
		trauma = minf(trauma + amount, cap)


func spray(x: float, h: float, z: float, f: int, count: int, color: Color, speed: float, size := 3.0, gravity := 900.0) -> void:
	for i in count:
		if particles.size() >= MAX_PARTICLES:
			return
		var p := Particle.new()
		p.x = x
		p.h = h
		p.z = z
		p.f = f
		var a := rng.randf() * TAU
		var v := rng.randf_range(0.3, 1.0) * speed
		p.vx = cos(a) * v
		p.vz = sin(a) * v * 0.6
		p.vh = rng.randf_range(0.2, 1.0) * speed
		p.life = rng.randf_range(0.25, 0.6)
		p.max_life = p.life
		p.color = color
		p.size = size * rng.randf_range(0.7, 1.3)
		p.gravity = gravity
		particles.append(p)


func shell(x: float, h: float, z: float, f: int, dir: float) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	var p := Particle.new()
	p.x = x
	p.h = h
	p.z = z
	p.f = f
	p.vx = -dir * rng.randf_range(60.0, 130.0)
	p.vz = rng.randf_range(-30.0, 30.0)
	p.vh = rng.randf_range(120.0, 220.0)
	p.life = 0.5
	p.max_life = 0.5
	p.color = Color(0.92, 0.76, 0.32)
	p.size = 2.5
	particles.append(p)


func decal(x: float, z: float, f: int, r: float, color: Color) -> void:
	var list: Array = decals[f]
	if list.size() >= MAX_DECALS_PER_FLOOR:
		list.pop_front()
	var d := FloorMark.new()
	d.x = x
	d.z = clampf(z, 4.0, t.depth - 4.0)
	d.r = r
	d.color = color
	list.append(d)


func number(x: float, h: float, z: float, f: int, text: String, color: Color, size := 22) -> void:
	if numbers.size() >= MAX_NUMBERS:
		numbers.pop_front()
	var n := Number.new()
	n.x = x + rng.randf_range(-12.0, 12.0)
	n.h = h
	n.z = z
	n.f = f
	n.text = text
	n.color = color
	n.size = size
	n.life = t.number_time
	numbers.append(n)


func glow(x: float, h: float, z: float, f: int, radius: float, color: Color, life: float, squash := 1.0) -> void:
	var g := Glow.new()
	g.x = x
	g.h = h
	g.z = z
	g.f = f
	g.radius = radius
	g.color = color
	g.life = life
	g.max_life = life
	g.squash = squash
	glows.append(g)


func update(dt: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var p := particles[i]
		p.life -= dt
		if p.life <= 0.0:
			particles.remove_at(i)
		else:
			p.vh -= p.gravity * dt
			p.h += p.vh * dt
			p.x += p.vx * dt
			p.z = clampf(p.z + p.vz * dt, 2.0, t.depth - 2.0)
			if p.h < 0.0:
				p.h = 0.0
				p.vh *= -0.4
				p.vx *= 0.6
				p.vz *= 0.6
		i -= 1
	i = numbers.size() - 1
	while i >= 0:
		numbers[i].life -= dt
		numbers[i].h += 70.0 * dt
		if numbers[i].life <= 0.0:
			numbers.remove_at(i)
		i -= 1
	i = glows.size() - 1
	while i >= 0:
		glows[i].life -= dt
		if glows[i].life <= 0.0:
			glows.remove_at(i)
		i -= 1


## Runs even during hitstop so the camera keeps moving through the freeze.
func update_shake(dt: float) -> void:
	noise_t += dt * 40.0
	var amount := trauma * trauma * t.shake_max
	shake_offset = Vector2(sin(noise_t * 1.3) + sin(noise_t * 2.9), cos(noise_t * 1.7) + sin(noise_t * 3.3)) * 0.5 * amount
	trauma = maxf(trauma - dt * 2.2, 0.0)
