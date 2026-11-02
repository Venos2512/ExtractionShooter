class_name AlienRig
extends RefCounted
## The sample alien from Figma on procedural bones, crawling a loop just inside the
## arena's outline. Nothing is keyframed. Each of the four feet stays planted until the
## body has moved too far from it, then steps to a new hold. The two weapon arms never
## touch a surface. Behaviour lives in Horde, which only sets state, s and the pose
## inputs here. pos is where the alien really is, for hits and for foot holds. What is
## drawn follows it through SecondOrder, which is where the inertia comes from.

enum State {IDLE, CRAWL, WINDUP, STRIKE, RECOVER, LEAP, DEAD, BRACE, CHARGE, STUN}
enum Dart {STOP, JUKE, BOLT}

## Size on screen against the Figma drawing.
const SCALE := 1.3
## Height of the body over a surface: thorax to ground in the drawing. Matches the
## alien's mid in Bug.STATS.
const RIDE := 25.0 * SCALE
const STRIDE := 18.0
const STEP_TIME := 0.13
const LIFT := 14.0
const FORCE_STEP := 90.0
const LOOKAHEAD := 0.06
## A long stride looks further ahead for its holds. This many tries, each less far, to
## find one the leg can reach.
const LONG_STRIDE_TRIES := 3
## A foot takes a hold only this far out, as a share of the leg's full length.
const HOLD_REACH := 0.9
## A ray may land this much further than the stance's own distance before it is ignored.
const RAY_STRETCH := 1.4
## A planted foot this far out, as a share of the leg, steps even out of turn.
const MUST_STEP := 0.92
## That is judged where the hip will be this many seconds from now, or a fast body would
## be past the foot's reach before it even left.
const MUST_STEP_AHEAD := 0.03
## A planted foot this far above the hips, on the back side of the body, has been left
## behind by a turn. No real leg holds on there, so it steps even out of turn.
const BEHIND_BACK := 6.0
const CROUCH_PX := 8.0
const TUCK := 26.0
## It must want to face the other way this long before it turns. Turning makes every
## foot change sides, so a small change of direction should not cause one.
const TURN_DELAY := 0.3
## Each far leg takes its bone lengths from the near leg on the same end of the body.
## Its sprites stretch along the bone to fit, so the Figma drawing can stay as it is.
const SAME_LENGTH_AS := {"leg_rear_far": "leg_rear_near", "leg_front_far": "leg_front_near"}
## Turning around, each foot goes to the leg opposite it, at the same depth.
const OPPOSITE_LEG := {"leg_rear_near": "leg_front_near", "leg_rear_far": "leg_front_far"}
const STEP_STATE: Array[String] = ["foot", "from", "to", "u", "step_lift", "step_time", "lift"]
## Legs that step together. Two diagonal pairs.
const GROUPS := {"leg_rear_near": 0, "leg_front_far": 0, "leg_rear_far": 1, "leg_front_near": 1}
## How far each forelimb joint turns, in radians, by the kind of forelimb: raised to wind
## up, thrown out to strike, folded in death, and how hard it thrashes on the run. A guard
## takes each arm to its own place, one shield high and one low, closing off the front.
const ARM_POSES := {
	"claws": {"raise": [-0.65, -0.25, 0.3], "swipe": [0.85, 0.3, -0.2], "curl": [-0.45, -1.3, -1.3], "thrash": 1.0},
	"scythe": {"raise": [-0.3, -0.7, -1.2], "swipe": [0.7, 0.9, 0.75], "curl": [-0.4, -1.1, -1.4], "thrash": 0.7},
	"shield": {
		"raise": [-0.3, -0.35, -0.45], "swipe": [0.6, 0.4, 0.5], "curl": [-0.2, -0.5, -0.5], "thrash": 0.15,
		"guard": {"weapon_near": [-0.37, 0.19, -1.17], "weapon_far": [0.35, 0.23, 2.0]},
	},
}
const ARM_SWAY := 0.05
const ARM_SWAY_IDLE := 0.13
const STRIKE_LUNGE_PX := 12.0
const BREATH_PX := 1.8
const FIDGET_MIN := 1.6
const FIDGET_MAX := 3.6
const FIDGET_LIFT := 0.5
## Death: how low the body settles, how far the legs fold, and when it fades.
const DEAD_RIDE := RIDE * 0.42
const LEG_CURL := 0.42
## Held closer than this to a surface, it turns its back to that surface.
const HOLD_SENSE := 110.0
## A joint shut tighter than this looks folded flat against itself. Well under the standing
## pose, whose tall arched legs are narrow at the knee and should stay that way.
const TIGHT_KNEE := deg_to_rad(25.0)
const TIGHT_ANKLE := deg_to_rad(25.0)
## The shin holds its lean unless a joint would shut or the ankle fall out of reach. Then it
## gives way, looking in steps this big, at most this many each way, then narrowing it
## down so the answer moves smoothly as the foot does.
const SHIN_SEARCH_STEP := deg_to_rad(15.0)
const SHIN_SEARCH_STEPS := 12
const SHIN_REFINE := 5
## Going down a leg, the knee and the ankle turn the same way, as they do in the drawing.
## The ankle may never turn against that: a shin folded backward is the one pose this
## rig must not show. It always keeps at least this much of a turn.
const SHIN_MIN_BEND := deg_to_rad(5.0)
## A try that scores this low or lower breaks that rule, or cannot reach.
const FORBIDDEN := -10.0
## In the air the claw curls in under the ankle by this much, in radians, until it stabs.
const SHIN_TUCK := 0.35
## How much a knee leans out to its own end of the body, against rising straight up,
## when working out which way its hinge folds from the standing pose.
const KNEE_OUT := 0.8
const DEATH_TWITCH_UNTIL := 0.55
const FADE_FROM := 1.15
const FADE_TO := 1.65
## How quickly it fades in when it appears, per second.
const APPEAR_SPEED := 4.0
const DEAD_TILT := 0.2
## What is drawn may trail the real position by this much at most. Hits use the real
## one, so a fast leap must not leave the picture far behind what can hurt the hero.
const MAX_BODY_LAG := 48.0
## How far the head may turn from the body, and the abdomen hang from it, in radians.
const HEAD_LIMIT := 0.5
const ABDOMEN_LIMIT := 0.45
const HEAD_LOOK := 0.12
const ABDOMEN_BREATH := 0.05
## The abdomen drags up a little with speed, in radians per pixel per second.
const ABDOMEN_DRAG := 0.0005
const ABDOMEN_DRAG_MAX := 0.12
## How much of a longer leg goes into standing taller, the rest being wider feet.
const RISE_SHARE := 0.5

# Frenzy. All of it scales with the frenzy var, and at 0 none of it happens.
## Crawling at this speed counts as flat out.
const FULL_TILT := 380.0
## It does not walk. It bolts at this many times its base speed, stops dead, and bolts again.
const BOLT_MIN := 2.2
const BOLT_MAX := 3.4
const BOLT_TIME_MIN := 0.16
const BOLT_TIME_MAX := 0.5
const STOP_TIME_MIN := 0.07
const STOP_TIME_MAX := 0.34
## Now and then a stop lasts longer, as if it were listening.
const LISTEN_CHANCE := 0.18
const LISTEN_TIME := 0.55
## Some bolts start with a jerk backward, as if it had changed its mind.
const JUKE_CHANCE := 0.3
const JUKE_PACE := -1.6
const JUKE_TIME := 0.11
## How quickly its speed changes, in multiples of base speed per second.
const PACE_SNAP := 34.0
const DRIVE_RISE := 12.0
const DRIVE_FALL := 6.0
## How part of a step changes flat out: shorter in time, higher, longer. Each step also
## differs from the last by this share, so the gait never reads as a machine.
const STEP_QUICKEN := 1.4
const LIFT_GAIN := 1.3
const STRIDE_GAIN := 1.2
const STEP_SCATTER := 0.22
## How far past its hold a foot swings before stabbing down on it.
const STAB_BACK := 1.6
const STAB_PEAK := 1.7
## Each footfall kicks the body: up and down, and rocking nose to tail.
const BOB_KICK := 320.0
const ROCK_KICK := 4.5
const ARM_KICK := 14.0
## It runs nose down, and pulls up first when it sets off.
const PITCH_MAX := 0.3
const PITCH_LIMIT := 0.6
const SQUASH_ALONG := 0.28
const SQUASH_ACROSS := 0.18
const SQUASH_MAX := 1.6
## How much faster each part follows, and how much less it settles.
const QUICKEN := {"body": 1.5, "turn": 1.2, "head": 4.0, "abdomen": 1.5, "arms": 1.2}
const LOOSEN := 0.35
const HEAD_SNAP := 0.55
const HEAD_SNAP_MIN := 0.06
const HEAD_SNAP_MAX := 0.26
const ABDOMEN_PUMP := 0.22
const ABDOMEN_PUMP_RATE := 24.0
const ARM_RUN_RAISE := 0.7
## How far each arm joint thrashes while it runs, in radians, and how much each joint lags
## the one before it, which is what makes the arm whip.
const ARM_THRASH: Array[float] = [0.5, 0.65, 0.85]
const ARM_THRASH_RATE := 34.0
const ARM_THRASH_LAG := 0.9
## Stopped, or about to strike, it shivers with what it is holding back.
const TENSE_BELOW := 110.0
const SHIVER_PX := 1.8
const SHIVER_RATE_A := 71.0
const SHIVER_RATE_B := 53.0
const COIL_PX := 5.0
const ARM_QUIVER := 0.09
const ARM_QUIVER_RATE := 62.0
## With nothing to hold, its legs scrabble at the air.
const SCRABBLE_PX := 14.0
const SCRABBLE_RATE_A := 34.0
const SCRABBLE_RATE_B := 27.0
const LAND_KICK := 620.0
## It somersaults through a leap, in radians per second.
const LEAP_SPIN := 11.0
## How quickly it rights itself after landing.
const SPIN_SETTLE := 18.0
## Cloaked it can only just be seen, flickering around this much.
const CLOAK_SHOW := 0.1
const CLOAK_FLICKER := 0.03
## Being shot leaves it showing for this long.
const REVEAL_TIME := 1.2
## Being shot jolts it.
const FLINCH_KICK := 320.0
const FLINCH_ROCK := 9.0
const FLINCH_HEAD := 16.0
## Sparks and dust where its claws hit, once it is going this hard.
const CHIPS_FROM := 0.25
const CHIP_MAX := 60

class Leg:
	var name := ""
	## The drawing's joints relative to the thorax, scaled to the screen. +y is down.
	var rest: Array[Vector2] = []
	var thigh := 0.0
	var calf := 0.0
	var reach := 0.0
	## Where this foot lands on a flat surface, as a direction from the thorax.
	var ray := Vector2.ZERO
	var group := 0
	## Ankle from foot. +y is down.
	var slant := Vector2.ZERO
	var shin := 0.0
	## Which way along the body this leg reaches: 1 forward, -1 back.
	var out := 1.0
	## Which side the knee prefers: 1 out from the body, -1 in.
	var knee_side := 1.0
	## Which way this leg's knee joint bends, as the turn from hip-to-ankle over to the
	## knee in the drawing's axes. A hinge, so it is the same in every pose.
	var hinge := 1.0
	## Its length against the drawing's. Sets how far out it stands.
	var growth := 1.0
	## Its length against the base alien's. Sets how far it steps and lifts.
	var size := 1.0
	var ray_length := 0.0
	var phase := 0.0
	var step_time := STEP_TIME
	var lift := LIFT
	## It has just turned around, so this foot steps when its pair's turn comes.
	var turn_step := false
	var foot := Vector2.ZERO
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	## Step progress. 1 means planted.
	var u := 1.0
	var step_lift := 1.0
	var hip := Vector2.ZERO
	var knee := Vector2.ZERO
	var ankle := Vector2.ZERO
	var tip := Vector2.ZERO

## A spark or a puff of dust thrown up by a claw, in world space.
class Chip:
	var at := Vector2.ZERO
	var v := Vector2.ZERO
	var age := 0.0
	var life := 0.2
	var size := 2.0
	var hot := false

class Arm:
	var name := ""
	var hip := Vector2.ZERO
	var lengths: Array[float] = []
	var angles: Array[float] = []
	var turn: Array[float] = [0.0, 0.0, 0.0]
	var phase := 0.0

var arena: Arena
var art: AlienArt
var gravity := 1700.0
## Being carried by the rig lab: the body goes where it is put.
var held := false
var held_at := Vector2.ZERO
## No breathing, fidgeting or swaying, so limbs can be edited against a body at rest.
var still := false
var state := State.IDLE
var state_t := 0.0
## Distance along the arena's loop while crawling.
var s := 0.0
var pos := Vector2.ZERO
## World space, pointing away from the surface.
var normal := Vector2.UP
var angle := 0.0
var face := 1.0
var want_face := 1.0
## 1 facing the way the drawing does, along the body's +x; -1 mirrored.
var side := 1.0
## Time since it last turned around.
var since_turn := 99.0
var _turn_wait := 0.0
## The way it has decided to face. Everything comes round once face passes through zero.
var _turning_to := 1.0
var crouch := 0.0
var swipe := 0.0
var clock := 0.0
var abdomen_sway := 0.0
var head_turn := 0.0
var body := Vector2.ZERO
var body_motion: SecondOrder
var turn_motion: SecondOrder
var head_motion: SecondOrder
var abdomen_motion: SecondOrder
## x is how far the arms are raised, y how far they are thrown out.
var arm_motion: SecondOrder
var pitch_motion: SecondOrder
var squash_motion: SecondOrder
## The surface's angle as the body has turned to it so far. angle is this plus pitch.
var ground_angle := 0.0
var pitch := 0.0
var squash := 0.0
## How unhinged this one moves, as in AlienArt.frenzy. Set for each alien by the level.
var frenzy := AlienArt.DEFAULT_FRENZY
## Comes for the hero wherever he is, instead of resting until he is near.
var hunting := false
## 1 with its shields closed in front of it. Set by Horde; what is drawn follows it.
var guard := 0.0
var guard_now := 0.0
var guard_motion: SecondOrder
## 1 with its abdomen swollen to burst.
var swell := 0.0
## 1 when it can only just be seen.
var cloak := 0.0
var reveal_t := 0.0
## Heading away from the hero after a strike, for this long.
var retreat_t := 0.0
var charge_dir := 1.0
var charge_speed := 0.0
var charge_left := 0.0
var charge_hits_wall := false
var stun_for := 0.0
## How hard it is going, against flat out, with the frenzy applied. 0 when at rest.
var drive := 0.0
## Claws that came down this frame, for sound.
var plants := 0
var chips: Array[Chip] = []
## What it looked like a moment ago, for the view's after-images: when, and each part.
var ghosts: Array = []
var ghost_at := 0.0
var velocity := Vector2.ZERO
var alpha := 1.0
var legs: Array[Leg] = []
var arms: Array[Arm] = []
## Limb name to its four joints in world space, ready to draw.
var bones: Dictionary = {}
## Limb name to how much each segment's sprite stretches along its bone.
var stretch: Dictionary = {}

## Which way it has chosen to reach the hero, and for how much longer.
var high_route := false
var route_t := 0.0
var melee_next := false
## Rest left once the hero has come near.
var notice_t := 1.0
## Hits landed, for tests.
var hits := 0

var _fidget_t := 0.0
var _rest_centroid := 0.0
## How far over its surface the body stands beyond RIDE, because of its leg lengths.
var _rise := 0.0
var _pace := 1.0
var _pace_to := 1.0
var _dart_t := 0.0
var _dart := Dart.STOP
var _skid := false
var _leap_spin := 0.0
var _head_snap := 0.0
var _head_snap_t := 0.0


func _init(the_arena: Arena, the_art: AlienArt, the_gravity: float, bug: Bug) -> void:
	arena = the_arena
	art = the_art
	gravity = the_gravity
	for limb: String in art.limbs:
		var joints: Array[Vector2] = []
		for j: Vector2 in art.limbs[limb]:
			joints.append((j - art.origin) * SCALE)
		bones[limb] = joints.duplicate()
		if limb.begins_with("leg_"):
			legs.append(_new_leg(limb, joints))
		else:
			arms.append(_new_arm(limb, joints))
	for i in legs.size():
		legs[i].phase = i * 1.7
	apply_stance()
	pitch_motion = SecondOrder.new(5.0, 0.3, -1.2)
	squash_motion = SecondOrder.new(7.0, 0.28, 0.0)
	body_motion = SecondOrder.new(1.0, 1.0, 0.0)
	turn_motion = SecondOrder.new(1.0, 1.0, 0.0)
	head_motion = SecondOrder.new(1.0, 1.0, 0.0)
	abdomen_motion = SecondOrder.new(1.0, 1.0, 0.0)
	arm_motion = SecondOrder.new(1.0, 1.0, 0.0)
	guard_motion = SecondOrder.new(5.0, 0.55, 0.0)
	apply_motion()
	want_face = 1.0 if randf() < 0.5 else -1.0
	face = want_face
	side = want_face
	_turning_to = want_face
	_fidget_t = randf_range(FIDGET_MIN, FIDGET_MAX)
	place(arena.floor_s(bug.x), bug)


## Where the limbs sit comes from the stance.
func _new_leg(limb: String, joints: Array[Vector2]) -> Leg:
	var leg := Leg.new()
	leg.name = limb
	leg.rest = joints
	leg.group = GROUPS[limb]
	return leg


## Bone lengths are the drawing's times the lengths set in the rig lab. Sprites stretch
## along their bones to fit, which also lets a far leg match the near leg on its end.
func _fit_lengths(leg: Leg) -> void:
	var from: Array[Vector2] = art.limbs[SAME_LENGTH_AS.get(leg.name, leg.name)]
	var own: Array[Vector2] = art.limbs[leg.name]
	var end := "front" if leg.name.contains("front") else "rear"
	var all: float = art.leg_length["all"]
	leg.thigh = from[0].distance_to(from[1]) * SCALE * all * float(art.leg_length[end + "_thigh"])
	leg.calf = from[1].distance_to(from[2]) * SCALE * all * float(art.leg_length[end + "_calf"])
	leg.shin = from[2].distance_to(from[3]) * SCALE * all * float(art.leg_length[end + "_shin"])
	leg.reach = leg.thigh + leg.calf + leg.shin
	var drawn := (from[0].distance_to(from[1]) + from[1].distance_to(from[2]) + from[2].distance_to(from[3])) * SCALE
	leg.growth = leg.reach / drawn
	leg.size = leg.growth * art.size
	stretch[leg.name] = [leg.thigh / (own[0].distance_to(own[1]) * SCALE), leg.calf / (own[1].distance_to(own[2]) * SCALE), leg.shin / (own[2].distance_to(own[3]) * SCALE)]


func _new_arm(limb: String, joints: Array[Vector2]) -> Arm:
	var arm := Arm.new()
	arm.name = limb
	arm.phase = 0.0 if limb.ends_with("_near") else 1.7
	for i in 3:
		var d := joints[i + 1] - joints[i]
		arm.lengths.append(d.length())
		arm.angles.append(d.angle())
	return arm


func apply_stance() -> void:
	_rest_centroid = 0.0
	var growth := 0.0
	for leg in legs:
		_fit_lengths(leg)
		growth += leg.growth / legs.size()
	# How tall this kind stands in its drawing, over where it really is on its loop.
	var stands := (art.ground_y - art.origin.y) * SCALE
	_rise = stands - RIDE + stands * (growth - 1.0) * RISE_SHARE
	for leg in legs:
		var row: Dictionary = art.stance[leg.name]
		var foot_x: float = row.foot_x
		var ground := Vector2(foot_x * SCALE * leg.growth, RIDE)
		var foot := ground + Vector2(0.0, _rise)
		var lean := Vector2(row.ankle[0], row.ankle[1])
		leg.out = signf(foot_x) if foot_x != 0.0 else 1.0
		leg.knee_side = float(row.knee)
		leg.slant = lean.normalized() * leg.shin
		leg.rest[0] = Vector2(row.hip[0], row.hip[1]) * SCALE
		leg.rest[2] = foot + leg.slant
		leg.rest[3] = foot
		leg.ray = ground.normalized()
		leg.ray_length = ground.length()
		leg.hinge = _hinge_of(leg)
		if row.has("pole"):
			leg.slant = _lean_from_pole(leg, foot, Vector2(row.pole[0], row.pole[1]) * SCALE)
			leg.rest[2] = foot + leg.slant
		_rest_centroid += foot.x / legs.size()
	for arm in arms:
		var row: Dictionary = art.stance[arm.name]
		arm.hip = Vector2(row.hip[0], row.hip[1]) * SCALE
		for i in 3:
			arm.turn[i] = row.turn[i]


## Takes how it moves from the art, which is what the rig lab edits.
func apply_motion() -> void:
	frenzy = art.frenzy
	_apply_feel()


## Gives this one a frenzy of its own.
func set_frenzy(value: float) -> void:
	frenzy = value
	_apply_feel()


func _apply_feel() -> void:
	_set_feel(body_motion, "body")
	_set_feel(turn_motion, "turn")
	_set_feel(head_motion, "head")
	_set_feel(abdomen_motion, "abdomen")
	_set_feel(arm_motion, "arms")


func _set_feel(motion: SecondOrder, part: String) -> void:
	var row: Dictionary = art.motion[part]
	var f := float(row.f) * (1.0 + float(QUICKEN[part]) * frenzy)
	var zeta := float(row.zeta) * (1.0 - LOOSEN * minf(frenzy, 1.0))
	motion.set_feel(f, zeta, row.r)


## Everything drawn jumps to where the alien really is, with no motion left over.
func _settle_motion() -> void:
	ground_angle = _normal_angle()
	angle = ground_angle
	pitch = 0.0
	squash = 0.0
	drive = 0.0
	_leap_spin = 0.0
	guard_now = guard
	guard_motion.reset(Vector2(guard, 0.0))
	pitch_motion.reset(Vector2.ZERO)
	squash_motion.reset(Vector2.ZERO)
	body = standing_at()
	body_motion.reset(body)
	turn_motion.reset(Vector2(angle, 0.0))
	head_motion.reset(Vector2(angle, 0.0))
	abdomen_motion.reset(Vector2(angle, 0.0))
	arm_motion.reset(Vector2.ZERO)
	head_turn = 0.0
	abdomen_sway = 0.0


## A knee placed by hand says where the knee sits in the standing pose, with the thigh
## aimed at it. That leaves one way for the shin to lean, which it then holds.
func _lean_from_pole(leg: Leg, foot: Vector2, pole: Vector2) -> Vector2:
	var hip := leg.rest[0]
	var aim := pole - hip
	if aim.length() < 0.01:
		return leg.slant
	var knee := hip + aim.normalized() * leg.thigh
	var fits := _circles_meet(knee, leg.calf, foot, leg.shin)
	if fits.is_empty():
		return foot.direction_to(knee) * leg.shin
	var first_ok := (fits[0] - knee).cross(foot - fits[0]) * -leg.hinge >= 0.0
	return (fits[0] if first_ok else fits[1]) - foot


## Set by the standing pose: the knee rises, and leans out to its own end of the body.
func _hinge_of(leg: Leg) -> float:
	var reach_to := leg.rest[2] - leg.rest[0]
	var prefer := Vector2(leg.out * leg.knee_side * KNEE_OUT, -1.0)
	return 1.0 if Vector2(-reach_to.y, reach_to.x).dot(prefer) >= 0.0 else -1.0


## The drawing's angle for one arm segment, before its stance turn.
func arm_rest_angle(limb: String, index: int) -> float:
	for arm in arms:
		if arm.name == limb:
			return arm.angles[index]
	return 0.0


## A world point in the drawing's axes, relative to the thorax, in its pixels.
func to_drawing(p: Vector2) -> Vector2:
	var d := p - body
	return Vector2(d.dot(_tangent()) * side, -d.dot(_up())) / SCALE


func place(at_s: float, bug: Bug) -> void:
	s = at_s
	_pose(bug)
	_settle_motion()
	plant_all()


func on_surface() -> bool:
	return state != State.LEAP and state != State.DEAD


func on_floor_side() -> bool:
	return on_surface() and normal.y < -0.5


## Turns around at once, for tools. Crawling turns by way of want_face.
func turn_now(to_side: float) -> void:
	want_face = to_side
	face = to_side
	_turning_to = to_side
	if to_side != side:
		_come_round()


func set_state(next: State) -> void:
	state = next
	state_t = 0.0


## Turns the body's front toward a point, if the surface lets it face that way at all.
func face_toward(point: Vector2) -> void:
	var along := _tangent().dot(point - pos)
	if absf(along) > 4.0:
		want_face = signf(along)


## How fast to crawl right now, against its base speed. Whoever moves it along the loop
## multiplies by this. At no frenzy it is always 1.
func dart(dt: float) -> float:
	var wild := frenzy
	if wild <= 0.0:
		return 1.0
	_dart_t -= dt
	if _dart_t <= 0.0:
		if _dart == Dart.BOLT:
			_dart = Dart.STOP
			_dart_t = LISTEN_TIME if randf() < LISTEN_CHANCE else randf_range(STOP_TIME_MIN, STOP_TIME_MAX)
			_pace_to = maxf(1.0 - wild, 0.0)
			_skid = true
		elif _dart == Dart.STOP and randf() < JUKE_CHANCE * minf(wild, 1.0):
			_dart = Dart.JUKE
			_dart_t = JUKE_TIME
			_pace_to = JUKE_PACE * wild
		else:
			_dart = Dart.BOLT
			_dart_t = randf_range(BOLT_TIME_MIN, BOLT_TIME_MAX)
			_pace_to = 1.0 + (randf_range(BOLT_MIN, BOLT_MAX) - 1.0) * wild
	_pace = move_toward(_pace, _pace_to, dt * PACE_SNAP)
	# Short legs cannot keep up the same speed.
	return _pace * minf(sqrt(legs[0].growth), 1.0)


## Whether a shot travelling this way, in world space, hits its closed shields.
func deflects(travel: Vector2) -> bool:
	return (state == State.BRACE or state == State.CHARGE) and guard_now > 0.5 and travel.dot(_tangent()) * side < 0.0


## How solid it looks, on top of alpha.
func visibility() -> float:
	return lerpf(1.0, CLOAK_SHOW + sin(clock * 9.0) * CLOAK_FLICKER, cloak)


## A hit jolts the body, and it will not stand still under fire.
func flinch(dir: float) -> void:
	var wild := frenzy
	reveal_t = REVEAL_TIME
	body_motion.velocity += Vector2(dir * FLINCH_KICK, -FLINCH_KICK * 0.4) * wild
	pitch_motion.velocity.x += randf_range(-FLINCH_ROCK, FLINCH_ROCK) * wild
	head_motion.velocity.x += randf_range(-FLINCH_HEAD, FLINCH_HEAD) * wild
	if _dart == Dart.STOP:
		_dart_t = 0.0


## How much longer than in the drawing a leg is.
func growth_of(limb: String) -> float:
	return _leg_named(limb).growth


func _leg_named(limb: String) -> Leg:
	for leg in legs:
		if leg.name == limb:
			return leg
	return null


func _normal_angle() -> float:
	return atan2(normal.x, -normal.y)


func _ground_tangent() -> Vector2:
	return Vector2(cos(ground_angle), sin(ground_angle))


func _ground_up() -> Vector2:
	return Vector2(sin(ground_angle), -cos(ground_angle))


## Where the body sits at rest on its surface, given how long its legs are.
func standing_at() -> Vector2:
	return pos + _ground_up() * _rise


func _tangent() -> Vector2:
	return Vector2(cos(angle), sin(angle))


func _up() -> Vector2:
	return Vector2(sin(angle), -cos(angle))


## From the drawing's axes, relative to the thorax, to the world.
func _world(v: Vector2) -> Vector2:
	return body + _tangent() * side * v.x - _up() * v.y


## Places a part of the body, which is drawn in the drawing's own pixels.
func body_transform() -> Transform2D:
	var flip := face if absf(face) > 0.3 else 0.3 * side
	var fit := Vector2(flip * (1.0 + squash * SQUASH_ALONG), 1.0 - squash * SQUASH_ACROSS) * SCALE
	return Transform2D(angle, fit, 0.0, body) * Transform2D(0.0, -art.origin)


# ---- Per frame -----------------------------------------------------------------

func _pose(bug: Bug) -> void:
	if held:
		_pose_held(bug)
	elif on_surface():
		arena.pose(s)
		normal = arena.normal
		bug.x = arena.at.x
		bug.h = -arena.at.y - bug.mid
	else:
		normal = Vector2.UP
	pos = Vector2(bug.x, -bug.h - bug.mid)


## Near a surface it turns its back to it. Far from everything it hangs upright.
func _pose_held(bug: Bug) -> void:
	bug.x = held_at.x
	bug.h = -held_at.y - bug.mid
	var near := arena.closest_point(held_at)
	var away := held_at - near
	normal = away.normalized() if away.length() > 1.0 and away.length() < HOLD_SENSE else Vector2.UP


func update(bug: Bug, dt: float) -> void:
	var was := pos
	_pose(bug)
	if dt > 0.0:
		velocity = (pos - was) / dt
	clock += dt
	plants = 0
	_update_chips(dt)
	if state == State.DEAD:
		_update_dead(dt)
		return
	alpha = minf(alpha + dt * APPEAR_SPEED, 1.0)
	if still:
		_settle_motion()
	else:
		ground_angle = turn_motion.update_angle(dt, _normal_angle())
		_update_frenzy(dt)
		_update_spin(dt)
		angle = ground_angle + pitch + _leap_spin
	_update_turn(dt)
	var calm := state == State.IDLE or state == State.RECOVER or state == State.STUN
	var tense := _tension()
	guard_now = guard_motion.update(dt, Vector2(guard, 0.0)).x
	var raise_to := 1.0 if state == State.LEAP else crouch
	if state == State.CRAWL:
		raise_to = maxf(raise_to, ARM_RUN_RAISE * minf(frenzy, 1.0))
	var arm_pose := arm_motion.update(dt, Vector2(raise_to, swipe))
	if not still:
		_update_trailing_parts(dt, calm)
	var up := _ground_up()
	var forward := _ground_tangent()
	var airborne := 0
	var centroid := 0.0
	for leg in legs:
		centroid += (leg.foot - pos).dot(forward)
		if leg.u < 1.0:
			airborne += 1
	# The body settles over its support, and rises a touch as feet push off.
	centroid = centroid / legs.size() - _rest_centroid * side
	var breath := sin(clock * 2.4) * BREATH_PX if calm else 0.0
	var lunge := STRIKE_LUNGE_PX * (1.0 + frenzy) * art.size
	var aim := pos + forward * (centroid * 0.14 + side * arm_pose.y * lunge) + up * (airborne * 0.7 + breath - crouch * CROUCH_PX + _rise - tense * COIL_PX)
	if held:
		aim = standing_at()
	if still:
		body = standing_at()
		body_motion.reset(body)
	else:
		body = body_motion.update(dt, aim)
		if body.distance_to(pos) > MAX_BODY_LAG:
			body = pos + (body - pos).limit_length(MAX_BODY_LAG)
			body_motion.value = body
		body += (forward * sin(clock * SHIVER_RATE_A) + up * sin(clock * SHIVER_RATE_B)) * SHIVER_PX * tense
	if state == State.LEAP:
		_tuck_legs(dt)
	else:
		if state == State.IDLE and not held and not still:
			_fidget(dt)
		_step_legs(dt, up)
		_spit_skid()
	_solve_legs()
	_solve_arms(0.0, tense)


## Reads its speed into how hard it is going, and everything that swings from that.
func _update_frenzy(dt: float) -> void:
	var wild := frenzy
	var want := minf(velocity.length() / FULL_TILT, 1.3) * wild
	drive = move_toward(drive, want, dt * (DRIVE_RISE if want > drive else DRIVE_FALL))
	var lean := clampf(velocity.dot(_ground_tangent()) / FULL_TILT, -1.0, 1.0) * PITCH_MAX * wild
	pitch = clampf(pitch_motion.update(dt, Vector2(lean, 0.0)).x, -PITCH_LIMIT, PITCH_LIMIT)
	squash = clampf(squash_motion.update(dt, Vector2(drive, 0.0)).x, -1.0, SQUASH_MAX)
	_head_snap_t -= dt
	if _head_snap_t <= 0.0:
		_head_snap_t = randf_range(HEAD_SNAP_MIN, HEAD_SNAP_MAX)
		_head_snap = randf_range(-HEAD_SNAP, HEAD_SNAP) * minf(wild, 1.0)


## It somersaults through a leap. Only what is drawn turns, so on landing its feet go
## straight to their holds while the body rights itself the short way round.
func _update_spin(dt: float) -> void:
	if state == State.LEAP:
		_leap_spin += side * LEAP_SPIN * frenzy * dt
	else:
		_leap_spin = wrapf(_leap_spin, -PI, PI) * exp(-dt * SPIN_SETTLE)


## How much it is holding back: stopped in the middle of a run, or about to strike.
func _tension() -> float:
	if still:
		return 0.0
	if state == State.BRACE:
		return minf(0.6 + state_t * 2.5, 1.6)
	if state == State.WINDUP:
		return maxf(frenzy * minf(0.6 + state_t * 2.5, 1.6), swell * 1.5)
	if state == State.CRAWL:
		return frenzy * (1.0 - minf(velocity.length() / TENSE_BELOW, 1.0))
	return 0.0


## The head and abdomen chase the body's turning more slowly than it turns. Their angles
## go into the drawing's axes, where a mirrored alien turns the other way.
func _update_trailing_parts(dt: float, calm: bool) -> void:
	var loose := 1.0 + 0.5 * minf(frenzy, 1.0)
	var look := sin(clock * 1.3) * HEAD_LOOK if calm else 0.0
	var head_at := head_motion.update_angle(dt, angle + (look + _head_snap) * side)
	head_turn = clampf(wrapf(head_at - angle, -PI, PI), -HEAD_LIMIT * loose, HEAD_LIMIT * loose) * side
	var drag := minf(velocity.length() * ABDOMEN_DRAG, ABDOMEN_DRAG_MAX) * loose * loose
	var hang := sin(clock * 2.4) * ABDOMEN_BREATH if calm else 0.0
	var pump := sin(clock * ABDOMEN_PUMP_RATE) * ABDOMEN_PUMP * drive
	var abdomen_at := abdomen_motion.update_angle(dt, angle + (drag + hang + pump) * side)
	abdomen_sway = clampf(wrapf(abdomen_at - angle, -PI, PI), -ABDOMEN_LIMIT * loose, ABDOMEN_LIMIT * loose) * side


func _update_turn(dt: float) -> void:
	since_turn += dt
	var wild := minf(frenzy, 1.0)
	if signf(want_face) == _turning_to:
		_turn_wait = 0.0
	else:
		_turn_wait += dt
		if _turn_wait >= TURN_DELAY / (1.0 + 2.0 * wild):
			_turning_to = signf(want_face)
			_turn_wait = 0.0
	face = move_toward(face, _turning_to, dt * 9.0 * (1.0 + 1.5 * wild))
	# The limbs come round when the body is edge-on, so they all change sides together.
	if signf(face) == -side:
		_come_round()


## Now facing the other way, each foot stands where the opposite leg of its own depth
## belongs, so that leg takes it over. No leg has to reach back across the body for its
## foot, and a dark foot stays dark. They then step in place, one pair after the other,
## which is what shows it turning.
func _come_round() -> void:
	side = -side
	since_turn = 0.0
	for rear: String in OPPOSITE_LEG:
		var a := _leg_named(rear)
		var b := _leg_named(OPPOSITE_LEG[rear])
		for field in STEP_STATE:
			var kept: Variant = a.get(field)
			a.set(field, b.get(field))
			b.set(field, kept)
		a.turn_step = a.u >= 1.0
		b.turn_step = b.u >= 1.0


## Now and then a resting foot lifts and sets back down in the same place.
func _fidget(dt: float) -> void:
	_fidget_t -= dt
	if _fidget_t > 0.0:
		return
	_fidget_t = randf_range(FIDGET_MIN, FIDGET_MAX)
	var leg: Leg = legs[randi() % legs.size()]
	if leg.u >= 1.0:
		_begin_step(leg, leg.foot)
		leg.step_lift = FIDGET_LIFT


func _tuck_legs(dt: float) -> void:
	for leg in legs:
		_dangle(leg, dt)


## With nothing to hold, a foot draws in and hangs loosely off the body, and scrabbles for
## something to grab.
func _dangle(leg: Leg, dt: float) -> void:
	var forward := _tangent()
	var up := _up()
	var splay := (forward * side * leg.ray.x * TUCK * 1.6 - up * (leg.ray.y * TUCK + 6.0)) * leg.size
	var scrabble := forward * sin(clock * SCRABBLE_RATE_A + leg.phase) + up * cos(clock * SCRABBLE_RATE_B + leg.phase * 1.7)
	splay += scrabble * SCRABBLE_PX * frenzy * leg.size
	leg.foot = leg.foot.lerp(body + splay, 1.0 - exp(-dt * (16.0 + 16.0 * minf(frenzy, 1.0))))
	leg.u = 1.0


## Takes hold of the loop right where it is, after being carried or held.
func take_hold(at_s: float) -> void:
	s = at_s
	set_state(State.IDLE)


## Feet in one pair only leave once the other pair is down.
func _step_legs(dt: float, up: Vector2) -> void:
	var busy := [false, false]
	var wild := minf(frenzy, 1.0)
	for leg in legs:
		if leg.u < 1.0:
			busy[leg.group] = true
	for leg in legs:
		var want := _foot_target(leg)
		var has_hold := want.is_finite()
		if leg.u < 1.0:
			leg.u = minf(leg.u + dt / leg.step_time, 1.0)
			if has_hold and leg.step_lift >= 1.0:
				leg.to = want
			var eased := lerpf(smoothstep(0.0, 1.0, leg.u), _stab_along(leg.u), wild)
			var height := sin(pow(leg.u, lerpf(1.0, STAB_PEAK, wild)) * PI)
			leg.foot = leg.from.lerp(leg.to, eased) + up * height * leg.lift * leg.step_lift
			if leg.u >= 1.0:
				_plant(leg)
			continue
		if not has_hold:
			if held:
				_dangle(leg, dt)
			continue
		var gap := leg.foot.distance_to(want)
		# Waiting for the other pair is only worth it while the leg can still reach.
		var ahead := velocity * MUST_STEP_AHEAD / minf(leg.growth, 1.0)
		var overdrawn := (leg.hip + ahead).distance_to(leg.foot) > leg.reach * MUST_STEP
		overdrawn = overdrawn or (leg.foot - leg.hip).dot(up) > BEHIND_BACK
		var stride := STRIDE * art.stride * leg.size * (1.0 + drive * STRIDE_GAIN)
		var force_at := FORCE_STEP * maxf(art.stride, 1.0) * leg.size
		if gap > force_at or overdrawn or ((gap > stride or leg.turn_step) and not busy[1 - leg.group]):
			_begin_step(leg, want)
			busy[leg.group] = true


func _begin_step(leg: Leg, want: Vector2) -> void:
	leg.from = leg.foot
	leg.to = want
	leg.u = 0.0
	leg.step_lift = 1.0
	leg.turn_step = false
	var scatter := STEP_SCATTER * minf(frenzy, 1.0)
	# Like a pendulum, a shorter leg swings quicker, which also keeps it from being outrun.
	# Each pair waits for the other to land, so a swing's length is what really sets how far
	# the body gets between steps, and it has to grow with the stride.
	leg.step_time = STEP_TIME * art.stride * sqrt(leg.size) / (1.0 + drive * STEP_QUICKEN) * randf_range(1.0 - scatter, 1.0 + scatter)
	leg.lift = LIFT * sqrt(art.stride) * leg.size * (1.0 + drive * LIFT_GAIN) * randf_range(1.0 - scatter, 1.0 + scatter)


## Swings past the hold, then comes back onto it.
func _stab_along(u: float) -> float:
	var left := u - 1.0
	return 1.0 + (STAB_BACK + 1.0) * left * left * left + STAB_BACK * left * left


## A claw has come down. The body answers, by turns from one pair and the other, which
## rocks it and bounces it in time with its own feet.
func _plant(leg: Leg) -> void:
	if leg.step_lift < 1.0:
		return
	plants += 1
	if drive < CHIPS_FROM:
		return
	var kick := 1.0 if leg.group == 0 else -1.0
	body_motion.velocity += _ground_up() * -kick * BOB_KICK * drive
	pitch_motion.velocity.x += kick * ROCK_KICK * drive
	arm_motion.velocity += Vector2(randf_range(-ARM_KICK, ARM_KICK), randf_range(0.0, ARM_KICK)) * drive
	_spit_chips(leg.foot, 1, drive)


## Coming to a dead stop, every claw on the ground throws up sparks.
func _spit_skid() -> void:
	if not _skid:
		return
	_skid = false
	if drive < CHIPS_FROM:
		return
	for leg in legs:
		if leg.u >= 1.0:
			_spit_chips(leg.foot, 3, drive)


## Sparks and dust come off the surface, and away from the way it is going.
func _spit_chips(at: Vector2, count: int, power: float) -> void:
	if cloak > 0.5:
		return
	var back := -velocity.normalized() if velocity.length() > 1.0 else Vector2.ZERO
	for i in count:
		for hot: bool in [true, false]:
			var chip := Chip.new()
			chip.at = at
			chip.hot = hot
			if hot:
				chip.v = back * randf_range(80.0, 280.0) * power + normal.rotated(randf_range(-0.7, 0.7)) * randf_range(60.0, 240.0) * power
				chip.life = randf_range(0.12, 0.3)
				chip.size = randf_range(1.8, 3.4)
			else:
				chip.v = back * randf_range(10.0, 70.0) + normal.rotated(randf_range(-1.1, 1.1)) * randf_range(10.0, 60.0)
				chip.life = randf_range(0.2, 0.42)
				chip.size = randf_range(2.0, 5.0)
			chips.append(chip)
	while chips.size() > CHIP_MAX:
		chips.pop_front()


func _update_chips(dt: float) -> void:
	var i := chips.size() - 1
	while i >= 0:
		var chip := chips[i]
		chip.age += dt
		if chip.age >= chip.life:
			chips.remove_at(i)
		else:
			if chip.hot:
				chip.v.y += gravity * 0.6 * dt
			chip.at += chip.v * dt
		i -= 1


func plant_all() -> void:
	for leg in legs:
		var want := _foot_target(leg)
		leg.foot = want if want.is_finite() else arena.closest_point(pos)
		leg.u = 1.0
		leg.turn_step = false
	body = standing_at()
	body_motion.reset(body)
	_solve_legs()
	_solve_arms()


## Where a ray from the body meets a surface, along the line the stance sets for this
## foot. At the top of a rise that line runs nearly along the slope and meets it far
## behind, which would drag the leg out, so a hit that far off gives way to the nearest
## surface instead. Returns INF only while being carried with nothing in reach.
func _foot_target(leg: Leg) -> Vector2:
	var forward := _ground_tangent()
	var dir := forward * side * leg.ray.x - _ground_up() * leg.ray.y
	# Feet look for holds under the body as drawn, which trails the real position, so
	# the legs stay spread around their hips. Only along the surface: its height is kept.
	var trail := forward * (body - pos).dot(forward)
	var ahead := velocity * LOOKAHEAD * art.stride
	var rest_length := leg.ray_length
	# Looking ahead must not take a hold that the leg, from where its hip is, cannot reach.
	var hold_limit := leg.reach * HOLD_REACH
	var hip := _world(leg.rest[0])
	var from_point := pos
	var tries := LONG_STRIDE_TRIES if art.stride > 1.0 else 1
	for i in tries:
		from_point = pos + trail + ahead * (1.0 - float(i) / tries)
		if not arena.contains(from_point):
			from_point = pos
		var hit := arena.raycast(from_point, dir, leg.reach)
		if hit.is_finite() and from_point.distance_to(hit) <= minf(rest_length * RAY_STRETCH, hold_limit) and hip.distance_to(hit) <= hold_limit:
			return hit
	var near := arena.closest_point(from_point + dir * rest_length)
	if near.distance_to(pos) <= hold_limit and hip.distance_to(near) <= hold_limit and arena.clear_line(pos, near + near.direction_to(pos)):
		return near
	if held:
		return Vector2.INF
	return arena.closest_point(hip)


## Comes down from a leap and catches the floor with every foot at once.
func land(bug: Bug) -> void:
	s = arena.floor_s(bug.x)
	_pose(bug)
	body_motion.velocity += normal * -LAND_KICK * frenzy
	squash_motion.velocity.x -= 16.0 * frenzy
	for leg in legs:
		var want := _foot_target(leg)
		if want.is_finite():
			_begin_step(leg, want)
		if frenzy > 0.0:
			_spit_chips(leg.foot, 2, 1.0)


# ---- Death ---------------------------------------------------------------------

## Lets go of the wall, drops, and curls up where it lands while it fades away.
func die(bug: Bug) -> void:
	set_state(State.DEAD)
	bug.vh = 0.0
	crouch = 0.0
	swipe = 0.0
	head_turn = 0.0
	pitch = 0.0
	squash = 0.0
	drive = 0.0
	_leap_spin = 0.0
	guard = 0.0
	swell = 0.0
	cloak = 0.0
	normal = Vector2.UP


## Returns true once it has finished and can be removed.
func update_corpse(bug: Bug, dt: float) -> bool:
	state_t += dt
	var settled := arena.ground_at(bug.x) + DEAD_RIDE - bug.mid
	if bug.h > settled:
		bug.vh -= gravity * dt
		bug.h = maxf(bug.h + bug.vh * dt, settled)
	update(bug, dt)
	return state_t >= FADE_TO


func _update_dead(dt: float) -> void:
	ground_angle = turn_motion.update_angle(dt, DEAD_TILT * side)
	angle = ground_angle
	body = body_motion.update(dt, pos)
	arm_motion.update(dt, Vector2.ZERO)
	var curl := minf(state_t * 2.2, 1.0)
	var twitch := 0.0
	if state_t < DEATH_TWITCH_UNTIL:
		twitch = sin(state_t * 46.0) * (1.0 - state_t / DEATH_TWITCH_UNTIL)
	for i in legs.size():
		var leg := legs[i]
		var folded := leg.rest[3] * LEG_CURL + Vector2(0.0, -2.0)
		leg.foot = leg.foot.lerp(_world(folded), 1.0 - exp(-dt * 9.0)) + _up() * twitch * (1.2 if i % 2 == 0 else -1.2)
		leg.u = 1.0
	abdomen_sway = twitch * 0.1
	alpha = 1.0 - smoothstep(FADE_FROM, FADE_TO, state_t)
	_solve_legs()
	_solve_arms(curl)


# ---- Bones ---------------------------------------------------------------------

## A leg has three bones, which leaves one thing free. The shin holds the lean the stance
## gives it, so what the foot does goes into the thigh and the middle bone, which swing
## as one chain from the hip to the ankle, folding the way the hinge folds.
func _solve_legs() -> void:
	for leg in legs:
		leg.hip = _world(leg.rest[0])
		_place_shin(leg, _shin_lean(leg))
		var joints: Array[Vector2] = bones[leg.name]
		joints[0] = leg.hip
		joints[1] = leg.knee
		joints[2] = leg.ankle
		joints[3] = leg.tip


## From the foot to the ankle. Held against the surface and not the body, so the body's
## rocking stays out of it. Only in the air does it turn with the body.
func _shin_lean(leg: Leg) -> Vector2:
	var turn := angle if state == State.LEAP else ground_angle
	var forward := Vector2(cos(turn), sin(turn))
	var up := Vector2(sin(turn), -cos(turn))
	var lean := forward * side * leg.slant.x - up * leg.slant.y
	if leg.u >= 1.0:
		return lean
	return lean.rotated(-leg.hinge * side * SHIN_TUCK * sin(leg.u * PI))


## If the held lean would fold the shin backward, shut a joint flat or leave the ankle out
## of reach, the shin turns no further than it takes, whichever way is nearer. If nothing
## keeps the shin the right way round, it goes straight on from the middle bone.
func _place_shin(leg: Leg, lean: Vector2) -> void:
	var best := 0.0
	var best_score := _try_shin(leg, lean)
	if best_score >= 0.0:
		return
	for i in range(1, SHIN_SEARCH_STEPS + 1):
		for way: float in [1.0, -1.0]:
			var high := SHIN_SEARCH_STEP * i * way
			var score := _try_shin(leg, lean.rotated(high))
			if score >= 0.0:
				var low := high - SHIN_SEARCH_STEP * way
				for j in SHIN_REFINE:
					var mid := (low + high) * 0.5
					if _try_shin(leg, lean.rotated(mid)) >= 0.0:
						high = mid
					else:
						low = mid
				_try_shin(leg, lean.rotated(high))
				return
			if score > best_score:
				best_score = score
				best = high
	if best_score <= FORBIDDEN:
		_straighten_shin(leg)
	else:
		_try_shin(leg, lean.rotated(best))


## Solves the leg with its shin along one lean. Below zero means a joint is too tight, and
## how far below says how bad it is. FORBIDDEN or lower means it cannot be used at all.
func _try_shin(leg: Leg, lean: Vector2) -> float:
	leg.tip = leg.foot
	leg.ankle = leg.foot + lean
	leg.knee = knee_of(leg.hip, leg.ankle, leg.thigh, leg.calf, leg.hinge * side, _up())
	var span := leg.hip.distance_to(leg.ankle)
	var beyond := maxf(span - leg.thigh - leg.calf, absf(leg.thigh - leg.calf) - span)
	if beyond > 0.0:
		return FORBIDDEN - beyond
	var bend := (leg.ankle - leg.knee).angle_to(leg.tip - leg.ankle) * -leg.hinge * side
	if bend < SHIN_MIN_BEND:
		return FORBIDDEN + bend - SHIN_MIN_BEND
	return minf(_knee_opening(leg, leg.ankle) - TIGHT_KNEE, PI - bend - TIGHT_ANKLE)


## The middle bone and the shin as one straight bone. A foot out of reach gives way, not
## the leg, since sprites cannot stretch.
func _straighten_shin(leg: Leg) -> void:
	leg.knee = knee_of(leg.hip, leg.foot, leg.thigh, leg.calf + leg.shin, leg.hinge * side, _up())
	var down := leg.knee.direction_to(leg.foot)
	leg.ankle = leg.knee + down * leg.calf
	leg.tip = leg.ankle + down * leg.shin


func _knee_opening(leg: Leg, ankle: Vector2) -> float:
	return absf((leg.hip - leg.knee).angle_to(ankle - leg.knee))


## Where two circles cross, or nothing if they do not.
static func _circles_meet(a: Vector2, ra: float, b: Vector2, rb: float) -> PackedVector2Array:
	var d := a.distance_to(b)
	if d < 0.01 or d > ra + rb or d < absf(ra - rb):
		return PackedVector2Array()
	var along := (ra * ra - rb * rb + d * d) / (2.0 * d)
	var out := sqrt(maxf(ra * ra - along * along, 0.0))
	var dir := (b - a) / d
	var mid := a + dir * along
	var step := Vector2(-dir.y, dir.x) * out
	return PackedVector2Array([mid + step, mid - step])


## Arms hang off the body and answer to the wind-up, a strike, death, a sway and the frenzy.
func _solve_arms(curl := 0.0, tense := 0.0) -> void:
	var pose := arm_motion.value
	var sway := ARM_SWAY_IDLE if state == State.IDLE or state == State.RECOVER else ARM_SWAY
	var poses: Dictionary = ARM_POSES[art.arm_style]
	var raise: Array = poses.raise
	var swipe_to: Array = poses.swipe
	var fold: Array = poses.curl
	var thrash: float = poses.thrash
	var guards: Dictionary = poses.get("guard", {})
	for arm in arms:
		var guard_to: Array = guards.get(arm.name, [0.0, 0.0, 0.0])
		var joints: Array[Vector2] = bones[arm.name]
		var point := arm.hip
		joints[0] = _world(point)
		for i in 3:
			var turn: float = arm.turn[i] + float(raise[i]) * pose.x + float(swipe_to[i]) * pose.y + float(fold[i]) * curl + float(guard_to[i]) * guard_now
			if state != State.DEAD and not still:
				turn += sin(clock * 3.0 + arm.phase + i) * sway
				turn += sin(clock * ARM_THRASH_RATE + arm.phase * 2.0 - i * ARM_THRASH_LAG) * ARM_THRASH[i] * minf(drive, 1.4) * thrash
				turn += sin(clock * ARM_QUIVER_RATE + arm.phase + i * 2.1) * ARM_QUIVER * tense
			point += Vector2.from_angle(arm.angles[i] + turn) * arm.lengths[i]
			joints[i + 1] = _world(point)


## Two bone IK. Of the two possible bends, the hinge's own, since a real leg joint only
## folds one way. A mirrored alien's hinges turn the opposite way on screen, which is why
## this takes the sign with side applied.
static func knee_of(hip: Vector2, foot: Vector2, thigh: float, calf: float, hinge: float, fallback: Vector2) -> Vector2:
	var d := foot - hip
	var distance := clampf(d.length(), absf(thigh - calf) + 0.25, thigh + calf)
	var dir := d.normalized() if d.length() > 0.01 else fallback
	var along := (thigh * thigh - calf * calf + distance * distance) / (2.0 * distance)
	var out := sqrt(maxf(thigh * thigh - along * along, 0.0))
	return hip + dir * along + Vector2(-dir.y, dir.x) * hinge * out
