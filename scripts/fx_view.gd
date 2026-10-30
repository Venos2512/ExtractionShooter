class_name FxView
extends Node2D
## Additive layer: muzzle flashes, explosions, lamp pools and crate beams.

var game: Game


func setup(g: Game) -> void:
	game = g


func _draw() -> void:
	if game == null:
		return
	var blob := game.art.blob
	var v := game.view
	for r in game.level.rooms:
		if r.id == game.level.roof_id or r.bright < 0.3:
			continue
		var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.009 + r.flicker) * sin(Time.get_ticks_msec() * 0.023 + r.flicker)
		var a := (r.bright - 0.2) * 0.34 * flicker
		_glow(blob, v.pt(r.lamp_x, 0.0, game.t.depth * 0.5, r.f), 210.0 * v.s_at(game.t.depth * 0.5), 0.34, Color(1.0, 0.9, 0.7, a))
		_glow(blob, v.pt(r.lamp_x, game.t.room_h * 0.85, game.t.depth * 0.55, r.f), 70.0, 1.0, Color(1.0, 0.92, 0.75, a * 1.2))
	for c in game.level.crates:
		if c.opened or c.room.bright < 0.25:
			continue
		var color: Color = Game.RARITY_COLORS[c.rarity]
		color.a = 0.28 * c.room.bright
		var base := v.pt(c.x, 0.0, c.z, c.f)
		var tip := v.pt(c.x, 160.0, c.z, c.f)
		draw_line(base, tip, color, 14.0)
		color.a = 0.5 * c.room.bright
		draw_line(base, tip, color, 4.0)
		_glow(blob, base, 58.0, 0.4, Color(color, 0.5 * c.room.bright))
	for g in game.fx.glows:
		var col := g.color
		col.a *= g.life / g.max_life
		_glow(blob, v.pt(g.x, g.h, g.z, g.f), g.radius * v.s_at(g.z), g.squash, col)
	var p := game.player
	# The hero carries a small pool of light into dark rooms.
	_glow(blob, v.pt(p.x, 0.0, p.z, p.f), 170.0, 0.36, Color(1.0, 0.95, 0.8, 0.14))
	if p.lasers > 0:
		for n in p.lasers:
			var tip := game.weapons.laser_tip(n)
			var a := v.pt(p.x, Weapons.MUZZLE_H, p.z, p.f)
			var b := v.pt(tip.x, Weapons.MUZZLE_H, tip.y, p.f)
			draw_line(a, b, Color(0.3, 0.7, 1.0, 0.35), 12.0)
			draw_line(a, b, Color(0.8, 0.95, 1.0, 0.8), 3.0)


func _glow(tex: Texture2D, center: Vector2, radius: float, squash: float, color: Color) -> void:
	var size := Vector2(radius * 2.0, radius * 2.0 * squash)
	draw_texture_rect(tex, Rect2(center - size * 0.5, size), false, color)
