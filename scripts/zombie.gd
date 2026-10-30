class_name Zombie
extends RefCounted
## Plain data for one zombie. Behaviour lives in Horde so the whole group can be
## updated in one tight loop.

enum Kind {NORMAL, RUNNER, BRUTE, EXPLODER, BOSS}

const STATS := {
	Kind.NORMAL: {"hp": 30.0, "speed": 62.0, "dmg": 7.0, "size": 1.0, "xp": 1, "radius": 16.0},
	Kind.RUNNER: {"hp": 20.0, "speed": 150.0, "dmg": 6.0, "size": 0.9, "xp": 1, "radius": 15.0},
	Kind.BRUTE: {"hp": 140.0, "speed": 50.0, "dmg": 18.0, "size": 1.45, "xp": 4, "radius": 24.0},
	Kind.EXPLODER: {"hp": 25.0, "speed": 85.0, "dmg": 25.0, "size": 1.05, "xp": 2, "radius": 16.0},
	Kind.BOSS: {"hp": 1400.0, "speed": 55.0, "dmg": 30.0, "size": 2.3, "xp": 20, "radius": 38.0},
}

var kind := Kind.NORMAL
var x := 0.0
var z := 0.0
var f := 0
var h := 0.0
var hp := 30.0
var max_hp := 30.0
var speed := 62.0
var dmg := 7.0
var size := 1.0
var radius := 16.0
var xp := 1
var awake := false
var dead := false
var facing := 1.0
var anim := 0.0
var flash := 0.0
var knock := 0.0
var attack_t := 0.0

var climb_dir := 0
var climb_u := 0.0
var climb_low := 0
var falling := false
var fall_speed := 170.0

var boss_state := 0
var boss_t := 3.0
var charge := Vector2.ZERO


func setup(k: Kind, hp_scale: float) -> void:
	kind = k
	var s: Dictionary = STATS[k]
	hp = float(s.hp) * hp_scale
	max_hp = hp
	speed = float(s.speed) * randf_range(0.9, 1.1)
	dmg = s.dmg
	size = s.size
	radius = s.radius
	xp = s.xp
	anim = randf() * 10.0
