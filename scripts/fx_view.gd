class_name FxView
extends Node2D
## Additive layer: muzzle flashes, explosions, lamp pools, crate beams, bile glow.

var game: Game


func setup(g: Game) -> void:
	game = g


func _draw() -> void:
	if game == null:
		return
	var blob := game.art.blob
	var v := game.view
	var now := Time.get_ticks_msec()
	for r in game.level.rooms:
		if r.kind == Level.Kind.GOAL or r.kind == Level.Kind.SAMPLE or r.bright < 0.3:
			continue
		var flicker := 0.85 + 0.15 * sin(now * 0.009 + r.flicker) * sin(now * 0.023 + r.flicker)
		var a := (r.bright - 0.2) * 0.34 * flicker
		_glow(blob, v.pt(r.lamp_x, 4.0, r.f), 190.0, 0.14, Color(1.0, 0.85, 0.6, a))
		_glow(blob, v.pt(r.lamp_x, game.t.room_h * 0.85, r.f), 90.0, 1.0, Color(1.0, 0.85, 0.6, a * 1.1))
	for c in game.level.crates:
		if c.opened or c.room.bright < 0.25:
			continue
		var color: Color = Game.RARITY_COLORS[c.rarity]
		color.a = 0.28 * c.room.bright
		var base := v.pt(c.x, 0.0, c.f)
		var tip := v.pt(c.x, 160.0, c.f)
		draw_line(base, tip, color, 14.0)
		color.a = 0.5 * c.room.bright
		draw_line(base, tip, color, 4.0)
		_glow(blob, base, 58.0, 0.3, Color(color, 0.5 * c.room.bright))
	for bug in game.horde.list:
		if bug.dead or bug.falling:
			continue
		if bug.kind == Bug.Kind.BLOATER or bug.kind == Bug.Kind.CHARGER:
			# Sacs breathe, so the dangerous ones stand out in a dark room.
			var pulse := 0.3 + 0.2 * sin(now * 0.008 + bug.x)
			var size := 48.0 if bug.kind == Bug.Kind.BLOATER else 80.0
			var at := v.pt(bug.x - bug.facing * bug.radius * 0.5, bug.h + bug.mid, bug.f)
			_glow(blob, at, size, 1.0, Color(1.0, 0.5, 0.1, pulse))
	for g in game.fx.glows:
		var col := g.color
		col.a *= g.life / g.max_life
		_glow(blob, v.pt(g.x, g.h, g.f), g.radius, g.squash, col)
	var p := game.player
	# The hero carries a small pool of light into dark rooms.
	_glow(blob, v.pt(p.x, 40.0 + p.h, p.f), 150.0, 0.8, Color(0.7, 0.85, 1.0, 0.1))
	if p.lasers > 0:
		for n in p.lasers:
			var tip := game.weapons.laser_tip(n)
			var a := v.pt(p.x, p.h + Weapons.MUZZLE_H, p.f)
			var b := v.pt(tip.x, tip.y, p.f)
			draw_line(a, b, Color(0.3, 0.7, 1.0, 0.35), 12.0)
			draw_line(a, b, Color(0.8, 0.95, 1.0, 0.8), 3.0)


func _glow(tex: Texture2D, center: Vector2, radius: float, squash: float, color: Color) -> void:
	var size := Vector2(radius * 2.0, radius * 2.0 * squash)
	draw_texture_rect(tex, Rect2(center - size * 0.5, size), false, color)
