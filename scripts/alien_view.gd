class_name AlienView
extends Node2D
## Draws aliens by placing each sprite from the Figma drawing on its bone.
## A node of its own because these sprites filter smoothly, unlike the pixel art.

## Going hard, it leaves pale copies of itself behind, one this often, each lasting this long.
const GHOST_FROM := 0.35
const GHOST_EVERY := 0.04
const GHOST_LIFE := 0.14
const GHOST_TINT := Color(0.45, 0.8, 1.0)
const GHOST_ALPHA := 0.26
const SPARK := Color(1.0, 0.62, 0.18)
const DUST := Color(0.72, 0.84, 1.0)
## A spark is drawn as the line it just travelled, in seconds of its speed.
const SPARK_STREAK := 0.018
## How much bigger an abdomen swollen to burst is.
const SWELL_GAIN := 0.5
## Over each alien in the test level: its frenzy, going from cold to hot.
const FRENZY_TEXT_SIZE := 20
const FRENZY_TEXT_AT := Vector2(-20.0, -52.0)
const FRENZY_COLD := Color(0.6, 0.85, 1.0)
const FRENZY_HOT := Color(1.0, 0.5, 0.15)

var flash_time := 0.07
var show_frenzy := false
## Returns the aliens to draw, bottom first.
var source: Callable


func setup(hit_flash_time: float, get_aliens: Callable) -> void:
	flash_time = hit_flash_time
	source = get_aliens


func _draw() -> void:
	if source.is_null():
		return
	for bug: Bug in source.call():
		_draw_alien(bug)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_alien(bug: Bug) -> void:
	var rig := bug.rig
	var art := rig.art
	var tint := Color(1, 1, 1, rig.alpha * rig.visibility())
	var flash := clampf(bug.flash / flash_time, 0.0, 1.0)
	var pose: Array = []
	for layer in art.order:
		var bones: Variant = rig.bones.get(layer)
		if bones == null:
			_body_part(rig, layer, pose)
		else:
			_limb(rig, layer, bones, pose)
	_draw_ghosts(rig, pose)
	for row: Array in pose:
		_part(art, row[0], row[1], tint, flash)
	_draw_chips(rig)
	if show_frenzy and rig.state != AlienRig.State.DEAD and rig.cloak < 0.5:
		_draw_frenzy(rig)


func _draw_ghosts(rig: AlienRig, pose: Array) -> void:
	if rig.drive >= GHOST_FROM and rig.cloak < 0.5 and rig.clock - rig.ghost_at >= GHOST_EVERY:
		rig.ghost_at = rig.clock
		rig.ghosts.append([rig.clock, pose])
	while not rig.ghosts.is_empty() and rig.clock - float(rig.ghosts[0][0]) > GHOST_LIFE:
		rig.ghosts.pop_front()
	for ghost: Array in rig.ghosts:
		var fade := 1.0 - (rig.clock - float(ghost[0])) / GHOST_LIFE
		var color := Color(GHOST_TINT, GHOST_ALPHA * fade * rig.alpha)
		for row: Array in ghost[1]:
			var part: AlienArt.Part = rig.art.parts[row[0]]
			draw_set_transform_matrix(row[1])
			draw_texture_rect_region(rig.art.flash, part.rect, part.region, color)


func _draw_chips(rig: AlienRig) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for chip in rig.chips:
		var u := chip.age / chip.life
		if chip.hot:
			draw_line(chip.at, chip.at - chip.v * SPARK_STREAK, Color(SPARK, 1.0 - u * u), chip.size * (1.0 - u * 0.5), true)
		else:
			draw_circle(chip.at, chip.size * (1.0 + u), Color(DUST, 0.32 * (1.0 - u)), true, -1.0, true)


func _draw_frenzy(rig: AlienRig) -> void:
	var font := ThemeDB.fallback_font
	var at := rig.body + FRENZY_TEXT_AT
	var text := "%.2f" % rig.frenzy
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FRENZY_TEXT_SIZE, 5, Color(0, 0, 0, rig.alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FRENZY_TEXT_SIZE, Color(FRENZY_COLD.lerp(FRENZY_HOT, rig.frenzy), rig.alpha))


func _body_part(rig: AlienRig, layer: String, pose: Array) -> void:
	var m := rig.body_transform()
	if layer == "abdomen":
		# The abdomen hangs off the thorax and sways as the body moves and breathes.
		var thorax: Rect2 = rig.art.parts["thorax"].rect
		var hinge := thorax.position + Vector2(2.0, thorax.size.y * 0.5)
		var fill := Vector2.ONE * (1.0 + rig.swell * SWELL_GAIN)
		m = m * Transform2D(rig.abdomen_sway, fill, 0.0, hinge) * Transform2D(0.0, -hinge)
	elif layer == "head":
		var head: Rect2 = rig.art.parts["head"].rect
		var neck := head.position + Vector2(1.0, head.size.y * 0.5)
		m = m * Transform2D(rig.head_turn, neck) * Transform2D(0.0, -neck)
	pose.append([layer, m])


## Every segment turns about its first joint, from where the drawing has it to where
## the bones are now.
func _limb(rig: AlienRig, layer: String, bones: Array[Vector2], pose: Array) -> void:
	var rest: Array[Vector2] = rig.art.limbs[layer]
	var side := rig.side
	var scale_xy := Vector2(side * AlienRig.SCALE, AlienRig.SCALE)
	for i in 3:
		var a := rest[i]
		var d := rest[i + 1] - a
		var turn := (bones[i + 1] - bones[i]).angle() - Vector2(d.x * side, d.y).angle()
		var m := Transform2D(turn, scale_xy, 0.0, bones[i])
		var fit: float = rig.stretch[layer][i] if rig.stretch.has(layer) else 1.0
		if not is_equal_approx(fit, 1.0):
			# Stretches along the bone only, so the segment keeps its width.
			var along := d.angle()
			m = m * Transform2D(along, Vector2.ZERO) * Transform2D(0.0, Vector2(fit, 1.0), 0.0, Vector2.ZERO) * Transform2D(-along, Vector2.ZERO)
		pose.append(["%s.seg_%d" % [layer, i + 1], m * Transform2D(0.0, -a)])
		if i < 2:
			# Joints are round, so they only need to follow the joint and the facing.
			var j := rest[i + 1]
			var jm := Transform2D(rig.angle, scale_xy, 0.0, bones[i + 1])
			pose.append(["%s.joint_%d" % [layer, i + 1], jm * Transform2D(0.0, -j)])


func _part(art: AlienArt, key: String, m: Transform2D, tint: Color, flash: float) -> void:
	var part: AlienArt.Part = art.parts[key]
	draw_set_transform_matrix(m)
	draw_texture_rect_region(art.atlas, part.rect, part.region, tint)
	if flash > 0.0:
		draw_texture_rect_region(art.flash, part.rect, part.region, Color(1, 1, 1, flash * tint.a))
