extends Node
## Development only. Plays a whole run through the normal input path so the
## game can be tested end to end without a person. Started by command line:
##   -- --bot                 play until the run ends, print the result, quit
##   -- --bot --god           same, but the hero cannot die
##   -- --bot --exit          take the early exit instead of the roof
##   -- --stress              150 awake zombies, print frame times, quit
##   -- --shots=DIR           save a screenshot every 12 s of run time
##   -- --speed=N             run the simulation N times faster
##   -- --joytest             drive the hero with simulated touches, print pass/fail

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
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var wiggle := 0.0
var joytest := false
var joy_stage := 0
var joy_t := 0.0
var joy_start_x := 0.0
var card_shot_done := false


func setup(g: Game, user_args: PackedStringArray) -> void:
	game = g
	args = user_args
	use_exit = args.has("--exit")
	stress = args.has("--stress")
	joytest = args.has("--joytest")
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
	print("[bot] started, seed run, args=", args)


func _start_stress() -> void:
	game.player.god_mode = true
	game.player.lasers = 1
	game.player.drones = 2
	game.player.grenades = 1
	game.player.pierce = 2
	game.next_wave_t = 9999.0
	var f := game.player.f
	while game.horde.list.size() < game.t.max_zombies:
		var kinds := [Zombie.Kind.NORMAL, Zombie.Kind.RUNNER, Zombie.Kind.BRUTE]
		var zb := game.horde.spawn(kinds[randi() % 3], randf_range(40.0, game.level.width - 40.0), randf_range(15.0, game.t.depth - 15.0), f, true)
		zb.hp = 1000000.0
		zb.max_hp = zb.hp
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
	if game.state == Game.State.CARD and shots_dir != "" and not card_shot_done:
		card_shot_done = true
		await _save("cards")
	_handle_modals()
	if game.state == Game.State.RESULT:
		_finish()
		return
	_drive(dt)
	_maybe_screenshot()
	report_t -= dt
	if report_t <= 0.0:
		report_t = 30.0
		print("[bot] t=%d floor=%d x=%d hp=%d danger=%d zombies=%d bag=%d cash=%d kills=%d lvl=%d rescue=%d" % [game.run_t, game.player.f, game.player.x, game.player.hp, game.danger, game.horde.list.size(), game.backpack_used(), game.cash, game.kills, game.level_no, game.rescue])


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
				finished = true
				get_tree().quit(0)


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
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
		print("[stress] zombies=%d bullets=%d avg=%.2f ms (%.0f fps) worst=%.2f ms" % [game.horde.list.size(), game.weapons.bullets.size(), avg, 1000.0 / avg, stress_worst_us / 1000.0])
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


func _drive(dt: float) -> void:
	var goal := _goal()
	var p := game.player
	var move := Vector2(goal.x - p.x, -(goal.y - p.z))
	var input := move.normalized() if move.length() > 6.0 else Vector2.ZERO
	# Getting stuck on a wall corner: step into the door band for a moment.
	if Vector2(p.x, p.z).distance_to(last_pos) < 0.1 and move.length() > 10.0:
		stuck_t += dt
	else:
		stuck_t = 0.0
	last_pos = Vector2(p.x, p.z)
	if stuck_t > 0.6:
		wiggle = 0.4
	if wiggle > 0.0:
		wiggle -= dt
		input = Vector2(input.x, -1.0 if p.z < game.t.depth * 0.5 else 1.0).normalized()
	input = _ladder_input(input)
	game.input_override = input
	if game.player.hp < game.player.max_hp * 0.4 and game.player.dash_cd <= 0.0:
		game.dash_requested = true


## Returns the (x, depth) to walk to, stepping through doors and ladders.
var ladder_push := 0.0


func _ladder_input(input: Vector2) -> Vector2:
	if ladder_push != 0.0:
		return Vector2(0.0, ladder_push)
	return input


func _goal() -> Vector2:
	var p := game.player
	ladder_push = 0.0
	var target_room := -1
	var target := Vector2.ZERO
	var heading_out := use_exit and game.run_t >= game.t.early_exit_opens_at
	var heading_roof := not use_exit and game.run_t >= 150.0
	if heading_out:
		target_room = game.level.room(0, 0).id
		target = Vector2(game.exit_room_x, game.t.depth * 0.5)
	elif heading_roof:
		target_room = game.level.roof_id
		target = Vector2(game.beacon_x, game.beacon_z)
	else:
		var crate := _nearest_crate()
		if crate != null:
			target_room = crate.room.id
			target = Vector2(crate.x, crate.z)
		else:
			target_room = game.level.roof_id
			target = Vector2(game.beacon_x, game.beacon_z)
	var here := game.level.room_at(p.f, p.x).id
	if here == target_room:
		return target
	var route: Array = game.level.build_field(target_room)
	var step: Level.Step = route[here]
	if step == null:
		return target
	if step.ladder != null:
		if absf(p.x - step.x) < 12.0 and absf(p.z - step.z) < 16.0 and not p.is_climbing():
			ladder_push = -1.0 if step.going_up else 1.0
		return Vector2(step.x, step.z)
	# Line up with the door band before walking through it.
	var door_x := step.door.x
	if absf(p.x - door_x) < 90.0 and not game.level.door_z_ok(p.z):
		return Vector2(p.x, game.t.depth * 0.5)
	return Vector2(step.x, game.t.depth * 0.5)


func _nearest_crate() -> Level.Crate:
	var p := game.player
	var best: Level.Crate = null
	var best_d := INF
	for c in game.level.crates:
		if c.opened:
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
