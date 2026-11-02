extends Node
## Development only. Plays a whole run through the normal input path so the
## game can be tested end to end without a person. Started by command line:
##   -- --bot                 play until the run ends, print the result, quit
##   -- --bot --god           same, but the hero cannot die
##   -- --bot --exit          take the early exit instead of the roof
##   -- --stress              150 awake bugs, print frame times, quit
##   -- --shots=DIR           save a screenshot every 12 s of run time
##   -- --speed=N             run the simulation N times faster
##   -- --joytest             drive the hero with simulated touches, print pass/fail
##   -- --parallaxtest        pan the camera, check each layer moved by its scroll scale
##   -- --introtest           play the story intro, check taps, then quit
##   -- --maptest             generate many random maps, check each one, print stats
##   -- --alientest           check the hero's new rules and everything the alien does
##   -- --leveltest           play the test level to the end; --mortal lets the hero die
##   -- --samplerun           stand in the arena unarmed, then shoot; screenshot with --shots
##   -- --aliens=N            with --stress in the arena, this many aliens
##   -- --oldmap              the old random map and swarm; --bot and --parallaxtest need it
##   -- --seed=N              build the map from this seed

## After turning around, the feet are still changing sides for this long.
const TURN_SETTLE := 0.5
## A planted leg this close to straight, as a share of its full length, looks dragged.
const STRAINED := 0.9
## A knee tighter than this, in degrees, looks folded flat.
const SHUT_KNEE := 15
## Leg frames per turn that a knee may sit under the line from hip to foot.
const KNEE_UNDER_PER_TURN := 8
## Past full length the foot lets go of the leg's tip. A few percent cannot be seen.
const STRETCH_LIMIT := 1.05

var game: Game
var args: PackedStringArray
var use_exit := false
var stress := false
var shots_dir := ""
var next_shot := 2.0
var shot_no := 0
var stress_frames := 0
var stress_total_us := 0
var stress_worst_us := 0
var last_tick := 0
var finished := false
var report_t := 0.0
var joytest := false
var joy_stage := 0
var joy_t := 0.0
var joy_start_x := 0.0
var card_shot_done := false
var parallaxtest := false
var plx_stage := 0
var plx_t := 0.0
var plx_cam := Vector2.ZERO
var plx_pos: Array[Vector2] = []
var plx_layers: Array[Parallax2D] = []
var plx_room: Level.Room
var plx_panel: WallLayer.WallPanel
var plx_wall_x := 0.0
var plx_failed := false
var ladder_push := 0.0
var introtest := false
var intro_shots := [1.0, 2.0, 2.3, 3.6, 8.0]
var intro_tapped_early := false
var intro_after := -1.0
var intro_wall_t := 0.0
var alientest := false
var samplerun := false
var sample_t := 0.0
var sample_no := 0
var sample_mark := ""
var sample_late_t := 0.0
var sample_fired := false
var sample_woke := false
var sample_climbed := false
var ali: Bug
var ali_step := 0
var ali_t := 0.0
var ali_failed := false
var ali_planted: Array[bool] = []
var ali_feet: Array[Vector2] = []
var ali_slips := 0
var ali_off_surface := 0
var ali_bad_bones := 0
var ali_backward := 0
var ali_gait_breaks := 0
var ali_frames := 0
var ali_cross_frames := 0
var ali_cross_turning := 0
var ali_body_lag := 0.0
var ali_cross_dark := 0
var ali_turn_frames := 0
var ali_mixed_frames := 0
var ali_seen: Bug
var ali_seen_wall := false
var ali_seen_ceiling := false
var ali_shots_while_moving := 0
var ali_h_before := 0.0
var ali_body_y := 0.0
var ali_body_moved := false
var ali_corpse_low := false
var ali_soak_t := 0.0
var ali_soak_input := Vector2.ZERO
var soak_hits := 0
var soak_close_frames := 0
var soak_ready := 0
var soak_aimed := 0
var soak_bullets := 0
var soak_no_target := 0
var leveltest := false
var lv_t := 0.0
## Each alien seen, and how long it has now sat at rest.
var lv_seen: Dictionary = {}
var lv_frenzies: Array[float] = []
var lv_nearest_spawn := INF
var lv_longest_rest := 0.0
var lv_shot_walking := 0
var lv_most_at_once := 0
var lv_next_shot := 6.0


func setup(g: Game, user_args: PackedStringArray) -> void:
	game = g
	args = user_args
	use_exit = args.has("--exit")
	stress = args.has("--stress")
	joytest = args.has("--joytest")
	parallaxtest = args.has("--parallaxtest")
	introtest = args.has("--introtest")
	alientest = args.has("--alientest")
	samplerun = args.has("--samplerun")
	leveltest = args.has("--leveltest")
	if args.has("--maptest"):
		_run_maptest()
		return
	game.input_override_on = not joytest
	if args.has("--god"):
		game.player.god_mode = true
	for a in args:
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
		if a.begins_with("--speed="):
			Engine.time_scale = float(a.trim_prefix("--speed="))
	game.sfx.muted = true
	if stress:
		_start_stress()
	if parallaxtest:
		game.player.god_mode = true
		game.next_wave_t = 9999.0
	if alientest:
		_start_alientest()
	if samplerun:
		game.player.god_mode = true
		game.player.x = 760.0
	if leveltest:
		game.player.god_mode = not args.has("--mortal")
	print("[bot] started, seed run, args=", args)


func _start_stress() -> void:
	game.player.god_mode = true
	game.player.lasers = 1
	game.player.drones = 2
	game.player.grenades = 1
	game.player.pierce = 2
	game.next_wave_t = 9999.0
	var f := game.player.f
	var room := game.level.start_room
	var aliens := 8
	for a in args:
		if a.begins_with("--aliens="):
			aliens = int(a.trim_prefix("--aliens="))
	var kinds := [Bug.Kind.WORKER, Bug.Kind.LEAPER, Bug.Kind.WARRIOR]
	while game.horde.list.size() < (aliens if game.sample_mode else game.t.max_bugs):
		var kind: Bug.Kind = Bug.Kind.ALIEN if game.sample_mode else kinds[randi() % 3]
		var bug := game.horde.spawn(kind, randf_range(room.x0 + 40.0, room.x1 - 40.0), f, true)
		bug.hp = 1000000.0
		bug.max_hp = bug.hp
	for d in game.level.doors:
		d.broken = true
	last_tick = Time.get_ticks_usec()


func _process(dt: float) -> void:
	if finished:
		return
	if stress:
		_measure()
		return
	if joytest:
		_run_joytest(dt)
		return
	if parallaxtest:
		_run_parallaxtest(dt)
		return
	if introtest:
		_run_introtest(dt)
		return
	if alientest:
		_run_alientest(dt)
		return
	if samplerun:
		_run_samplerun(dt)
		return
	if leveltest:
		_run_leveltest(dt)
		return
	if game.state == Game.State.CARD and shots_dir != "" and not card_shot_done:
		card_shot_done = true
		await _save("cards")
	_handle_modals()
	if game.state == Game.State.RESULT:
		_finish()
		return
	_drive()
	_maybe_screenshot()
	report_t -= dt
	if report_t <= 0.0:
		report_t = 30.0
		print("[bot] t=%d floor=%d x=%d hp=%d danger=%d bugs=%d bag=%d cash=%d kills=%d lvl=%d rescue=%d" % [game.run_t, game.player.f, game.player.x, game.player.hp, game.danger, game.horde.list.size(), game.backpack_used(), game.cash, game.kills, game.level_no, game.rescue])


## Sends the same touch events a phone would send, then checks the hero reacted.
func _run_joytest(dt: float) -> void:
	joy_t += dt
	match joy_stage:
		0:
			joy_start_x = game.player.x
			_touch(Vector2(200.0, 900.0), true)
			_drag(Vector2(290.0, 900.0))
			joy_stage = 1
			joy_t = 0.0
		1:
			if joy_t > 0.5:
				_touch(Vector2(290.0, 900.0), false)
				var moved := game.player.x - joy_start_x
				print("[joytest] drag right moved hero by %.0f px: %s" % [moved, "PASS" if moved > 50.0 else "FAIL"])
				var released := game.hud.joy_vector()
				print("[joytest] release clears stick: %s" % ("PASS" if released == Vector2.ZERO else "FAIL"))
				_touch(Hud.DASH_CENTER, true)
				_touch(Hud.DASH_CENTER, false)
				joy_stage = 2
				joy_t = 0.0
		2:
			if joy_t > 0.1:
				print("[joytest] dash button starts cooldown: %s" % ("PASS" if game.player.dash_cd > 0.0 else "FAIL"))
				_touch(Vector2(200.0, 900.0), true)
				_drag(Vector2(200.0, 800.0))
				joy_stage = 3
				joy_t = 0.0
		3:
			if joy_t > 0.1:
				var ground := game.arena.ground_at(game.player.x) if game.arena != null else 0.0
				print("[joytest] drag up does not jump: %s" % ("PASS" if is_equal_approx(game.player.h, ground) else "FAIL"))
				finished = true
				get_tree().quit(0)


## Checks what must hold for every seed, then reports how much the maps vary.
func _run_maptest() -> void:
	var t := game.t
	var runs := 500
	var layouts: Dictionary = {}
	var failures := 0
	var left_steps := 0
	var total_rooms := 0
	var total_ladders := 0
	var total_crates := 0
	var total_halls := 0
	var total_side := 0
	for s in runs:
		var l := Level.new(t, s + 1)
		var problem := _map_problem(l)
		if problem != "":
			failures += 1
			print("[map] seed %d: %s" % [s + 1, problem])
		left_steps += _route_left_steps(l)
		var key := ""
		for r in l.rooms:
			key += "%d.%d.%d " % [r.f, r.c0, r.c1]
			if r.c1 > r.c0:
				total_halls += 1
			if not r.on_route:
				total_side += 1
		layouts[key] = true
		l.release()
		total_rooms += l.rooms.size()
		total_ladders += l.ladders.size()
		total_crates += l.crates.size()
	var d := float(runs)
	print("[map] room width %.0f (was 420, +%.0f%%)" % [t.room_w, (t.room_w / 420.0 - 1.0) * 100.0])
	print("[map] per map: rooms %.1f, side rooms %.1f, halls %.1f, ladders %.1f, crates %.1f" % [total_rooms / d, total_side / d, total_halls / d, total_ladders / d, total_crates / d])
	print("[map] every map valid: %s (%d bad of %d)" % ["PASS" if failures == 0 else "FAIL", failures, runs])
	print("[map] route to goal never steps left: %s (%d left steps)" % ["PASS" if left_steps == 0 else "FAIL", left_steps])
	print("[map] distinct layouts: %d of %d: %s" % [layouts.size(), runs, "PASS" if layouts.size() > runs * 0.9 else "FAIL"])
	var same_a := Level.new(t, 77)
	var same_b := Level.new(t, 77)
	print("[map] same seed gives same map: %s" % ("PASS" if same_a.route == same_b.route and same_a.rooms.size() == same_b.rooms.size() else "FAIL"))
	same_a.release()
	same_b.release()
	finished = true
	get_tree().quit(0 if failures == 0 and left_steps == 0 else 1)


func _map_problem(l: Level) -> String:
	if l.start_room.f != 0 or l.start_room.c0 != 0:
		return "start is not at the left on the ground"
	if l.goal_room.f != 0 or l.goal_room.c1 != game.t.cols - 1:
		return "goal is not at the right on the ground"
	var field := l.build_field(l.goal_room.id)
	for r in l.rooms:
		if r != l.goal_room and field[r.id] == null:
			return "room %d cannot reach the goal" % r.id
		if r.x1 - r.x0 < game.t.room_w:
			return "room %d is too narrow" % r.id
	for d in l.doors:
		if d.room_a.f != d.f or d.room_b.f != d.f or d.room_a.x1 != d.x or d.room_b.x0 != d.x:
			return "door at %.0f does not join its rooms" % d.x
	for lad in l.ladders:
		if lad.x <= lad.low_room.x0 or lad.x >= lad.low_room.x1 or lad.x <= lad.high_room.x0 or lad.x >= lad.high_room.x1:
			return "ladder at %.0f is outside its rooms" % lad.x
		if lad.high_room.f != lad.low_room.f + 1:
			return "ladder at %.0f skips a floor" % lad.x
	for c in l.crates:
		if c.x <= c.room.x0 or c.x >= c.room.x1:
			return "crate outside its room"
	return ""


## Walks from start to goal using the guide arrow's route and counts backward moves.
func _route_left_steps(l: Level) -> int:
	var field := l.build_field(l.goal_room.id)
	var count := 0
	var x := l.start_room.x0
	var room := l.start_room
	while room != l.goal_room:
		var step: Level.Step = field[room.id]
		if step.x < x - 1.0:
			count += 1
		x = step.x
		room = l.rooms[step.to_room]
	return count


## Walks up to a resting alien, stands and lets it act, then shoots it. With --shots,
## saves a frame each time it changes state and prints where it is on screen.
func _run_samplerun(dt: float) -> void:
	sample_t += dt
	var firing := sample_t >= 14.0
	if not firing:
		game.weapons.fire_timer = 9999.0
	elif not sample_fired:
		sample_fired = true
		game.weapons.fire_timer = 0.0
	var bug: Bug = game.horde.corpses[0] if not game.horde.corpses.is_empty() else (game.horde.list[0] if not game.horde.list.is_empty() else null)
	if bug != null:
		var dist: float = absf(bug.x - game.player.x)
		game.input_override = Vector2(signf(bug.x - game.player.x), 0.0) if sample_t > 2.5 and dist > 300.0 and not sample_woke else Vector2.ZERO
		if dist <= 300.0:
			sample_woke = true
		# Partway through, set it up for the climb and the leap.
		if sample_t > 6.0 and not sample_climbed and bug.rig.on_surface():
			sample_climbed = true
			game.player.x = 1340.0
			bug.rig.place(game.arena.floor_s(1570.0), bug)
			bug.rig.set_state(AlienRig.State.CRAWL)
			bug.leap_cd = 3.0
		if sample_climbed and not firing and bug.rig.state == AlienRig.State.CRAWL:
			bug.rig.high_route = true
			bug.rig.route_t = 9.0
		var rig := bug.rig
		sample_late_t -= dt
		var mark := "%d" % rig.state
		if rig.state == AlienRig.State.DEAD:
			mark = "%d_%d" % [rig.state, int(rig.state_t / 0.35)]
		elif rig.state == AlienRig.State.CRAWL:
			mark = "%d_%d" % [rig.state, 0 if rig.on_floor_side() else (1 if absf(rig.normal.x) > 0.7 else 2)]
		# Waits for the peak of each move, which is what is worth looking at.
		var peak := 0.05
		match rig.state:
			AlienRig.State.WINDUP:
				peak = 0.28
			AlienRig.State.STRIKE:
				peak = 0.12
			AlienRig.State.IDLE, AlienRig.State.RECOVER:
				peak = 0.3
		var at: Vector2 = get_viewport().get_canvas_transform() * rig.pos
		var seen := at.x > 60.0 and at.x < 826.0
		if shots_dir != "" and seen and mark != sample_mark and rig.state_t > peak and sample_late_t <= 0.0:
			sample_mark = mark
			sample_no += 1
			sample_late_t = 0.05
			var label := "%03d_s%s" % [sample_no, mark]
			print("[shot] %s %d %d" % [label, at.x, at.y])
			await _save(label)
	if sample_t > 24.0:
		finished = true
		get_tree().quit(0)


func _start_alientest() -> void:
	# Checks the default stance, not whatever has been saved by hand in the rig lab.
	game.art.alien.use_defaults()
	game.art.alien.motion = AlienArt.DEFAULT_MOTION.duplicate(true)
	_check_second_order()
	var p := game.player
	p.god_mode = true
	game.input_override = Vector2.ZERO
	game.weapons.fire_timer = 9999.0
	var bug: Bug = game.horde.list[0]
	bug.dead = true
	game.horde.list.clear()
	_check_arena()
	_check_rest_pose()
	_check_leg_reach()
	_check_turning()
	_check_kinds()
	_check_frenzy()
	_check_leg_length()
	_check_point_blank()
	ali = _new_alien(1000.0)
	game.respawn_t = 9999.0


func _check_second_order() -> void:
	var dt := 1.0 / 60.0
	var goal := Vector2(100.0, 0.0)
	var bouncy := SecondOrder.new(3.0, 0.4, 0.0)
	var firm := SecondOrder.new(3.0, 1.0, 0.0)
	var eager := SecondOrder.new(3.0, 0.5, -2.0)
	var top_bouncy := 0.0
	var top_firm := 0.0
	var low_eager := 0.0
	for i in 240:
		top_bouncy = maxf(top_bouncy, bouncy.update(dt, goal).x)
		top_firm = maxf(top_firm, firm.update(dt, goal).x)
		# Anticipation answers a target that starts moving, not one that teleports.
		low_eager = minf(low_eager, eager.update(dt, Vector2(i * 5.0, 0.0)).x)
	_alien_result("feel: settles on the target", absf(bouncy.value.x - 100.0) < 0.5 and absf(firm.value.x - 100.0) < 0.5)
	_alien_result("feel: zeta under 1 overshoots (%.0f)" % top_bouncy, top_bouncy > 105.0)
	_alien_result("feel: zeta of 1 does not (%.1f)" % top_firm, top_firm < 100.5)
	_alien_result("feel: negative r pulls back first (%.0f)" % low_eager, low_eager < -1.0)
	# A lag spike on a very stiff setting must not launch it.
	var stiff := SecondOrder.new(12.0, 0.05, 3.0)
	var worst := 0.0
	for i in 400:
		var long_frame := 0.25 if i % 7 == 0 else dt
		worst = maxf(worst, absf(stiff.update(long_frame, goal if i % 20 < 10 else -goal).x))
	_alien_result("feel: lag spikes on a stiff setting stay bounded (%.0f)" % worst, is_finite(worst) and worst < 2000.0)
	var turning := SecondOrder.new(3.0, 1.0, 0.0, Vector2(3.0, 0.0))
	var furthest := 0.0
	for i in 120:
		var a := turning.update_angle(dt, -3.0)
		furthest = maxf(furthest, absf(wrapf(a - 3.0, -PI, PI)))
	_alien_result("feel: an angle takes the short way round (%.2f rad)" % furthest, furthest < 0.4)


func _rig_up(rig: AlienRig) -> Vector2:
	return Vector2(sin(rig.angle), -cos(rig.angle))


## True when the knee sits on the far side of the line from hip to ankle.
func _knee_flipped(rig: AlienRig, leg: AlienRig.Leg) -> bool:
	var a := leg.ankle - leg.hip
	var k := leg.knee - leg.hip
	if a.length() < 1.0:
		return false
	return signf(a.cross(k)) != leg.hinge * rig.side and absf(a.cross(k)) > 1.0


## True when the shin folds against the way the rest of the leg turns. Never allowed.
func _shin_backward(rig: AlienRig, leg: AlienRig.Leg) -> bool:
	return (leg.ankle - leg.knee).cross(leg.tip - leg.ankle) * -leg.hinge * rig.side < -1.0


## Crawls the whole loop both ways and measures how far each foot lands from where the
## stance wants it, and how close each leg comes to full stretch.
func _check_leg_reach() -> void:
	var bug := game.horde.spawn(Bug.Kind.ALIEN, 150.0, 0, true)
	var rig := bug.rig
	var a := game.arena
	var dt := 1.0 / 60.0
	var worst := 0.0
	var worst_at := Vector2.ZERO
	var worst_leg := ""
	var strained := 0
	var flips := 0
	var backward := 0
	var behinds := 0
	var tightest_knee := 180.0
	var shut_knees := 0
	var tightest_ankle := 180.0
	var frames := 0
	for dir: float in [1.0, -1.0]:
		rig.place(a.floor_s(150.0), bug)
		rig.turn_now(dir)
		rig.want_face = dir
		rig.set_state(AlienRig.State.CRAWL)
		var moved := 0.0
		while moved < a.length:
			# At the pace it really goes, which is where a leg gets left behind.
			var step := bug.speed * rig.dart(dt) * dt
			rig.s = fposmod(rig.s + dir * step, a.length)
			moved += step
			rig.update(bug, dt)
			frames += 1
			var over := false
			var flipped := false
			var behind := false
			for leg in rig.legs:
				var knee_open := absf(rad_to_deg((leg.hip - leg.knee).angle_to(leg.ankle - leg.knee)))
				tightest_knee = minf(tightest_knee, knee_open)
				if knee_open < SHUT_KNEE:
					shut_knees += 1
				tightest_ankle = minf(tightest_ankle, absf(rad_to_deg((leg.knee - leg.ankle).angle_to(leg.tip - leg.ankle))))
				flipped = flipped or _knee_flipped(rig, leg)
				if _shin_backward(rig, leg):
					backward += 1
				if leg.u >= 1.0 and (leg.foot - leg.hip).dot(_rig_up(rig)) > AlienRig.BEHIND_BACK:
					behind = true
				if leg.u < 1.0:
					continue
				var pull := leg.hip.distance_to(leg.foot) / leg.reach
				over = over or pull > STRAINED
				if pull > worst:
					worst = pull
					worst_at = rig.pos
					worst_leg = leg.name
			if over:
				strained += 1
			if flipped:
				flips += 1
			if behind:
				behinds += 1
	print("[alien] crawling the whole room: worst leg stretch %.0f%% (%s at %s), strained in %d of %d frames" % [worst * 100.0, worst_leg, worst_at, strained, frames])
	print("[alien] tightest knee %.0f deg (under %d in %d leg frames), tightest ankle %.0f deg" % [tightest_knee, SHUT_KNEE, shut_knees, tightest_ankle])
	_alien_result("knees are not shut flat", shut_knees * 100 < frames * 4)
	print("[alien] knees bent the wrong way in %d of %d frames, a planted foot behind the back in %d" % [flips, frames, behinds])
	_alien_result("knees rarely bend the other way (%.1f%% of frames)" % (100.0 * flips / frames), flips * 20 < frames)
	_alien_result("shins never fold backward (%d leg frames)" % backward, backward == 0)
	_alien_result("planted legs stay within reach all around the room", worst <= STRETCH_LIMIT)
	_alien_result("legs are rarely near full stretch (%.1f%% of frames)" % (100.0 * strained / frames), strained * 20 < frames)
	bug.dead = true
	game.horde.list.erase(bug)


## Back and forth on flat floor, calm and frantic. Turning around must not leave a leg
## reaching back across the body with its knee pushed down, and no foot may move to do it.
func _check_turning() -> void:
	var a := game.arena
	var dt := 1.0 / 60.0
	for frenzy: float in [0.0, 1.0]:
		var bug := game.horde.spawn(Bug.Kind.ALIEN, 160.0, 0, true)
		bug.speed = 150.0
		var rig := bug.rig
		rig.set_frenzy(frenzy)
		rig.place(a.floor_s(160.0), bug)
		rig.turn_now(1.0)
		rig.set_state(AlienRig.State.CRAWL)
		var dir := 1.0
		var turns := 0
		var under := 0
		var under_running := 0
		var moved_feet := 0
		var last_side := rig.side
		for i in 1800:
			if rig.pos.x > 300.0:
				dir = -1.0
			elif rig.pos.x < 60.0:
				dir = 1.0
			rig.want_face = dir
			rig.s = fposmod(rig.s + dir * bug.speed * rig.dart(dt) * dt, a.length)
			var planted: Array[Vector2] = []
			for leg in rig.legs:
				if leg.u >= 1.0:
					planted.append(leg.foot)
			rig.update(bug, dt)
			if rig.side != last_side:
				last_side = rig.side
				turns += 1
				for at in planted:
					var kept := false
					for leg in rig.legs:
						kept = kept or leg.foot.distance_to(at) < 0.01
					if not kept:
						moved_feet += 1
			for leg in rig.legs:
				var line := leg.foot - leg.hip
				var perp := Vector2(-line.y, line.x)
				if perp.y > 0.0:
					perp = -perp
				# With the foot right under the hip there is no telling which side is under.
				if absf(line.x) > 12.0 and (leg.knee - leg.hip).dot(perp.normalized()) < -1.0:
					if rig.since_turn < TURN_SETTLE:
						under += 1
					else:
						under_running += 1
		print("[alien] turning at frenzy %.0f: %d turns, knee under its line just after one in %d leg frames, and in %d while running on" % [frenzy, turns, under, under_running])
		_alien_result("turning at frenzy %.0f: it does turn" % frenzy, turns >= 5)
		_alien_result("turning at frenzy %.0f: no foot moves to do it (%d did)" % [frenzy, moved_feet], moved_feet == 0)
		# A frantic run leaves front feet behind the hips anyway, so only calm shows the turn.
		if frenzy == 0.0:
			_alien_result("turning: knees stay up (%.1f leg frames a turn)" % (float(under) / maxi(turns, 1)), under <= turns * KNEE_UNDER_PER_TURN)
		bug.dead = true
		game.horde.list.erase(bug)


## Every kind: insects, so 6 limbs of 3 segments, whose legs hold up all around the room.
## Then what each one does that the others do not.
func _check_kinds() -> void:
	var a := game.arena
	var dt := 1.0 / 60.0
	var kinds: Array[Bug.Kind] = [Bug.Kind.ALIEN_BOMBER, Bug.Kind.ALIEN_LEAPER, Bug.Kind.ALIEN_STALKER, Bug.Kind.ALIEN_CHARGER]
	for kind in kinds:
		var bug := game.horde.spawn(kind, 200.0, 0, true)
		var rig := bug.rig
		var label: String = Bug.STATS[kind].art
		var segments := true
		for limb: String in rig.bones:
			var joints: Array[Vector2] = rig.bones[limb]
			segments = segments and joints.size() == 4
		_alien_result("%s: 4 legs, 2 forelimbs, 3 segments each" % label, rig.legs.size() == 4 and rig.arms.size() == 2 and rig.bones.size() == 6 and segments)
		rig.place(a.floor_s(200.0), bug)
		rig.turn_now(1.0)
		rig.want_face = 1.0
		rig.set_state(AlienRig.State.CRAWL)
		# The boss keeps to the floor. The rest can go anywhere.
		var limit := Arena.WIDTH - 300.0 if kind == Bug.Kind.ALIEN_CHARGER else a.length
		var backward := 0
		var shut := 0
		var bad_bones := 0
		var worst := 0.0
		var moved := 0.0
		var frames := 0
		while moved < limit:
			var step := bug.speed * maxf(rig.dart(dt), 0.0) * dt + 1.0
			rig.s = fposmod(rig.s + step, a.length)
			moved += step
			rig.update(bug, dt)
			frames += 1
			for leg in rig.legs:
				if _shin_backward(rig, leg):
					backward += 1
				if rad_to_deg(absf((leg.hip - leg.knee).angle_to(leg.ankle - leg.knee))) < SHUT_KNEE:
					shut += 1
				if absf(leg.hip.distance_to(leg.knee) - leg.thigh) > 0.5 or absf(leg.knee.distance_to(leg.ankle) - leg.calf) > 0.5:
					bad_bones += 1
				if leg.u >= 1.0:
					worst = maxf(worst, leg.hip.distance_to(leg.foot) / leg.reach)
		_alien_result("%s: shins never fold backward (%d leg frames)" % [label, backward], backward == 0)
		_alien_result("%s: knees not shut flat (%d of %d leg frames)" % [label, shut, frames * 4], shut * 100 < frames * 4)
		_alien_result("%s: bone lengths hold (%d bad)" % [label, bad_bones], bad_bones * 100 < frames * 4)
		_alien_result("%s: planted legs stay within reach (worst %.0f%%)" % [label, worst * 100.0], worst <= STRETCH_LIMIT)
		bug.dead = true
		game.horde.list.erase(bug)
	game.horde.boss = null
	_check_bomber()
	_check_stalker()
	_check_shields()
	game.kills = 0
	game.horde.corpses.clear()
	game.horde.list.clear()
	game.horde.boss = null
	game.weapons.bullets.clear()
	game.weapons.target = null


func _check_bomber() -> void:
	var p := game.player
	var a := game.arena
	p.x = 200.0
	p.h = a.ground_at(200.0)
	p.god_mode = false
	p.iframes = 0.0
	var worker := game.horde.spawn(Bug.Kind.ALIEN, 900.0, 0, true)
	worker.rig.place(a.floor_s(900.0), worker)
	var shot := game.horde.spawn(Bug.Kind.ALIEN_BOMBER, 880.0, 0, true)
	shot.rig.place(a.floor_s(880.0), shot)
	var before := worker.hp
	game.kill_bug(shot, false)
	_alien_result("bomber: shot down it hurts the aliens around it", worker.hp < before)
	_alien_result("bomber: it leaves no corpse", game.horde.corpses.is_empty())
	var hero_hp := p.hp
	var far := game.horde.spawn(Bug.Kind.ALIEN_BOMBER, 240.0, 0, true)
	far.rig.place(a.floor_s(240.0), far)
	game.kill_bug(far, false)
	_alien_result("bomber: shot down right beside the hero, it does not hurt him", p.hp == hero_hp)
	var fuse := game.horde.spawn(Bug.Kind.ALIEN_BOMBER, 240.0, 0, true)
	fuse.rig.place(a.floor_s(240.0), fuse)
	game.kill_bug(fuse, true)
	_alien_result("bomber: its own fuse does (%.0f of %.0f hp)" % [p.hp, hero_hp], p.hp < hero_hp)
	p.hp = p.max_hp
	p.god_mode = true
	worker.dead = true
	game.horde.list.erase(worker)
	game.horde.list.erase(shot)
	game.horde.list.erase(far)
	game.horde.list.erase(fuse)


func _check_stalker() -> void:
	var p := game.player
	var a := game.arena
	p.x = 120.0
	p.h = a.ground_at(120.0)
	var w := game.weapons
	var bug := game.horde.spawn(Bug.Kind.ALIEN_STALKER, 300.0, 0, true)
	bug.rig.place(a.floor_s(300.0), bug)
	bug.rig.cloak = 1.0
	_alien_result("stalker: cloaked, the gun does not find it", w._pick_target(p.x, p.h + Weapons.MUZZLE_H, p.f) == null)
	bug.rig.flinch(0.0)
	game.horde._update_cloak(bug, 0.5)
	_alien_result("stalker: being shot shows it (%.2f)" % bug.rig.cloak, bug.rig.cloak < 0.5)
	_alien_result("stalker: shown, the gun finds it", w._pick_target(p.x, p.h + Weapons.MUZZLE_H, p.f) == bug)
	bug.dead = true
	game.horde.list.erase(bug)


## A closed shield turns a shot from the front, and only from the front.
func _check_shields() -> void:
	var p := game.player
	var a := game.arena
	var w := game.weapons
	var dt := 1.0 / 60.0
	p.x = 200.0
	p.h = a.ground_at(200.0)
	var bug := game.horde.spawn(Bug.Kind.ALIEN_CHARGER, 700.0, 0, true)
	var rig := bug.rig
	rig.place(a.floor_s(700.0), bug)
	rig.turn_now(-1.0)
	rig.want_face = -1.0
	rig.set_state(AlienRig.State.BRACE)
	rig.guard = 1.0
	for i in 60:
		rig.update(bug, dt)
	game.horde._rebuild_grid()
	var before := bug.hp
	_shoot_at(bug, 400.0)
	_alien_result("shields: closed, a shot from the front glances off", bug.hp == before)
	rig.turn_now(1.0)
	rig.want_face = 1.0
	_shoot_at(bug, 400.0)
	_alien_result("shields: from behind it does not (%.0f of %.0f hp)" % [bug.hp, before], bug.hp < before)
	before = bug.hp
	rig.turn_now(-1.0)
	rig.want_face = -1.0
	rig.guard = 0.0
	rig.set_state(AlienRig.State.STUN)
	for i in 60:
		rig.update(bug, dt)
	_shoot_at(bug, 400.0)
	_alien_result("shields: open, a shot from the front lands", bug.hp < before)
	bug.dead = true
	game.horde.list.erase(bug)
	game.horde.boss = null
	w.bullets.clear()


func _shoot_at(bug: Bug, from_x: float) -> void:
	var w := game.weapons
	w.bullets.clear()
	var muzzle_h := bug.aim_h()
	w._spawn_bullet(from_x, muzzle_h, bug.f, Vector2(signf(bug.x - from_x), 0.0), 20.0, 0, 0)
	for i in 40:
		w._update_bullets(1.0 / 60.0)
	w.bullets.clear()


## It should bolt and stop, stay fair on average, and do none of it at no frenzy.
func _check_frenzy() -> void:
	var bug := game.horde.spawn(Bug.Kind.ALIEN, 150.0, 0, true)
	var rig := bug.rig
	var dt := 1.0 / 60.0
	var fastest := 0.0
	var stopped := 0
	var backward := 0
	var total := 0.0
	var frames := 1800
	for i in frames:
		var pace := rig.dart(dt)
		fastest = maxf(fastest, pace)
		total += pace
		if is_zero_approx(pace):
			stopped += 1
		if pace < 0.0:
			backward += 1
	var mean := total / frames
	_alien_result("frenzy: it bolts at %.1f times its speed" % fastest, fastest > 2.5)
	_alien_result("frenzy: it stops dead (%.0f%% of the time)" % (100.0 * stopped / frames), stopped * 10 > frames and stopped * 2 < frames)
	_alien_result("frenzy: it jerks backward now and then (%.0f%% of the time)" % (100.0 * backward / frames), backward > 0 and backward * 5 < frames)
	_alien_result("frenzy: it is no more than twice as fast overall (%.2f)" % mean, mean > 1.0 and mean < 2.0)
	var art := rig.art
	var keep := art.frenzy
	art.frenzy = 0.0
	rig.apply_motion()
	var even := true
	for i in 60:
		even = even and is_equal_approx(rig.dart(dt), 1.0)
	_alien_result("frenzy: at 0 it keeps an even pace", even)
	art.frenzy = keep
	bug.dead = true
	game.horde.list.erase(bug)


## Long legs and short legs both have to hold up all the way around the room.
func _check_leg_length() -> void:
	var art := game.art.alien
	var a := game.arena
	var dt := 1.0 / 60.0
	for length: float in [0.6, 1.8]:
		art.leg_length["all"] = length
		var bug := game.horde.spawn(Bug.Kind.ALIEN, 150.0, 0, true)
		var rig := bug.rig
		rig.place(a.floor_s(150.0), bug)
		rig.turn_now(1.0)
		rig.want_face = 1.0
		rig.set_state(AlienRig.State.CRAWL)
		var worst := 0.0
		var shut := 0
		var flips := 0
		var backward := 0
		var frames := 0
		var moved := 0.0
		while moved < a.length:
			var step := bug.speed * rig.dart(dt) * dt
			rig.s = fposmod(rig.s + step, a.length)
			moved += step
			rig.update(bug, dt)
			frames += 1
			var flipped := false
			for leg in rig.legs:
				if rad_to_deg(absf((leg.hip - leg.knee).angle_to(leg.ankle - leg.knee))) < SHUT_KNEE:
					shut += 1
				flipped = flipped or _knee_flipped(rig, leg)
				if _shin_backward(rig, leg):
					backward += 1
				if leg.u >= 1.0:
					worst = maxf(worst, leg.hip.distance_to(leg.foot) / leg.reach)
			if flipped:
				flips += 1
		_alien_result("legs at %.1f times: shins never fold backward (%d leg frames)" % [length, backward], backward == 0)
		_alien_result("legs at %.1f times: stay in reach (worst %.0f%%)" % [length, worst * 100.0], worst <= STRETCH_LIMIT)
		_alien_result("legs at %.1f times: knees not shut flat (%d of %d leg frames)" % [length, shut, frames * 4], shut * 100 < frames * 4)
		_alien_result("legs at %.1f times: knees rarely bend the other way (%.1f%% of frames)" % [length, 100.0 * flips / frames], flips * 20 < frames)
		bug.dead = true
		game.horde.list.erase(bug)
	art.leg_length["all"] = 1.0


## A shot at an alien standing right on the hero, on the floor, against a wall and
## on a slope, has to land. A bullet starting past it, or going into the floor, would not.
func _check_point_blank() -> void:
	var p := game.player
	var w := game.weapons
	var a := game.arena
	var missed: Array[String] = []
	for spot: float in [200.0, 25.0, 390.0, 1100.0]:
		for offset: float in [0.0, 30.0, -30.0]:
			var bug := game.horde.spawn(Bug.Kind.ALIEN, clampf(spot + offset, 30.0, Arena.WIDTH - 30.0), 0, true)
			p.x = spot
			p.h = a.ground_at(spot)
			game.horde._rebuild_grid()
			w.target = bug
			w.bullets.clear()
			var before := bug.hp
			w._fire(p)
			for i in 6:
				w._update_bullets(1.0 / 60.0)
			if bug.hp >= before:
				missed.append("%d%+d" % [spot, offset])
			bug.dead = true
			game.horde.list.erase(bug)
	w.bullets.clear()
	w.target = null
	game.kills = 0
	p.x = 200.0
	p.h = a.ground_at(200.0)
	_alien_result("point-blank shots land everywhere (missed at %s)" % str(missed), missed.is_empty())


func _new_alien(x: float) -> Bug:
	var bug := game.horde.spawn(Bug.Kind.ALIEN, x, 0, true)
	ali_feet.clear()
	return bug


func _check_arena() -> void:
	var a := game.arena
	var wrong := 0
	for i in 400:
		a.pose(a.length * i / 400.0)
		if not a.contains(a.at + a.normal * 4.0):
			wrong += 1
	_alien_result("loop runs inside the room with its normal facing in (%d wrong of 400)" % wrong, wrong == 0)
	a.pose(a.floor_s(100.0))
	_alien_result("floor runs rightward along the loop", a.normal.y < -0.9)
	_alien_result("hero can walk the whole floor under every hanging block", _floor_clearance() > 76.0)


func _floor_clearance() -> float:
	var a := game.arena
	var least := INF
	var x := 10.0
	while x < Arena.WIDTH - 10.0:
		var ground := game.view.pt(x, a.ground_at(x), 0)
		var hit := a.raycast(ground + Vector2.UP, Vector2.UP, 900.0)
		if hit.is_finite():
			least = minf(least, ground.distance_to(hit))
		x += 20.0
	return least


## On open floor, at rest: hips where the drawing has them, feet in order along the
## floor, no two legs crossing.
func _check_rest_pose() -> void:
	var bug := game.horde.spawn(Bug.Kind.ALIEN, 150.0, 0, true)
	var rig := bug.rig
	rig.turn_now(1.0)
	rig.plant_all()
	var art := game.art.alien
	var worst := 0.0
	var segments := true
	for limb: String in art.limbs:
		var rest: Array[Vector2] = art.limbs[limb]
		segments = segments and rest.size() == 4
		if limb.begins_with("leg_"):
			var joints: Array[Vector2] = rig.bones[limb]
			var hip: Array = art.stance[limb].hip
			worst = maxf(worst, joints[0].distance_to(rig.pos + Vector2(hip[0], hip[1]) * AlienRig.SCALE))
	_alien_result("%d legs and %d arms, 3 segments each" % [rig.legs.size(), rig.arms.size()], rig.legs.size() == 4 and rig.arms.size() == 2 and segments)
	_alien_result("hips sit where the stance has them (worst off by %.2f px)" % worst, worst < 2.0)
	var order := true
	var names: Array[String] = ["leg_rear_near", "leg_rear_far", "leg_front_far", "leg_front_near"]
	for i in 3:
		var a: Array[Vector2] = rig.bones[names[i]]
		var b: Array[Vector2] = rig.bones[names[i + 1]]
		order = order and a[3].x < b[3].x - AlienRig.STRIDE
	_alien_result("feet stand in order, more than a stride apart", order)
	_alien_result("near legs and far legs each keep clear of their own pair at rest", _crossing_pairs(rig, true) == 0)
	_alien_result("body rides at the alien's mid", is_equal_approx(AlienRig.RIDE, bug.mid))
	bug.dead = true
	game.horde.list.erase(bug)


## How many pairs of legs visibly cross right now, either within one depth, or near
## over far. Far legs draw behind the body, so a crossing the body hides does not count.
func _crossing_pairs(rig: AlienRig, same_depth: bool) -> int:
	var count := 0
	var legs := rig.legs
	for i in legs.size():
		for j in range(i + 1, legs.size()):
			var near_a := legs[i].name.ends_with("_near")
			var near_b := legs[j].name.ends_with("_near")
			if (near_a == near_b) == same_depth and _legs_cross(rig, rig.bones[legs[i].name], rig.bones[legs[j].name], near_a and near_b):
				count += 1
	return count


## Near legs draw over the body, so only those two can cross in plain sight on top of it.
func _legs_cross(rig: AlienRig, a: Array[Vector2], b: Array[Vector2], both_near: bool) -> bool:
	for i in 3:
		for j in 3:
			var hit: Variant = Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1])
			if hit != null and (both_near or not _hidden_by_body(rig, hit)):
				return true
	return false


func _hidden_by_body(rig: AlienRig, p: Vector2) -> bool:
	var art := game.art.alien
	var local: Vector2 = rig.body_transform().affine_inverse() * p
	for part: String in ["abdomen", "thorax", "head"]:
		var r: Rect2 = art.parts[part].rect
		var d := (local - r.get_center()) / (r.size * 0.5)
		if d.length() < 1.0:
			return true
	return false


func _next_step() -> void:
	ali_step += 1
	ali_t = 0.0


func _run_alientest(dt: float) -> void:
	ali_t += dt
	var p := game.player
	game.player.hp = game.player.max_hp
	if ali_step == 11 and not game.horde.list.is_empty():
		ali = game.horde.list[0]
	if ali != ali_seen:
		ali_seen = ali
		ali_feet.clear()
	if ali != null and not ali.dead:
		_check_alien_body()
	var rig: AlienRig = ali.rig if ali != null else null
	match ali_step:
		0:
			# The alien is held far off, resting, while the hero's rules are checked.
			p.x = 200.0
			if ali_t > 0.5:
				_alien_result("idle while the hero is far away", rig.state == AlienRig.State.IDLE)
				ali_body_y = rig.body.y
				_next_step()
		1:
			if absf(rig.body.y - ali_body_y) > 0.5:
				ali_body_moved = true
			if ali_t > 1.5:
				_alien_result("idle body breathes", ali_body_moved)
				_alien_result("idle alien keeps its place", rig.state == AlienRig.State.IDLE and rig.velocity.length() < 1.0)
				_park_alien_near_hero()
				game.input_override = Vector2(1.0, 0.0)
				game.weapons.fire_timer = 0.0
				_next_step()
		2:
			_hold_alien()
			if not game.weapons.bullets.is_empty():
				ali_shots_while_moving += 1
			if ali_t > 0.7:
				_alien_result("walking fires (%d frames with bullets)" % ali_shots_while_moving, ali_shots_while_moving > 0)
				_alien_result("walking away, the hero still faces what he shoots at", p.facing == signf(ali.x - p.x))
				_alien_result("hero walks the slopes (x %.0f, h %.0f)" % [p.x, p.h], is_equal_approx(p.h, game.arena.ground_at(p.x)))
				game.input_override = Vector2.ZERO
				_next_step()
		3:
			_hold_alien()
			if ali_t > 0.5:
				_alien_result("standing still fires", game.weapons.fire_timer > 0.0 and game.weapons.fire_timer < 1.0 and game.weapons.target != null)
				ali_h_before = p.h
				game.input_override = Vector2(0.0, -1.0)
				_next_step()
		4:
			_hold_alien()
			if ali_t > 0.5:
				_alien_result("pushing up does not jump", is_equal_approx(p.h, ali_h_before))
				game.input_override = Vector2.ZERO
				game.weapons.fire_timer = 9999.0
				ali.hp = ali.max_hp
				p.x = 870.0
				_place_alien(game.arena.floor_s(1250.0))
				rig.set_state(AlienRig.State.CRAWL)
				rig.high_route = false
				rig.route_t = 9999.0
				_next_step()
		5:
			game.weapons.fire_timer = 9999.0
			rig.route_t = 9999.0
			if rig.hits > 0 or ali_t > 15.0:
				_alien_result("ground route reaches the hero and strikes in %.1f s" % ali_t, rig.hits > 0 and rig.on_floor_side())
				rig.hits = 0
				_place_alien(game.arena.floor_s(1570.0))
				rig.set_state(AlienRig.State.CRAWL)
				rig.high_route = true
				rig.route_t = 9999.0
				ali.leap_cd = 9999.0
				p.x = 1340.0
				_next_step()
		6:
			game.weapons.fire_timer = 9999.0
			rig.route_t = 9999.0
			rig.high_route = true
			if absf(rig.normal.x) > 0.9:
				ali_seen_wall = true
			if rig.normal.y > 0.9:
				ali_seen_ceiling = true
				ali.leap_cd = minf(ali.leap_cd, 0.0)
			if rig.state == AlienRig.State.LEAP or ali_t > 30.0:
				_alien_result("high route climbs the wall", ali_seen_wall)
				_alien_result("high route crosses the ceiling", ali_seen_ceiling)
				_alien_result("leaps from up high in %.1f s" % ali_t, rig.state == AlienRig.State.LEAP)
				_next_step()
		7:
			game.weapons.fire_timer = 9999.0
			if rig.state != AlienRig.State.LEAP or ali_t > 4.0:
				_alien_result("leap comes down on the floor and recovers", rig.state == AlienRig.State.RECOVER and rig.on_floor_side())
				_alien_result("leap can hit the hero", rig.hits > 0)
				_place_alien(game.arena.above_s(300.0, -200.0))
				rig.set_state(AlienRig.State.IDLE)
				p.x = 1500.0
				_next_step()
		8:
			game.weapons.fire_timer = 9999.0
			_hold_alien()
			if ali_t > 0.3:
				game.kill_bug(ali, false)
				_alien_result("death leaves a corpse", game.horde.corpses.size() == 1 and game.kills == 1)
				_next_step()
		9:
			var corpses := game.horde.corpses
			if not corpses.is_empty() and corpses[0].rig.alpha < 1.0:
				ali_corpse_low = absf(corpses[0].h + corpses[0].mid - game.arena.ground_at(corpses[0].x)) < 20.0
			if corpses.is_empty() or ali_t > 3.0:
				_alien_result("corpse falls from the ceiling, curls on the floor and fades", ali_corpse_low)
				_alien_result("death finishes in %.1f s" % ali_t, corpses.is_empty() and ali_t < 2.0)
				game.respawn_t = 0.5
				_next_step()
		10:
			game.weapons.fire_timer = 9999.0
			if not game.horde.list.is_empty():
				_alien_result("a new alien comes after the last one dies", game.horde.list.size() == 1)
				_begin_soak()
				_next_step()
			elif ali_t > 3.0:
				_alien_result("a new alien comes after the last one dies", false)
				_finish_alientest()
		11:
			_run_soak(dt)


## Keeps the test alien in place next to the hero, in his line of fire, without acting.
func _park_alien_near_hero() -> void:
	_place_alien(game.arena.floor_s(game.player.x + 280.0))
	ali.leap_cd = 9999.0


## Moving the alien by hand is not a foot sliding, so the check starts over.
func _place_alien(at_s: float) -> void:
	ali.rig.place(at_s, ali)
	ali_feet.clear()


func _hold_alien() -> void:
	ali.rig.set_state(AlienRig.State.IDLE)
	ali.hp = ali.max_hp


func _begin_soak() -> void:
	game.player.x = 200.0
	game.weapons.fire_timer = 0.0
	game.respawn_t = 1.2
	ali_soak_t = 0.0


## Free play with a hero who wanders and stops at random, the way a person would.
func _run_soak(dt: float) -> void:
	ali_soak_t -= dt
	if ali_soak_t <= 0.0:
		ali_soak_t = randf_range(0.5, 2.0)
		var toward := 1.0 if randf() < 0.5 else -1.0
		if not game.horde.list.is_empty() and game.horde.list[0].x != game.player.x:
			toward = signf(game.horde.list[0].x - game.player.x)
		# Stands about half the time, otherwise heads for the alien or flees.
		ali_soak_input = Vector2(0.0 if randf() < 0.5 else (toward if randf() < 0.7 else -toward), 0.0)
		game.input_override = ali_soak_input
	for bug in game.horde.list:
		soak_hits = maxi(soak_hits, bug.rig.hits)
		_check_can_hit_back(bug)
	_note_soak_gunfire()
	if ali_t > 90.0:
		var high := game.horde.alien_picked_high
		var ground := game.horde.alien_picked_ground
		print("[alien] free play 90 s: %d kills, chose ground %d times and high %d times, most hits in one life %d" % [game.kills - 1, ground, high, soak_hits])
		if game.kills <= 1 and not game.horde.list.is_empty():
			var b: Bug = game.horde.list[0]
			print("[alien] no kills: alien hp %.0f of %.0f at %s state %d, hero x %.0f h %.0f, fire_timer %.1f, frames ready %d aimed %d with bullets %d" % [b.hp, b.max_hp, b.rig.pos, b.rig.state, game.player.x, game.player.h, game.weapons.fire_timer, soak_ready, soak_aimed, soak_bullets])
		_alien_result("free play kills it", game.kills > 1)
		_alien_result("free play picks both routes", high >= 1 and ground >= 1)
		_alien_result("the hero can shoot whatever strikes him (no target in %d of %d frames)" % [soak_no_target, soak_close_frames], soak_no_target * 50 <= soak_close_frames)
		_alien_result("free play lands hits on the hero", soak_hits > 0)
		_finish_alientest()


func _note_soak_gunfire() -> void:
	if game.player.can_shoot():
		soak_ready += 1
		if game.weapons.target != null:
			soak_aimed += 1
	if not game.weapons.bullets.is_empty():
		soak_bullets += 1


## Whatever can strike the hero, he must be able to shoot back at.
func _check_can_hit_back(bug: Bug) -> void:
	var p := game.player
	var center := Vector2(p.x, -p.h - Horde.HERO_MID)
	if not p.can_shoot() or bug.rig.state != AlienRig.State.STRIKE or bug.rig.pos.distance_to(center) > Horde.ALIEN_REACH:
		return
	soak_close_frames += 1
	if game.weapons.target == null:
		soak_no_target += 1
		if soak_no_target == 1:
			print("[alien] no target while being struck: hero %s, alien %s, normal %s" % [center, bug.rig.pos, bug.rig.normal])


## Plays the level to its end with a hero who stands his ground until something comes
## near, then backs away from it, firing the whole time.
func _run_leveltest(dt: float) -> void:
	var p := game.player
	var hero := game.view.pt(p.x, p.h + Horde.HERO_MID, p.f)
	if game.state == Game.State.RESULT or lv_t > 600.0:
		_finish_leveltest()
		return
	lv_t += dt
	var nearest: Bug = null
	var least := INF
	lv_most_at_once = maxi(lv_most_at_once, game.horde.list.size())
	for bug in game.horde.list:
		var d := bug.rig.pos.distance_to(hero)
		if not lv_seen.has(bug):
			lv_seen[bug] = 0.0
			lv_frenzies.append(bug.rig.frenzy)
			lv_nearest_spawn = minf(lv_nearest_spawn, d)
		lv_seen[bug] = float(lv_seen[bug]) + dt if bug.rig.state == AlienRig.State.IDLE else 0.0
		lv_longest_rest = maxf(lv_longest_rest, lv_seen[bug])
		if d < least:
			least = d
			nearest = bug
	var dir := 0.0
	if nearest != null and least < 240.0:
		dir = signf(p.x - nearest.x)
		if p.x < 70.0 or p.x > Arena.WIDTH - 70.0:
			dir = -signf(p.x - Arena.WIDTH * 0.5)
	game.input_override = Vector2(dir, 0.0)
	if absf(p.vx) > 20.0 and game.weapons.muzzle_flash > 0.0:
		lv_shot_walking += 1
	if shots_dir != "" and lv_t >= lv_next_shot:
		lv_next_shot += 12.0
		await _save("level_%d" % lv_t)


func _finish_leveltest() -> void:
	var total := 0
	for kinds: Array in SampleLevel.WAVES:
		total += kinds.size()
	var low := 1.0
	var high := 0.0
	for value in lv_frenzies:
		low = minf(low, value)
		high = maxf(high, value)
	var mortal := args.has("--mortal")
	print("[level] over after %d s: %s, hero at %d hp, %d kills, wave %d, most at once %d" % [lv_t, game.hud.result_title.text, game.player.hp, game.kills, game.sample_level.wave, lv_most_at_once])
	_alien_result("level: it ends on a result screen", game.state == Game.State.RESULT and game.hud.result_root.visible)
	if not mortal:
		_alien_result("level: every wave came (%d of %d aliens)" % [lv_frenzies.size(), total], lv_frenzies.size() == total)
		_alien_result("level: clearing it wins", game.hud.result_title.text == "HOÀN THÀNH MÀN" and game.kills == total)
	_alien_result("level: frenzy runs across 0 to 1 (%.2f to %.2f)" % [low, high], low >= 0.0 and high <= 1.0 and low < 0.35 and high > 0.65)
	_alien_result("level: they appear away from the hero (nearest %.0f px)" % lv_nearest_spawn, lv_nearest_spawn >= SampleLevel.SPAWN_CLEAR * 0.9)
	_alien_result("level: none of them sits waiting (longest %.1f s)" % lv_longest_rest, lv_longest_rest <= SampleLevel.NOTICE_MAX + 1.0)
	_alien_result("level: the hero shoots while walking (%d frames)" % lv_shot_walking, lv_shot_walking > 0)
	print("[level] %s" % ("FAIL" if ali_failed else "ALL PASS"))
	finished = true
	get_tree().quit(1 if ali_failed else 0)


func _check_alien_body() -> void:
	var rig := ali.rig
	# In every state, leaps and strikes included.
	for leg in rig.legs:
		if _shin_backward(rig, leg):
			ali_backward += 1
	# Turning around hands each foot to the leg opposite, which is not a foot sliding.
	if not rig.on_surface() or ali_feet.size() != rig.legs.size() or is_zero_approx(rig.since_turn):
		ali_feet.clear()
		ali_planted.clear()
		for leg in rig.legs:
			ali_feet.append(leg.foot)
			ali_planted.append(false)
		return
	ali_frames += 1
	ali_body_lag = maxf(ali_body_lag, rig.body.distance_to(rig.pos))
	# Just after a strike or a landing the feet are still finding their places.
	var settling := rig.state == AlienRig.State.RECOVER and rig.state_t < 0.35
	# From wanting to turn, when it already walks backward, until the feet have settled.
	var turning := rig.since_turn < TURN_SETTLE or settling or _feet_round_a_corner(rig) or signf(rig.want_face) != rig.side
	if turning:
		ali_turn_frames += 1
	if _crossing_pairs(rig, true) > 0:
		if turning:
			ali_cross_turning += 1
		else:
			ali_cross_frames += 1
			if _legs_cross(rig, rig.bones["leg_rear_near"], rig.bones["leg_front_near"], true):
				ali_cross_dark += 1
	if _crossing_pairs(rig, false) > 0:
		ali_mixed_frames += 1
	var busy := [0, 0]
	for i in rig.legs.size():
		var leg := rig.legs[i]
		var planted := leg.u >= 1.0
		if planted:
			if ali_planted[i] and leg.foot.distance_to(ali_feet[i]) > 0.001:
				ali_slips += 1
			if game.arena.closest_point(leg.foot).distance_to(leg.foot) > 1.0:
				ali_off_surface += 1
		else:
			busy[leg.group] += 1
		if absf(leg.hip.distance_to(leg.knee) - leg.thigh) > 0.5 or absf(leg.knee.distance_to(leg.ankle) - leg.calf) > 0.5:
			ali_bad_bones += 1
		ali_feet[i] = leg.foot
		ali_planted[i] = planted
	if busy[0] > 0 and busy[1] > 0:
		ali_gait_breaks += 1


## True while its feet are not all on the one surface under its body.
func _feet_round_a_corner(rig: AlienRig) -> bool:
	for leg in rig.legs:
		if leg.u >= 1.0 and absf((leg.foot - rig.pos).dot(rig.normal) + AlienRig.RIDE) > 6.0:
			return true
	return false


func _alien_result(label: String, ok: bool) -> void:
	ali_failed = ali_failed or not ok
	print("[alien] %s: %s" % [label, "PASS" if ok else "FAIL"])


func _finish_alientest() -> void:
	var n := maxi(ali_frames, 1)
	print("[alien] checked %d frames" % ali_frames)
	_alien_result("planted feet never slide (%d slips)" % ali_slips, ali_slips == 0)
	_alien_result("planted feet on a surface (%d off of %d leg frames)" % [ali_off_surface, n * 4], ali_off_surface * 1000 < n * 4)
	_alien_result("leg pairs alternate (%d frames with both up, %.1f%%)" % [ali_gait_breaks, 100.0 * ali_gait_breaks / n], ali_gait_breaks * 10 < n)
	_alien_result("bone lengths hold (%d bad)" % ali_bad_bones, ali_bad_bones == 0)
	_alien_result("shins never fold backward in play (%d leg frames)" % ali_backward, ali_backward == 0)
	_alien_result("drawn body stays near the real one (worst %.0f px)" % ali_body_lag, ali_body_lag < 60.0)
	var steady := maxi(n - ali_turn_frames, 1)
	_alien_result("the two dark near legs keep clear on a straight run (%d of %d frames cross)" % [ali_cross_dark, steady], ali_cross_dark * 100 < steady)
	_alien_result("legs of the same depth rarely cross on a straight run (%d of %d frames, %.1f%%)" % [ali_cross_frames, steady, 100.0 * ali_cross_frames / steady], ali_cross_frames * 20 < steady)
	print("[alien] same depth while turning around or rounding a corner: %d of %d frames" % [ali_cross_turning, ali_turn_frames])
	print("[alien] near over far, outside the body: %d frames, %.1f%%" % [ali_mixed_frames, 100.0 * ali_mixed_frames / n])
	print("[alien] %s" % ("FAIL" if ali_failed else "ALL PASS"))
	finished = true
	get_tree().quit(1 if ali_failed else 0)


func _run_introtest(dt: float) -> void:
	if intro_after >= 0.0:
		intro_after += dt
		if shots_dir != "" and not intro_shots.is_empty() and intro_after >= float(intro_shots[0]):
			var at: float = intro_shots.pop_front()
			await _save("after_%.2f" % at)
		if intro_after > 2.2:
			print("[intro] camera settled on hero: %s" % ("PASS" if absf(game.camera.position.y - (game.view.floor_y(0) - game.t.camera_lift)) < 20.0 else "FAIL"))
			finished = true
			get_tree().quit(0)
		return
	var it := game.intro_t
	intro_wall_t += dt
	if game.state != Game.State.INTRO or intro_wall_t > 20.0:
		print("[intro] FAIL: state=%d intro_t=%.2f after %.1f s, frames=%d, big_t=%.2f, landed=%s" % [game.state, it, intro_wall_t, Engine.get_process_frames(), game.backdrop.sky_fx.big_t, game.impact_t])
		finished = true
		get_tree().quit(1)
		return
	if shots_dir != "" and not intro_shots.is_empty() and it >= float(intro_shots[0]):
		var at: float = intro_shots.pop_front()
		await _save("intro_%.1f" % at)
	if not intro_tapped_early and it > 1.0:
		intro_tapped_early = true
		_touch(Vector2(360.0, 640.0), true)
		_touch(Vector2(360.0, 640.0), false)
		print("[intro] early tap is ignored: %s" % ("PASS" if game.state == Game.State.INTRO else "FAIL"))
	if it > 8.5:
		print("[intro] impact happened: %s" % ("PASS" if game.impact_t > 0.0 and game.backdrop.meteor_layer.visible else "FAIL"))
		_touch(Vector2(360.0, 640.0), true)
		_touch(Vector2(360.0, 640.0), false)
		print("[intro] tap starts the run: %s" % ("PASS" if game.state == Game.State.PLAY else "FAIL"))
		intro_after = 0.0
		intro_shots = [0.25, 0.6, 1.5]


## Screen position of a layer's content, taken modulo its repeat size.
func _layer_screen_pos(layer: Parallax2D) -> Vector2:
	var cam_origin := game.camera.get_screen_center_position() - get_viewport().get_visible_rect().size * 0.5
	return layer.global_position - cam_origin


func _run_parallaxtest(dt: float) -> void:
	plx_t += dt
	match plx_stage:
		0:
			plx_layers.assign(game.backdrop.layers)
			if not game.foreground.pieces.is_empty():
				plx_layers.append(game.foreground.pieces[0])
			plx_stage = 1
			plx_t = 0.0
		1:
			if plx_t > 1.5:
				plx_cam = game.camera.get_screen_center_position()
				plx_pos.clear()
				for l in plx_layers:
					plx_pos.append(_layer_screen_pos(l))
				# A floor up and well along the map, so both axes are measured.
				plx_room = _upper_room()
				game.player.f = plx_room.f
				game.player.x = (plx_room.x0 + plx_room.x1) * 0.5 - 120.0
				plx_stage = 2
				plx_t = 0.0
		2:
			if plx_t > 1.5:
				var pan := game.camera.get_screen_center_position() - plx_cam
				print("[parallax] camera moved by ", pan)
				var failed := false
				for i in plx_layers.size():
					var l := plx_layers[i]
					var moved := _layer_screen_pos(l) - plx_pos[i]
					var want := -pan * l.scroll_scale
					var err := Vector2(_wrapped(moved.x - want.x, l.repeat_size.x), _wrapped(moved.y - want.y, l.repeat_size.y))
					if l.autoscroll != Vector2.ZERO:
						print("[parallax] %s scroll=%.2f autoscroll, skipped" % [l.name, l.scroll_scale.x])
						continue
					var ok := err.length() < 2.0
					failed = failed or not ok
					print("[parallax] %s scroll=%.2f moved=%s want=%s: %s" % [l.name, l.scroll_scale.x, moved, want, "PASS" if ok else "FAIL"])
				plx_failed = failed
				plx_panel = game.walls.panel_for(plx_room)
				plx_wall_x = game.walls.content_x(plx_panel)
				plx_cam = game.camera.get_screen_center_position()
				game.player.x += 240.0
				plx_stage = 3
				plx_t = 0.0
		3:
			if plx_t > 1.5:
				var pan_x := game.camera.get_screen_center_position().x - plx_cam.x
				var slid := game.walls.content_x(plx_panel) - plx_wall_x
				var want_slide := pan_x * (1.0 - game.t.scroll_walls)
				var wall_ok := absf(pan_x) > 100.0 and absf(slid - want_slide) < 2.0
				print("[parallax] Walls scroll=%.2f camera %.0f, wall slid %.1f, want %.1f: %s" % [game.t.scroll_walls, pan_x, slid, want_slide, "PASS" if wall_ok else "FAIL"])
				plx_failed = plx_failed or not wall_ok
				print("[parallax] %s" % ("FAIL" if plx_failed else "ALL PASS"))
				finished = true
				get_tree().quit(1 if plx_failed else 0)


func _upper_room() -> Level.Room:
	for r in game.level.rooms:
		if r.f >= 1 and r.c1 - r.c0 == 0:
			return r
	return game.level.rooms[1]


func _wrapped(value: float, repeat: float) -> float:
	if repeat <= 0.0:
		return value
	var m := fposmod(value, repeat)
	return minf(m, repeat - m)


## Takes the HUD's layout units, as a finger on the real screen would land.
func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos * Hud.UI_SCALE
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos * Hud.UI_SCALE
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _measure() -> void:
	var now := Time.get_ticks_usec()
	var used := now - last_tick
	last_tick = now
	stress_frames += 1
	if stress_frames <= 30:
		return
	stress_total_us += used
	stress_worst_us = maxi(stress_worst_us, used)
	if stress_frames % 60 == 0:
		game.player.hp = game.player.max_hp
	if stress_frames == 630:
		var avg := float(stress_total_us) / 600.0 / 1000.0
		print("[stress] bugs=%d bullets=%d avg=%.2f ms (%.0f fps) worst=%.2f ms" % [game.horde.list.size(), game.weapons.bullets.size(), avg, 1000.0 / avg, stress_worst_us / 1000.0])
		finished = true
		get_tree().quit(0)


func _handle_modals() -> void:
	if game.state == Game.State.CARD:
		game.choose_card(0)
	elif game.state == Game.State.REVIVE:
		print("[bot] down at t=%d, reviving" % game.run_t)
		game.revive()


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots_dir, label])


func _finish() -> void:
	finished = true
	if shots_dir != "":
		await _save("result")
	print("[bot] RESULT survived=%s rescue=%d t=%d kills=%d cards=%s" % [game.player.hp > 0.0, game.rescue, game.run_t, game.kills, game.cards_taken])
	print("[bot] ", game.result_text.replace("\n", " | "))
	get_tree().quit(0)


func _drive() -> void:
	var goal_x := _goal()
	var p := game.player
	var dx := goal_x - p.x
	var input := Vector2(signf(dx), 0.0) if absf(dx) > 6.0 else Vector2.ZERO
	if ladder_push != 0.0:
		input = Vector2(0.0, ladder_push)
	game.input_override = input
	if p.hp < p.max_hp * 0.4 and p.dash_cd <= 0.0:
		game.dash_requested = true


## Returns the x to walk to, stepping through doors and ladders.
func _goal() -> float:
	var p := game.player
	ladder_push = 0.0
	var target_room := game.level.goal_room.id
	var target := game.exit_x if use_exit else game.beacon_x
	var crate := _next_crate() if game.run_t < 150.0 else null
	if crate != null:
		target_room = crate.room.id
		target = crate.x
	var here := game.level.room_at(p.f, p.x).id
	if here == target_room:
		return target
	var route: Array = game.level.build_field(target_room)
	var step: Level.Step = route[here]
	if step == null:
		return target
	if step.ladder != null and absf(p.x - step.x) < 12.0 and not p.is_climbing():
		ladder_push = -1.0 if step.going_up else 1.0
	return step.x


## The nearest crate that does not mean turning back.
func _next_crate() -> Level.Crate:
	var p := game.player
	var best: Level.Crate = null
	var best_d := INF
	for c in game.level.crates:
		if c.opened or c.x < p.x - 60.0:
			continue
		var d := absf(c.x - p.x) + absf(c.f - p.f) * 1400.0
		if d < best_d:
			best_d = d
			best = c
	return best


func _maybe_screenshot() -> void:
	if shots_dir == "" or game.run_t < next_shot:
		return
	next_shot += 12.0
	shot_no += 1
	var path := "%s/shot_%03d_t%03d.png" % [shots_dir, shot_no, int(game.run_t)]
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
