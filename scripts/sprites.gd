class_name Sprites
extends RefCounted
## Actor art, painted part by part at startup and drawn at Tuning.pixel_scale.
## Bugs are original designs with the swarm-bug read: low chitin bodies,
## segmented abdomens and glowing orange bile sacs. All face right.

const WALK_FRAMES := 4
const OUTLINE := Color(0.05, 0.03, 0.04)
const CHITIN_D := Color(0.17, 0.09, 0.07)
const CHITIN := Color(0.37, 0.19, 0.10)
const CHITIN_L := Color(0.63, 0.36, 0.14)
const PLATE := Color(0.80, 0.55, 0.24)
const GLOW := Color(1.0, 0.56, 0.10)
const GLOW_HI := Color(1.0, 0.88, 0.40)
const EYE := Color(1.0, 0.18, 0.08)

class Anim:
	var frames: Array[Texture2D] = []
	var flash: Array[Texture2D] = []

var player: Anim
var player_idle: Anim
## bugs[kind] is an Anim with WALK_FRAMES frames.
var bugs: Array[Anim] = []
var shard: Texture2D
var crate: Texture2D
var crate_open: Texture2D
var heli: Texture2D
var blob: Texture2D
var alien: AlienArt
## The rest of the alien kinds, by folder, loaded when first needed.
var aliens: Dictionary = {}


func _init() -> void:
	player = _anim(WALK_FRAMES, _soldier)
	player_idle = _anim(1, func(_phase: float) -> Paint: return _soldier(-1.0))
	bugs = [_anim(WALK_FRAMES, _worker), _anim(WALK_FRAMES, _leaper), _anim(WALK_FRAMES, _warrior), _anim(WALK_FRAMES, _bloater), _anim(WALK_FRAMES, _charger)]
	shard = _shard()
	crate = _crate(false)
	crate_open = _crate(true)
	heli = _heli()
	blob = _radial()
	alien = AlienArt.new()
	aliens[AlienArt.BASE] = alien


func _anim(count: int, painter: Callable) -> Anim:
	var a := Anim.new()
	for i in count:
		var p: Paint = painter.call(TAU * i / count)
		a.frames.append(p.texture())
		a.flash.append(p.flash_texture())
	return a


## Hip to knee to foot for each leg, in a rippling gait. The knee sits above the
## hip, which is what makes a leg read as an insect leg.
func _legs(p: Paint, hips: Array, ground: float, phase: float, reach: float, lift: float, col: Color, thick := 1) -> void:
	var n := hips.size()
	for i in n:
		var hip: Vector2 = hips[i]
		var a := phase + i * TAU / n
		var spread := (i - (n - 1) * 0.5) * reach * 0.8
		var foot := Vector2(hip.x + spread + cos(a) * reach * 0.4, ground - maxf(sin(a), 0.0) * lift)
		var knee := Vector2((hip.x + foot.x) * 0.5 + spread * 0.3, hip.y - lift * 0.7)
		p.line(hip, knee, col, thick)
		p.line(knee, foot, col, thick)


func _worker(phase: float) -> Paint:
	var p := Paint.new(34, 20)
	var hips := [Vector2(13, 12), Vector2(18, 13), Vector2(23, 13)]
	_legs(p, hips, 19.0, phase + PI, 7.0, 2.5, CHITIN_D)
	p.disc(11, 9, 10, 7, CHITIN)
	p.disc(11, 7, 8, 4, CHITIN_L)
	for x in [4, 8, 12, 16, 19]:
		p.band(11, 9, 10, 7, x, CHITIN_D)
	p.disc(7, 12, 4, 2.5, GLOW)
	p.disc(6, 12, 2, 1.2, GLOW_HI)
	p.disc(21, 10, 5, 5, CHITIN)
	p.disc(21, 8, 4, 2.5, PLATE)
	p.disc(27, 12, 4, 3.5, CHITIN_L)
	p.dot(28, 11, EYE)
	p.dot(29, 11, EYE)
	p.line(Vector2(30, 13), Vector2(33, 15), CHITIN_D)
	p.line(Vector2(29, 15), Vector2(32, 17), CHITIN_D)
	_legs(p, hips, 19.0, phase, 7.0, 2.5, CHITIN_L)
	p.outline(OUTLINE)
	return p


func _leaper(phase: float) -> Paint:
	var p := Paint.new(40, 26)
	var hips := [Vector2(14, 14), Vector2(19, 14), Vector2(23, 14)]
	_legs(p, hips, 25.0, phase + PI, 9.0, 6.0, CHITIN_D)
	p.disc(10, 11, 9, 5, CHITIN)
	p.disc(10, 9, 7, 2.5, GLOW)
	for x in [4, 7, 10, 13, 16]:
		p.band(10, 11, 9, 5, x, CHITIN_D)
	p.disc(20, 13, 5, 3.5, CHITIN_L)
	p.disc(27, 12, 3.5, 3, PLATE)
	p.dot(28, 11, EYE)
	p.dot(29, 11, EYE)
	# Raised hook arm, the read of a bug that is about to jump.
	var arm := 1.5 * sin(phase)
	p.line(Vector2(24, 11), Vector2(31, 3 + arm), CHITIN_L, 2)
	p.line(Vector2(31, 3 + arm), Vector2(38, 11 + arm), GLOW_HI)
	_legs(p, hips, 25.0, phase, 9.0, 6.0, CHITIN_L)
	p.outline(OUTLINE)
	return p


func _warrior(phase: float) -> Paint:
	var p := Paint.new(44, 40)
	var hips := [Vector2(11, 28), Vector2(16, 29), Vector2(21, 29)]
	_legs(p, hips, 39.0, phase + PI, 9.0, 4.0, CHITIN_D, 2)
	p.disc(11, 24, 10, 8, CHITIN)
	p.disc(9, 22, 7, 4, CHITIN_L)
	for x in [3, 6, 9, 12, 15, 18]:
		p.band(11, 24, 10, 8, x, CHITIN_D)
	p.disc(7, 27, 4, 3, GLOW)
	p.disc(19, 18, 7, 10, CHITIN)
	p.disc(20, 14, 5.5, 5.5, PLATE)
	p.band(19, 18, 7, 10, 19, CHITIN_D)
	p.line(Vector2(14, 22), Vector2(25, 22), CHITIN_D)
	p.disc(26, 8, 5, 4.5, CHITIN_L)
	p.dot(28, 7, EYE)
	p.dot(29, 7, EYE)
	p.line(Vector2(23, 4), Vector2(21, 0), PLATE, 2)
	p.line(Vector2(30, 10), Vector2(33, 13), CHITIN_D)
	# Scythe arms swing against the walk.
	var swing := 2.0 * sin(phase)
	p.line(Vector2(23, 14), Vector2(33, 10 + swing), CHITIN_L, 3)
	p.line(Vector2(33, 10 + swing), Vector2(41, 25 + swing), PLATE, 2)
	p.line(Vector2(41, 25 + swing), Vector2(42, 28 + swing), GLOW_HI)
	_legs(p, hips, 39.0, phase, 9.0, 4.0, CHITIN_L, 2)
	p.outline(OUTLINE)
	return p


func _bloater(phase: float) -> Paint:
	var p := Paint.new(40, 28)
	var hips := [Vector2(14, 20), Vector2(21, 21), Vector2(26, 21)]
	_legs(p, hips, 27.0, phase + PI, 7.0, 2.5, CHITIN_D, 2)
	var swell := 0.7 * sin(phase)
	p.disc(13, 12, 12 + swell, 11 + swell, GLOW)
	p.disc(11, 10, 7, 6, GLOW_HI)
	for x in [5, 11, 17, 22]:
		p.band(13, 12, 12 + swell, 11 + swell, x, CHITIN)
	p.disc(27, 16, 5, 5, CHITIN)
	p.disc(32, 18, 4, 3.5, CHITIN_L)
	p.dot(33, 17, EYE)
	p.dot(34, 17, EYE)
	p.line(Vector2(35, 20), Vector2(38, 22), CHITIN_D)
	_legs(p, hips, 27.0, phase, 7.0, 2.5, CHITIN_L, 2)
	p.outline(OUTLINE)
	return p


## Armoured head shield in front, glowing sac behind: the tank of the swarm.
func _charger(phase: float) -> Paint:
	var p := Paint.new(80, 50)
	var hips := [Vector2(26, 34), Vector2(38, 36), Vector2(50, 36)]
	_legs(p, hips, 49.0, phase + PI, 14.0, 5.0, CHITIN_D, 4)
	p.disc(13, 28, 12, 11, GLOW)
	p.disc(11, 26, 7, 6, GLOW_HI)
	for x in [4, 9, 14, 19]:
		p.band(13, 28, 12, 11, x, CHITIN)
	p.disc(33, 26, 18, 17, CHITIN)
	p.disc(33, 20, 15, 10, CHITIN_L)
	for x in [20, 26, 32, 38, 44]:
		p.band(33, 26, 18, 17, x, CHITIN_D)
	p.disc(55, 25, 15, 20, CHITIN_L)
	p.disc(56, 20, 12, 14, PLATE)
	p.line(Vector2(46, 12), Vector2(66, 12), CHITIN_L)
	p.line(Vector2(44, 22), Vector2(70, 22), CHITIN_L)
	p.line(Vector2(45, 32), Vector2(69, 32), CHITIN_D)
	p.disc(68, 33, 7, 6, CHITIN)
	p.dot(70, 31, EYE)
	p.dot(71, 31, EYE)
	p.dot(70, 32, EYE)
	p.line(Vector2(72, 36), Vector2(78, 42), PLATE, 2)
	p.line(Vector2(68, 38), Vector2(73, 45), PLATE, 2)
	_legs(p, hips, 49.0, phase, 14.0, 5.0, CHITIN_L, 4)
	p.outline(OUTLINE)
	return p


## Cool armor colors so the hero never gets lost among the warm bugs.
## A negative phase paints the standing pose.
func _soldier(phase: float) -> Paint:
	const ARMOR := Color(0.33, 0.47, 0.58)
	const ARMOR_L := Color(0.55, 0.72, 0.82)
	const DARK := Color(0.14, 0.18, 0.24)
	const BOOT := Color(0.10, 0.11, 0.14)
	var p := Paint.new(30, 38)
	var hip := Vector2(14, 25)
	var stride := 0.0 if phase < 0.0 else sin(phase) * 6.0
	var bob := 0.0 if phase < 0.0 else absf(cos(phase))
	_soldier_leg(p, hip + Vector2(-1, 0), -stride - 1.0, phase, DARK, BOOT)
	p.rect(4, 11, 6, 13, Color(0.28, 0.25, 0.20))
	p.rect(5, 12, 4, 3, Color(0.42, 0.38, 0.30))
	p.rect(9, int(11 - bob), 11, 15, ARMOR)
	p.rect(10, int(12 - bob), 9, 5, ARMOR_L)
	p.rect(10, int(20 - bob), 9, 1, Color(0.95, 0.75, 0.2))
	p.rect(10, 25, 9, 2, DARK)
	_soldier_leg(p, hip + Vector2(2, 0), stride + 1.0, phase, ARMOR, BOOT)
	p.disc(15, 6.5 - bob, 6.5, 6, ARMOR)
	p.disc(14, 4.5 - bob, 5, 3, ARMOR_L)
	p.rect(16, int(5 - bob), 6, 3, Color(0.35, 0.95, 1.0))
	p.rect(20, int(5 - bob), 2, 1, Color(0.85, 1.0, 1.0))
	p.rect(14, int(14 - bob), 5, 8, DARK)
	p.outline(OUTLINE)
	return p


func _soldier_leg(p: Paint, hip: Vector2, stride: float, phase: float, col: Color, boot: Color) -> void:
	var lift := 0.0 if phase < 0.0 else maxf(stride * 0.3, 0.0)
	var foot := Vector2(hip.x + stride, 36.0 - lift)
	var knee := Vector2(hip.x + stride * 0.6 + 1.0, 30.0 - lift * 0.5)
	p.line(hip, knee, col, 3)
	p.line(knee, foot, col, 3)
	p.rect(int(foot.x) - 1, int(foot.y), 6, 2, boot)


func _shard() -> Texture2D:
	var p := Paint.new(26, 26)
	p.disc(13, 14, 11, 10, Color(0.15, 0.11, 0.12))
	p.disc(10, 11, 7, 6, Color(0.27, 0.20, 0.20))
	p.disc(16, 18, 6, 4, Color(0.09, 0.07, 0.09))
	p.line(Vector2(4, 18), Vector2(12, 14), GLOW)
	p.line(Vector2(12, 14), Vector2(10, 7), GLOW)
	p.line(Vector2(12, 14), Vector2(21, 17), GLOW_HI)
	p.outline(OUTLINE)
	return p.texture()


func _crate(opened: bool) -> Texture2D:
	var p := Paint.new(28, 20)
	var body := Color(0.24, 0.27, 0.25) if opened else Color(0.33, 0.38, 0.33)
	p.rect(1, 5, 26, 15, body)
	p.rect(1, 5, 26, 2, body.lightened(0.25))
	p.rect(4, 7, 2, 13, body.darkened(0.3))
	p.rect(22, 7, 2, 13, body.darkened(0.3))
	if opened:
		p.rect(3, 6, 22, 3, Color(0.05, 0.05, 0.06))
		p.line(Vector2(2, 4), Vector2(10, 0), body.lightened(0.15), 2)
	else:
		p.rect(0, 2, 28, 3, body.lightened(0.15))
	p.outline(OUTLINE)
	return p.texture()


func _heli() -> Texture2D:
	const BODY := Color(0.26, 0.31, 0.27)
	var p := Paint.new(116, 46)
	p.line(Vector2(50, 18), Vector2(110, 14), BODY.darkened(0.15), 5)
	p.rect(106, 4, 4, 14, BODY.darkened(0.25))
	p.disc(36, 24, 30, 15, BODY)
	p.disc(36, 18, 26, 7, BODY.lightened(0.15))
	p.disc(13, 22, 9, 9, Color(0.45, 0.72, 0.85))
	p.disc(11, 19, 5, 3, Color(0.75, 0.92, 1.0))
	p.rect(32, 20, 16, 12, Color(0.08, 0.09, 0.09))
	p.rect(34, 3, 6, 8, Color(0.12, 0.12, 0.13))
	p.line(Vector2(20, 38), Vector2(16, 44), Color(0.1, 0.1, 0.1), 2)
	p.line(Vector2(50, 38), Vector2(54, 44), Color(0.1, 0.1, 0.1), 2)
	p.rect(6, 44, 58, 2, Color(0.1, 0.1, 0.1))
	p.outline(OUTLINE)
	return p.texture()


func _radial() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func alien_art(kind: Bug.Kind) -> AlienArt:
	var folder: String = Bug.STATS[kind].art
	if not aliens.has(folder):
		aliens[folder] = AlienArt.new(folder)
	return aliens[folder]
