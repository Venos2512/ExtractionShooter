class_name Hud
extends CanvasLayer
## On-screen readouts, the floating joystick, the dash button, and modal screens.
## Built in code so the whole prototype stays in a few readable scripts.

const SCREEN := Vector2(720.0, 1280.0)
const JOY_RADIUS := 90.0
const DASH_CENTER := Vector2(630.0, 1120.0)
const DASH_RADIUS := 62.0
const PANEL := Color(0.09, 0.10, 0.08, 0.94)
const INK := Color(0.93, 0.92, 0.82)
const ACCENT := Color(0.84, 0.70, 0.26)

var game: Game
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var danger_label: Label
var timer_label: Label
var bag_label: Label
var cash_label: Label
var wave_label: Label
var status_label: Label
var toast_label: Label
var tint: ColorRect
var touch_view: TouchView
var card_root: Control
var card_row: VBoxContainer
var reroll_button: Button
var revive_root: Control
var result_root: Control
var result_title: Label
var result_body: Label

var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO


class TouchView:
	extends Control
	var hud: Hud

	func _draw() -> void:
		if hud == null or hud.game == null:
			return
		var p := hud.game.player
		var ready_frac := 1.0 - p.dash_cd / maxf(p.dash_cooldown, 0.01)
		var center := Hud.DASH_CENTER
		draw_circle(center, Hud.DASH_RADIUS, Color(0.05, 0.06, 0.05, 0.55))
		var fill := Color(0.5, 0.85, 1.0, 0.9) if ready_frac >= 1.0 else Color(0.5, 0.6, 0.65, 0.7)
		draw_arc(center, Hud.DASH_RADIUS - 5.0, -PI * 0.5, -PI * 0.5 + TAU * ready_frac, 48, fill, 8.0, true)
		var font := ThemeDB.fallback_font
		draw_string(font, center + Vector2(-60.0, 10.0), "LƯỚT", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 24, fill)
		if hud.joy_index >= 0:
			draw_circle(hud.joy_origin, Hud.JOY_RADIUS, Color(1, 1, 1, 0.08))
			draw_arc(hud.joy_origin, Hud.JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 3.0, true)
			draw_circle(hud.joy_pos, 40.0, Color(1, 1, 1, 0.3))


func setup(g: Game) -> void:
	game = g
	_build()
	hide_cards()
	hide_revive()
	result_root.visible = false


func _build() -> void:
	tint = ColorRect.new()
	tint.size = SCREEN
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0.8, 0.05, 0.03, 0.0)
	add_child(tint)
	var root := Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hp_bar = _bar(root, Vector2(24, 26), Vector2(360, 26), Color(0.82, 0.2, 0.16))
	xp_bar = _bar(root, Vector2(24, 58), Vector2(360, 10), Color(0.4, 0.75, 1.0))
	danger_label = _label(root, Vector2(404, 18), 34, ACCENT)
	timer_label = _label(root, Vector2(600, 18), 34, INK)
	bag_label = _label(root, Vector2(24, 78), 26, INK)
	cash_label = _label(root, Vector2(244, 78), 26, Color(1.0, 0.84, 0.3))
	wave_label = _label(root, Vector2(0, 124), 36, Color(1.0, 0.4, 0.3))
	wave_label.size = Vector2(SCREEN.x, 50)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = _label(root, Vector2(0, 172), 28, Color(0.5, 0.9, 1.0))
	status_label.size = Vector2(SCREEN.x, 44)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _label(root, Vector2(0, 222), 32, INK)
	toast_label.size = Vector2(SCREEN.x, 44)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = _label(root, Vector2(0, 1178), 24, Color(1.0, 0.5, 0.4))
	boss_label.size = Vector2(SCREEN.x, 34)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.text = "BOSS: BẢO VỆ KHỔNG LỒ"
	boss_bar = _bar(root, Vector2(60, 1214), Vector2(600, 22), Color(0.9, 0.2, 0.15))
	touch_view = TouchView.new()
	touch_view.hud = self
	touch_view.size = SCREEN
	touch_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_view)
	_build_cards()
	_build_revive()
	_build_result()


func _label(parent: Control, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.border_color = Color(0.7, 0.7, 0.6, 0.5)
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


func _button(parent: Control, text: String, height: float, callback: Callable, color := Color(0.26, 0.30, 0.20)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 30)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(3)
	normal.border_color = color.lightened(0.3)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _modal() -> Control:
	var root := ColorRect.new()
	root.size = SCREEN
	root.color = Color(0, 0, 0, 0.7)
	add_child(root)
	return root


func _build_cards() -> void:
	card_root = _modal()
	var title := _label(card_root, Vector2(0, 250), 44, ACCENT)
	title.size = Vector2(SCREEN.x, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "CHỌN MỘT THẺ"
	card_row = VBoxContainer.new()
	card_row.position = Vector2(60, 340)
	card_row.size = Vector2(600, 500)
	card_row.add_theme_constant_override("separation", 18)
	card_root.add_child(card_row)
	reroll_button = Button.new()
	reroll_button.text = "Đổi thẻ (miễn phí 1 lần)"
	reroll_button.position = Vector2(160, 880)
	reroll_button.size = Vector2(400, 76)
	reroll_button.add_theme_font_size_override("font_size", 28)
	reroll_button.pressed.connect(func() -> void: game.reroll_cards())
	card_root.add_child(reroll_button)


func _build_revive() -> void:
	revive_root = _modal()
	var title := _label(revive_root, Vector2(0, 420), 52, Color(1.0, 0.4, 0.3))
	title.size = Vector2(SCREEN.x, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "BẠN ĐÃ GỤC"
	var box := VBoxContainer.new()
	box.position = Vector2(110, 540)
	box.size = Vector2(500, 240)
	box.add_theme_constant_override("separation", 20)
	revive_root.add_child(box)
	_button(box, "Hồi sinh (1 lần mỗi lượt)", 100.0, func() -> void: game.revive(), Color(0.2, 0.42, 0.24))
	_button(box, "Bỏ cuộc", 80.0, func() -> void: game.give_up(), Color(0.32, 0.14, 0.12))


func _build_result() -> void:
	result_root = _modal()
	result_title = _label(result_root, Vector2(0, 340), 56, ACCENT)
	result_title.size = Vector2(SCREEN.x, 80)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body = _label(result_root, Vector2(40, 450), 32, INK)
	result_body.size = Vector2(640, 300)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	var box := VBoxContainer.new()
	box.position = Vector2(160, 800)
	box.size = Vector2(400, 100)
	result_root.add_child(box)
	_button(box, "Chơi lại", 100.0, func() -> void: game.restart(), Color(0.2, 0.42, 0.24))


func refresh() -> void:
	var p := game.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	xp_bar.max_value = game.xp_next
	xp_bar.value = game.xp
	danger_label.text = "DANGER %d" % game.danger
	timer_label.text = "%d:%02d" % [int(game.run_t) / 60, int(game.run_t) % 60]
	bag_label.text = "Ba lô %d/%d" % [game.backpack_used(), game.t.backpack_slots]
	cash_label.text = "Tiền %d" % game.cash
	var warn := game.next_wave_t <= game.t.wave_warning
	wave_label.visible = warn and game.rescue != Game.Rescue.LANDED
	wave_label.text = "Đợt zombie sau %d giây" % int(ceil(game.next_wave_t))
	status_label.text = _status_text()
	toast_label.text = game.toast if game.toast_t > 0.0 else ""
	var boss := game.horde.boss
	boss_bar.visible = boss != null
	boss_label.visible = boss != null
	if boss != null:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
	var red := clampf(float(game.danger - 4) / 16.0, 0.0, 0.14)
	if game.rescue == Game.Rescue.CALLING:
		red = 0.14 + 0.05 * sin(Time.get_ticks_msec() * 0.006)
	if p.hp < p.max_hp * 0.3:
		red = maxf(red, 0.18 + 0.08 * sin(Time.get_ticks_msec() * 0.012))
	tint.color.a = red
	touch_view.queue_redraw()


func _status_text() -> String:
	match game.rescue:
		Game.Rescue.CALLING:
			return "Cứu hộ tới sau %d giây" % int(ceil(game.rescue_left))
		Game.Rescue.LANDED:
			return "Trực thăng đã đến! Vào vòng tròn"
	if game.exit_hold > 0.0:
		return "Đang thoát... %d giây" % int(ceil(game.t.early_exit_hold - game.exit_hold))
	if game.run_t < game.t.early_exit_opens_at:
		return "Hầm thoát mở sau %d giây" % int(ceil(game.t.early_exit_opens_at - game.run_t))
	if game.run_t < game.t.rescue_opens_at:
		return "Hầm thoát đã mở. Cứu hộ mở sau %d giây" % int(ceil(game.t.rescue_opens_at - game.run_t))
	return "Thoát sớm qua hầm, hay lên mái gọi cứu hộ?"


func show_cards() -> void:
	for c in card_row.get_children():
		card_row.remove_child(c)
		c.queue_free()
	for i in game.card_offer.size():
		var card: Dictionary = game.card_offer[i]
		var text := "%s\n%s" % [card.title, card.desc]
		var idx := i
		_button(card_row, text, 140.0, func() -> void: game.choose_card(idx), Cards.COLORS[card.rarity])
	reroll_button.disabled = not game.free_reroll
	card_root.visible = true
	joy_index = -1


func hide_cards() -> void:
	card_root.visible = false


func show_revive() -> void:
	revive_root.visible = true
	joy_index = -1


func hide_revive() -> void:
	revive_root.visible = false


func show_result(survived: bool, body: String) -> void:
	result_title.text = "THOÁT THÀNH CÔNG" if survived else "NHIỆM VỤ THẤT BẠI"
	result_title.add_theme_color_override("font_color", ACCENT if survived else Color(1.0, 0.4, 0.3))
	result_body.text = body
	result_root.visible = true
	joy_index = -1


func joy_vector() -> Vector2:
	if joy_index < 0:
		return Vector2.ZERO
	return ((joy_pos - joy_origin) / JOY_RADIUS).limit_length(1.0)


func _input(event: InputEvent) -> void:
	if game == null or game.state != Game.State.PLAY:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(DASH_CENTER) < DASH_RADIUS:
				game.dash_requested = true
			elif joy_index < 0 and event.position.y > SCREEN.y * 0.3:
				joy_index = event.index
				joy_origin = event.position
				joy_pos = event.position
		elif event.index == joy_index:
			joy_index = -1
	elif event is InputEventScreenDrag and event.index == joy_index:
		joy_pos = event.position
		var delta: Vector2 = joy_pos - joy_origin
		# The base follows the thumb so direction changes stay quick.
		if delta.length() > JOY_RADIUS:
			joy_origin = joy_pos - delta.normalized() * JOY_RADIUS
