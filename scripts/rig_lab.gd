class_name RigLab
extends Node2D
## A workbench for the alien's body, separate from the game. Pick it up and drag it
## around the arena to see how it adjusts, or switch to limb editing and move the
## handles. Saved limb positions go to the file the game reads.
## Run with F6 on this scene, or: --path . res://scenes/rig_lab.tscn

enum Mode {DRAG, EDIT}

const ZOOM_DRAG := 1.85
const ZOOM_EDIT := 3.9
## At the lowest the whole room fits. Each click of the wheel multiplies by ZOOM_WHEEL.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 6.0
const ZOOM_WHEEL := 1.12
## Where it stands for editing: open flat floor, away from walls.
const EDIT_X := 190.0
const GRAB_RADIUS := 100.0
## Zoomed in, that shrinks to this on screen, so the view can still be dragged from nearby.
const GRAB_SCREEN := 185.0
const HANDLE_PX := 13.0
## Keeps the dragged body from sinking into the surface it is held against.
const HELD_CLEARANCE := 20.0
## Let go this close to a surface and it simply takes hold again rather than falling.
const SNAP_DISTANCE := 48.0
const CRAWL_SPEED := 150.0
const ANY_DEVICE := -1000
const VARIANTS := {
	Bug.Kind.ALIEN: "Thợ", Bug.Kind.ALIEN_BOMBER: "Nổ", Bug.Kind.ALIEN_LEAPER: "Nhảy",
	Bug.Kind.ALIEN_STALKER: "Tàng hình", Bug.Kind.ALIEN_CHARGER: "Boss",
}
## The tabs of the panel. The ones that are parts of the body tune its f, zeta and r.
const CHANNEL_NAMES := {"frenzy": "Độ điên", "legs": "Dài chân", "stride": "Bước chân", "body": "Thân", "turn": "Xoay", "head": "Đầu", "abdomen": "Bụng", "arms": "Vũ khí"}
## Each number on the panel: its label, and its slider's lowest, highest and step.
const FEEL_RANGES := {"f": ["Độ nhanh f", 0.5, 12.0, 0.1], "zeta": ["Độ nảy zeta", 0.05, 1.5, 0.05], "r": ["Phản ứng đầu r", -3.0, 3.0, 0.1]}
const FRENZY_RANGE := {"frenzy": ["Độ điên (0 là đi bình thường)", 0.0, 2.0, 0.05]}
const STRIDE_RANGE := {"stride": ["Khoảng cách bước (tốc độ không đổi)", 0.4, 2.5, 0.05]}
const ALL_LEGS_RANGE := {"all": ["Cả 4 chân", 0.4, 2.5, 0.05]}
const LENGTH_RANGES := {
	"front_thigh": ["Trước, đùi", 0.5, 2.0, 0.05], "rear_thigh": ["Sau, đùi", 0.5, 2.0, 0.05],
	"front_calf": ["Trước, cẳng", 0.5, 2.0, 0.05], "rear_calf": ["Sau, cẳng", 0.5, 2.0, 0.05],
	"front_shin": ["Trước, ống", 0.5, 2.0, 0.05], "rear_shin": ["Sau, ống", 0.5, 2.0, 0.05],
}
const LIMB_NAMES := {
	"leg_rear_near": "Chân sau gần", "leg_rear_far": "Chân sau xa", "leg_front_near": "Chân trước gần",
	"leg_front_far": "Chân trước xa", "weapon_near": "Vũ khí gần", "weapon_far": "Vũ khí xa",
}
const PART_NAMES := {"hip": "hông", "knee": "gối", "ankle": "cổ chân", "foot": "bàn chân", "joint": "khớp"}

## A draggable point on a limb.
class Handle:
	var limb := ""
	var part := ""
	var index := 0
	var at := Vector2.ZERO
	var color := Color.WHITE

## Draws the handles in screen-sized dots over the alien.
class HandleView:
	extends Node2D
	var lab: RigLab

	func _draw() -> void:
		if lab.mode != Mode.EDIT:
			return
		var unit := 1.0 / lab.camera.zoom.x
		for h: Handle in lab.handles():
			var r := HANDLE_PX * unit * (1.3 if h == lab.hover or lab.is_grabbed(h) else 1.0)
			draw_circle(h.at, r + 2.0 * unit, Color(0.04, 0.06, 0.1), true, -1.0, true)
			draw_circle(h.at, r, h.color, true, -1.0, true)

var stance_path := ""
## Which kind of alien is on the bench.
var variant := Bug.Kind.ALIEN
var variant_row: HBoxContainer
var variant_buttons: Dictionary = {}
## Its special pose is on: closed shields, swollen abdomen, cloak, or weapons raised.
var skill_on := false
var mode := Mode.DRAG
var art: AlienArt
var arena: Arena
var bug: Bug
var rig: AlienRig
var gravity := 1700.0
var hover: Handle = null
## The limb being edited. Only its handles show, since all of them together pile up
## around the hips.
var selected_limb := "leg_rear_near"
var limb_row: GridContainer
var limb_buttons: Dictionary = {}
var mouse_world := Vector2.ZERO
var dragging_body := false
var falling := false
var grabbed: Handle = null
var unsaved := false
## A test sets this so the real cursor cannot interfere while it runs.
var only_device := ANY_DEVICE
## Which tab of the panel is showing.
var channel := "frenzy"
## Runs around the room by itself, so both hands are free for the sliders.
var auto_run := false
var run_dir := 1.0
var motion_panel: VBoxContainer
var tabs: GridContainer
var frenzy_box: VBoxContainer
var legs_box: VBoxContainer
var stride_box: VBoxContainer
var feel_box: VBoxContainer
var channel_buttons: Dictionary = {}
var sliders: Dictionary = {}
var slider_labels: Dictionary = {}
var slider_names: Dictionary = {}

## The view stays on the alien. Off, it stays put, and dragging empty space moves it.
var follow := true
var follow_button: Button
## Each mode keeps its own zoom.
var zooms := {Mode.DRAG: ZOOM_DRAG, Mode.EDIT: ZOOM_EDIT}
var zoom_slider: HSlider
var zoom_label: Label
var mouse_screen := Vector2.ZERO
var panning := false
var pan_screen := Vector2.ZERO
var pan_camera := Vector2.ZERO

var sfx: Sfx
var camera: Camera2D
var handle_view: HandleView
var alien_view: AlienView
var hint: Label
var readout: Label
var mode_button: Button
var status_t := 0.0
var status := ""


func _ready() -> void:
	var tuning: Tuning = load("res://data/tuning.tres")
	gravity = tuning.gravity
	art = AlienArt.new()
	stance_path = art.stance_path
	arena = Arena.new(AlienRig.RIDE)
	var arena_view := ArenaView.new()
	arena_view.name = "ArenaView"
	add_child(arena_view)
	arena_view.setup(arena, tuning.scroll_walls)
	alien_view = AlienView.new()
	alien_view.name = "AlienView"
	alien_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(alien_view)
	alien_view.setup(tuning.hit_flash_time, func() -> Array: return [bug])
	sfx = Sfx.new()
	add_child(sfx)
	handle_view = HandleView.new()
	handle_view.name = "Handles"
	handle_view.lab = self
	add_child(handle_view)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_build_ui()
	_new_alien()
	_set_mode(Mode.DRAG)
	select_channel(channel)
	camera.position = rig.pos
	if OS.get_cmdline_user_args().has("--labtest"):
		var test: Node = load("res://scripts/rig_lab_test.gd").new()
		add_child(test)
		test.call("setup", self)


func _new_alien() -> void:
	bug = Bug.new()
	bug.setup(variant, 1.0)
	bug.x = EDIT_X
	rig = AlienRig.new(arena, art, gravity, bug)
	bug.rig = rig
	rig.turn_now(1.0)
	rig.plant_all()


# ---- Screen ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.transform = Transform2D().scaled(Vector2.ONE * Hud.UI_SCALE)
	add_child(layer)
	hint = Label.new()
	hint.position = Vector2(16, Hud.TOP_MARGIN)
	hint.size = Vector2(688, 90)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 25)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	readout = Label.new()
	readout.size = Vector2(688, 100)
	readout.add_theme_font_size_override("font_size", 25)
	readout.add_theme_color_override("font_outline_color", Color.BLACK)
	readout.add_theme_constant_override("outline_size", 6)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(readout)
	limb_row = GridContainer.new()
	limb_row.columns = 3
	limb_row.position = Vector2(16, Hud.TOP_MARGIN + 124.0)
	limb_row.add_theme_constant_override("h_separation", 10)
	limb_row.add_theme_constant_override("v_separation", 10)
	layer.add_child(limb_row)
	for limb: String in LIMB_NAMES:
		var b := _button(limb_row, LIMB_NAMES[limb], select_limb.bind(limb))
		b.toggle_mode = true
		limb_buttons[limb] = b
	_build_variant_row(layer)
	_build_motion_panel(layer)
	var row := GridContainer.new()
	row.columns = 4
	row.position = Vector2(16, 1350)
	row.size = Vector2(688, 150)
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	layer.add_child(row)
	mode_button = _button(row, "", toggle_mode)
	_button(row, "Lật hướng", flip)
	_button(row, "Tự chạy", toggle_auto_run).toggle_mode = true
	_button(row, "Lưu", save)
	_button(row, "Về bản đã lưu", revert)
	_button(row, "Về mặc định", reset_to_drawing)
	_button(row, "Đặt lại vị trí", _reset_position)
	follow_button = _button(row, "Đi theo", toggle_follow)
	follow_button.toggle_mode = true
	follow_button.set_pressed_no_signal(true)
	for b: Button in row.get_children():
		b.custom_minimum_size = Vector2(164, 68)
		b.add_theme_font_size_override("font_size", 21)
	_build_zoom_row(layer)


func _build_variant_row(layer: CanvasLayer) -> void:
	variant_row = HBoxContainer.new()
	variant_row.position = Vector2(16, Hud.TOP_MARGIN + 170.0)
	variant_row.add_theme_constant_override("separation", 6)
	layer.add_child(variant_row)
	for kind: Bug.Kind in VARIANTS:
		var b := _button(variant_row, VARIANTS[kind], select_variant.bind(kind))
		b.custom_minimum_size = Vector2(110, 52)
		b.add_theme_font_size_override("font_size", 21)
		b.toggle_mode = true
		b.set_pressed_no_signal(kind == variant)
		variant_buttons[kind] = b
	var skill := _button(variant_row, "Thử chiêu", toggle_skill)
	skill.custom_minimum_size = Vector2(110, 52)
	skill.add_theme_font_size_override("font_size", 21)


## Puts another kind on the bench, with its own saved stance.
func select_variant(kind: Bug.Kind) -> void:
	variant = kind
	art = AlienArt.new(Bug.STATS[kind].art)
	stance_path = art.stance_path
	skill_on = false
	unsaved = false
	_new_alien()
	_set_mode(mode)
	_sync_sliders()
	for key: Bug.Kind in variant_buttons:
		(variant_buttons[key] as Button).set_pressed_no_signal(key == kind)


func toggle_skill() -> void:
	skill_on = not skill_on
	var amount := 1.0 if skill_on else 0.0
	match variant:
		Bug.Kind.ALIEN_CHARGER:
			rig.guard = amount
		Bug.Kind.ALIEN_BOMBER:
			rig.swell = amount
		Bug.Kind.ALIEN_STALKER:
			rig.cloak = amount
		_:
			rig.crouch = amount


func _build_zoom_row(layer: CanvasLayer) -> void:
	var box := HBoxContainer.new()
	box.position = Vector2(16, 1506)
	box.add_theme_constant_override("separation", 12)
	layer.add_child(box)
	zoom_label = Label.new()
	zoom_label.custom_minimum_size = Vector2(150, 0)
	zoom_label.add_theme_font_size_override("font_size", 23)
	zoom_label.add_theme_color_override("font_outline_color", Color.BLACK)
	zoom_label.add_theme_constant_override("outline_size", 6)
	box.add_child(zoom_label)
	zoom_slider = HSlider.new()
	zoom_slider.min_value = ZOOM_MIN
	zoom_slider.max_value = ZOOM_MAX
	zoom_slider.step = 0.05
	zoom_slider.custom_minimum_size = Vector2(526, 36)
	zoom_slider.value_changed.connect(_on_zoom_slider)
	box.add_child(zoom_slider)


## How it moves and how long its legs are, tuned while it runs around. Editing limbs shows
## only the leg lengths.
func _build_motion_panel(layer: CanvasLayer) -> void:
	motion_panel = VBoxContainer.new()
	motion_panel.position = Vector2(16, 920)
	motion_panel.custom_minimum_size = Vector2(688, 0)
	motion_panel.add_theme_constant_override("separation", 6)
	layer.add_child(motion_panel)
	tabs = GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	motion_panel.add_child(tabs)
	for part: String in CHANNEL_NAMES:
		var b := _button(tabs, CHANNEL_NAMES[part], select_channel.bind(part))
		b.custom_minimum_size = Vector2(167, 52)
		b.add_theme_font_size_override("font_size", 22)
		b.toggle_mode = true
		channel_buttons[part] = b
	frenzy_box = VBoxContainer.new()
	motion_panel.add_child(frenzy_box)
	_add_sliders(frenzy_box, FRENZY_RANGE, 688.0)
	stride_box = VBoxContainer.new()
	motion_panel.add_child(stride_box)
	_add_sliders(stride_box, STRIDE_RANGE, 688.0)
	legs_box = VBoxContainer.new()
	motion_panel.add_child(legs_box)
	_add_sliders(legs_box, ALL_LEGS_RANGE, 688.0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	legs_box.add_child(grid)
	_add_sliders(grid, LENGTH_RANGES, 338.0)
	feel_box = VBoxContainer.new()
	motion_panel.add_child(feel_box)
	_add_sliders(feel_box, FEEL_RANGES, 688.0)


func _add_sliders(parent: Control, ranges: Dictionary, width: float) -> void:
	for key: String in ranges:
		var info: Array = ranges[key]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		parent.add_child(box)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		box.add_child(label)
		var slider := HSlider.new()
		slider.min_value = info[1]
		slider.max_value = info[2]
		slider.step = info[3]
		slider.custom_minimum_size = Vector2(width, 30)
		slider.value_changed.connect(_on_slider.bind(key))
		box.add_child(slider)
		sliders[key] = slider
		slider_labels[key] = label
		slider_names[key] = info[0]


func select_channel(part: String) -> void:
	channel = part
	for key: String in channel_buttons:
		(channel_buttons[key] as Button).set_pressed_no_signal(key == part)
	_show_panel()
	_sync_sliders()


func _show_panel() -> void:
	var editing := mode == Mode.EDIT
	tabs.visible = not editing
	frenzy_box.visible = not editing and channel == "frenzy"
	stride_box.visible = not editing and channel == "stride"
	legs_box.visible = editing or channel == "legs"
	feel_box.visible = not editing and art.motion.has(channel)


## Puts the stored numbers on the sliders without counting as an edit.
func _sync_sliders() -> void:
	for key: String in sliders:
		(sliders[key] as HSlider).set_value_no_signal(_value_of(key))
		_label_slider(key)


func _value_of(key: String) -> float:
	if key == "frenzy":
		return art.frenzy
	if key == "stride":
		return art.stride
	if art.leg_length.has(key):
		return art.leg_length[key]
	# The f, zeta and r sliders only show while a part of the body is picked.
	return art.motion[channel][key] if art.motion.has(channel) else 0.0


func _label_slider(key: String) -> void:
	(slider_labels[key] as Label).text = "%s: %.2f" % [slider_names[key], _value_of(key)]


func _on_slider(value: float, key: String) -> void:
	if key == "frenzy":
		art.frenzy = value
		rig.apply_motion()
	elif key == "stride":
		art.stride = value
	elif art.leg_length.has(key):
		art.leg_length[key] = value
		rig.apply_stance()
		if mode == Mode.EDIT:
			rig.plant_all()
	else:
		art.motion[channel][key] = value
		rig.apply_motion()
	unsaved = true
	_label_slider(key)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(222, 68)
	b.add_theme_font_size_override("font_size", 25)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _refresh_ui() -> void:
	if mode == Mode.DRAG:
		hint.text = "Bấm giữ con bọ rồi kéo đi, thả gần bề mặt thì nó bám lại, thả giữa không trung thì nó rơi. A / D để chạy, hoặc bấm Tự chạy rồi kéo thanh trượt bên dưới. Con lăn để zoom."
		mode_button.text = "Chỉnh chi"
	else:
		hint.text = "Chọn chi, rồi kéo chấm: vàng là hông, trắng là gối lúc đứng, cam là bàn chân, đỏ là khớp vũ khí. Bấm chấm xanh để đảo chiều gập."
		mode_button.text = "Kéo bọ"
	var lines: Array[String] = []
	if status_t > 0.0:
		lines.append(status)
	elif unsaved:
		lines.append("Chưa lưu")
	var shown := grabbed if grabbed != null else hover
	if shown != null:
		lines.append("%s, %s" % [LIMB_NAMES[shown.limb], PART_NAMES[shown.part]])
	if mode == Mode.EDIT:
		lines.append(_limb_values(selected_limb))
	if not follow:
		lines.append("Không đi theo: kéo chỗ trống để di chuyển khung nhìn")
	readout.text = "\n".join(lines)


func _limb_values(limb: String) -> String:
	var row: Dictionary = art.stance[limb]
	if limb.begins_with("leg_"):
		var knee_text := "(%.1f, %.1f)" % [row.pole[0], row.pole[1]] if row.has("pole") else "tự động"
		return "hông (%.1f, %.1f)  bàn chân %.1f  gối %s" % [row.hip[0], row.hip[1], row.foot_x, knee_text]
	return "hông (%.1f, %.1f)  xoay %.2f, %.2f, %.2f" % [row.hip[0], row.hip[1], row.turn[0], row.turn[1], row.turn[2]]


func _say(text: String) -> void:
	status = text
	status_t = 2.5


# ---- Actions --------------------------------------------------------------------

func select_limb(limb: String) -> void:
	selected_limb = limb
	grabbed = null
	hover = null
	for key: String in limb_buttons:
		(limb_buttons[key] as Button).set_pressed_no_signal(key == limb)


func toggle_mode() -> void:
	_set_mode(Mode.EDIT if mode == Mode.DRAG else Mode.DRAG)


func _set_mode(next: Mode) -> void:
	mode = next
	dragging_body = false
	falling = false
	grabbed = null
	hover = null
	rig.held = false
	rig.still = next == Mode.EDIT
	limb_row.visible = next == Mode.EDIT
	variant_row.visible = next == Mode.DRAG
	readout.position = Vector2(16, Hud.TOP_MARGIN + (290.0 if next == Mode.EDIT else 124.0))
	_show_panel()
	if next == Mode.EDIT:
		_stand_for_editing()
		select_limb(selected_limb)
	panning = false
	_apply_zoom(zooms[next])
	# Not following, the view still has to go to it once, or it would be left off screen.
	if not follow:
		camera.position = _camera_target()


func _stand_for_editing() -> void:
	bug.x = EDIT_X
	bug.vh = 0.0
	rig.set_state(AlienRig.State.IDLE)
	rig.place(arena.floor_s(EDIT_X), bug)


func _reset_position() -> void:
	falling = false
	dragging_body = false
	rig.held = false
	_stand_for_editing()
	if not follow:
		camera.position = _camera_target()


func toggle_follow() -> void:
	follow = not follow
	panning = false


func _on_zoom_slider(value: float) -> void:
	_zoom_at(value, get_viewport_rect().size * 0.5)


## What is under the given screen point stays there, if the view is free to move.
func _zoom_at(value: float, at: Vector2) -> void:
	var zoom_to := clampf(value, ZOOM_MIN, ZOOM_MAX)
	var from_center := at - get_viewport_rect().size * 0.5
	if not follow:
		camera.position += from_center / camera.zoom.x - from_center / zoom_to
	_apply_zoom(zoom_to)


func _apply_zoom(value: float) -> void:
	zooms[mode] = value
	camera.zoom = Vector2.ONE * value
	zoom_slider.set_value_no_signal(value)
	zoom_label.text = "Zoom %.2f" % value


func toggle_auto_run() -> void:
	auto_run = not auto_run


func flip() -> void:
	rig.turn_now(-rig.side)
	if mode == Mode.EDIT:
		rig.plant_all()


func save() -> void:
	var ok := art.save_stance(stance_path)
	unsaved = not ok
	_say("Đã lưu, game sẽ dùng tư thế này" if ok else "Không lưu được file")


func revert() -> void:
	art.load_stance(stance_path)
	rig.apply_motion()
	_sync_sliders()
	_stance_changed(false)
	_say("Đã về bản đã lưu")


func reset_to_drawing() -> void:
	art.use_defaults()
	rig.apply_motion()
	_sync_sliders()
	_stance_changed(true)
	_say("Đã về mặc định, bấm Lưu để giữ")


func _stance_changed(dirty: bool) -> void:
	rig.apply_stance()
	if mode == Mode.EDIT:
		rig.plant_all()
	unsaved = dirty


# ---- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if only_device != ANY_DEVICE and event.device != only_device:
		return
	if event is InputEventMouseButton:
		mouse_screen = event.position as Vector2
		mouse_world = get_canvas_transform().affine_inverse() * mouse_screen
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press()
			else:
				release()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(camera.zoom.x * ZOOM_WHEEL, mouse_screen)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(camera.zoom.x / ZOOM_WHEEL, mouse_screen)
	elif event is InputEventMouseMotion:
		mouse_screen = event.position as Vector2
		# From where the drag began, since the camera only takes effect on the next frame
		# and a frame can bring several of these.
		if panning:
			camera.position = pan_camera + (pan_screen - mouse_screen) / camera.zoom.x
		mouse_world = get_canvas_transform().affine_inverse() * mouse_screen


func press() -> void:
	if mode == Mode.DRAG:
		if mouse_world.distance_to(rig.body) < minf(GRAB_RADIUS, GRAB_SCREEN / camera.zoom.x):
			dragging_body = true
			falling = false
			rig.set_state(AlienRig.State.IDLE)
			rig.held = true
			rig.held_at = _hold_point(mouse_world)
		else:
			_start_pan()
		return
	grabbed = _handle_at(mouse_world)
	if grabbed == null:
		_start_pan()
		return
	if grabbed.part == "ankle":
		var row: Dictionary = art.stance[grabbed.limb]
		row.knee = -int(row.knee)
		_stance_changed(true)
		grabbed = null


func _start_pan() -> void:
	panning = not follow
	pan_screen = mouse_screen
	pan_camera = camera.position


func release() -> void:
	panning = false
	grabbed = null
	if not dragging_body:
		return
	dragging_body = false
	rig.held = false
	var s := arena.nearest_s(rig.pos)
	arena.pose(s)
	if arena.at.distance_to(rig.pos) < SNAP_DISTANCE:
		rig.take_hold(s)
		return
	falling = true
	bug.vh = 0.0
	rig.set_state(AlienRig.State.LEAP)


func is_grabbed(h: Handle) -> bool:
	return grabbed != null and grabbed.limb == h.limb and grabbed.part == h.part and grabbed.index == h.index


## Stays inside the room and clear of whatever surface it is pressed against.
func _hold_point(p: Vector2) -> Vector2:
	var near := arena.closest_point(p)
	if not arena.contains(p):
		arena.pose(arena.nearest_s(p))
		return arena.at
	if near.distance_to(p) < HELD_CLEARANCE:
		return near + (p - near).normalized() * HELD_CLEARANCE
	return p


## The selected limb's handles.
func handles() -> Array[Handle]:
	var out: Array[Handle] = []
	var limb := selected_limb
	var joints: Array[Vector2] = rig.bones[limb]
	out.append(_handle(limb, "hip", 0, joints[0], Color("ffd45a")))
	if limb.begins_with("leg_"):
		out.append(_handle(limb, "knee", 0, joints[1], Color.WHITE))
		out.append(_handle(limb, "ankle", 0, joints[2], Color("3df2ff")))
		out.append(_handle(limb, "foot", 0, joints[3], Color("ff8a2b")))
	else:
		for i in 3:
			out.append(_handle(limb, "joint", i, joints[i + 1], Color("ff5a4a")))
	return out


func _handle(limb: String, part: String, index: int, at: Vector2, color: Color) -> Handle:
	var h := Handle.new()
	h.limb = limb
	h.part = part
	h.index = index
	h.at = at
	h.color = color
	return h


func _handle_at(p: Vector2) -> Handle:
	var best: Handle = null
	var best_d := (HANDLE_PX + 6.0) / camera.zoom.x
	for h in handles():
		var d := h.at.distance_to(p)
		if d < best_d:
			best_d = d
			best = h
	return best


# ---- Per frame ------------------------------------------------------------------

func _process(dt: float) -> void:
	status_t = maxf(status_t - dt, 0.0)
	if mode == Mode.DRAG:
		_update_drag(dt)
	else:
		_update_edit()
	rig.update(bug, dt)
	if rig.plants > 0:
		sfx.play("tick", -20.0, 0.02)
	_update_camera(dt)
	_refresh_ui()
	alien_view.queue_redraw()
	handle_view.queue_redraw()


func _update_drag(dt: float) -> void:
	if dragging_body:
		rig.held_at = _hold_point(mouse_world)
		return
	if falling:
		bug.vh -= gravity * dt
		bug.h += bug.vh * dt
		var ground := arena.ground_at(bug.x)
		if bug.h <= ground:
			bug.h = ground
			falling = false
			rig.land(bug)
			rig.set_state(AlienRig.State.IDLE)
		return
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir += 1.0
	if dir == 0.0 and auto_run:
		dir = run_dir
	# The same state it crawls in during the game, so what is tuned here is what is played.
	if dir != 0.0:
		run_dir = dir
		if rig.state != AlienRig.State.CRAWL:
			rig.set_state(AlienRig.State.CRAWL)
		rig.s = fposmod(rig.s + dir * CRAWL_SPEED * rig.dart(dt) * dt, arena.length)
		rig.want_face = dir
	elif rig.state == AlienRig.State.CRAWL:
		rig.set_state(AlienRig.State.IDLE)


func _update_edit() -> void:
	hover = _handle_at(mouse_world) if grabbed == null else null
	if grabbed != null:
		_drag_handle(grabbed)
		unsaved = true


## Moves a limb's stored pose to follow the pointer. Bones keep their lengths, so an
## ankle or arm joint swings around the joint before it.
func _drag_handle(h: Handle) -> void:
	var row: Dictionary = art.stance[h.limb]
	var local := rig.to_drawing(mouse_world)
	match h.part:
		"hip":
			row.hip = [clampf(local.x, -32.0 * art.size, 24.0 * art.size), clampf(local.y, -16.0 * art.size, 14.0 * art.size)]
		"foot":
			row.foot_x = clampf(local.x / rig.growth_of(h.limb), -75.0 * art.size, 75.0 * art.size)
		"knee":
			row.pole = [clampf(local.x, -90.0 * art.size, 90.0 * art.size), clampf(local.y, -90.0 * art.size, 30.0 * art.size)]
		"joint":
			var joints: Array[Vector2] = rig.bones[h.limb]
			var from := rig.to_drawing(joints[h.index])
			var want := (local - from).angle()
			var rest: float = rig.arm_rest_angle(h.limb, h.index)
			row.turn[h.index] = wrapf(want - rest, -PI, PI)
	rig.apply_stance()
	rig.plant_all()


func _camera_target() -> Vector2:
	return rig.pos if mode == Mode.DRAG else rig.pos + Vector2(0.0, -8.0)


func _update_camera(dt: float) -> void:
	if follow:
		camera.position = camera.position.lerp(_camera_target(), 1.0 - exp(-dt * 5.0))
