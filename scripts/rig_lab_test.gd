extends Node
## Development only. Plays the rig lab through real mouse events, checks each thing it
## promises, and saves a screenshot of each with --shots=DIR.
##   --path . res://scenes/rig_lab.tscn -- --labtest --shots=DIR

const TEST_FILE := "user://rig_lab_test_stance.json"
const TEST_DEVICE := 77

var lab: RigLab
var step := -3
var t := 0.0
var failed := false
var shots := ""
var feet_before: Array[Vector2] = []
var saved_value := 0.0
var busy := false
var last_screen := Vector2.ZERO
var view_before: Array[Vector2] = []
var wheel_at := Vector2(200.0, 600.0)
var steps_taken := 0
var ran_from := 0.0
var short_run: Array[float] = []


func setup(l: RigLab) -> void:
	lab = l
	lab.stance_path = TEST_FILE
	lab.only_device = TEST_DEVICE
	# Starts from the default stance, not whatever has been saved by hand.
	lab.art.use_defaults()
	lab.rig.apply_motion()
	lab.select_channel("body")
	lab.rig.apply_stance()
	lab.rig.plant_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")


func _process(dt: float) -> void:
	# A screenshot takes a frame, and the step waiting on it must not run again.
	if busy:
		return
	t += dt
	var rig := lab.rig
	match step:
		-3:
			if t > 0.2:
				rig.place(lab.arena.floor_s(1000.0), lab.bug)
				rig.turn_now(1.0)
				_next()
		-2:
			# Crawls over the top of a rise, where the rear leg used to get dragged out.
			rig.s = fposmod(rig.s + 150.0 * get_process_delta_time(), lab.arena.length)
			rig.want_face = 1.0
			if rig.pos.x > 1110.0:
				var stretched := 0.0
				for leg in rig.legs:
					stretched = maxf(stretched, leg.hip.distance_to(leg.foot) / leg.reach)
				_result("over the top of a rise, no leg is dragged out (%.0f%%)" % (stretched * 100.0), stretched < 1.0)
				_next()
				await _shot("top_of_rise")
				# Next, around the tip of the ledge, where knees used to flip over.
				rig.place(lab.arena.nearest_s(Vector2(70.0, -340.0)), lab.bug)
				rig.turn_now(1.0)
		-1:
			rig.s = fposmod(rig.s + 150.0 * get_process_delta_time(), lab.arena.length)
			rig.want_face = 1.0
			if rig.normal.x > 0.7 and rig.pos.y > -300.0:
				_next()
				await _shot("ledge_tip")
				lab._reset_position()
		0:
			if t > 0.5:
				_mouse_at(rig.body)
				_press(true)
				_next()
		1:
			_result_once("pressing on the body picks it up", lab.dragging_body and rig.held)
			# Walks out in stages, the way a hand would, since the camera follows.
			_mouse_at(Vector2(800.0, -280.0))
			if t > 0.8:
				_result("held body goes to the pointer", rig.pos.distance_to(Vector2(800.0, -280.0)) < 2.0)
				_result("what is drawn has caught up with it", rig.body.distance_to(rig.pos) < 6.0)
				_result("held clear of everything, its feet let go", _feet_off_surfaces() >= 3)
				await _shot("held_in_air")
				_next()
		2:
			_mouse_at(Vector2(40.0, -120.0))
			if t > 0.8:
				_result("pressed near a wall, it turns to face out of the wall", rig.normal.x > 0.7)
				_result("feet take hold near the wall", _feet_on_surfaces() >= 3)
				await _shot("held_near_wall")
				_next()
		3:
			_mouse_at(Vector2(546.0, -215.0))
			if t > 0.8:
				_result("under a dividing wall, it hangs from it", rig.normal.y > 0.7)
				await _shot("held_under_block")
				_mouse_at(Vector2(380.0, -300.0))
				_next()
		4:
			if t > 0.6:
				_press(false)
				_result_once("letting go in the air makes it fall", lab.falling)
				_next()
		5:
			if not lab.falling or t > 3.0:
				_result("it lands on the floor and stands", not lab.falling and rig.on_floor_side())
				_next()
		6:
			if t > 0.5:
				_result("after landing, feet settle on the floor", _feet_on_surfaces() == 4)
				await _shot("landed")
				_mouse_at(rig.body)
				_press(true)
				_mouse_at(Vector2(rig.pos.x + 90.0, rig.pos.y + 6.0))
				_next()
		7:
			if t > 0.3:
				_press(false)
				_result_once("letting go near a surface takes hold, not a fall", not lab.falling and rig.on_surface())
				_next()
		8:
			if t > 0.3:
				lab.toggle_mode()
				_next()
		9:
			if t > 0.8:
				_result("edit mode stands it on flat floor", absf(rig.pos.x - RigLab.EDIT_X) < 1.0 and rig.on_floor_side())
				var all_four := true
				for limb: String in RigLab.LIMB_NAMES:
					lab.select_limb(limb)
					all_four = all_four and lab.handles().size() == 4
				_result("every limb has its four handles, one limb at a time", all_four)
				lab.select_limb("leg_rear_near")
				await _shot("edit_mode")
				var leg := _leg("leg_rear_near")
				saved_value = float(lab.art.stance["leg_rear_near"].foot_x)
				_mouse_at(leg.foot)
				_press(true)
				_mouse_at(leg.foot + Vector2(-10.0, 0.0))
				_next()
		10:
			if t > 0.2:
				_press(false)
				var now := float(lab.art.stance["leg_rear_near"].foot_x)
				_result("dragging a foot moves it along the floor (%.1f to %.1f)" % [saved_value, now], now < saved_value - 2.0)
				_result("the planted foot goes where it was dragged", absf(_leg("leg_rear_near").foot.y - rig.pos.y - AlienRig.RIDE) < 1.0)
				lab.select_limb("leg_front_far")
				var leg := _leg("leg_front_far")
				saved_value = leg.hip.x
				_mouse_at(leg.hip)
				_press(true)
				_mouse_at(leg.hip + Vector2(6.0, -3.0))
				_next()
		11:
			if t > 0.2:
				_press(false)
				_result("dragging a hip moves it", _leg("leg_front_far").hip.x > saved_value + 2.0)
				lab.select_limb("leg_front_near")
				var leg := _leg("leg_front_near")
				var joints: Array[Vector2] = rig.bones[leg.name]
				feet_before = [joints[1], leg.foot]
				_mouse_at(leg.knee)
				_press(true)
				# Sideways to the thigh, since pulling along it keeps the same aim, and toward
				# the foot, since this short leg has no reach to spare the other way.
				var across := (leg.knee - leg.hip).normalized().orthogonal() * 14.0
				if (leg.knee + across).distance_to(leg.foot) > (leg.knee - across).distance_to(leg.foot):
					across = -across
				_mouse_at(leg.knee + across)
				_next()
		12:
			if t > 0.2:
				_press(false)
				var leg := _leg("leg_front_near")
				_result("dragging the knee control moves the knee", leg.knee.distance_to(feet_before[0]) > 4.0)
				_result("the foot stays put when the knee moves", leg.foot.distance_to(feet_before[1]) < 0.5)
				_result("the knee stays on its bones", absf(leg.ankle.distance_to(leg.tip) - leg.shin) < 0.5 and absf(leg.hip.distance_to(leg.knee) - leg.thigh) < 0.5)
				lab.select_limb("leg_rear_far")
				var before: int = lab.art.stance["leg_rear_far"].knee
				_mouse_at(_leg("leg_rear_far").ankle)
				_press(true)
				_press(false)
				_result("clicking an ankle flips which way the leg folds", lab.art.stance["leg_rear_far"].knee == -before)
				lab.select_limb("weapon_near")
				var joints: Array[Vector2] = rig.bones["weapon_near"]
				feet_before = [joints[3]]
				_mouse_at(joints[2])
				_press(true)
				_mouse_at(joints[2] + Vector2(3.0, -10.0))
				_next()
		13:
			if t > 0.2:
				_press(false)
				var joints: Array[Vector2] = rig.bones["weapon_near"]
				_result("dragging a weapon joint swings the arm", joints[3].distance_to(feet_before[0]) > 3.0)
				var moved := 0.0
				for limb: String in rig.bones:
					moved = maxf(moved, _bones_length_error(limb))
				_result("no bone changes length in any of it (worst %.2f px)" % moved, moved < 0.5)
				await _shot("edited")
				saved_value = float(lab.art.stance["leg_rear_near"].foot_x)
				lab.save()
				_result("saving writes the file", FileAccess.file_exists(TEST_FILE) and not lab.unsaved)
				lab.reset_to_drawing()
				_result("back to the drawing's stance", absf(float(lab.art.stance["leg_rear_near"].foot_x) - saved_value) > 1.0)
				lab.revert()
				_result("back to the saved stance", is_equal_approx(float(lab.art.stance["leg_rear_near"].foot_x), saved_value))
				var fresh := AlienArt.new()
				fresh.load_stance(TEST_FILE)
				_result("a fresh load reads the same values", is_equal_approx(float(fresh.stance["leg_rear_near"].foot_x), saved_value))
				lab.flip()
				_result("flip mirrors it", rig.side < 0.0)
				await _shot("flipped")
				lab.toggle_mode()
				_next()
		14:
			# The edited stance has to walk too: crawl it along the floor and up the wall.
			rig.s = fposmod(rig.s + 150.0 * get_process_delta_time(), lab.arena.length)
			rig.want_face = 1.0
			if t > 4.0:
				_result("the edited alien still crawls with feet on surfaces", _feet_on_surfaces() >= 2)
				var same := true
				for far: String in AlienRig.SAME_LENGTH_AS:
					var a := _leg(far)
					var b := _leg(AlienRig.SAME_LENGTH_AS[far])
					same = same and is_equal_approx(a.thigh, b.thigh) and is_equal_approx(a.calf, b.calf) and is_equal_approx(a.shin, b.shin)
				_result("near and far legs have the same lengths", same)
				await _shot("edited_crawling")
				_next()
		15:
			# A real click on the middle of a slider, through the GUI.
			if t > 0.1:
				lab.select_channel("abdomen")
				# The panel lays out the tab it just opened on the next frame.
				await get_tree().process_frame
				var slider: HSlider = lab.sliders["zeta"]
				saved_value = slider.value
				var box := slider.get_global_rect()
				var at: Vector2 = slider.get_canvas_transform() * box.get_center()
				_click_screen(at + Vector2(box.size.x * 0.3 * Hud.UI_SCALE, 0.0))
				_next()
		16:
			if t > 0.1:
				var now: float = lab.art.motion["abdomen"]["zeta"]
				_result("clicking a slider changes that part's feel (%.2f to %.2f)" % [saved_value, now], not is_equal_approx(now, saved_value) and lab.unsaved)
				lab.select_channel("body")
				_result("the sliders show the part just picked", is_equal_approx((lab.sliders["r"] as HSlider).value, float(lab.art.motion["body"]["r"])))
				lab.save()
				var fresh := AlienArt.new()
				fresh.load_stance(TEST_FILE)
				_result("feel is saved and reads back", is_equal_approx(float(fresh.motion["abdomen"]["zeta"]), now))
				_next()
				await _shot("feel_panel")
				lab.select_channel("legs")
		17:
			# A frame for the tab's layout, then a real click along the length slider.
			if t > 0.1:
				saved_value = _leg("leg_rear_far").reach
				var slider: HSlider = lab.sliders["all"]
				var box := slider.get_global_rect()
				_click_screen(slider.get_canvas_transform() * box.get_center() + Vector2(box.size.x * 0.2 * Hud.UI_SCALE, 0.0))
				_next()
		18:
			if t > 0.1:
				var now := _leg("leg_rear_far").reach
				_result("clicking the length slider makes the legs longer (%.0f to %.0f px)" % [saved_value, now], now > saved_value * 1.2 and lab.unsaved)
				_result("near and far legs still match", is_equal_approx(_leg("leg_rear_far").thigh, _leg("leg_rear_near").thigh) and is_equal_approx(_leg("leg_front_far").shin, _leg("leg_front_near").shin))
				lab.select_channel("frenzy")
				lab.toggle_auto_run()
				_next()
		19:
			if t > 2.5:
				lab.toggle_auto_run()
				var worst := 0.0
				for limb: String in rig.bones:
					worst = maxf(worst, _bones_length_error(limb))
				_result("long legs run around and keep their lengths (worst %.2f px)" % worst, worst < 0.5 and rig.state == AlienRig.State.CRAWL)
				_result("long legs keep to surfaces", _feet_on_surfaces() >= 2)
				await _shot("long_legs_running")
				lab.save()
				var fresh := AlienArt.new()
				fresh.load_stance(TEST_FILE)
				_result("lengths are saved and read back", is_equal_approx(float(fresh.leg_length["all"]), float(lab.art.leg_length["all"])))
				lab.revert()
				lab.reset_to_drawing()
				_result("back to the drawing's lengths", is_equal_approx(_leg("leg_rear_far").growth, 1.0))
				_next()
		20:
			if t > 0.1:
				var slider: HSlider = lab.sliders["frenzy"]
				var box := slider.get_global_rect()
				_click_screen(slider.get_canvas_transform() * box.get_center() + Vector2(box.size.x * 0.3 * Hud.UI_SCALE, 0.0))
				_next()
		21:
			if t > 0.1:
				_result("clicking the frenzy slider changes it (%.2f)" % lab.art.frenzy, lab.art.frenzy > AlienArt.DEFAULT_FRENZY + 0.2)
				lab.art.frenzy = 0.0
				lab.rig.apply_motion()
				_result("at no frenzy it keeps an even pace", is_equal_approx(rig.dart(0.016), 1.0))
				_next()
				_click_screen(_center_of(lab.follow_button))
		22:
			if t > 0.1:
				_result("clicking the follow button turns it off", not lab.follow)
				view_before = [lab.camera.position, rig.pos]
				lab.toggle_auto_run()
				_next()
		23:
			if t > 1.0:
				lab.toggle_auto_run()
				var ran := rig.pos.distance_to(view_before[1])
				_result("not following, the view stays put while it runs (it went %.0f px)" % ran, lab.camera.position == view_before[0] and ran > 20.0)
				view_before = [lab.get_canvas_transform().affine_inverse() * wheel_at]
				saved_value = lab.camera.zoom.x
				_wheel(wheel_at, true)
				_next()
		24:
			if t > 0.1:
				var inverse := lab.get_canvas_transform().affine_inverse()
				var drift := (inverse * wheel_at).distance_to(view_before[0])
				_result("the wheel zooms in (%.2f to %.2f)" % [saved_value, lab.camera.zoom.x], lab.camera.zoom.x > saved_value)
				_result("not following, it zooms around the pointer (off by %.1f px)" % drift, drift < 1.0)
				var high := Vector2(443.0, 400.0)
				var low := Vector2(443.0, 800.0)
				var empty := high if (inverse * high).distance_to(rig.body) > (inverse * low).distance_to(rig.body) else low
				view_before = [lab.camera.position]
				_mouse_at(inverse * empty)
				_press(true)
				_result("pressing empty space moves the view and leaves it alone", lab.panning and not lab.dragging_body)
				_mouse_at(inverse * (empty + Vector2(60.0, 30.0)))
				_next()
		25:
			if t > 0.1:
				var off := lab.camera.position.distance_to(view_before[0] - Vector2(60.0, 30.0) / lab.camera.zoom.x)
				_result("dragging empty space moves the view (off by %.1f px)" % off, off < 1.0)
				_press(false)
				_result("letting go stops moving the view", not lab.panning)
				_click_screen(_center_of(lab.follow_button))
				_next()
		26:
			if t > 2.5:
				var off := lab.camera.position.distance_to(rig.pos)
				_result("following again, the view goes back to it (%.0f px off)" % off, lab.follow and off < 15.0)
				saved_value = lab.camera.zoom.x
				var box := lab.zoom_slider.get_global_rect()
				_click_screen(_center_of(lab.zoom_slider) + Vector2(box.size.x * 0.3 * Hud.UI_SCALE, 0.0))
				_next()
		27:
			if t > 0.1:
				_result("the zoom slider zooms (%.2f to %.2f)" % [saved_value, lab.camera.zoom.x], not is_equal_approx(lab.camera.zoom.x, saved_value))
				saved_value = lab.camera.zoom.x
				lab.toggle_mode()
				_next()
		28:
			if t > 0.3:
				_result("editing has a zoom of its own", is_equal_approx(lab.camera.zoom.x, RigLab.ZOOM_EDIT))
				_wheel(lab.get_viewport_rect().size * 0.5, false)
				_next()
		29:
			if t > 0.1:
				lab.select_limb("leg_rear_near")
				_result("a handle can still be grabbed zoomed out", lab.camera.zoom.x < RigLab.ZOOM_EDIT and lab._handle_at(_leg("leg_rear_near").foot) != null)
				lab.toggle_mode()
				_result("back out, the view has its own zoom again", is_equal_approx(lab.camera.zoom.x, saved_value))
				lab.select_channel("stride")
				_next()
		30:
			# A frame for the tab's layout, then a real click along the stride slider.
			if t > 0.1:
				saved_value = lab.art.stride
				var box := lab.sliders["stride"].get_global_rect() as Rect2
				_click_screen(_center_of(lab.sliders["stride"]) + Vector2(box.size.x * 0.3 * Hud.UI_SCALE, 0.0))
				_next()
		31:
			if t > 0.1:
				_result("clicking the stride slider changes it (%.2f to %.2f)" % [saved_value, lab.art.stride], not is_equal_approx(lab.art.stride, saved_value) and lab.unsaved)
				lab.save()
				var fresh := AlienArt.new()
				fresh.load_stance(TEST_FILE)
				_result("stride is saved and reads back", is_equal_approx(fresh.stride, lab.art.stride))
				# At no frenzy its speed is even, so two runs can be compared directly.
				lab.art.frenzy = 0.0
				lab.art.stride = 0.5
				lab.toggle_auto_run()
				steps_taken = 0
				ran_from = rig.s
				_next()
		32:
			steps_taken += rig.plants
			if t > 2.0:
				short_run = [float(steps_taken), absf(lab.arena.gap(ran_from, rig.s))]
				lab.art.stride = 2.0
				steps_taken = 0
				ran_from = rig.s
				_next()
		33:
			steps_taken += rig.plants
			if t > 2.0:
				lab.toggle_auto_run()
				var moved := absf(lab.arena.gap(ran_from, rig.s))
				_result("a longer stride takes fewer steps (%d at 0.5, %d at 2)" % [short_run[0], steps_taken], steps_taken * 2 < short_run[0])
				_result("and goes just as fast (%.0f and %.0f px)" % [short_run[1], moved], absf(moved - short_run[1]) < 6.0)
				var six := true
				for kind: Bug.Kind in RigLab.VARIANTS:
					lab.select_variant(kind)
					lab.stance_path = TEST_FILE
					six = six and lab.rig.legs.size() == 4 and lab.rig.arms.size() == 2
					lab.toggle_skill()
					await _shot("kind_%d" % kind)
				_result("every kind can be put on the bench, with 4 legs and 2 forelimbs", six)
				_next()
				print("[lab] %s" % ("FAIL" if failed else "ALL PASS"))
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
				get_tree().quit(1 if failed else 0)


func _next() -> void:
	step += 1
	t = 0.0


## Real input events, so a handle hidden behind a button would fail like it would by hand.
func _mouse_at(world: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = lab.get_canvas_transform() * world
	e.global_position = e.position
	e.device = TEST_DEVICE
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	last_screen = e.position


func _press(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = last_screen
	e.global_position = e.position
	e.device = TEST_DEVICE
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _center_of(control: Control) -> Vector2:
	return control.get_canvas_transform() * control.get_global_rect().get_center()


func _wheel(at: Vector2, up: bool) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = down
		e.position = at
		e.global_position = at
		e.device = TEST_DEVICE
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _click_screen(at: Vector2) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _leg(limb: String) -> AlienRig.Leg:
	for leg in lab.rig.legs:
		if leg.name == limb:
			return leg
	return null


func _feet_on_surfaces() -> int:
	var count := 0
	for leg in lab.rig.legs:
		if lab.arena.closest_point(leg.foot).distance_to(leg.foot) < 1.5:
			count += 1
	return count


func _feet_off_surfaces() -> int:
	return lab.rig.legs.size() - _feet_on_surfaces()


func _bones_length_error(limb: String) -> float:
	var joints: Array[Vector2] = lab.rig.bones[limb]
	var worst := 0.0
	var leg := _leg(limb)
	if leg != null:
		worst = absf(joints[0].distance_to(joints[1]) - leg.thigh)
		worst = maxf(worst, absf(joints[1].distance_to(joints[2]) - leg.calf))
	else:
		for arm in lab.rig.arms:
			if arm.name == limb:
				for i in 3:
					worst = maxf(worst, absf(joints[i].distance_to(joints[i + 1]) - arm.lengths[i]))
	return worst


func _result(label: String, ok: bool) -> void:
	failed = failed or not ok
	print("[lab] %s: %s" % [label, "PASS" if ok else "FAIL"])


var _once: Dictionary = {}


func _result_once(label: String, ok: bool) -> void:
	if not _once.has(label):
		_once[label] = true
		_result(label, ok)


func _shot(label: String) -> void:
	if shots == "":
		return
	busy = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, label])
	busy = false
