class_name Bug
extends RefCounted
## Plain data for one alien bug. Behaviour lives in Horde so the whole swarm can
## be updated in one tight loop.

enum Kind {WORKER, LEAPER, WARRIOR, BLOATER, CHARGER, ALIEN, ALIEN_BOMBER, ALIEN_LEAPER, ALIEN_STALKER, ALIEN_CHARGER}

## mid is the hit center above the feet, top is the head height. Those with art are built
## on AlienRig, and strike at anything within reach.
const STATS := {
	Kind.WORKER: {"hp": 30.0, "speed": 66.0, "dmg": 7.0, "mid": 14.0, "top": 32.0, "xp": 1, "radius": 15.0},
	Kind.LEAPER: {"hp": 20.0, "speed": 120.0, "dmg": 6.0, "mid": 20.0, "top": 44.0, "xp": 1, "radius": 15.0},
	Kind.WARRIOR: {"hp": 140.0, "speed": 50.0, "dmg": 18.0, "mid": 34.0, "top": 76.0, "xp": 4, "radius": 22.0},
	Kind.BLOATER: {"hp": 25.0, "speed": 85.0, "dmg": 25.0, "mid": 24.0, "top": 52.0, "xp": 2, "radius": 20.0},
	Kind.CHARGER: {"hp": 1400.0, "speed": 55.0, "dmg": 30.0, "mid": 46.0, "top": 96.0, "xp": 20, "radius": 46.0},
	Kind.ALIEN: {"hp": 300.0, "speed": 150.0, "dmg": 16.0, "mid": 32.5, "top": 56.0, "xp": 3, "radius": 24.0, "art": "alien_base", "reach": 78.0},
	Kind.ALIEN_BOMBER: {"hp": 60.0, "speed": 165.0, "dmg": 30.0, "mid": 32.5, "top": 70.0, "xp": 2, "radius": 26.0, "art": "alien_bomber", "reach": 70.0},
	Kind.ALIEN_LEAPER: {"hp": 90.0, "speed": 175.0, "dmg": 14.0, "mid": 32.5, "top": 70.0, "xp": 3, "radius": 24.0, "art": "alien_leaper", "reach": 92.0},
	Kind.ALIEN_STALKER: {"hp": 110.0, "speed": 170.0, "dmg": 22.0, "mid": 32.5, "top": 90.0, "xp": 4, "radius": 26.0, "art": "alien_stalker", "reach": 96.0},
	Kind.ALIEN_CHARGER: {"hp": 900.0, "speed": 85.0, "dmg": 24.0, "mid": 32.5, "top": 170.0, "xp": 20, "radius": 72.0, "art": "alien_charger", "reach": 170.0},
}
const LANES := 4

var kind := Kind.WORKER
var x := 0.0
var f := 0
var h := 0.0
var vx := 0.0
var vh := 0.0
var hp := 30.0
var max_hp := 30.0
var speed := 62.0
var dmg := 7.0
var mid := 14.0
var top := 32.0
var radius := 15.0
var reach := 78.0
var xp := 1
var awake := false
var dead := false
var facing := 1.0
var anim := 0.0
var flash := 0.0
var knock := 0.0
var attack_t := 0.0
## Visual only: which row of the floor band it walks on, so a swarm has thickness.
var lane := 0

var climb_dir := 0
var climb_u := 0.0
var climb_low := 0
## Falling bugs ride a burning meteor shard down to the landing zone.
var falling := false
var fall_speed := 300.0

var leap_cd := 1.0
var windup := 0.0
var airborne := false

var boss_state := 0
var boss_t := 3.0
var charge_dir := 1.0

## The sample alien only: its procedural body and where it is on the arena.
var rig: AlienRig = null


## Where to shoot at it. A rig's body can stand higher than where it really is.
func aim_x() -> float:
	return rig.standing_at().x if rig != null else x


func aim_h() -> float:
	return -rig.standing_at().y if rig != null else h + mid


func setup(k: Kind, hp_scale: float) -> void:
	kind = k
	var s: Dictionary = STATS[k]
	hp = float(s.hp) * hp_scale
	max_hp = hp
	speed = float(s.speed) * randf_range(0.9, 1.1)
	dmg = s.dmg
	mid = s.mid
	top = s.top
	radius = s.radius
	reach = s.get("reach", reach)
	xp = s.xp
	anim = randf() * 10.0
	lane = randi() % LANES
	leap_cd = randf_range(0.5, 2.0)
