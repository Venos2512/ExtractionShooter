class_name SecondOrder
extends RefCounted
## Follows a moving target with inertia, so motion has character without keyframes.
## Three numbers describe the feel:
##   f     how fast it responds, in Hz. Does not change the shape of the motion.
##   zeta  how it settles. 0 rings forever, below 1 overshoots and comes back, 1 and up
##         settles without any overshoot.
##   r     how it starts. 0 eases in, above 0 reacts at once, above 1 overshoots at the
##         start, below 0 pulls back first in anticipation.
## After t3ssel8r's "Giving Personality to Procedural Animations using Math".

## A target jumping across the screen should not throw the output as far the other way.
const MAX_TARGET_SPEED := 1200.0
const MIN_F := 0.05
## A hitch longer than this is simply lost, rather than simulated in many small steps.
const MAX_FRAME := 0.1
const SAFETY := 0.8

var value := Vector2.ZERO
var velocity := Vector2.ZERO
var _k1 := 0.0
var _k2 := 0.0
var _k3 := 0.0
var _last := Vector2.ZERO
var _last_angle := 0.0


func _init(f: float, zeta: float, r: float, start := Vector2.ZERO) -> void:
	set_feel(f, zeta, r)
	reset(start)


func set_feel(f: float, zeta: float, r: float) -> void:
	var w := TAU * maxf(f, MIN_F)
	_k1 = 2.0 * zeta / w
	_k2 = 1.0 / (w * w)
	_k3 = r * zeta / w


func reset(to: Vector2) -> void:
	value = to
	velocity = Vector2.ZERO
	_last = to
	_last_angle = to.x


func update(dt: float, target: Vector2) -> Vector2:
	if dt <= 0.0:
		return value
	var target_velocity := ((target - _last) / dt).limit_length(MAX_TARGET_SPEED)
	_last = target
	_integrate(dt, target, target_velocity)
	return value


## For angles, kept in value.x. Always takes the short way round.
func update_angle(dt: float, target: float) -> float:
	if dt <= 0.0:
		return value.x
	var target_velocity := clampf(wrapf(target - _last_angle, -PI, PI) / dt, -40.0, 40.0)
	_last_angle = target
	var near := value.x + wrapf(target - value.x, -PI, PI)
	_integrate(dt, Vector2(near, 0.0), Vector2(target_velocity, 0.0))
	value.x = wrapf(value.x, -PI, PI)
	return value.x


## Semi-implicit Euler. A step longer than the critical time makes the feedback grow
## without limit, so a long frame is split into steps short enough to stay stable.
func _integrate(dt: float, target: Vector2, target_velocity: Vector2) -> void:
	var total := minf(dt, MAX_FRAME)
	var critical := sqrt(4.0 * _k2 + _k1 * _k1) - _k1
	var steps := ceili(total / (critical * SAFETY))
	var t := total / steps
	for i in steps:
		value += velocity * t
		velocity += (target + target_velocity * _k3 - value - velocity * _k1) * t / _k2
